# Inference Engineering — From One Token to Production GPU Serving

This guide explains how a trained model becomes a reliable, measurable, and economical production service. It follows the public topic surface of Fanout's [Inference Engineering course](https://fanout.sh/inference-eng) and [LLM inference engineer roadmap](https://fanout.sh/blog/llm-inference-engineer-roadmap), but all questions, explanations, examples, and exercises below are original.

Inference engineering is not “make tokens per second as large as possible.” It is the work of meeting a defined quality, latency, throughput, reliability, security, and cost contract for a real workload. Every optimization in this guide begins with a bottleneck and ends with evidence.

**Related foundations:** [AI Engineering Design](ai-engineering-design.md) explains product/model/retrieval/tool contracts, [AI Mathematics & Research Workbook](ai-math-research-workbook.md) builds the required math and experiment skills, and [AI System Design](ai-system-design.md) covers broader AI architectures.

## Table of Contents

1. [The request lifecycle: tokenization, prefill, decode, and streaming](#inf-m1-the-request-lifecycle-tokenization-prefill-decode-and-streaming)
2. [Reproducible benchmarking and inference SLOs](#inf-m2-reproducible-benchmarking-and-inference-slos)
3. [Weight, activation, workspace, and KV-cache capacity](#inf-m3-weight-activation-workspace-and-kv-cache-capacity)
4. [Continuous batching, scheduling, PagedAttention, and prefix caching](#inf-m4-continuous-batching-scheduling-pagedattention-and-prefix-caching)
5. [Single-GPU optimization: quantization, kernels, compilation, and profiling](#inf-m5-single-gpu-optimization-quantization-kernels-compilation-and-profiling)
6. [Speculative decoding and fair engine comparison](#inf-m6-speculative-decoding-and-fair-engine-comparison)
7. [Multi-GPU parallelism and Mixture-of-Experts inference](#inf-m7-multi-gpu-parallelism-and-mixture-of-experts-inference)
8. [Long context, tiered KV storage, and prefill/decode disaggregation](#inf-m8-long-context-tiered-kv-storage-and-prefilldecode-disaggregation)
9. [Production model lifecycle, routing, and autoscaling](#inf-m9-production-model-lifecycle-routing-and-autoscaling)
10. [Observability, reliability, admission control, and security](#inf-m10-observability-reliability-admission-control-and-security)
11. [Inference economics and capacity planning](#inf-m11-inference-economics-and-capacity-planning)
12. [Specialized workloads, mini-engine design, and research reproduction](#inf-m12-specialized-workloads-mini-engine-design-and-research-reproduction)

### Core vocabulary

| Term | Meaning |
|---|---|
| Prefill | Processes the prompt, usually many tokens in parallel, and creates the initial KV cache |
| Decode | Generates output autoregressively, normally one accepted token per sequence per iteration |
| TTFT | Time to first token: queueing + tokenization + prefill + initial decode/streaming overhead |
| ITL / TPOT | Inter-token latency / time per output token after the first token |
| E2E latency | Arrival until the request finishes or is cancelled |
| Throughput | Completed requests or processed tokens per unit time, regardless of whether their SLO was met |
| Goodput | Work completed while satisfying the declared latency and correctness constraints |
| KV cache | Per-sequence keys and values retained so decode does not recompute attention state for earlier tokens |
| Active sequence | A request currently occupying scheduler and KV-cache resources |
| Prefix cache | Reuses KV blocks for an identical token prefix, model revision, and compatible inference configuration |
| Open-loop load | Sends requests according to an arrival process even when earlier requests are still running |
| Closed-loop load | A fixed client population sends a new request only after the prior request completes |

### Fanout public curriculum coverage

This map includes the module names publicly visible on Fanout, including modules whose lesson bodies require a paid plan. The repository material is an original treatment of those topics.

| Public curriculum space/modules | Covered here |
|---|---|
| Foundations, prerequisites, first LLM | INF-M1 request lifecycle, INF-M2 measurement, INF-M3 capacity, plus the linked math workbook |
| One token; prefill, decode, KV cache and memory | INF-M1 and INF-M3 |
| Benchmark correctly; break one GPU | INF-M2, INF-M3, and INF-M5 |
| Real serving engine; continuous batching/scheduling; PagedAttention; optimize one GPU | INF-M4 and INF-M5 |
| Prefill/prefix optimization; quantization/KV compression; profiling/GPU performance | INF-M4 and INF-M5 |
| Triton/kernel engineering; attention optimization; compilation/CUDA graphs; speculative decoding; engine comparison | INF-M5 and INF-M6 |
| Multi-GPU parallelism; MoE inference | INF-M7 |
| Long context/tiered KV; prefill/decode disaggregation | INF-M8 |
| Production lifecycle; routing/autoscaling/orchestration | INF-M9 |
| Observability/reliability/security; inference economics/capacity planning | INF-M10 and INF-M11 |
| Structured/tool, Multi-LoRA, multimodal, agentic, reasoning, batch, RL-rollout, and diffusion inference | INF-M12 |
| Read an engine; build a mini engine; reproduce research; final capstone | INF-M12 and its cumulative build exercise |

---

## INF-M1. The Request Lifecycle: Tokenization, Prefill, Decode, and Streaming

**Question:** What happens from the moment an inference request arrives until the final token is streamed, and why must prefill and decode be measured separately?

**Answer:** The server validates the request, selects a model/configuration, tokenizes the input, waits for admission, executes prefill over the prompt, allocates and populates KV-cache blocks, repeatedly schedules decode iterations, samples or constrains each next token, detokenizes output, streams chunks, and finally releases sequence state. Prefill is usually dominated by processing the prompt with large parallel matrix operations. Decode repeatedly reads model weights and a growing KV cache for a small amount of new-token work. They therefore respond differently to prompt length, batch size, memory bandwidth, kernels, and hardware.

**What problem does it solve?** A phase-aware model lets engineers attribute latency and memory correctly. Without it, a single “tokens per second” number hides queueing, long prompts, slow first-token experience, decode jitter, network buffering, and abandoned work.

**Before this concept:** The team measured only total response time from a development prompt. When users complained about a blank screen, engineers optimized decode throughput even though most delay came from queueing and long-prompt prefill.

❌ **Wrong/before example — one timer hides every phase:**

```python
started = time.perf_counter()
text = model.generate(prompt, max_new_tokens=256)
print({"latency_seconds": time.perf_counter() - started})
```

This does not record token counts, first-token time, queue delay, prefill duration, per-token gaps, cancellation, model revision, sampling settings, or whether output semantics were correct.

✅ **After/correct example — trace the request as a state machine:**

```python
trace = {
    "request_id": request_id,
    "model_revision": model_revision,
    "arrival_ns": monotonic_ns(),
    "input_tokens": None,
    "output_tokens": 0,
}

tokens = tokenizer.encode(prompt)
trace["input_tokens"] = len(tokens)
trace["tokenized_ns"] = monotonic_ns()

ticket = scheduler.admit(tokens, max_new_tokens=256)
trace["admitted_ns"] = monotonic_ns()

async for token in engine.stream(ticket):
    now = monotonic_ns()
    if trace["output_tokens"] == 0:
        trace["first_token_ns"] = now
    trace["output_tokens"] += 1
    trace.setdefault("token_times_ns", []).append(now)
    yield tokenizer.decode([token])

trace["finished_ns"] = monotonic_ns()
metrics.record(trace)
```

The example is illustrative: production telemetry should record bounded histograms or sampled traces rather than an unbounded timestamp list for every token.

**How it works now:** Queue time is separated from execution. TTFT is calculated from arrival to first streamed token. Inter-token gaps describe decode experience. Prompt and output lengths explain workload shape. Cancellation releases scheduler and KV resources. A trace links gateway, tokenizer, scheduler, engine, GPU, and stream so latency has an owner.

### Mechanism and mental model

```text
request
  -> validate/auth/rate limit
  -> select model + adapter + decoding policy
  -> tokenize
  -> admission queue
  -> prefill(prompt tokens) -> initial KV cache
  -> decode step -> sample/constraint -> stream token
       ^                                  |
       +----------- repeat ---------------+
  -> finish/cancel/error -> free KV blocks
```

Autoregressive generation creates a sequential dependency between accepted output tokens. Kernels can parallelize work within an iteration and engines can batch many sequences, but token `t + 1` for one sequence depends on the state after token `t`. Streaming improves perceived responsiveness; it does not reduce the model's compute by itself.

**Trade-offs and when not to use it:** Not every model is autoregressive text. Encoder-only classification, embedding, reranking, diffusion, speech, and vision workloads have different stages and metrics. Do not force TTFT/ITL terminology onto a batch classifier. Extremely detailed per-token tracing can add overhead and sensitive content risk, so aggregate timings and sample traces deliberately.

**Production checks:**

- Record queue, tokenize, prefill, first-token, decode, stream, and total durations separately.
- Partition latency by model revision, prompt/output length bucket, priority, hardware, adapter, and success/cancellation result.
- Confirm proxies and clients do not buffer streaming chunks; measure client-observed TTFT as well as server TTFT.
- Stop generation promptly on disconnect or deadline and verify KV blocks return to the free pool.
- Bound input, requested output, stop sequences, and structured-decoding complexity before admission.
- Validate output semantics and safety; fast incorrect output is not successful inference.

**Try it:** Run the same model with prompt lengths 128, 2,048, and 16,384 tokens and output lengths 32 and 512. Record queue time, TTFT, median/p99 ITL, E2E latency, GPU memory, and output correctness. Explain which phase changes and why.

---

## INF-M2. Reproducible Benchmarking and Inference SLOs

**Question:** How do you benchmark an inference service so another engineer can reproduce the result and so the benchmark predicts production behavior?

**Answer:** Define a workload distribution, quality target, arrival model, SLO, hardware/software manifest, warm-up policy, and failure accounting before measuring. Report latency percentiles, throughput, goodput, errors, cancellations, token lengths, memory, and cost at several offered-load points. A useful benchmark compares the same model revision, precision, tokenizer, sampling/structured-output policy, dataset, and hardware. It includes low-load latency and saturation behavior rather than publishing the single best tokens-per-second number.

**What problem does it solve?** Reproducible benchmarks prevent invalid engine/hardware comparisons and reveal where an inference service stops meeting user-facing objectives.

**Before this concept:** One engineer ran a short prompt after the model was warm; another included model download and compilation. One used batch size 64, another measured an interactive stream. The resulting numbers looked comparable but answered different questions.

❌ **Wrong/before example — benchmark the fastest successful request:**

```bash
time curl -s http://localhost:8000/generate \
  -d '{"prompt":"Hello","max_tokens":16}'

# Report: "Our server handles 900 tokens/s."
```

This does not state concurrency, arrival rate, prompt/output distributions, failed requests, latency constraint, warm state, quality, or whether “tokens/s” means input, output, or both.

✅ **After/correct example — immutable run manifest plus workload result:**

```yaml
run_id: llama8b-fp8-a100-2026-11-13-01
model_revision: exact-content-hash
tokenizer_revision: exact-content-hash
engine: vllm
engine_version: pinned-version
precision: fp8-weights-fp16-kv
hardware:
  gpu: A100-80GB
  count: 1
workload:
  arrival: open-loop-poisson
  offered_rps: [1, 2, 4, 8, 12]
  input_tokens: recorded-distribution-v3
  output_tokens: recorded-distribution-v3
  max_concurrency: 256
slo:
  ttft_p99_ms: 1200
  itl_p99_ms: 80
  success_rate: 0.995
quality_gate: task-suite-v7
warmup_requests: 100
measurement_minutes: 20
```

**How it works now:** The harness validates response semantics, drives a controlled arrival pattern, records every completion/error/cancellation, scrapes server/GPU metrics, and emits both a manifest and raw/aggregated results. A load curve shows the knee where queueing rises and goodput falls, which becomes the operating limit—not the last point that avoided a crash.

### Metrics that answer different questions

| Metric | What it tells you | Common misuse |
|---|---|---|
| TTFT p50/p95/p99 | Prompt/queue responsiveness | Reporting only the mean hides long tails |
| ITL/TPOT | Streaming smoothness | Mixing prefill time into decode time |
| E2E latency | Full request experience | Comparing requests with different token lengths without buckets |
| Output tokens/s | Decode throughput | Ignoring input-token work and quality |
| Total tokens/s | Overall processing | Treating input and output tokens as equal-cost units |
| Goodput | Work meeting the SLO | Counting late/abandoned responses as success |
| Error/cancel rate | Reliability and wasted work | Dropping failed requests from the denominator |
| GPU utilization | Device activity | Assuming high utilization means useful, SLO-compliant work |

Open-loop tests expose overload because arrivals continue while the server slows. Closed-loop tests model a fixed client population but can hide saturation through coordinated omission: clients stop sending while they wait. Both can be useful when their intent is explicit.

**Trade-offs and when not to use it:** A synthetic trace is easier to share but may omit real length correlations, prefix reuse, tool calls, priorities, cancellations, and bursts. A production trace is more representative but must be sanitized and may encode yesterday's product behavior. Microbenchmarks are valuable for kernels and isolated phases, but they cannot replace end-to-end load tests.

**Production checks:**

- Pin model/tokenizer/engine/driver/container revisions and record GPU topology, clocks/power policy where relevant.
- Warm model weights, kernels, allocators, and representative shapes; separately measure cold-start behavior.
- Include invalid inputs, timeouts, disconnects, and OOM/rejection results in the report.
- Preserve prompt/output length distributions and their correlation; do not benchmark every request at one length.
- Verify output quality after quantization, compilation, engine changes, and speculative decoding.
- Plot offered load against TTFT, ITL, goodput, queue depth, KV occupancy, and errors to locate safe headroom.

**Try it:** Build an open-loop test at five arrival rates and a closed-loop test with 32 clients. Use the same request corpus. Explain why their throughput and tail latency differ, identify coordinated omission, and select a production operating point with failure headroom.

---

## INF-M3. Weight, Activation, Workspace, and KV-Cache Capacity

**Question:** How do you determine whether a model and target concurrency fit on a GPU before attempting to serve it?

**Answer:** Account separately for model weights, runtime/allocator overhead, temporary activations and kernel workspaces, CUDA graphs or compiled-shape pools, adapters, and KV cache for active sequences. Weight memory is approximately parameter count multiplied by bytes per stored parameter, plus quantization scales/metadata. KV bytes per token are approximately `2 × layers × KV_heads × head_dim × bytes_per_KV_element`; multiply by cached tokens across active sequences. Then reserve safety headroom and validate the estimate with measured peak memory under the real scheduler and workload.

**What problem does it solve?** Capacity arithmetic catches impossible configurations, prevents predictable OOM loops, and connects context/concurrency limits to an explicit memory budget.

**Before this concept:** The team divided GPU memory by model weight-file size and assigned everything left to requests. Runtime workspaces, fragmentation, adapters, and long-output KV growth pushed the worker into repeated OOM and restart cycles.

❌ **Wrong/before example — weight files are not the whole serving footprint:**

```python
free_for_users_gib = gpu_memory_gib - model_file_size_gib
max_users = int(free_for_users_gib / 0.1)  # unexplained 100 MiB/user
```

✅ **After/correct example — explicit, reviewable estimate:**

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class ModelShape:
    parameters: int
    layers: int
    kv_heads: int
    head_dim: int
    weight_bytes: float
    kv_bytes: int

def estimate_bytes(shape: ModelShape, cached_tokens: int,
                   runtime_overhead_bytes: int) -> dict[str, int]:
    weights = int(shape.parameters * shape.weight_bytes)
    kv_per_token = (
        2 * shape.layers * shape.kv_heads * shape.head_dim * shape.kv_bytes
    )
    kv_cache = kv_per_token * cached_tokens
    return {
        "weights": weights,
        "kv_per_token": kv_per_token,
        "kv_cache": kv_cache,
        "runtime_overhead": runtime_overhead_bytes,
        "estimated_total": weights + kv_cache + runtime_overhead_bytes,
    }
```

`weight_bytes` must include the actual representation and metadata rather than assuming every “4-bit” checkpoint costs exactly 0.5 bytes per parameter. `cached_tokens` is the total live token count after prefix sharing, eviction, and scheduler policy—not merely `concurrency × maximum_context` unless the engine really reserves that much.

**How it works now:** Admission estimates the KV blocks a request may consume and rejects, queues, truncates, or routes it before unsafe allocation. Dashboards compare estimated and actual weight/runtime/KV pools. Load tests increase context and concurrency until the controlled limit, confirming that the worker rejects excess work rather than crashing.

### Worked capacity example

Assume 32 transformer layers, 8 KV heads, head dimension 128, and FP16 KV values:

```text
KV bytes/token = 2 (K,V) × 32 × 8 × 128 × 2 bytes
               = 131,072 bytes/token
               = 128 KiB/token

One 8,192-token sequence ≈ 1 GiB of KV cache.
Twenty such fully occupied sequences ≈ 20 GiB before weights and runtime overhead.
```

Grouped-query or multi-query attention reduces KV heads and therefore KV memory. It does not reduce all model weights or every compute cost. Prefix sharing can reduce duplicate KV allocation only for byte/token-identical compatible prefixes routed to a worker that still owns those blocks.

**Trade-offs and when not to use it:** Formulas are planning tools, not substitutes for measurement. Engines use different block sizes, graph captures, attention backends, allocator policies, and temporary buffers. Quantization may reduce weights but add metadata or use larger KV precision. Reserving maximum output for every request is safe but wastes capacity; optimistic allocation improves utilization but requires preemption or rejection when sequences grow.

**Production checks:**

- Record model, adapter, runtime, KV, graph/workspace, and unclassified GPU memory separately where the engine exposes them.
- Track KV block occupancy, allocation failures, fragmentation/waste, preemption, eviction, and prefix-cache hit rate.
- Enforce model-specific input/output/concurrency limits at admission, not after GPU allocation fails.
- Test the longest allowed prompts and outputs concurrently, including cancellations and mixed lengths.
- Leave headroom for driver/runtime variance, rolling upgrades, failover traffic, and metrics/profiling overhead.
- Treat repeated OOM restarts as an admission-control failure; do not rely on the orchestrator to make unsafe load healthy.

**Try it:** Pick one open model and exact checkpoint format. Calculate weight memory and KV bytes/token from its configuration. Estimate capacity for three prompt/output distributions, then run the engine and explain every material difference between estimated and measured peak memory.

---

## INF-M4. Continuous Batching, Scheduling, PagedAttention, and Prefix Caching

**Question:** How should an inference engine schedule variable-length requests while using GPU compute and KV memory efficiently without starving interactive users?

**Answer:** Use iteration-level or continuous batching so completed sequences leave and waiting sequences enter between decode iterations. Manage KV state in blocks/pages rather than reserving one maximum-length contiguous region per request. Define admission, fairness, priority, preemption, and chunked-prefill policies from the SLO. Reuse prefix KV blocks only when the model, adapter, tokenizer, exact token prefix, positional semantics, and security boundary are compatible.

**What problem does it solve?** Static batches suffer from stragglers and poor utilization. Naive KV allocation wastes memory. Unbounded first-come-first-served queues let long prompts or low-priority jobs destroy TTFT for everyone.

**Before this concept:** The server waited to fill a batch, ran it until every sequence finished, and reserved the maximum context for each request. A ten-token response occupied memory and a batch slot until a 2,000-token response completed.

❌ **Wrong/before example — static batches and no fairness:**

```python
while True:
    batch = [queue.get() for _ in range(MAX_BATCH)]
    outputs = generate_until_every_request_finishes(batch)
    return_all(outputs)
```

This blocks new arrivals behind the longest sequence, cannot stream fairly, and treats `MAX_BATCH` as if requests had equal prompt length, output length, and KV cost.

✅ **After/correct example — scheduler state is explicit:**

```python
while server_running:
    release_finished_and_cancelled_sequences()
    reclaim_or_cache_their_kv_blocks()

    while capacity_for_more_work():
        request = admission_queue.pick_next(
            policy="weighted-fair",
            estimated_kv_blocks=kv_estimator,
        )
        if request is None:
            break
        allocate_blocks_or_preempt(request)
        active.add(request)

    microbatch = scheduler.build_iteration(active)
    logits = model.execute(microbatch)
    sample_stream_and_update_state(microbatch, logits)
```

**How it works now:** Every scheduling iteration accounts for prefill chunks, decode sequences, KV blocks, priority budgets, waiting time, and deadlines. Finished/cancelled work releases capacity quickly. Paged allocation reduces internal fragmentation and allows non-contiguous growth. Prefix-aware routing improves reuse without mixing tenant-private state.

### Scheduling decisions that must be intentional

- **Continuous batching:** admits/removes sequences between iterations instead of waiting for a whole static batch.
- **Chunked prefill:** divides very long prompts so one prefill does not monopolize the GPU and inflate decode ITL for active streams.
- **Preemption:** pauses or recomputes lower-priority sequences when memory is scarce; it trades wasted work for SLO protection.
- **Priority/fairness:** prevents batch jobs from starving interactive traffic and prevents a constant high-priority stream from starving everything else.
- **Paged KV allocation:** maps logical sequence blocks to physical GPU blocks, reducing contiguous reservation waste.
- **Prefix caching:** reuses already-computed KV blocks for identical compatible prefixes; it reduces prefill work but consumes cache capacity and depends on routing locality.

PagedAttention and FlashAttention solve different problems. PagedAttention is principally a serving-time KV-memory-management design. FlashAttention is an IO-aware exact attention algorithm that reduces data movement between HBM and on-chip memory. An engine can use both.

**Trade-offs and when not to use it:** Aggressive batching improves throughput but can worsen TTFT/ITL. Tiny chunks improve fairness but add scheduling and kernel overhead. Prefix caching can waste memory when reuse is low and creates privacy risks if cache identities ignore tenant/model/adapter boundaries. Preemption may cause expensive recomputation. Simple static batching remains appropriate for homogeneous offline jobs.

**Production checks:**

- Track waiting/running/preempted sequences, queue age by priority, batch token count, and scheduler decision reasons.
- Track KV block occupancy, allocation failure, fragmentation, prefix hit/miss/eviction, and reclaimed blocks after cancellation.
- Load-test mixed short/long prompts and outputs; verify p99 interactive TTFT/ITL while batch traffic is present.
- Include tenant, model revision, adapter, token sequence, and relevant decoding/context configuration in prefix-cache identity.
- Test starvation, deadline expiry, preemption loops, and cancellation during prefill and decode.
- Compare throughput gains with goodput and fairness; high GPU occupancy is not sufficient.

**Try it:** Write a scheduler simulator with short interactive and long batch requests. Compare static batching, first-come continuous batching, and weighted-fair continuous batching. Plot TTFT, ITL proxy, completion time, starvation, KV occupancy, and useful work discarded by preemption.

---

## INF-M5. Single-GPU Optimization: Quantization, Kernels, Compilation, and Profiling

**Question:** How do you choose among quantization, FlashAttention, kernel fusion, compilation, CUDA graphs, and KV compression instead of enabling every optimization blindly?

**Answer:** Profile the target workload and separate prefill from decode. Identify whether the limiting resource is weight/KV memory capacity, HBM bandwidth, tensor-core compute, CPU/tokenizer work, kernel-launch overhead, synchronization, or poor shapes. Apply the technique that targets that bottleneck, confirm kernel/hardware support, then remeasure latency, throughput, memory, energy, and quality with the same manifest.

**What problem does it solve?** Hardware-aware optimization turns a measured bottleneck into a controlled experiment. It prevents a lower-precision or more complex configuration from becoming slower, less accurate, or less reliable because the runtime lacks an efficient path.

**Before this concept:** The team enabled 4-bit weights because the checkpoint was smaller, assumed smaller meant faster, and published the best short-prompt throughput. In production, dequantization overhead and an untuned kernel worsened p99 decode latency.

❌ **Wrong/before example — change five variables and claim a cause:**

```text
baseline: engine A, BF16, eager mode, 2K prompts, greedy decode
candidate: engine B, INT4, compiled graphs, 8K prompts, speculative decode
conclusion: "INT4 is 2.4x faster"
```

✅ **After/correct example — one hypothesis per experiment:**

```yaml
hypothesis: "weight-only INT4 improves decode at concurrency 1-16 because weight reads dominate"
fixed:
  model_revision: exact-hash
  engine_version: pinned
  prompt_output_corpus: trace-v4
  sampling: identical-seeds-and-policy
  hardware_power_clocks: recorded
compare:
  - bf16-baseline
  - int4-weight-only
measure:
  - quality_suite
  - ttft_and_itl_percentiles
  - output_tokens_per_second
  - peak_weight_kv_workspace_memory
  - gpu_power_and_cost
```

**How it works now:** A profiler attributes time to kernels, memory transfers, launch gaps, synchronization, and CPU stalls. The engineer changes one technique, records exact artifacts/configuration, checks correctness, and keeps the baseline. Unsupported or workload-negative optimizations are removed rather than kept because they are fashionable.

### Optimization-to-bottleneck map

| Technique | Primarily targets | Can disappoint when |
|---|---|---|
| Weight quantization | Weight memory and bandwidth | Kernels/dequantization are poor or quality falls |
| KV quantization/compression | Long-context/concurrency KV capacity and bandwidth | Scale metadata/conversion costs dominate or attention quality degrades |
| FlashAttention | Attention IO and intermediate-memory traffic | Attention is not the bottleneck or shape/hardware path is unsupported |
| Kernel fusion | HBM round trips and launch overhead | Fused kernel reduces occupancy or makes uncommon shapes slow |
| Compilation | Graph/operator optimization and specialization | Dynamic shapes cause recompilation or graph breaks |
| CUDA graphs | Repeated launch overhead for stable shapes | Shape/batch diversity requires too many captures and memory pools |
| Prefix caching | Repeated prefill work | Prefix reuse/locality is low or cache memory displaces active KV |
| Chunked prefill | Interactivity/fair scheduling | Chunk overhead outweighs benefit for homogeneous offline loads |

Quantization names are incomplete without dimensions: weight precision, activation precision, KV precision, calibration method/data, group size, scale granularity, kernel, and hardware. “INT4” or “FP8” alone does not identify a reproducible serving configuration.

**Trade-offs and when not to use it:** Optimizations increase artifact count, warm-up, build time, hardware coupling, debugging difficulty, and rollout risk. A larger precision with mature kernels can outperform a smaller format. CUDA graph pools and compiled variants consume memory. Do not optimize a model that already meets cost/SLO targets until the added operational complexity has a measured payoff.

**Production checks:**

- Preserve a high-precision baseline and a representative quality/eval suite.
- Profile both prefill and decode across length/concurrency buckets; averages hide phase regressions.
- Record engine/compiler/kernel/driver/GPU versions and exact quantization/calibration artifacts.
- Monitor graph-cache/recompilation behavior, fallback kernels, workspace growth, and numerical errors.
- Canary by workload class and keep rollback artifacts warm enough to meet recovery objectives.
- Re-run benchmarks after driver, runtime, model, adapter, or hardware changes; optimized paths are version-sensitive.

**Try it:** Compare BF16 with one supported weight-quantized configuration on the same GPU. Use short/long prompts and low/saturated concurrency. Report quality, TTFT, ITL, throughput, peak memory, power, and cost. State exactly when the quantized configuration wins and loses.

---

## INF-M6. Speculative Decoding and Fair Engine Comparison

**Question:** How does speculative decoding reduce autoregressive latency, and how do you compare inference engines without producing a misleading benchmark?

**Answer:** Speculative decoding uses a cheaper draft mechanism to propose several tokens, then the target model verifies them in fewer serial target-model steps using a correctness-preserving acceptance rule. It helps when proposal acceptance is high and draft/verification overhead is lower than the saved target decode steps. Engine comparison must align model/tokenizer revision, precision, attention/KV settings, context/output limits, sampling, structured constraints, hardware/topology, workload, warm-up, quality, and failure accounting.

**What problem does it solve?** Speculation attacks the serial decode bottleneck; disciplined comparison determines whether it helps this workload rather than relying on vendor defaults or an unrelated headline.

**Before this concept:** The team compared one engine using greedy decoding and prefix caching against another using temperature sampling without caching. The faster result was attributed to the engine even though the workloads and semantics differed.

❌ **Wrong/before example — report proposed tokens as useful output:**

```python
speedup = proposed_tokens_per_second / baseline_accepted_tokens_per_second
# Rejected proposals and verification work are ignored.
```

✅ **After/correct example — measure accepted progress and overhead:**

```python
result = {
    "accepted_output_tokens": accepted,
    "drafted_tokens": drafted,
    "acceptance_rate": accepted / max(drafted, 1),
    "target_verification_steps": target_steps,
    "draft_time_ms": draft_ms,
    "verification_time_ms": verify_ms,
    "ttft_ms": ttft_ms,
    "itl_ms": inter_token_ms,
    "quality_equal": compare_distribution_or_task_quality(),
}
```

**How it works now:** A baseline ordinary decode run is preserved. The candidate uses a documented draft method and speculation length. Results are bucketed by workload because code, constrained JSON, conversational text, and high-temperature sampling can have different acceptance behavior. The team measures target passes avoided, acceptance histogram, additional memory, ITL/TTFT, throughput, and quality.

### Why speculation sometimes loses

- The draft model is not much cheaper than the target.
- Acceptance is low for the domain, temperature, or constraint.
- Large batches already saturate target compute, so added draft work reduces throughput.
- Draft weights/KV consume memory that would have supported more active requests.
- Verification kernels or engine integration are inefficient for the chosen hardware.
- Structured decoding changes which proposals are valid.

An engine comparison should produce a Pareto curve, not one winner: low-load TTFT/ITL, saturated goodput, memory, quality, reliability, operational fit, and cost may select different configurations.

**Trade-offs and when not to use it:** Speculative decoding adds a model/artifact, scheduler state, memory, tuning, metrics, and failure paths. It is often most attractive for latency-sensitive, relatively small-batch decode. It may be counterproductive at high throughput or low acceptance. Engine feature breadth is not automatically useful; choose the simplest engine that meets the workload contract and can be operated safely.

**Production checks:**

- Track drafted, accepted, rejected, and bonus tokens plus acceptance distribution by route/model/settings.
- Compare accepted output tokens and SLO-compliant goodput, never proposed-token throughput alone.
- Validate output distribution or task quality according to the method's guarantee and implementation.
- Account for draft memory, startup, rollout, and failure behavior.
- Align all comparison variables and publish the exact command/configuration and raw manifest.
- Test cancellation, structured output, long context, mixed batches, and saturated load.

**Try it:** Benchmark ordinary decode and one speculative configuration on three workload classes. Sweep speculation length. Plot acceptance, ITL, throughput, memory, and goodput. Identify the crossover where extra drafting stops helping and defend whether to deploy it.

---

## INF-M7. Multi-GPU Parallelism and Mixture-of-Experts Inference

**Question:** How do you choose tensor, pipeline, data, context, or expert parallelism, and why is the GPU/network topology part of the model-serving design?

**Answer:** Choose parallelism from model fit, request shape, throughput/latency SLO, and available interconnect. Data parallelism replicates the model and isolates requests but duplicates weights. Tensor parallelism splits layer operations and performs frequent collectives. Pipeline parallelism splits layers into stages and introduces bubbles/stage balance concerns. Context/sequence parallelism divides long-sequence work. Expert parallelism distributes MoE experts and often requires token all-to-all communication. Communication volume, link bandwidth/latency, collective implementation, and imbalance determine whether more GPUs help.

**What problem does it solve?** Distributed inference makes models or contexts that exceed one device feasible and can increase aggregate capacity, but only when compute saved or memory gained exceeds coordination and communication costs.

**Before this concept:** The team set tensor parallel size equal to the number of available GPUs. Half the devices were across a slower network link, so collective communication dominated every transformer layer and latency worsened.

❌ **Wrong/before example — topology-free configuration:**

```yaml
tensor_parallel_size: 8
# No record of whether the 8 GPUs share NVLink, PCIe, or cross-node networking.
```

✅ **After/correct example — topology and hypothesis are explicit:**

```yaml
model: exact-revision
nodes: 2
gpus_per_node: 8
topology:
  intra_node: NVLink
  inter_node: 400Gbps-RDMA
candidate:
  tensor_parallel_per_node: 8
  data_parallel_replicas: 2
reason: >
  Keep layer collectives inside each high-bandwidth node; use two replicas
  across nodes because the model fits in one 8-GPU node.
measure:
  - collective_time_by_operation
  - ttft_itl_goodput
  - per_rank_memory
  - straggler_and_failure_behavior
```

**How it works now:** The design draws the physical topology, locates weights/KV/activations, and marks collectives per step. A one-GPU or smallest-fitting baseline is measured first. Candidate strategies are benchmarked with the real prompt/output mix, and communication time is visible rather than buried inside “GPU utilization.”

### Parallelism decision table

| Strategy | Main benefit | Main cost |
|---|---|---|
| Data parallel | Independent replicas, simple scaling/failure isolation | Duplicated weights and cache-locality routing |
| Tensor parallel | Splits large layer weights/compute | Frequent all-reduce/all-gather and topology sensitivity |
| Pipeline parallel | Splits layers and weight memory | Pipeline bubbles, stage imbalance, activation transfer |
| Context/sequence parallel | Enables long sequences/attention distribution | Communication and algorithm/runtime complexity |
| Expert parallel | Distributes MoE expert weights/compute | Token routing, all-to-all traffic, hot experts, padding |

MoE models activate only a subset of experts per token, reducing compute relative to dense activation at similar total parameter count. They still need expert weights placed somewhere, and real batches may route unevenly. Expert-choice/token-choice policies, capacity factors, load-balancing objectives, grouped GEMM padding, and all-to-all topology affect serving efficiency.

**Trade-offs and when not to use it:** Multi-GPU inference increases cost, failure surface, deployment time, synchronization, and debugging complexity. If the model fits one GPU and latency matters, replication may outperform splitting. Pipeline parallelism can be poor for small interactive batches. Expert parallelism may save memory while network or imbalance destroys latency. Do not scale out before profiling the single-device baseline.

**Production checks:**

- Record topology and placement; alert when scheduled onto a slower/unexpected link arrangement.
- Measure collective duration/bytes, per-rank compute/memory, straggler time, and stage/expert imbalance.
- Verify all ranks fail and recover coherently; prevent partial groups from accepting requests.
- Test node/GPU loss, network degradation, NCCL/collective timeout, and rolling replacement.
- Track MoE tokens per expert, padding, dropped/rerouted tokens, all-to-all time, and hot experts.
- Include distributed startup and model-load time in capacity/failover planning.

**Try it:** For a model that fits on two tightly connected GPUs, compare TP=2 with two single-GPU quantized replicas if feasible. Then reason about an eight-GPU/two-node placement. Estimate communication boundaries and identify which arrangement wins for low-latency and high-throughput workloads.

---

## INF-M8. Long Context, Tiered KV Storage, and Prefill/Decode Disaggregation

**Question:** When should KV state move beyond GPU memory, and when does separating prefill and decode improve inference serving?

**Answer:** Long contexts make prefill compute and KV capacity dominant. Tiered KV systems keep hot blocks on GPU and may move colder/reusable state to CPU, local SSD, or remote cache when transfer plus lookup is cheaper than recomputation and the SLO permits it. Prefill/decode disaggregation uses different worker pools for compute-heavy prefill and latency/memory-sensitive decode, transferring KV between them. It helps when phases need different scaling/hardware/scheduling and KV-transfer overhead is below the benefit; it hurts when prompts are short, interconnect is slow, or transfer destroys locality.

**What problem does it solve?** It expands usable context/concurrency and lets phases scale independently without forcing one GPU pool to handle conflicting prefill and decode workloads.

**Before this concept:** Long-prefill requests shared one queue with active decoders. Each large prompt caused ITL spikes for existing streams, and the GPU rejected new work when KV memory filled even though CPU memory was available.

❌ **Wrong/before example — offload everything because lower tiers are larger:**

```python
for kv_block in sequence.blocks:
    move_to_remote_store(kv_block)  # on every decode step
```

This replaces fast HBM reads with repeated network/storage transfer and can make every generated token wait on remote state.

✅ **After/correct example — admit by measured crossover:**

```python
decision = policy.choose(
    prompt_tokens=request.input_tokens,
    expected_output_tokens=request.max_new_tokens,
    gpu_kv_free_blocks=metrics.gpu_kv_free_blocks,
    reusable_prefix=prefix_index.lookup(request.prefix_hash),
    transfer_bandwidth_gbps=topology.kv_link_gbps,
    recompute_ms=estimator.prefill_ms(request.input_tokens),
    transfer_ms=estimator.kv_transfer_ms(request.input_tokens),
    deadline_ms=request.deadline_ms,
)

route(request, decision)  # colocated, disaggregated, reuse tier, or reject
```

**How it works now:** The system distinguishes active decode KV, reusable prefix KV, and cold recoverable state. Admission/routing accounts for transfer bandwidth, cache locality, deadline, and memory pressure. In a disaggregated path, prefill creates KV, transfers it once through a versioned protocol, and decode owns subsequent state. Pools autoscale from phase-specific demand.

### Crossover reasoning

Disaggregation is attractive only if:

```text
benefit from independent scheduling/scaling/hardware
  > KV serialization + transfer + synchronization + extra queueing
```

Tiered reuse is attractive only if loading cached KV is faster/cheaper than recomputing prefill and does not violate privacy or freshness. Cache keys must bind model/tokenizer revision, adapter, exact tokens, positional/configuration semantics, and tenant/security salt.

**Trade-offs and when not to use it:** Offload adds bandwidth contention, serialization, eviction, consistency, and security. Disaggregation adds a network boundary and new partial-failure states. For short prompts or a single GPU, co-location is simpler and often faster. KV quantization/compression can expand capacity but may change quality and kernel behavior. Sparse/alternative attention changes compute patterns but does not automatically eliminate all KV state.

**Production checks:**

- Measure prompt-length scaling, prefill time, decode ITL impact, KV bytes, transfer time, and reuse hit rate.
- Track tier admission/eviction, bytes moved, wasted loads, recomputation, and stale/incompatible cache rejection.
- Test prefill success followed by transfer/decode failure; ensure leaked KV is reclaimed and retries are safe.
- Encrypt/authenticate remote KV, isolate tenants, and avoid content-derived cross-tenant timing leaks.
- Autoscale prefill and decode pools from their own queue/token pressure and keep warm failure headroom.
- Compare disaggregated and colocated paths at the actual length/concurrency crossover, not only the longest case.

**Try it:** Estimate KV transfer time for a chosen model/context over PCIe, NVLink, and a network link. Compare with measured prefill recomputation time. Design a routing rule and then list three cases where that rule will be wrong unless it uses live pressure and locality.

---

## INF-M9. Production Model Lifecycle, Routing, and Autoscaling

**Question:** How do you deploy, route, scale, and retire inference models without cold-start outages, cache thrashing, or incompatible responses?

**Answer:** Package immutable model, tokenizer, adapter, engine, and configuration revisions; stage weights and compiled artifacts; warm representative shapes; expose startup/readiness separately from liveness; canary or shadow traffic with quality and SLO gates; drain streams and KV state before shutdown; and retain rollback artifacts. Route using model capability plus queue/KV/prefix locality and tenant policy. Autoscale from tokens, queue age, KV occupancy, goodput, and warm capacity—not CPU alone.

**What problem does it solve?** Model lifecycle and inference-aware orchestration keep expensive, stateful GPU workers ready and compatible while traffic, model versions, prefixes, and request costs vary dramatically.

**Before this concept:** Kubernetes saw low CPU and removed GPU pods during a quiet minute. A burst arrived while new pods downloaded 100 GB of weights and compiled kernels. Requests queued for minutes and retries multiplied the backlog.

❌ **Wrong/before example — generic CPU autoscaling for token workloads:**

```yaml
metric: cpu_utilization
target: 60
minReplicas: 0
# Model download, GPU memory, queue age, tokens, and warm-up are ignored.
```

✅ **After/correct example — inference-aware operating policy:**

```yaml
deployment:
  revision: model-tokenizer-engine-config-hash
  min_warm_replicas: 2
  startup_probe: weights-loaded-and-runtime-initialized
  readiness_probe: warmed-and-admission-open
autoscaling:
  signals:
    - waiting_token_seconds
    - oldest_request_age
    - kv_cache_occupancy
    - slo_goodput_per_replica
  scale_up_ahead_of_saturation: true
  scale_down_requires_drain: true
routing:
  filters: [model, adapter, tenant_policy, context_limit]
  scores: [queue_pressure, prefix_locality, kv_headroom, zone_cost]
rollout:
  stages: [shadow, 1_percent, 10_percent, 50_percent, 100_percent]
  gates: [quality, ttft, itl, errors, cost]
```

**How it works now:** The control plane prepares capacity before advertising readiness. The router filters incompatible replicas, then scores eligible ones using pressure and locality. Scale-up considers startup lead time and burst forecasts. Scale-down closes admission, drains or explicitly migrates/recomputes state, and only then stops the worker. Rollout compares candidate and baseline by workload cohort.

### Model routing is more than round robin

- Route to a replica that actually has the model/adapter and supports the request's context/feature set.
- Preserve prefix/KV locality when the benefit exceeds queue imbalance.
- Use queue-aware routing so a cache hit does not send work to a severely overloaded worker.
- Separate priority/tenant capacity so one customer or batch job cannot consume all KV blocks.
- Fall back only to models whose quality, safety, schema, and data-boundary contracts are compatible.

**Trade-offs and when not to use it:** Locality-aware routing can create hot replicas. Too many model variants fragment capacity. Keeping rollback models warm costs money. Shadow traffic doubles some work and must not trigger tools or external side effects. Scale-to-zero is usually poor for large interactive models with long download/compile times, but can fit infrequent offline jobs.

**Production checks:**

- Measure cold/warm startup components: scheduling, image, weight download, load, compile/capture, and warm-up.
- Distinguish startup, readiness, liveness, and deep dependency health; do not restart healthy-but-busy workers.
- Track routing reason, queue/KV state at decision time, cache locality, reroutes, and imbalance.
- Verify draining stops new admissions and bounded deadlines eventually free all state.
- Canary quality, safety, schema compatibility, TTFT/ITL, error/OOM, and cost—not just availability.
- Exercise rollback when the previous artifacts are no longer in node cache and during regional capacity loss.

**Try it:** Design a rollout from model A to B where B has a different tokenizer and twice the weight size. Include artifact staging, shadow evaluation without side effects, warm-up, cache separation, canary gates, rollback, and capacity during the overlap.

---

## INF-M10. Observability, Reliability, Admission Control, and Security

**Question:** What must a production inference service observe and protect so overload or GPU failure becomes controlled degradation rather than a cascading outage or data leak?

**Answer:** Trace the request across gateway, tokenizer, queue, scheduler, model execution, KV allocator, streaming, and dependencies. Measure latency phases, token work, scheduler/KV/GPU state, correctness/safety, cancellation, and cost with bounded-cardinality labels. Enforce admission budgets before GPU allocation, shed low-priority work, propagate cancellation/deadlines, and use retry rules aware of streaming. Secure model artifacts, endpoints, tenants, logs, prefix/KV state, tool credentials, and supply chain.

**What problem does it solve?** Inference-specific observability explains whether delay comes from queueing, prefill, decode, memory pressure, routing, kernels, or streaming. Admission and isolation keep expensive work bounded and prevent one tenant or malformed request from exhausting shared GPUs.

**Before this concept:** The only dashboard showed GPU utilization. During an incident it read 99%, but the team could not tell whether useful requests were completing, a retry storm filled the queue, or abandoned requests still consumed decode slots.

❌ **Wrong/before example — accept unbounded work and retry streaming blindly:**

```csharp
return await Retry.Forever(() => inference.GenerateAsync(request));
// No input/output budget, deadline, cancellation, idempotency, or stream state.
```

✅ **After/correct example — admission and retry semantics are explicit:**

```csharp
var estimate = estimator.Estimate(request);

if (!budget.TryReserve(
        tenantId: request.TenantId,
        inputTokens: estimate.InputTokens,
        maximumOutputTokens: request.MaxOutputTokens,
        kvBlocks: estimate.KvBlocks,
        deadline: request.Deadline))
{
    return Results.StatusCode(StatusCodes.Status429TooManyRequests);
}

// Retry only before visible output and only when the operation remains safe.
await foreach (var chunk in inference.StreamAsync(request, cancellationToken))
{
    await response.WriteAsync(chunk, cancellationToken);
    await response.Body.FlushAsync(cancellationToken);
}
```

**How it works now:** The gateway validates tenant/model budgets. The router selects an eligible worker. Admission reserves bounded token/KV capacity or rejects with a retryable contract. A trace records queue and engine phases without prompt content by default. Disconnect/deadline cancels work. Worker OOM or loss trips health/fencing, releases capacity, and retries only requests that have not produced externally visible partial output unless the protocol supports resumable generation.

### Minimum inference telemetry

| Layer | Evidence |
|---|---|
| Request | arrivals, accepted/rejected, input/output tokens, deadline, completion/cancel/error |
| Latency | queue, tokenize, prefill, TTFT, ITL, E2E, stream flush/client-observed latency |
| Scheduler | waiting/running/preempted, batch tokens, priority age, decision reason |
| KV/cache | used/free blocks, allocation failure, prefix hit/miss/eviction, offload/transfer |
| GPU/runtime | memory pools, utilization, power, temperature, kernel/collective time, OOM/ECC/reset |
| Product | output validity, task quality, safety violations, user feedback, tool-side-effect success |
| Economics | useful/total tokens, abandoned work, cost per successful/SLO-compliant request |

Security includes model extraction/abuse, denial-of-wallet, malicious token lengths, prompt/tool injection at the application layer, unauthorized adapters, cross-tenant cache reuse, sensitive telemetry, artifact tampering, and network/API authentication. Inference infrastructure security does not replace AI application safety; both layers are required.

**Trade-offs and when not to use it:** Per-token high-cardinality traces can be expensive and leak content. Sample intelligently, aggregate histograms, hash or omit sensitive identifiers, and keep deep profiling off the default hot path. Strict admission protects the fleet but rejects users; set priority, quota, retry-after, and degraded-mode policy deliberately.

**Production checks:**

- Define SLOs and alerts on error-budget burn/goodput, not raw GPU utilization alone.
- Bound metric labels; never label by prompt, request ID, user ID, or unbounded model input.
- Chaos-test worker kill, OOM, slow tokenizer, queue overload, network partition, cache loss, and rolling shutdown.
- Verify cancellation reaches the engine and releases KV blocks within a bounded time.
- Test fail-open/fail-closed behavior for auth, quota, safety, and policy dependencies.
- Sign/verify model and adapter artifacts, pin dependencies, restrict egress, rotate credentials, and audit model access.
- Ensure logs/traces omit prompts, outputs, embeddings, KV content, secrets, and tenant data unless explicit protected diagnostics require them.

**Try it:** Write a failure-injection plan for one GPU worker. Include overload, OOM, process kill, corrupted artifact, slow stream consumer, client disconnect, and cross-tenant prefix collision. For each, name the invariant, expected response, telemetry, and cleanup proof.

---

## INF-M11. Inference Economics and Capacity Planning

**Question:** How do you translate a benchmark into GPU count, failure headroom, and cost per useful request or million tokens?

**Answer:** Start from a representative arrival and token-length distribution plus quality/latency SLO. Measure per-replica goodput at a safe operating point. Divide peak SLO-qualified demand by safe goodput, round up, then add explicit failure, maintenance, growth, and burst headroom. Cost includes GPU/host time, idle warm capacity, storage/egress, orchestration, observability, engineering operations, failed/abandoned work, and provider/API fees. Compare self-hosting and APIs at equivalent quality, reliability, and utilization—not list price alone.

**What problem does it solve?** Capacity planning prevents a benchmark winner from becoming an underprovisioned production outage or an expensive idle fleet, and makes optimization value measurable in business terms.

**Before this concept:** The team multiplied average requests per second by average tokens and divided by peak benchmark tokens/s. It omitted bursts, p99 lengths, SLO losses, replicas under failure, and 50% real utilization.

❌ **Wrong/before example — average demand divided by marketing throughput:**

```text
GPUs = average_tokens_per_second / maximum_lab_tokens_per_second
```

✅ **After/correct example — capacity from safe goodput:**

```python
import math

peak_slo_requests_per_second = 42.0
safe_goodput_per_gpu = 6.5       # measured at target TTFT/ITL/error limits
failure_headroom = 0.25          # capacity remains after one failure/domain event
growth_and_burst_headroom = 0.20

base = peak_slo_requests_per_second / safe_goodput_per_gpu
required = math.ceil(base / (1 - failure_headroom - growth_and_burst_headroom))
print(required)
```

Headroom percentages must reflect the actual failure model and should not be naively added if the organization models independent scenarios differently. The important point is that assumptions are explicit and stress-tested.

**How it works now:** Each SKU/configuration has a workload-specific Pareto curve. The selected operating point meets quality and latency with margin. A capacity model converts forecast demand into warm replicas per failure domain and produces uncertainty bands. Actual demand, goodput, utilization, and cost continuously calibrate the forecast.

### Useful unit economics

```text
cost per successful request
  = total serving cost / correct successful requests

cost per SLO-compliant request
  = total serving cost / requests meeting correctness + latency SLO

cost per million accepted output tokens
  = total serving cost / accepted output tokens × 1,000,000

waste ratio
  = (failed + rejected-after-work + cancelled-after-work token cost)
    / total token cost
```

Token cost should distinguish input/prefill and output/decode when their resource economics differ. A cheaper model that needs more retries, tools, or human correction may be more expensive per resolved task.

**Trade-offs and when not to use it:** Forecasts are uncertain; false precision hides risk. Warm capacity improves reliability but costs money. Spot/preemptible capacity can fit offline or retryable workloads but needs interruption handling. Provider APIs avoid low-utilization capital/operations while reducing infrastructure control. Self-hosting can win at stable utilization, privacy, or specialization, but engineering and failure costs are real.

**Production checks:**

- Capacity from peak distribution and safe goodput, not average load or maximum throughput.
- Model node/zone loss, deployment overlap, maintenance, forecast error, burst, and cold-start lead time.
- Track idle, useful, failed, cancelled, and speculative/draft work separately.
- Reconcile forecast versus actual by route/model/tenant and update uncertainty bands.
- Compare provider and self-hosted options at the same task quality, SLO, redundancy, and support burden.
- Put cost anomaly limits on unbounded output, agent loops, retries, and denial-of-wallet traffic.

**Try it:** Given hourly traffic and prompt/output histograms, build a capacity sheet for two GPU SKUs and one API provider. Include safe goodput, one-node failure, 30% growth, rollout overlap, warm-up time, quality, and total monthly cost. Defend the choice and its break-even assumptions.

---

## INF-M12. Specialized Workloads, Mini-Engine Design, and Research Reproduction

**Question:** How do structured output, Multi-LoRA, multimodal, agentic, reasoning, batch, RL rollout, and diffusion workloads change inference design, and what project proves genuine engine understanding?

**Answer:** Each workload changes scheduler state, memory, kernels, validation, latency shape, or correctness. Structured output adds constraint state and may change speculative acceptance. Multi-LoRA adds adapter placement/cache/routing. Multimodal inputs add encoders and large non-text representations. Agentic/reasoning requests have variable long outputs, tool pauses, and cancellation/cost risk. Batch inference optimizes throughput rather than interactive TTFT. RL rollout generation needs versioned policies and very high sampling throughput. Diffusion performs iterative denoising with step/quality trade-offs rather than autoregressive token decode. A mini engine should make request state, KV allocation, batching, preemption, streaming, and metrics observable and replayable.

**What problem does it solve?** Workload-specific design prevents a generic text-chat configuration from silently violating memory, latency, quality, isolation, or cost requirements.

**Before this concept:** Every request entered the same queue with the same limits. A reasoning request generated 30,000 tokens beside short JSON extraction calls; an uncached LoRA adapter loaded synchronously; a tool pause held scarce KV memory indefinitely.

❌ **Wrong/before example — one undifferentiated route:**

```python
@app.post("/generate")
def generate(request):
    return engine.generate(request.input, max_tokens=request.max_tokens)
```

✅ **After/correct example — workload contract drives admission and pool:**

```python
profile = workload_catalog.resolve(
    modality=request.modality,
    task=request.task,
    model=request.model,
    adapter=request.adapter,
)

validated = profile.validate_and_estimate(request)
pool = router.select_pool(
    engine_features=profile.required_features,
    memory_class=validated.memory_class,
    latency_class=profile.latency_class,
    adapter_locality=request.adapter,
)

return pool.execute(validated, cancellation=request.cancellation)
```

**How it works now:** Workload profiles define schema/constraints, model/adapter, token or step budget, modality preprocessing, priority, pool, quality gate, cancellation, side-effect policy, and metrics. The router sends work only to compatible capacity. Paused agent/tool work has an explicit KV retention/offload/recompute policy. Batch and interactive queues cannot starve each other.

### Specialization questions

| Workload | Additional design question |
|---|---|
| Structured output/tool calls | Is schema enforcement incremental, how are invalid/dead-end states handled, and are tool arguments authorized? |
| Multi-LoRA | Which adapters stay resident, how are they versioned/routed/evicted, and can tenants access each other's adapters? |
| Multimodal | Where do encoders run, how are image/audio/video tokens budgeted, and what content validation applies? |
| Agentic/multi-turn | How are tool waits, long state, retries, side effects, and cost/step limits controlled? |
| Reasoning | What output/compute budget and verifier determine useful success rather than longer text? |
| Batch | How are jobs checkpointed, partitioned, retried, and charged while maximizing throughput? |
| RL rollouts | Which policy revision generated each sample, how is staleness controlled, and how is enormous sample throughput stored? |
| Diffusion | How do denoising steps, resolution, scheduler, batching, and guidance affect latency/memory/quality? |

**Trade-offs and when not to use it:** Separate pools improve isolation but fragment expensive GPUs. Multi-model serving improves utilization but causes eviction/cold-start interference. A custom engine is an educational or specialized investment, not the default production choice; mature engines contain years of correctness, kernel, and failure work. Research reproduction requires time and may show that a paper's gain disappears on modern baselines or different hardware—that is a valuable result.

**Production checks:**

- Partition metrics and limits by workload profile; do not compare diffusion steps with output tokens.
- Version models, adapters, preprocessors, tokenizers, constraints, and policy/quality gates together.
- Bound agent steps, tool calls, tokens, wall time, side effects, and paused-state memory.
- Test adapter/model eviction, modality decoder failure, invalid schema, tool timeout, and batch resume.
- For a mini engine, assert KV block ownership, no use-after-free, cancellation cleanup, deterministic scheduler replay, and backpressure.
- For research, publish exact baseline, workload, environment, seeds, raw results, ablations, and where the technique stops helping.

**Try it:** Build a small observable inference-engine simulator or real mini engine. Add request admission, tokenization stub, static then continuous batching, KV block allocation, cancellation, streaming, prefix reuse, metrics, and a replayable scheduler trace. Compare it with a mature engine on the same small model and explain correctness and performance gaps.

---

## Topic-Wise Practice Workbook

Use this section closed-book first. Write your assumptions, calculations, failure model, and evidence before opening the answer key. A complete response must explain why the tempting alternative fails.

### Workbook questions

1. A service has low total latency but users report a long blank screen. Which measurements distinguish proxy buffering, queue delay, and prefill delay?
2. Engine A reports 8,000 total tokens/s; engine B reports 5,000 output tokens/s. Can you choose a winner? What must be normalized?
3. A 40-layer model uses 8 KV heads, head dimension 128, and two-byte KV elements. Calculate KV bytes per token and for 100,000 live tokens.
4. Why can continuous batching improve throughput while worsening p99 TTFT for one class of request?
5. When can 4-bit weights be slower than BF16 despite using less memory?
6. A speculative decoder has 90% proposal acceptance but no latency gain. Name at least four possible causes.
7. A model fits on four NVLink-connected GPUs. Why might two four-GPU replicas outperform one eight-GPU tensor-parallel deployment across nodes?
8. A remote prefix cache loads state in 80 ms while recomputing prefill takes 45 ms. Should the cache always be bypassed?
9. Why is round-robin routing poor for a fleet with prefix caching and unequal KV occupancy? Why is cache-only routing also poor?
10. A client disconnects after receiving 20 streamed tokens. When is automatic retry unsafe, and what must cleanup prove?
11. A GPU benchmark reaches 20 requests/s but only 12 requests/s meet TTFT/ITL SLOs. Which number belongs in capacity planning and why?
12. How does a paused agent tool call affect KV memory, and what policies can the platform choose?

### Answer key

1. Measure client/server TTFT and stream flush timestamps for buffering; admission/queue timestamps for queue delay; tokenized/admitted-to-first-token plus prompt length and prefill engine metrics for prefill. A single E2E timer cannot isolate them.
2. No. Align model/tokenizer revision, input/output token definitions and distributions, precision, sampling, cache, concurrency/arrival model, hardware, quality, failures, warm state, TTFT/ITL constraints, and cost. Then compare goodput/Pareto curves.
3. `2 × 40 × 8 × 128 × 2 = 327,680 bytes/token` (320 KiB). For 100,000 live tokens: 32,768,000,000 bytes, about 30.52 GiB, before block waste and other memory.
4. The scheduler can pack more work but admit long prefills or too many sequences ahead of latency-sensitive requests. Throughput rises while queueing/chunk policy/priority fairness worsens one cohort. Measure by class and use weighted fairness/chunked prefill/admission.
5. The runtime may lack tuned kernels; dequantization and scale loads may dominate; shapes may be poor; compilation may fall back; a larger batch may no longer fit an efficient path; or quality loss may require retries/larger models. Measure, do not infer speed from bytes.
6. Draft cost, verification inefficiency, memory pressure reducing batch capacity, already-saturated target compute, network/coordination overhead, too-long speculation, high TTFT overhead, unsuitable workload, or a metric counting accepted tokens differently.
7. Tensor parallelism performs frequent collectives. Keeping TP inside a node and using data-parallel replicas avoids cross-node collectives, improves failure isolation, and may serve independent requests more efficiently when each node can fit the model.
8. Not always. Bypass for this isolated case if all else is equal, but reuse may protect scarce prefill compute during saturation or the 45 ms estimate may change with queue pressure. The policy should compare live transfer, recompute, locality, deadline, and downstream impact.
9. Round robin ignores reusable prefixes and capacity, causing recomputation and overloaded workers. Cache-only routing can create hot replicas and long queues. Filter by compatibility, then score both locality and pressure with bounded imbalance.
10. Retry is unsafe after visible output unless the protocol can resume/deduplicate the stream; users may see duplicated or divergent text/tool effects. Cleanup must cancel scheduler work, stop kernels at a safe boundary, release KV/admission quota, close traces, and prove no side effect repeats.
11. Use 12 SLO-compliant requests/s, with additional headroom. The other eight are throughput but not useful capacity. Capacity planning from 20 institutionalizes an SLO violation.
12. The pause may retain expensive KV while no GPU compute progresses. Policies include bounded in-memory retention, lower-tier offload, recompute from stored tokens, a dedicated agent pool, or cancellation after a deadline. Choose from pause distribution, transfer/recompute cost, privacy, and SLO.

## Primary References

- [Fanout Inference Engineering public curriculum](https://fanout.sh/inference-eng)
- [Fanout LLM inference engineer roadmap](https://fanout.sh/blog/llm-inference-engineer-roadmap)
- [vLLM documentation](https://docs.vllm.ai/en/latest/)
- [PagedAttention/vLLM paper](https://arxiv.org/abs/2309.06180)
- [FlashAttention paper](https://proceedings.neurips.cc/paper_files/paper/2022/hash/67d57c32e20fd0a7a302cb81d36e40d5-Abstract.html)
- [TensorRT-LLM documentation](https://nvidia.github.io/TensorRT-LLM/)
- [Speculative Decoding paper](https://proceedings.mlr.press/v202/leviathan23a.html)
- [NVIDIA Triton metrics](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/user_guide/metrics.html)
- [KServe generative-inference configuration](https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/llmisvc-configuration)
- [MLPerf Inference](https://mlcommons.org/benchmarks/inference-datacenter/)

---

**Key takeaway:** Trace one request until every millisecond and byte has an owner. Optimize the measured bottleneck, protect the SLO under overload and failure, and report quality plus goodput—not a context-free tokens-per-second headline.

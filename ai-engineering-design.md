# AI Engineering & System Design

Quick reference for designing AI/ML systems at scale. Covers LLMs, agents, RAG, evaluation, and deployment patterns.

---

## Table of Contents
1. [LLM Concepts](#llm-concepts)
2. [RAG (Retrieval-Augmented Generation)](#rag)
3. [AI Agents](#agents)
4. [Prompt Engineering](#prompt-engineering)
5. [LLM Evaluation](#evaluation)
6. [Vector Databases](#vector-db)
7. [Fine-tuning vs Prompting](#fine-tuning)
8. [Context Engineering](#context-engineering)
9. [Multi-Agent Systems](#multi-agent)
10. [Deployment & Monitoring](#deployment)
11. [One Model Call End to End](#aie-m1-one-model-call-end-to-end)
12. [Embedding and Retrieval Internals](#aie-m2-embedding-and-retrieval-internals)
13. [Transformer Shapes, Attention, and KV State](#aie-m3-transformer-shapes-attention-and-kv-state)
14. [Match Optimizations to the Bottleneck](#aie-m4-match-optimizations-to-the-bottleneck)
15. [Reasoning, Verification, Tools, and MCP](#aie-m5-reasoning-verification-tools-and-mcp)
16. [Evaluation-Driven Production AI](#aie-m6-evaluation-driven-production-ai)

### Fanout public AI Engineering curriculum coverage

| Public module | Repository coverage |
|---|---|
| AI engineering map and one model call | AIE-M1 plus the existing LLM Concepts section |
| Embeddings, compression, vector search, indexing, and vector-database internals | Vector Databases plus AIE-M2 |
| LLM foundations and RAG | LLM Concepts and RAG sections |
| Positional embeddings, attention, transformer architecture, KV cache | AIE-M3 and [Inference Engineering](inference-engineering.md) |
| Masked/multi-head attention and transformer shape tracing | AIE-M3 and the linked math/research workbook |
| PagedAttention, MoE, FlashAttention, and KV allocation | AIE-M4 and [Inference Engineering](inference-engineering.md) |
| Quantization, sparse attention, distillation, speculative decoding, and bottleneck matching | AIE-M4 |
| Reasoning, chain/tree search, tool usage, and failure diagnosis | AIE-M5 |
| Context engineering, agent loops, MCP, and checkable plans | Existing Context/Agent sections plus AIE-M5 |
| Evaluation, monitoring, and production feedback | Existing Evaluation/Deployment sections plus AIE-M6 |

---

<a id="llm-concepts"></a>
## LLM Concepts

### Definition
Large Language Model (LLM): Neural network trained on trillions of tokens of text. Predicts next token given previous tokens. Examples: GPT-4, Claude, Llama.

### Key Concepts

**Tokens**: Subword units (words split into chunks). "Hello" = 1 token, "ChatGPT" = 2 tokens. Roughly 4 characters per token.

**Context Window**: Max tokens model can see at once (GPT-4: 128K, Claude: 200K). Limit determines how much history/document model sees.

**Temperature**: Randomness in outputs (0 = deterministic, 1 = random). Lower for factual (0.1), higher for creative (0.8).

**Top-K, Top-P**: Filtering next-token predictions. Top-K = consider top K candidates, Top-P = consider tokens until cumulative probability P. Reduces nonsense.

### Q&A

**Q: Why do LLMs hallucinate?**
- A: LLMs predict next token based on patterns. No fact-checking. If training data sparse on topic, guesses. Solution: RAG (retrieve facts), few-shot examples, system prompts constraining output.

**Q: What is fine-tuning and when necessary?**
- A: Train LLM on task-specific data. Improves accuracy for narrow domains (customer support, medical). Cost: Data, compute, risks catastrophic forgetting.

**Q: Why is context window size matter?**
- A: Larger context = more history seen = better coherence. But quadratic cost (attention = O(n²)). 128K tokens costs more than 8K.

**Q: What is prompt injection and why dangerous?**
- A: User input contains hidden instructions ("ignore previous instructions and..."). Model follows new instructions, bypassing safety. Solution: Separate user input from prompts (use structured formats), validate outputs.

### Why This Approach
- **Tokens**: Efficient encoding. More granular than words, less than characters.
- **Temperature**: Control vs creativity tradeoff.
- **Context Window**: Larger = better quality. Smaller = faster + cheaper.

### Pros & Cons

**Large Context Window Pros**: Better coherence, more history, can process long documents.
**Large Context Window Cons**: Slower (quadratic attention), more expensive (charged per token).

**Fine-tuning Pros**: Task-specific accuracy, better for domain (medical, legal).
**Fine-tuning Cons**: Expensive data + compute, catastrophic forgetting (forget general knowledge), hard to maintain.

**Low Temperature Pros**: Consistent, factual, controllable.
**Low Temperature Cons**: Boring, repetitive, less creative.

### Right vs Wrong Usage

**✅ Right**: Prompt for one-off tasks. Fine-tune for specific domain (medical). Zero-shot prompting for general. Few-shot for style examples.

**❌ Wrong**: Don't rely on LLM for facts without RAG (hallucinates). Don't use high temperature for factual (inconsistent). Don't fine-tune on tiny dataset (overfits).

**Alternative**: Fine-tune → In-context learning (few-shot + prompting) if smaller data. LLM → Smaller model if cost critical.

---

<a id="rag"></a>
## RAG (Retrieval-Augmented Generation)

### Definition
Combine retrieval (find relevant documents) + generation (LLM writes answer). Reduces hallucination, adds external knowledge.

### Architecture

```
User Query
    ↓
[Embedding Model] → Convert query to vector
    ↓
[Vector DB] → Search similar documents
    ↓
[Top-K Results] → Retrieve chunks
    ↓
[LLM] → Feed query + context, generate answer
    ↓
Response
```

### Q&A

**Q: Why is RAG better than fine-tuning for knowledge?**
- A: RAG adds facts at query time (current knowledge). Fine-tuning requires retraining (outdated fast). RAG retrieves only relevant docs (efficient context).

**Q: How to handle long documents (1000+ pages)?**
- A: Chunk into overlapping sections (e.g., 500 tokens with 50-token overlap). Embed each chunk. Retrieve top-K chunks. Feed to LLM.

**Q: What is relevance score and how to tune?**
- A: Similarity between query and document (cosine similarity for vectors). Threshold = min similarity to retrieve. Low threshold = more docs (context bloat), high = fewer docs (miss relevant).

**Q: How to prevent RAG from returning irrelevant documents?**
- A: Use good embedding model (trained on semantic similarity). Tune retrieval threshold. Implement reranking (second-pass scoring). Validate chunk quality.

### Why This Approach
- **RAG**: Adds external knowledge without retraining. Reduces hallucination by grounding in retrieved facts.
- **Chunking**: Handles long documents. Overlapping prevents context cut-off.
- **Embedding**: Converts text to vectors. Similarity search in high dimensions.

### Pros & Cons

**RAG Pros**: Up-to-date knowledge (no retraining), reduces hallucination, retrieves only relevant docs.
**RAG Cons**: Retrieval errors compound (bad document = bad answer), latency (retrieval + generation), requires good vector DB.

**Chunk-Based Pros**: Handles long documents, reduces context bloat.
**Chunk-Based Cons**: Risk of splitting relevant info across chunks, chunk size tuning needed.

**Vector-Based Retrieval Pros**: Semantic search (finds meaning-similar docs), scales to millions.
**Vector-Based Retrieval Cons**: Requires embedding model, vector DB infra, possible semantic drift.

### Right vs Wrong Usage

**✅ Right**: Use RAG for FAQ, documentation, knowledge bases. Don't use RAG for simple queries (overkill).

**✅ Right**: Chunk at sentence/paragraph boundaries. Overlap chunks to prevent cuts. Validate chunk quality.

**❌ Wrong**: Don't use RAG for real-time facts (documents stale). Don't ignore retrieval errors. Don't chunk arbitrarily (context broken).

**Alternative**: RAG → Fine-tune if documents stable. Vector DB → SQL if structured data. Embedding → Keyword search if semantic similarity not needed.

---

<a id="agents"></a>
## AI Agents

### Definition
AI Agent: Autonomous system that perceives environment, decides actions, executes. Loop: Sense → Think → Act.

### Agent Types

**Agentic Loop**: Agent iterates. Each step: reads input, decides action, executes, observes result, repeats until goal.

```
1. User Input
2. Agent Thinks (calls LLM)
3. Agent Decides Action (tool use)
4. Agent Executes (call API, run code)
5. Agent Observes Result
6. If goal reached → Done
7. Else → Back to step 2
```

**Tool Use (Function Calling)**: Agent decides which tool to use (API, calculator, database). LLM selects tool + args, system executes, returns result.

**Memory**: Agent remembers prior steps. Short-term (recent messages) + long-term (summaries, embeddings).

### Q&A

**Q: Why are agents hard to build?**
- A: Unpredictable (LLM can make mistakes). May loop forever. Tool outputs may be unstructured. Hallucinate tool names/args. Need strict contracts (output validation, timeouts).

**Q: How to prevent agent from looping?**
- A: Max iterations (e.g., 10 steps). Timeout. Monitor for repeated actions. Explicit termination (agent says "done").

**Q: What is tool use and how to implement?**
- A: LLM outputs structured request ("use calculator with args 5 + 3"). System parses, calls tool, returns result. LLM continues with result. Requires strict format (JSON, function calling).

**Q: How to debug agentic failures?**
- A: Log each step (input, LLM output, tool executed, result). Replay steps to understand where it went wrong. Common: wrong tool selection, tool args invalid, stale tool results.

### Why This Approach
- **Agentic Loop**: Enables complex multi-step problems. Break into steps.
- **Tool Use**: Extends LLM beyond text (can call APIs, code).
- **Memory**: Context (avoid repeating prior steps).

### Pros & Cons

**Agentic Loop Pros**: Solves complex problems, adapts to outcomes, human-like reasoning.
**Agentic Loop Cons**: Unpredictable (LLM fallibility), latency (multiple LLM calls), expensive (N calls = N * token cost).

**Tool Use Pros**: Extends LLM capability (APIs, code), up-to-date info (not trained).
**Tool Use Cons**: Hallucination (wrong tool/args), requires strict contracts, tool failures compound.

**Memory Pros**: Avoids repeating steps, improves context.
**Memory Cons**: Storage overhead, token usage (large context), stale info.

### Right vs Wrong Usage

**✅ Right**: Use agents for multi-step tasks (plan trip, debug code). Tool use for APIs, calculations. Memory for conversations.

**❌ Wrong**: Don't use agents for simple queries (overkill). Don't trust agent output (validate). Don't allow unlimited iterations (loop forever). Don't ignore tool hallucination (validate tool names/args).

**Alternative**: Agent → Simple prompting if task simple. Tool use → Hard-coded if tool unreliable. Memory → Vector DB for large-scale memory retrieval.

---

<a id="prompt-engineering"></a>
## Prompt Engineering

### Definition
Prompt: Text sent to LLM. Prompt engineering: Optimize prompts for accuracy, consistency, task-specific behavior.

### Techniques

**Zero-Shot**: Ask directly without examples. Fast, simple, but lower accuracy on complex tasks.

```
Prompt: "Translate to French: Hello"
```

**Few-Shot**: Provide 2-3 examples before asking.

```
Prompt:
"Translate to French:
 English: Hello → French: Bonjour
 English: Goodbye → French: Au revoir
 English: Good morning → ?"
```

**Chain-of-Thought (CoT)**: Ask model to explain reasoning step-by-step. Improves accuracy on math, logic.

```
Prompt: "Solve step-by-step: 9 * 8 = ?"
Answer: "9 * 8 = (9 * 8) = 72. Because 9 * 8 = 72."
```

**System Prompt**: Set behavior, tone, constraints before user query.

```
System: "You are a Python expert. Answer concisely. Include code examples."
User: "How to reverse a list?"
```

### Q&A

**Q: Why do few-shot examples improve accuracy?**
- A: LLM learns style, format from examples. Constrains output to match pattern. More examples = more specific constraints.

**Q: When use zero-shot vs few-shot?**
- A: Zero-shot for general (LLM has knowledge). Few-shot for specific style/format. Few-shot costs more tokens (examples included).

**Q: What is prompt injection and how to prevent?**
- A: User input contains hidden instructions. Solution: Separate user input from system prompt. Use structured formats. Validate outputs.

**Q: How to improve prompt consistency?**
- A: More specific constraints (e.g., "respond in JSON"). System prompt setting expectations. Few-shot examples. Lower temperature. Validate output format.

### Why This Approach
- **Few-Shot**: Constrains output. Examples show desired format/style.
- **Chain-of-Thought**: Reasoning improves accuracy (math, logic).
- **System Prompt**: Consistent behavior. Tone/constraints.

### Pros & Cons

**Zero-Shot Pros**: Simple, no examples needed, lower token cost.
**Zero-Shot Cons**: Lower accuracy, less control over format.

**Few-Shot Pros**: Higher accuracy, format control, style matching.
**Few-Shot Cons**: Token cost (examples included), requires good examples.

**Chain-of-Thought Pros**: Higher accuracy on reasoning tasks (70-80% improvement).
**Chain-of-Thought Cons**: Longer response (cost), slower (more tokens), not helpful for simple tasks.

**System Prompt Pros**: Consistent behavior, style/tone control.
**System Prompt Cons**: No guarantee (LLM may ignore), risk of prompt injection.

### Right vs Wrong Usage

**✅ Right**: Zero-shot for general knowledge. Few-shot for specific format. Chain-of-Thought for math/logic. System prompt for consistent behavior.

**❌ Wrong**: Don't include user input in system prompt (injection risk). Don't use few-shot with bad examples (teaches wrong behavior). Don't trust output format without validation.

**Alternative**: Few-shot → Fine-tune if need perfect accuracy. Chain-of-Thought → Simpler prompt if reasoning not needed. System prompt → No prompt if behavior flexible.

---

<a id="evaluation"></a>
## LLM Evaluation

### Definition
Evaluate LLM outputs on task metrics. Objective (exact match) vs subjective (quality).

### Metrics

**BLEU**: Matches output words to reference. 0-100, higher = better. Good for translation, summarization.

**ROUGE**: Overlap of n-grams between output and reference. Similar to BLEU.

**Exact Match (EM)**: Output exactly matches reference. 0 or 1. Strict (too strict for paraphrasing).

**F1**: Precision and recall combined. Good for QA (partial credit).

**Human Evaluation**: Experts rate on fluency, correctness, relevance. Expensive but accurate.

### Q&A

**Q: Why is LLM evaluation hard?**
- A: Output rarely exact match (multiple valid answers). Subjectivity (quality is subjective). Expensive (human evaluation needed). Metrics can mislead (high BLEU, bad quality).

**Q: How many examples to evaluate?**
- A: 100+ for confidence. Small dataset (10) has high variance. Trade-off: cost vs confidence.

**Q: What is prompt sensitivity and how to test?**
- A: Small prompt changes → big output changes. Test multiple prompt variations on same dataset. If sensitive, prompt is brittle.

**Q: How to evaluate fairness and bias?**
- A: Test on diverse examples (different demographics, domains). Measure performance delta. Look for stereotypes in output.

### Why This Approach
- **Multiple Metrics**: Capture different aspects (fluency, correctness, style).
- **Human Evaluation**: Gold standard but expensive. Use for subset (spot check).
- **Prompt Sensitivity**: Understand prompt robustness.

### Pros & Cons

**BLEU/ROUGE Pros**: Automatic, fast, cheap, no human annotation.
**BLEU/ROUGE Cons**: Correlate poorly with human judgment, penalize paraphrasing.

**Exact Match Pros**: Clear definition, easy to implement.
**Exact Match Cons**: Too strict (most valid answers marked wrong).

**Human Evaluation Pros**: Gold standard, accurate, catches nuance.
**Human Evaluation Cons**: Expensive, slow, subjective (inter-rater disagreement).

**F1 Score Pros**: Gives partial credit, good for QA.
**F1 Score Cons**: Requires reference annotations, penalizes over/under generation.

### Right vs Wrong Usage

**✅ Right**: Use multiple metrics (complement each other). Human eval for final validation. Automated eval for iteration.

**❌ Wrong**: Don't rely on single metric (misleading). Don't trust BLEU for fluency (doesn't measure). Don't evaluate on tiny dataset (high variance).

**Alternative**: BLEU → Human eval if accuracy critical. Automatic → Cheap proxy if budget tight.

---

<a id="vector-db"></a>
## Vector Databases

### Definition
Vector database (Pinecone, Weaviate, Milvus) stores embeddings (vectors). Fast similarity search in high dimensions.

### Concepts

**Embedding**: Dense vector (768-1536 dimensions) representing semantic meaning. Generated by embedding models (OpenAI, Sentence-BERT).

**Similarity Search**: Find vectors closest to query vector. Cosine similarity, Euclidean distance, etc.

**Approximate Nearest Neighbor (ANN)**: Fast approximation instead of exact search. HNSW (Hierarchical NSW) common algorithm.

**Indexing**: Build index structure (tree, hash) for fast lookup. Trade-off: Build time vs query speed.

### Q&A

**Q: Why use vector DB vs SQL?**
- A: Vector DB indexes by semantic similarity (meaning). SQL indexes by keyword (exact match). Vector DB scales to millions of embeddings efficiently.

**Q: How to choose embedding model?**
- A: Larger models (1536D) more expressive but slower, expensive. Smaller (384D) fast but lower quality. Test on task. Use pre-trained (OpenAI, Sentence-BERT).

**Q: What is metadata filtering?**
- A: Filter results by field (e.g., date > 2024). Combines vector similarity + metadata filter. Reduces results before ranking.

**Q: How to handle query drift (embedding model changes)?**
- A: Re-embed and re-index entire database. Expensive. Plan for it when choosing model (balance: quality vs stability).

### Why This Approach
- **Embeddings**: Capture semantic meaning (similar concepts → similar vectors).
- **Similarity Search**: Fast retrieval of relevant documents.
- **Metadata Filtering**: Combine semantic + structured search.

### Pros & Cons

**Vector DB Pros**: Semantic search, scales to millions, efficient storage (compression).
**Vector DB Cons**: Model-dependent (quality depends on embedding model), requires re-embedding for model changes, approximate (not exact).

**ANN Pros**: Fast (logarithmic), scales well.
**ANN Pros**: Approximate (rare misses), tuning needed.

**Metadata Filtering Pros**: Combine semantic + filters (e.g., recent + relevant).
**Metadata Filtering Cons**: Filtering reduces results (may miss relevant if too strict).

### Right vs Wrong Usage

**✅ Right**: Vector DB for RAG, recommendation, semantic search. ANN for millions of embeddings. Metadata filtering for structured constraints.

**❌ Wrong**: Don't use vector DB for exact-match queries (use SQL). Don't use vector DB for numeric ranges (poor performance). Don't ignore embedding model quality.

**Alternative**: Vector DB → Elasticsearch if keyword search OK. ANN → Exact search if speed not critical. Metadata → SQL if mostly structured.

---

<a id="fine-tuning"></a>
## Fine-tuning vs Prompting

### Definition
**Fine-tuning**: Train model on task-specific data. **Prompting**: Give examples/instructions in prompt.

### Comparison

| Aspect | Prompting | Fine-tuning |
|--------|-----------|-------------|
| Cost | Cheap (token cost) | Expensive (compute, data) |
| Latency | No training latency | Training latency (hours) |
| Data | 2-3 examples | 100+ examples minimum |
| Accuracy | Lower | Higher |
| Generalization | Better (uses general knowledge) | Worse (overfits to domain) |
| Update | Instant (just change prompt) | Slow (retrain) |

### Q&A

**Q: When should I fine-tune vs prompt?**
- A: Prompt if accuracy OK (few-shot enough). Fine-tune if accuracy critical (medical, legal) or massive scale (millions of calls). Prompt → retrain model:

```
Accuracy 70% → Prompt (acceptable)
Accuracy 90% needed → Few-shot prompt
Accuracy 95%+ needed → Fine-tune
```

**Q: What is catastrophic forgetting?**
- A: Fine-tuning on task-specific data makes model worse at general tasks. Example: Fine-tune on medical data → model forgets general knowledge. Solution: Mix task data with general data.

**Q: How much data for fine-tuning?**
- A: Start with 100 examples. Diminishing returns after 1000 (small data → memorization, large data → good generalization). Test on held-out set.

**Q: Can I fine-tune a closed-source model (GPT-4)?**
- A: Limited options. OpenAI allows fine-tuning GPT-3.5, but not GPT-4. Use open-source (Llama, Mistral) for full control.

### Why This Approach
- **Prompting**: Fast iteration, uses general knowledge, easy update.
- **Fine-tuning**: Higher accuracy for domain, but one-shot learning (can't easily switch domains).

### Pros & Cons

**Prompting Pros**: Fast (instant), uses general knowledge, easy to update.
**Prompting Cons**: Lower accuracy, limited by model size (can't teach model new facts).

**Fine-tuning Pros**: Higher accuracy (domain-specific), one-shot (train once, use everywhere).
**Fine-tuning Cons**: Expensive, slow, requires data, catastrophic forgetting.

### Right vs Wrong Usage

**✅ Right**: Prompt for exploration, fast iteration. Fine-tune for production (accuracy critical), high volume (saves token cost).

**❌ Wrong**: Don't fine-tune tiny dataset (overfits). Don't fine-tune if prompting sufficient (waste). Don't assume fine-tuning always better (sometimes worse due to forgetting).

**Alternative**: Fine-tune → Prompting + RAG if more flexible. Prompting → Larger model if more general knowledge helpful.

---

<a id="context-engineering"></a>
## Context Engineering

### Definition
Optimizing context (system prompt, examples, retrieval) to improve LLM output quality. Similar to prompt engineering but more structured.

### Techniques

**System Prompt Design**: Set role, constraints, output format.

```
"You are a Python expert. 
Respond in JSON.
Include time complexity.
Avoid numpy (use vanilla Python)."
```

**Example Selection**: Choose few-shot examples strategically (matching query type, difficulty).

**Constraint Definition**: Define output format, length, tone.

**Retrieval Tuning**: Vary retrieval parameters (top-K, similarity threshold) to optimize context.

### Q&A

**Q: How to design system prompts?**
- A: Be specific (role, constraints). Avoid negative instructions (instead of "don't mention X", say "focus on Y"). Short prompts (200 words) perform better than long ones.

**Q: How many examples in few-shot?**
- A: 2-3 examples often sufficient. More = better consistency but higher cost. Diminishing returns after 5.

**Q: What is in-context learning and why it works?**
- A: LLM learns from examples in context (few-shot). Pattern matching: sees examples → infers pattern. Works because LLM trained on diverse data.

**Q: How to handle ambiguous queries?**
- A: Add clarifying examples (show how to interpret ambiguity). Constraint output format (force specific answer format). Ask for reasoning (chain-of-thought).

### Why This Approach
- **System Prompt**: Constrains behavior (tone, format, constraints).
- **Examples**: Show desired style. Few-shot learning.
- **Constraints**: Force specific output (JSON, bullet points).

### Pros & Cons

**Specific Prompts Pros**: Better results, consistent format, controllable.
**Specific Prompts Cons**: Requires iterating, risk of over-constraining.

**Few-Shot Pros**: Higher accuracy, style matching.
**Few-Shot Cons**: Token cost, requires good examples.

**Constraint Format Pros**: Consistent parsing, easy to validate.
**Constraint Format Cons**: May force wrong answer into format, reduces flexibility.

### Right vs Wrong Usage

**✅ Right**: Specific system prompts (role + constraints). Few examples. Format constraints (JSON, bullets). Test on samples.

**❌ Wrong**: Don't use vague prompts ("be helpful"). Don't use negative constraints ("don't..."). Don't over-constrain (limits creativity).

**Alternative**: Context → Fine-tuning if consistency critical. System prompt → Hardcoded logic if simple.

---

<a id="multi-agent"></a>
## Multi-Agent Systems

### Definition
Multiple independent agents working together. Specialization, parallel execution, consensus.

### Patterns

**Hierarchical**: Manager agent delegates to specialist agents. Manager: "Please review code" → Reviewer: provides feedback.

**Collaborative**: Agents cooperate. Agent1: writes code → Agent2: reviews → Agent1: fixes.

**Competitive**: Agents argue/debate. Pros: Idea1, Cons: Idea1 → Arbitrator: decides.

**Swarm**: Many simple agents, collective behavior emerges. Rarely used in LLM context.

### Q&A

**Q: Why multi-agent instead of single agent?**
- A: Specialization (expert agents better at tasks). Parallel execution (speed). Consensus (quality). Better handling of complex problems.

**Q: How to handle disagreement between agents?**
- A: Voting (majority). Arbitrator (referee agent decides). Debate (agents argue, arbitrator picks best). Escalate (send to human if can't decide).

**Q: What is prompt consistency across agents?**
- A: Different agents may interpret prompt differently. Solution: Shared context, explicit contracts (structured output), validation.

**Q: How to measure multi-agent quality?**
- A: Each agent's output + final aggregated output. Track time (N agents = slow if sequential). Cost (N * agent cost).

### Why This Approach
- **Specialization**: Expert agents better at narrow tasks.
- **Parallel**: Multiple agents = potential speedup (if parallelizable).
- **Consensus**: Multiple perspectives reduce errors.

### Pros & Cons

**Hierarchical Pros**: Clear structure, specialization, delegation.
**Hierarchical Cons**: Sequential (slow if deep), complex management.

**Collaborative Pros**: Iterative refinement (quality), specialization.
**Collaborative Cons**: Sequential (multiple rounds), complexity.

**Competitive Pros**: Challenge assumptions, reduce groupthink.
**Competitive Cons**: Time (debates slow), complexity.

### Right vs Wrong Usage

**✅ Right**: Hierarchical for well-defined tasks (code review). Collaborative for iterative (writing). Competitive for disagreement-resolution.

**❌ Wrong**: Don't use multi-agent for simple tasks (overhead). Don't parallelize interdependent tasks (wait for dependency). Don't ignore coordination complexity.

**Alternative**: Multi-agent → Single agent if task simple. Debate → Fine-tune model if disagreement common.

---

<a id="deployment"></a>
## Deployment & Monitoring

### Definition
Deploy LLM app to production. Monitor quality, cost, latency.

### Concepts

**Latency**: Response time. LLM call (1-10 seconds) + retrieval + parsing.

**Cost**: Per-token pricing. Track usage: input tokens + output tokens.

**Quality**: Accuracy metrics (BLEU, F1), user satisfaction, error rate.

**Monitoring**: Track latency, cost, quality. Alert on anomalies.

### Q&A

**Q: How to reduce latency?**
- A: Cache LLM responses (same query = same answer). Smaller model (faster but less accurate). Streaming (send tokens as they arrive). Parallel calls (if independent).

**Q: How to control costs?**
- A: Use cheaper model (GPT-3.5 vs GPT-4). Cache responses. Batch requests (off-peak). Limit context size. Fine-tune (cheaper than calling API repeatedly).

**Q: What to monitor in production?**
- A: Latency (p50, p95, p99). Cost per request. Error rate (API failures, timeouts). Quality metrics (accuracy, user satisfaction). Alert thresholds.

**Q: How to handle model changes (new GPT version)?**
- A: A/B test (50% users on old, 50% on new). Monitor quality delta. Rollback if worse. Gradual rollout (10% → 50% → 100%).

### Why This Approach
- **Caching**: Reduces latency + cost (don't recompute).
- **Monitoring**: Catch issues early (quality drift, cost spikes).
- **A/B Testing**: Safe rollout. Compare old vs new.

### Pros & Cons

**Caching Pros**: Reduced latency + cost (repeats = instant).
**Caching Cons**: Stale responses (cache time-based), storage overhead.

**Monitoring Pros**: Early detection, data-driven decisions.
**Monitoring Cons**: Overhead (instrumentation), alert fatigue (too many alerts).

**A/B Testing Pros**: Safe rollout, measured impact.
**A/B Testing Cons**: Time (need significant traffic), complexity (two code paths).

### Right vs Wrong Usage

**✅ Right**: Cache obvious candidates (product searches, FAQ). Monitor latency p99 (tail). A/B test model changes.

**❌ Wrong**: Don't cache user-specific queries (stale). Don't monitor everything (alert fatigue). Don't roll out major changes without testing.

**Alternative**: Caching → Time-based TTL if data fresh needed. Monitoring → Logs if metrics not needed. A/B → Canary if simpler.

---

## AIE-M1. One Model Call End to End

**Question:** What does an AI engineer own around one model call, beyond sending a prompt to an SDK?

**Answer:** An AI engineer turns a probabilistic model into a bounded product capability. The complete path includes request/authentication, product intent, input validation, policy and data classification, context/retrieval, prompt/template and schema versions, model routing, token/cost budgets, inference, structured parsing, grounding/verification, safety, tool authorization, retries/fallback, response streaming, telemetry, evaluation, feedback, and rollback. The model call is one dependency inside that system.

**What problem does it solve?** It makes quality, safety, latency, cost, privacy, and failure behavior explicit and testable instead of scattering them across controllers and prompt strings.

**Before this concept:** A feature called a provider directly from a controller, concatenated user text into a prompt, parsed free-form output, and logged the entire exchange. Model changes silently changed behavior and cost.

❌ **Wrong/before example — an unbounded call with an implicit contract:**

```csharp
[HttpPost("approve-refund")]
public async Task<string> ApproveRefund(string complaint)
{
    var response = await _llm.CompleteAsync(
        $"Decide whether to approve this refund: {complaint}");

    if (response.Contains("approve", StringComparison.OrdinalIgnoreCase))
        await _payments.RefundAsync();

    return response;
}
```

The model receives unclassified data, output parsing is ambiguous, the model can trigger a side effect, no policy facts are supplied, and there is no versioned evaluation contract.

✅ **After/correct example — model proposes; deterministic code validates and acts:**

```csharp
public sealed record RefundAssessment(
    bool RecommendApproval,
    string PolicyClause,
    decimal MaximumAmount,
    string[] MissingEvidence);

public async Task<RefundDecision> AssessAsync(
    RefundRequest request,
    CancellationToken cancellationToken)
{
    var policy = await _policyRepository.GetVersionAsync(
        request.PolicyVersion, cancellationToken);

    var assessment = await _ai.GenerateStructuredAsync<RefundAssessment>(new()
    {
        Capability = "refund-assessment-v3",
        ModelRoute = "reasoning-medium",
        Inputs = Redact(request, policy),
        MaximumInputTokens = 8_000,
        MaximumOutputTokens = 600,
        Deadline = TimeSpan.FromSeconds(8)
    }, cancellationToken);

    return _refundRules.ValidateAndDecide(request, policy, assessment);
}
```

**How it works now:** A capability contract owns the prompt/context/schema/model policy and evaluation version. The gateway enforces budgets and records safe telemetry. The model produces a typed recommendation with evidence. Deterministic business rules validate policy, money, authorization, and side effects. A rollout compares candidate versus baseline and can revert the entire capability version.

### End-to-end request map

```text
product request
 -> authenticate + authorize
 -> classify/redact data
 -> validate intent and budgets
 -> retrieve/assemble context
 -> render versioned instructions + schema
 -> route model and invoke
 -> parse/validate output
 -> ground/verify/policy-check
 -> request approval or execute bounded tool
 -> stream/respond
 -> trace + eval + feedback
```

**Trade-offs and when not to use it:** A wrapper/gateway adds latency and platform work. A small internal prototype may begin with a direct call, but money, access, external communication, personal data, or production traffic justify explicit contracts early. Do not create a generic abstraction that hides provider features or makes every capability share one prompt and fallback policy.

**Production checks:**

- Version prompt/template, retrieval policy, schema, model route, safety policy, and evaluator together.
- Enforce input/output/tool/cost/wall-time budgets and propagate cancellation.
- Separate user text, retrieved evidence, system policy, and tool output as untrusted/privileged channels.
- Test malformed output, provider timeout, throttling, partial stream, fallback, and policy dependency failure.
- Log identifiers, versions, timing, token/cost, and evaluation result without sensitive prompt/output content by default.
- Require deterministic authorization and human approval for high-impact or irreversible actions.

**Try it:** Trace one repository AI feature from HTTP request to final response. Name every version, trust boundary, token/cost budget, fallback, side effect, metric, and test. If any decision is implicit in a prompt string, move it into a reviewable capability contract.

---

## AIE-M2. Embedding and Retrieval Internals

**Question:** How do embeddings become search results, and how do storage, compression, indexing, filtering, hybrid retrieval, and reranking change quality and cost?

**Answer:** An embedding model maps inputs into vectors whose similarity should correlate with task relevance. The system stores vectors plus stable IDs, source versions, metadata, access controls, and text/chunk references. Exact search compares every vector; approximate indexes such as graph- or partition-based structures trade recall for latency/memory/build cost. Compression or lower precision reduces memory/bandwidth with possible recall loss. A production pipeline often combines lexical and vector candidates, applies authorization and structured filters, fuses scores, reranks a small set, and evaluates final evidence relevance.

**What problem does it solve?** It makes retrieval an engineered information-retrieval pipeline rather than “put embeddings in a vector database and choose top five.”

**Before this concept:** Documents were split every 500 characters, embedded once, and retrieved only by cosine similarity. Product codes, exact names, dates, tenant filters, updated documents, and deletion were unreliable.

❌ **Wrong/before example — similarity alone is treated as truth:**

```python
query_vector = embed(user_question)
chunks = vector_db.search(query_vector, top_k=5)
answer = llm.generate(user_question, chunks)
```

There is no tenant/ACL filter, embedding version, lexical path, threshold, deduplication, reranking, source freshness, or evidence-quality evaluation.

✅ **After/correct example — retrieval stages expose their contract:**

```python
query = understand(user_question)

lexical = bm25.search(
    query.text,
    filters={"tenant": tenant_id, "acl": principal_groups},
    limit=100,
)
semantic = ann.search(
    embedding_model.embed(query.semantic_text),
    filters={"tenant": tenant_id, "acl": principal_groups},
    limit=100,
    index_version="products-emb-v7",
)

candidates = reciprocal_rank_fusion(lexical, semantic)
candidates = deduplicate_by_source_and_span(candidates)
ranked = reranker.score(query.text, candidates[:50])
evidence = select_with_budget(ranked, max_tokens=6_000, minimum_score=0.62)
```

**How it works now:** Ingestion parses and chunks by document structure, assigns stable source/span IDs, embeds with a versioned model, and atomically publishes an index version. Query understanding selects exact/lexical/semantic paths. Metadata filtering occurs before or during candidate search where possible. Reranking improves precision over a bounded set. The answer cites selected sources, and evaluations separate retrieval failure from generation failure.

### Retrieval design dimensions

| Dimension | Question to answer |
|---|---|
| Embedding | Does the model represent this language/domain/query-document relationship? |
| Chunking | Does a chunk contain one useful answer unit with enough surrounding meaning? |
| Index | What recall/latency/memory/build/update trade-off fits the corpus and traffic? |
| Compression | How much recall/score stability is lost for memory and bandwidth saved? |
| Filters | Can tenant, ACL, date, product, and availability constraints be applied safely and efficiently? |
| Hybrid | Which exact terms, identifiers, and semantic concepts need lexical/vector candidates? |
| Reranking | Is added quality worth model latency/cost, and how many candidates should reach it? |
| Freshness | How are upsert, delete, re-embed, rebuild, alias swap, and rollback handled? |

**Trade-offs and when not to use it:** Vector search adds embeddings, duplicated data, eventual consistency, index tuning, and evaluation. Exact database or full-text search can be better for small corpora, structured filters, identifiers, and strict freshness. Reranking adds latency and cost. Compression saves resources but must be measured on the target retrieval set.

**Production checks:**

- Maintain query/relevance judgments and measure recall@k, precision@k, MRR/NDCG where appropriate, and answer evidence sufficiency.
- Enforce ACL/tenant filters in the retrieval service and test adversarial cross-tenant queries.
- Version embedding model, preprocessing, chunker, vector dimension, index parameters, and source document.
- Track indexing lag, missing/deleted/stale documents, duplicate chunks, filter selectivity, zero-result rate, and reranker latency.
- Rebuild into a new index/version, validate, switch an alias, and retain rollback.
- Evaluate compression/index parameter changes against exact-search or a trusted baseline on representative queries.

**Try it:** Build a 50-query judged set containing exact IDs, paraphrases, rare terms, dates, typos, negative filters, and access-control cases. Compare lexical, vector, hybrid fusion, and reranked retrieval. Explain every query where the “more advanced” pipeline loses.

---

## AIE-M3. Transformer Shapes, Attention, and KV State

**Question:** How do tokens and tensor shapes move through a decoder transformer, and where do attention cost and the KV cache come from?

**Answer:** Token IDs map to embeddings with shape `[batch, sequence, hidden]`. Each layer normalizes and projects hidden states into query, key, and value tensors, commonly reshaped by attention heads. Causal masked attention computes scores between each query position and allowed key positions, applies scaled softmax, combines values, merges heads, and continues through output projection and an MLP/residual path. During autoregressive inference, prior keys and values are cached per layer; each decode step computes new state and attends to cached history instead of recomputing every earlier token.

**What problem does it solve?** Shape fluency lets engineers debug memory, invalid dimensions, attention complexity, KV capacity, model parallelism, and why prefill/decode behave differently.

**Before this concept:** The model was treated as a black-box HTTP endpoint. Context increases caused OOM, but the team could not distinguish weight, activation, or KV growth or explain why grouped-query attention changed memory.

❌ **Wrong/before example — multiply tensors without naming axes:**

```python
scores = q @ k.T
# For batched multi-head tensors, .T reverses every dimension and is wrong.
```

✅ **After/correct example — state every axis and verify it:**

```python
# x: [batch, sequence, hidden]
b, s, h = x.shape

q = q_proj(x).view(b, s, q_heads, head_dim).transpose(1, 2)
k = k_proj(x).view(b, s, kv_heads, head_dim).transpose(1, 2)
v = v_proj(x).view(b, s, kv_heads, head_dim).transpose(1, 2)

assert q.shape == (b, q_heads, s, head_dim)
assert k.shape == (b, kv_heads, s, head_dim)

# An implementation expands/maps KV heads when q_heads != kv_heads.
scores = (q @ k_for_q_heads.transpose(-2, -1)) / math.sqrt(head_dim)
scores = scores.masked_fill(causal_mask, float("-inf"))
weights = torch.softmax(scores, dim=-1)
context = weights @ v_for_q_heads
```

**How it works now:** Every calculation names batch, sequence, head, and feature axes. Prefill handles many prompt queries/keys/values and creates cache state. Decode adds one or a few new token positions, reads the growing cache, and appends new K/V. Capacity math uses layer count, KV head count, head dimension, element bytes, and live cached tokens.

### Shape walkthrough example

For `batch=2`, `sequence=1024`, `hidden=4096`, `query_heads=32`, and `head_dim=128`:

```text
input hidden: [2, 1024, 4096]
Q:            [2, 32, 1024, 128]
attention:    conceptually [2, 32, 1024, 1024] during full prefill
context:      [2, 32, 1024, 128]
merged:       [2, 1024, 4096]
```

Multi-query/grouped-query attention uses fewer KV heads than query heads, reducing KV-cache memory and bandwidth. Positional schemes affect how token order enters attention and may constrain safe prefix reuse/context extension.

**Trade-offs and when not to use it:** The conceptual attention matrix is useful for reasoning, but optimized kernels may never materialize it in HBM. Implementation layouts differ. Shape exercises do not replace profiling. KV caching accelerates autoregressive reuse but consumes memory proportional to live cached tokens and is unnecessary in the same form for every non-autoregressive workload.

**Production checks:**

- Record the exact model configuration: layers, hidden size, query/KV heads, head dimension, context, dtype, positional method.
- Unit-test shapes, masks, padding, cache append, batch reorder, beam/candidate paths, and cancellation cleanup.
- Calculate weight and KV memory before deployment and compare with runtime pools.
- Validate long-context quality, not only that a larger position limit loads.
- Use optimized framework attention primitives unless a measured need justifies custom kernels.
- Keep tokenizer/model/positional/cache compatibility together during versioning and prefix reuse.

**Try it:** Choose one open decoder model configuration. Write every tensor shape for one layer during prefill and one-token decode. Calculate KV bytes/token, then explain how GQA/MQA, quantized KV, and tensor parallelism alter the memory or placement.

---

## AIE-M4. Match Optimizations to the Bottleneck

**Question:** How do you choose between PagedAttention, FlashAttention, MoE, quantization, sparse attention, distillation, and speculative decoding?

**Answer:** These techniques solve different problems. First measure whether the constraint is model quality, weight/KV capacity, attention IO, decode serialization, compute, memory bandwidth, context length, or cost. PagedAttention manages serving-time KV blocks. FlashAttention reduces exact-attention memory traffic. MoE increases total parameter capacity while activating a subset of experts but adds routing/communication. Quantization reduces representation size with kernel/quality trade-offs. Sparse attention reduces attended positions under a defined pattern. Distillation trains a smaller model to imitate useful behavior. Speculative decoding drafts and verifies tokens to reduce serial target steps when acceptance is high.

**What problem does it solve?** A bottleneck map prevents engineers from combining unrelated techniques, attributing gains incorrectly, or trading away quality and operability for a benchmark that does not match the product.

**Before this concept:** The team enabled a quantized MoE model, a new serving engine, prefix caching, and speculative decoding simultaneously. Quality and latency changed, but no one could explain which change helped or how to roll back safely.

❌ **Wrong/before example — optimization shopping list:**

```text
Goal: make AI cheaper
Plan: INT4 + MoE + FlashAttention + sparse attention + speculative decoding
Evidence: vendor benchmark screenshot
```

✅ **After/correct example — bottleneck decision record:**

```yaml
product_contract:
  quality: eval-suite-v12 >= baseline
  p99_ttft_ms: 1200
  p99_itl_ms: 90
  cost_per_resolved_task_usd: <= 0.04
measured_bottleneck:
  cohort: long-context-interactive
  finding: kv-capacity-and-prefill-io
candidate_sequence:
  - paged-kv-allocation
  - flash-attention-supported-kernel
  - measured-kv-quantization
hold_constant:
  - model-and-tokenizer-revision
  - workload-and-quality-suite
  - hardware-and-engine-version
rollback: previous-immutable-serving-profile
```

**How it works now:** A baseline is profiled by workload cohort. One hypothesis changes at a time. The experiment checks task quality, latency distribution, goodput, memory, power, cost, and failures. Techniques graduate only if their benefit survives production-shaped load and their operational complexity is acceptable.

### Technique selection map

| Technique | Strong signal to evaluate it | Important counter-check |
|---|---|---|
| PagedAttention | KV fragmentation/reservation limits concurrency | Scheduler/block overhead and actual fragmentation |
| FlashAttention | Attention IO/intermediates dominate supported shapes | Kernel support and whether attention is really dominant |
| MoE | Need higher model capacity without dense activation cost | Expert placement, imbalance, all-to-all, total weight memory |
| Weight quantization | Weight memory/bandwidth blocks fit or decode | Kernel maturity, calibration, quality, metadata/dequantization |
| KV quantization | Long-context/concurrency KV dominates | Attention quality, scale granularity, conversion/kernel overhead |
| Sparse attention | Full attention cost at long context is unacceptable | Task loses information outside the sparse pattern |
| Distillation | Smaller deployable model can learn the target task | Teacher bias, data rights, generalization, retraining lifecycle |
| Speculative decoding | Low-batch serial decode with high proposal acceptance | Draft cost/memory, verification, saturated-throughput regression |

**Trade-offs and when not to use it:** Optimization creates variant/artifact explosion and hardware/runtime coupling. A simple smaller model or shorter context can outperform a complex optimization stack. Model-architecture techniques such as MoE or sparse attention may require training choices, not a serving flag. Do not optimize before product quality and workload are measured.

**Production checks:**

- Keep one immutable baseline and change one major variable per experiment.
- Use representative cohorts, including long/short inputs, tools, structured outputs, and cancellations.
- Re-run the full quality/safety suite; perplexity or one benchmark is not the product contract.
- Track configuration/artifact/kernel versions and hardware compatibility.
- Compare cost per correct/SLO-compliant task, not raw tokens per second alone.
- Canary and retain a tested rollback that does not depend on an evicted artifact.

**Try it:** Take one slow AI workflow and write a bottleneck decision tree. For every candidate optimization, state the resource it targets, required measurement, expected gain, quality risk, operational cost, and condition that would make you reject it.

---

## AIE-M5. Reasoning, Verification, Tools, and MCP

**Question:** How should an AI system use reasoning, verification, tools, agent loops, and MCP without trusting plausible text or granting uncontrolled side effects?

**Answer:** Ask the model for the minimum structured artifact the application needs—answer, plan, arguments, evidence, or candidate solution—then verify it using deterministic constraints, tools, retrieval, tests, or a separately designed evaluator. An agent loop alternates model decisions with bounded tool observations under step, token, time, and permission budgets. MCP standardizes how clients discover and call tools/resources/prompts, but it does not make a server, description, data, or tool result trustworthy. Authorization belongs at execution time with least-privilege credentials and human approval for high-impact actions.

**What problem does it solve?** It converts open-ended model output into checkable progress while containing prompt injection, hallucinated tool arguments, loops, unauthorized access, and irreversible actions.

**Before this concept:** A prompt asked the model to “think step by step, use any available tool, and finish the task.” The same broad service credential was exposed to every request, and success meant the final text sounded confident.

❌ **Wrong/before example — free-form reasoning directly triggers a tool:**

```python
response = model.generate("Investigate and fix the customer's billing problem")
if "refund" in response.lower():
    payments.refund(customer_id, amount="all")
```

✅ **After/correct example — typed proposal, policy validation, scoped execution:**

```python
proposal = model.generate_schema(
    schema=RefundProposal,
    context=trusted_policy_plus_untrusted_customer_evidence,
    allowed_tools=["lookup_invoice", "lookup_refund_policy"],
)

verified = refund_policy.verify(
    principal=current_operator,
    invoice_id=proposal.invoice_id,
    amount=proposal.amount,
    evidence_ids=proposal.evidence_ids,
)

if verified.requires_human_approval:
    return approval_queue.create(verified)

return payments.refund(
    credential=short_lived_credential(scope="refund", invoice=verified.invoice_id),
    idempotency_key=verified.operation_id,
    amount=verified.amount,
)
```

**How it works now:** Instructions and policy are separated from untrusted content. The model selects only allow-listed tools and produces schema-valid arguments. The application authenticates the principal, reauthorizes each call, validates business rules, supplies task-scoped credentials, deduplicates effects, and records evidence. The loop stops on success, explicit failure, budget, or approval boundary.

### Verification choices

- **Deterministic checks:** schema, types, ranges, permissions, invariants, compilers, tests, calculators, database constraints.
- **Evidence checks:** citations exist, support the claim, match the source version, and are authorized for the user.
- **Independent candidate checks:** execute code in a sandbox, solve equations, simulate a plan, or compare against a known oracle.
- **Model graders/verifiers:** useful when human judgment is costly, but must be calibrated against humans and protected from shared bias/prompt leakage.
- **Search/tree reasoning:** generate and score multiple candidates only when improved success justifies extra latency/cost; bound branching/depth.

Do not require or store private hidden chain-of-thought. Ask for concise rationale, evidence, intermediate artifacts, or verifiable calculations appropriate to the product.

**Trade-offs and when not to use it:** Agents add latency, token cost, nondeterminism, and side-effect risk. A deterministic workflow or ordinary API integration is better when steps are known. Multiple agents often multiply coordination without improving correctness. Verification can be expensive and verifiers can share model blind spots.

**Production checks:**

- Enforce tool allow-lists, argument schemas, per-call authorization, short-lived credentials, network boundaries, and idempotency.
- Treat tool descriptions/results, retrieved text, web pages, and MCP server content as untrusted inputs.
- Bound steps, parallel branches, tokens, wall time, spend, retries, and paused state.
- Trace plan/tool/observation transitions without logging secrets or sensitive content.
- Test indirect prompt injection, malicious tool output, schema edge cases, approval bypass, duplicate calls, and cancellation.
- Evaluate task completion, evidence, unsafe actions avoided, human corrections, and cost—not eloquence.

**Try it:** Redesign one “autonomous agent” as a state machine. List states, allowed tools, credentials, invariants, verification, budgets, approval boundaries, retry/idempotency policy, and recovery after a tool succeeds but the agent times out.

---

## AIE-M6. Evaluation-Driven Production AI

**Question:** How do offline evaluation, online experiments, feedback, and observability become a development loop rather than a dashboard added after launch?

**Answer:** Define the product task and unacceptable failures, build a versioned dataset with representative and adversarial cases, measure components and end-to-end outcomes, and run the suite on every prompt/model/retrieval/tool/policy change. Calibrate model graders against human judgments. Use shadow/canary/A-B experiments with guardrails for online impact. Capture privacy-safe failure evidence, classify root cause, add confirmed cases to regression sets, and version the complete capability so it can roll back.

**What problem does it solve?** Evaluation-driven development prevents subjective prompt tweaking, detects regressions hidden by averages, and creates a data flywheel that improves the real failure distribution rather than a demo set.

**Before this concept:** Engineers tried five prompts on friendly examples and shipped the one they liked. Production failures were stored as screenshots, model upgrades were assumed better, and no test reproduced the issue.

❌ **Wrong/before example — one aggregate model score gates release:**

```python
if llm_judge(candidate_outputs).average_score > 0.8:
    deploy(candidate)
```

This omits judge calibration, task slices, safety, retrieval/tool failures, cost/latency, significance, and worst-case regressions.

✅ **After/correct example — multi-layer release gate:**

```yaml
capability_version: support-answer-v18
offline_gates:
  schema_validity: 1.0
  citation_entailment: ">= 0.97"
  task_success_overall: ">= baseline"
  task_success_each_critical_slice: ">= baseline - 0.01"
  forbidden_disclosure: 0
  tool_side_effect_simulation_failures: 0
  p95_cost_and_latency: "within approved budget"
online_rollout:
  shadow: true
  canary_percent: [1, 5, 20, 50, 100]
  guardrails: [escalation_rate, complaint_rate, safety, latency, cost]
rollback_on: "guardrail breach or unexplained critical failure"
```

**How it works now:** Every run records dataset version, capability version, model/provider revision, outputs, component traces, scores, and reviewer labels. Failures are attributed to input policy, retrieval, context, model reasoning, structured parsing, tool selection/execution, safety filter, or UX. Confirmed production failures become minimized regression cases with privacy review.

### Evaluation pyramid

1. **Deterministic unit/contract tests:** schemas, prompt rendering, filters, permissions, budgets, tool mocks, parsers.
2. **Component evals:** retrieval recall, reranker quality, classifier calibration, tool selection/arguments, citation support.
3. **End-to-end offline evals:** task success, groundedness, safety, style, latency, cost by slice.
4. **Adversarial/red-team evals:** prompt injection, data leakage, policy evasion, denial-of-wallet, unsafe tools.
5. **Shadow/canary/online experiments:** real distribution with product metrics and guardrails.
6. **Monitoring and feedback:** drift, failure taxonomy, human escalation, rollback, dataset growth.

**Trade-offs and when not to use it:** Evaluation sets can overfit and stale; human labels cost time; model judges inherit bias; online experiments may be unethical for high-risk behavior. Use deterministic or expert review where required. Do not collect prompts/outputs without consent, minimization, retention, and access controls.

**Production checks:**

- Slice by task, language, tenant/product, input length, risk, model route, retrieval/tool path, and known edge cases.
- Calibrate graders against blinded human labels and monitor disagreement/drift.
- Keep a locked holdout and periodically refresh from real failures without leaking answers into prompts.
- Gate quality, safety, schema, latency, cost, and reliability together.
- Trace version lineage so every output can be reproduced or at least explained from preserved artifacts/configuration.
- Make user feedback actionable: distinguish dislike, factual error, missing evidence, policy failure, latency, and UX.

**Try it:** Create a 30-case evaluation plan for one AI feature. Include happy, boundary, adversarial, long-input, ambiguous, no-answer, tool-failure, and authorization cases. Define component metrics, end-to-end success, critical slices, human rubric, rollout gates, and how a production failure becomes a regression test.

---

## AI Engineering Practice Workbook

Answer these without notes, then verify against the key. For each answer, add one production failure and one metric that would reveal it.

### Questions

1. Why is a model call a dependency rather than the product boundary?
2. A vector search returns semantically similar but unauthorized documents. Which layer failed, and why is prompt instruction insufficient?
3. When would hybrid lexical/vector retrieval outperform either alone?
4. For a decoder with 24 layers, 4 KV heads, head dimension 128, and FP16 KV, calculate KV bytes/token.
5. Explain why FlashAttention and PagedAttention are not competing names for the same optimization.
6. A 4-bit model uses less GPU memory but has worse cost per resolved task. Give four explanations.
7. Why should a model not directly authorize a refund even if its offline accuracy is 99%?
8. When is tree/search reasoning justified, and what budgets must be explicit?
9. What is wrong with using one LLM judge as the entire release gate?
10. A candidate model improves average task success but regresses one rare safety-critical slice. What should the rollout do?
11. How do you distinguish retrieval failure from generation failure?
12. What must be versioned to reproduce an AI capability beyond the model name?

### Answer key

1. Product behavior also depends on data/policy, context, prompt/schema, routing, validation, tools, safety, budgets, telemetry, and rollback. Those belong to an owned capability contract around the model.
2. Retrieval authorization failed. Untrusted documents must be filtered before they enter context; a prompt asking the model not to reveal them is not an access-control boundary.
3. Exact identifiers, names, numbers, and rare terms favor lexical retrieval; paraphrases/concepts favor embeddings. Fusion plus reranking can recover both when evaluated on the target query set.
4. `2 × 24 × 4 × 128 × 2 = 49,152 bytes/token`, or 48 KiB/token, before allocator/block overhead.
5. FlashAttention is an IO-aware exact attention computation that reduces memory traffic/intermediates. PagedAttention manages serving KV memory in blocks/pages. A serving engine may use both.
6. Poor kernels/dequantization, quality loss causing retries/escalation, lower batching/goodput, extra calibration/operations, unsupported shapes/fallback, or a smaller model missing tasks and invoking tools/humans more often.
7. Accuracy is not authorization. Money movement needs deterministic identity, policy, amount/invariant checks, audit, idempotency, and often human approval; the model can propose evidence, not own permission.
8. Use it when multiple candidates plus verification materially improve a high-value task. Bound branching, depth, tokens, wall time, spend, tools, side effects, and stopping/approval rules.
9. The judge may share bias, be uncalibrated, miss critical slices, be prompt-sensitive, and ignore safety/latency/cost. Use deterministic checks, calibrated humans/judges, component metrics, slices, and online guardrails.
10. Block or restrict the rollout until the critical regression is understood and mitigated. Averages cannot trade away a declared zero/near-zero critical-failure constraint.
11. Inspect whether relevant authorized evidence appeared in candidate/context (retrieval) and whether the answer used it correctly (generation). Maintain separate judged retrieval and answer-evidence metrics.
12. Data/source versions, preprocessing/chunking, embeddings/index, retrieval/reranking, prompt/template, schema, model/provider parameters, tools, policy/safety, evaluator, runtime, and rollout configuration.

## Summary Table

| Concept | Use Case | Trade-off |
|---------|----------|-----------|
| LLM | General knowledge, reasoning | Hallucination, cost |
| RAG | Knowledge base, documentation | Retrieval errors, latency |
| Agents | Multi-step, complex tasks | Unpredictable, expensive |
| Fine-tuning | Domain-specific, accuracy critical | Expensive, slow, forgetting |
| Few-shot | Quick iteration, flexible | Lower accuracy, token cost |
| Chain-of-Thought | Math, logic, reasoning | Slower, longer responses |
| Vector DB | Semantic search, RAG | Model-dependent, approximate |
| Multi-agent | Specialization, consensus | Complexity, sequential slowdown |
| Caching | Repeated queries | Stale responses |
| Monitoring | Production quality, cost | Overhead, alert fatigue |
| Capability contract | Version the full product behavior around a model | Platform work and explicit governance |
| Hybrid retrieval + reranking | Exact and semantic evidence with higher precision | Indexing, latency, evaluation, synchronization |
| Transformer/KV shape analysis | Explain memory, attention, and inference phases | Model-specific detail and implementation variation |
| Bottleneck-driven optimization | Improve measured quality/latency/memory/cost constraint | Artifact and runtime complexity |
| Typed tools + verification | Make model proposals checkable and side effects safe | Extra latency, policies, approval paths |
| Evaluation-driven development | Prevent regressions and learn from production failures | Dataset, labeling, privacy, and grader maintenance |

## Primary References for the Mastery Extensions

- [Fanout AI Engineering public curriculum](https://fanout.sh/ai-engineering/overview)
- [Fanout course roadmaps](https://fanout.sh/roadmaps)
- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [FlashAttention](https://proceedings.neurips.cc/paper_files/paper/2022/hash/67d57c32e20fd0a7a302cb81d36e40d5-Abstract.html)
- [PagedAttention/vLLM](https://arxiv.org/abs/2309.06180)
- [Speculative Decoding](https://proceedings.mlr.press/v202/leviathan23a.html)
- [Inference Engineering workbook](inference-engineering.md)

---

**Key Takeaway**: LLM apps require iteration, evaluation, and monitoring. Start simple (prompting), scale to complex (agents, fine-tuning) only when needed.

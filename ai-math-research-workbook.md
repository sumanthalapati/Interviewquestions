# AI Mathematics & Research Practice Workbook

This workbook turns the public topic lists in Fanout's [AI Research roadmap](https://fanout.sh/roadmaps/ai-research?track=ai) and [ML mathematics roadmap](https://www.fanout.sh/blog/ml-math-roadmap-for-engineers-without-a-math-degree) into original worked questions, answer keys, calculations, and implementation exercises. It does not reproduce paid lesson content.

Use paper, code, and diagrams. For each problem:

1. Translate the notation into plain language.
2. Write tensor/vector shapes and units beside every operation.
3. Calculate a small case by hand.
4. Implement the same case and compare results.
5. State numerical, statistical, or experimental failure modes.

## Workbook Index

1. [Notation, functions, sets, argmax, and boundaries](#1-notation-functions-sets-argmax-and-boundaries)
2. [Vectors, matrices, dot products, projections, rank, and SVD](#2-vectors-matrices-dot-products-projections-rank-and-svd)
3. [Derivatives, gradients, chain rule, Jacobians, and backpropagation](#3-derivatives-gradients-chain-rule-jacobians-and-backpropagation)
4. [Probability, expectation, entropy, cross-entropy, and KL divergence](#4-probability-expectation-entropy-cross-entropy-and-kl-divergence)
5. [Optimization, norms, numerical stability, and moving averages](#5-optimization-norms-numerical-stability-and-moving-averages)
6. [Tensor programming, shapes, broadcasting, and automatic differentiation](#6-tensor-programming-shapes-broadcasting-and-automatic-differentiation)
7. [Neural networks from scratch, normalization, and gated activations](#7-neural-networks-from-scratch-normalization-and-gated-activations)
8. [Attention and transformers from scratch](#8-attention-and-transformers-from-scratch)
9. [Reinforcement learning and policy optimization](#9-reinforcement-learning-and-policy-optimization)
10. [Fine-tuning, LoRA, QLoRA, data, and evaluation](#10-fine-tuning-lora-qlora-data-and-evaluation)
11. [MLOps, reproducibility, deployment, and monitoring](#11-mlops-reproducibility-deployment-and-monitoring)
12. [Research reproduction, ablations, and technical writing](#12-research-reproduction-ablations-and-technical-writing)

---

## 1. Notation, Functions, Sets, Argmax, and Boundaries

### Concept map

- A **function** maps each allowed input in its domain to one output in its codomain.
- A **predicate** returns true/false; an **indicator** converts that result to `1` or `0`.
- `argmax` returns the input/index that maximizes a value; `max` returns the value itself.
- A **supremum** is the least upper bound and need not belong to the set.
- Interior and boundary points describe whether a small neighborhood stays inside a region.
- A vertical bar can mean “such that,” conditional probability, determinant, norm/absolute value, divisibility, or evaluation depending on context.

### Worked example

Let `S = {(x, y) ∈ R² | x² + y² < 1}`.

- Plain language: points strictly inside the unit circle.
- Indicator: `1_S(x,y) = 1` when `x² + y² < 1`, otherwise `0`.
- `(0,0)` is interior because a small circle around it remains in `S`.
- `(1,0)` is a boundary point but is not in `S` because the inequality is strict.
- `sup{x | (x,0) ∈ S} = 1`, but no point in the set has `x = 1`; therefore the supremum is not a maximum.

### Practice questions

1. For scores `[0.2, 1.8, 1.8, -0.4]`, what are `max` and `argmax`? What ambiguity must code handle?
2. Translate `A = {x ∈ R | 0 ≤ x < 3}` into an indicator function. Is `3` interior, boundary, or exterior?
3. In `P(Y | X)`, `f(x) |_(x=0)`, and `{x | x > 2}`, what does the bar mean?
4. Give a set with supremum `5` but no maximum, and a set with both supremum and maximum `5`.

### Answer key

1. `max = 1.8`; `argmax` is the set of indices `{1,2}`. Many libraries return the first maximum, so tie behavior must be documented—especially when argmax selects a class or action.
2. `1_A(x)=1` when `0 ≤ x < 3`, otherwise `0`. Point `3` is a boundary point and is not in the half-open set.
3. Conditional on `X`; evaluate `f` at `x=0`; “such that.” Symbols must be read from grammar and surrounding objects, not memorized with one meaning.
4. `[0,5)` has supremum 5 but no maximum. `[0,5]` has supremum and maximum 5.

### Build task

Write a small notebook that plots open/closed planar regions, samples points, evaluates indicator functions, and marks interior/boundary candidates. Add tests for strict versus non-strict inequalities.

---

## 2. Vectors, Matrices, Dot Products, Projections, Rank, and SVD

### Concept map

- A vector can represent a point, direction, feature row, embedding, gradient, or parameter slice.
- A dot product measures aligned magnitude; cosine similarity normalizes by vector lengths.
- Matrix multiplication composes weighted sums; inner dimensions must agree.
- A projection finds the component along a direction/subspace.
- Rank counts independent directions represented by a matrix.
- SVD factors `A = UΣVᵀ`; truncating singular values produces a best low-rank approximation under common norms.

### Worked example — similarity is not the same as dot product

Let `a = [1, 2]`, `b = [2, 0]`.

```text
a · b = 1×2 + 2×0 = 2
||a||₂ = √5
||b||₂ = 2
cos(a,b) = 2 / (2√5) = 1/√5 ≈ 0.447
```

If one embedding has a much larger norm, raw dot-product ranking can differ from cosine ranking. The model/index contract determines which score is valid.

### Practice questions

1. Multiply `A=[[1,2],[3,4]]` by `x=[5,6]`. State every shape.
2. Project `v=[3,4]` onto `u=[1,0]`.
3. Why does a matrix with one row equal to twice another have reduced rank?
4. What does keeping only the top `k` singular values trade away and gain?
5. Why can vector quantization/compression change nearest-neighbor order?

### Answer key

1. `A` is `[2,2]`, `x` is `[2]` (or `[2,1]` as a column), and output is `[2]`: `[1×5+2×6, 3×5+4×6] = [17,39]`.
2. `proj_u(v) = (v·u / u·u)u = (3/1)[1,0] = [3,0]`.
3. The second row adds no new independent direction; it is a linear combination of the first. Redundant rows/columns reduce the dimension of the spanned space.
4. Gain: fewer parameters/bytes and faster approximate computation. Loss: information/energy in discarded singular directions, which may hurt the downstream task even when reconstruction error is small.
5. Compression perturbs vector components and therefore distances/similarities. Close candidates can swap order; recall must be measured on judged queries.

### Build task

Generate a matrix with known low-rank structure plus noise. Compute SVD, reconstruct with ranks 1..k, plot reconstruction error, and test whether downstream nearest-neighbor labels remain stable.

---

## 3. Derivatives, Gradients, Chain Rule, Jacobians, and Backpropagation

### Concept map

- A derivative is local sensitivity of one scalar output to one scalar input.
- A partial derivative varies one input while holding others fixed.
- A gradient collects scalar-output partial derivatives into a vector.
- A Jacobian contains derivatives of vector outputs with respect to vector inputs.
- The chain rule composes local derivatives through a computation graph.
- Backpropagation efficiently applies reverse-mode automatic differentiation from a scalar loss to many parameters.

### Worked example — backpropagate through one neuron

Let `z = wx + b`, `ŷ = z²`, and `L = (ŷ - y)²`. Use `x=2`, `w=3`, `b=1`, `y=25`.

```text
z = 3×2+1 = 7
ŷ = 7² = 49
L = (49-25)² = 576

dL/dŷ = 2(ŷ-y) = 48
dŷ/dz = 2z = 14
dz/dw = x = 2

dL/dw = 48 × 14 × 2 = 1344
dL/db = 48 × 14 × 1 = 672
```

The values are large because the nested square and error amplify sensitivity. This is a useful warning about scale, initialization, and exploding gradients.

### Practice questions

1. For `f(x)=x³`, compute the derivative at `x=2` and verify with a finite difference.
2. For `f(x,y)=x²+3xy`, compute the gradient.
3. If `y = softmax(Wx)` with `x∈R^d`, `W∈R^(c×d)`, what are the shapes of `Wx`, `y`, and the Jacobian `∂y/∂x`?
4. Why is reverse mode well suited to one scalar loss and millions of parameters?
5. What can cause a numerical gradient check to fail even when analytic differentiation is correct?

### Answer key

1. `f'(x)=3x²`, so `f'(2)=12`. Finite difference `(f(2+ε)-f(2-ε))/(2ε)` approaches 12 for a sensible `ε`; too large adds approximation error, too small suffers floating-point cancellation.
2. `∂f/∂x=2x+3y`, `∂f/∂y=3x`; gradient is `[2x+3y, 3x]`.
3. `Wx:[c]`, `y:[c]`, and `∂y/∂x:[c,d]`.
4. Reverse mode propagates one output's adjoint backward and obtains gradients for all upstream parameters in roughly a small multiple of forward computation, without explicitly materializing a full Jacobian.
5. Non-smooth points, stochastic layers, state mutation, mixed precision, poor `ε`, nondeterminism, or comparing different reduction/scaling conventions.

### Build task

Implement a tiny scalar autograd engine with values, operations, local derivative rules, topological sorting, and backward accumulation. Test it against finite differences and a framework on branching graphs where one variable affects the loss through two paths.

---

## 4. Probability, Expectation, Entropy, Cross-Entropy, and KL Divergence

### Concept map

- A random variable maps outcomes to values; a distribution assigns probabilities/density.
- Expectation is a probability-weighted average, not necessarily an observed value.
- Variance measures squared deviation around the mean; covariance measures joint variation.
- Conditional probability and Bayes' rule update beliefs using evidence.
- Entropy measures uncertainty in a distribution.
- Cross-entropy scores predictions against a target distribution.
- KL divergence measures directed distribution mismatch and is not a symmetric distance.

### Worked example — cross-entropy from logits

For logits `[2, 1, 0]`, subtract the maximum for numerical stability and exponentiate:

```text
shifted = [0, -1, -2]
exp ≈ [1, 0.3679, 0.1353]
sum ≈ 1.5032
softmax ≈ [0.6652, 0.2447, 0.0900]
```

If the true class is index 0, cross-entropy is `-log(0.6652) ≈ 0.4076`. If the true class is index 2, loss is `-log(0.0900) ≈ 2.4079`. The same logits are judged differently by the target.

### Practice questions

1. A disease has 1% prevalence. A test has 95% sensitivity and 90% specificity. Is a positive result 95% likely to mean disease? Calculate the posterior.
2. Compare entropy of `[1,0]` and `[0.5,0.5]`.
3. Why is `KL(P||Q)` different from `KL(Q||P)`?
4. What does label smoothing change in the target distribution and loss?
5. Why can average log loss improve while rare-class recall gets worse?

### Answer key

1. No. Out of 10,000: about 100 diseased → 95 true positives; 9,900 healthy → 990 false positives. Posterior is `95/(95+990) ≈ 8.76%`. Base rates matter.
2. `[1,0]` has zero entropy under the usual convention; outcome is certain. `[0.5,0.5]` has one bit (or `ln 2` nats), the maximum for two classes.
3. Each expectation weights regions using a different distribution; missing mass and penalty behavior differ. KL is nonnegative but asymmetric and does not obey all metric properties.
4. It replaces a one-hot target with a mixture that gives non-target classes small mass, discouraging extreme confidence. It can improve calibration/generalization but may hurt tasks needing very sharp probabilities and changes the minimum achievable loss.
5. The majority classes dominate the aggregate. Slice metrics, confusion matrices, calibration, and cost-sensitive objectives are needed when rare classes matter.

### Build task

Simulate the medical-test example across prevalences from 0.1% to 50%. Plot posterior probability after a positive test. Then implement stable `logsumexp`, softmax, cross-entropy, entropy, and both KL directions with unit tests for zero/near-zero probabilities.

---

## 5. Optimization, Norms, Numerical Stability, and Moving Averages

### Concept map

- Gradient descent follows a local descent direction; learning rate controls step size.
- Momentum/Adam accumulate gradient history; their state and bias correction matter.
- L1 and L2 norms encode different geometry and regularization behavior.
- Conditioning affects how easily one step size works in every direction.
- Stable implementations avoid overflow, underflow, cancellation, and division by tiny values.
- Exponential moving averages smooth noisy measurements or parameter trajectories with a defined time scale.

### Worked example — stable softmax

Naively exponentiating `[1000,1001]` overflows ordinary floating point. Subtracting the maximum preserves probabilities:

```text
softmax([1000,1001])
= softmax([-1,0])
= [e^-1/(e^-1+1), 1/(e^-1+1)]
≈ [0.2689, 0.7311]
```

The common shift cancels in the ratio, so numerical stability improves without changing the mathematical result.

### Practice questions

1. Why can a learning rate that works in one direction oscillate in another for an ill-conditioned loss?
2. Compare the geometry and typical sparsity effect of L1 and L2 regularization.
3. An EMA uses `m_t = βm_(t-1) + (1-β)x_t`. Roughly how does larger `β` change responsiveness?
4. Why does mixed precision often keep some accumulations or optimizer state in higher precision?
5. What experimental controls are needed to compare Adam and SGD fairly?

### Answer key

1. Curvature differs by direction. A step safe along a flat axis may overshoot a steep axis, creating zig-zagging or divergence. Scaling/preconditioning/adaptive methods can help.
2. L1 balls have corners aligned with axes and often drive coefficients exactly to zero; L2 shrinks smoothly and spreads penalty across correlated features. Neither automatically selects the best causal features.
3. Larger `β` averages over a longer effective history, reducing noise but reacting more slowly to change. Bias correction may be needed early when initialized at zero.
4. Small gradients/updates can underflow and long sums lose precision; higher-precision master weights, accumulators, loss scaling, and numerically stable kernels preserve signal.
5. Same model/data split/order or seeds, initialization, augmentation, total update/compute budget, learning-rate tuning budget/schedule, regularization, precision, and evaluation intervals. Comparing defaults is not an optimizer experiment.

### Build task

Optimize an elongated quadratic with SGD, momentum, and Adam. Plot paths and loss against both steps and wall time. Add gradient clipping and mixed precision, then explain whether each change addresses explosion, conditioning, bandwidth, or something else.

---

## 6. Tensor Programming, Shapes, Broadcasting, and Automatic Differentiation

### Concept map

- Tensor code is easier to verify when every axis has a semantic name and expected size.
- `reshape/view`, transpose/permute, squeeze/unsqueeze, concatenate, and stack change layout or interpretation differently.
- Broadcasting aligns dimensions from the right and expands size-1 axes conceptually.
- Contiguity/strides determine whether a view is possible and how memory is traversed.
- Automatic differentiation records operations and applies chain rules; mutation/detach/control flow can alter the graph.

### Worked example — broadcasting with named shapes

```python
# activations: [batch=32, sequence=128, hidden=768]
# bias:        [hidden=768]
output = activations + bias
```

The bias behaves as `[1,1,768]` and is shared across batch/sequence. This is intended. Accidentally adding a vector of length 128 could align with the wrong axis only if shapes permit, producing a plausible but incorrect result.

### Practice questions

1. What is the difference between concatenating two `[4,8]` tensors on axis 0 versus stacking them on a new axis?
2. Why can `view` fail after a transpose while `reshape` succeeds by copying?
3. For `A:[32,1,128]` and `B:[1,64,1]`, what is the broadcast output shape?
4. Why is in-place mutation risky for autograd?
5. How do you detect a silent batch/sequence-axis swap?

### Answer key

1. Concatenate axis 0 gives `[8,8]`; stack gives `[2,4,8]`. Concatenate extends an existing dimension; stack creates a new one.
2. Transpose changes strides and may make the desired logical order non-contiguous. `view` requires compatible strides; `reshape` may allocate/copy to satisfy the shape.
3. `[32,64,128]`.
4. Backward may need the original value/version. Mutation can invalidate saved tensors or silently change another view; frameworks detect many but not all conceptual mistakes.
5. Assert named dimensions, use distinct non-equal test sizes, compare a hand-computed tiny case, check masks, and include permutation-sensitive tests. Equal dimensions can hide swaps.

### Build task

Implement a small attention-like tensor computation twice: one clear version with explicit shape assertions/einsum, and one optimized batched-matmul version. Test equality, gradients, non-contiguous inputs, masks, and batch/sequence sizes that cannot be confused.

---

## 7. Neural Networks from Scratch, Normalization, and Gated Activations

### Concept map

- A neuron computes an affine transformation followed by an activation.
- Layers compose representations; nonlinearities prevent the entire stack collapsing into one linear map.
- Loss connects outputs to an objective; backprop computes parameter gradients.
- Initialization and normalization control signal/gradient scale.
- RMSNorm scales by root-mean-square magnitude without subtracting the mean.
- Gated activations such as SwiGLU combine a value branch with a learned gate and change parameter/compute layout.

### Worked example — two-layer network shapes

```text
X:  [batch, input=4]
W1: [4, hidden=8]     -> H_pre: [batch,8]
H = ReLU(H_pre)
W2: [8, classes=3]    -> logits: [batch,3]
cross-entropy(logits, labels)
```

Without the activation, `XW1W2` is another linear map and added depth does not create nonlinear decision boundaries.

### Practice questions

1. Why can zero-initializing every weight in a hidden layer prevent units from learning distinct features?
2. What does normalization stabilize, and why does it not remove the need for careful optimization?
3. Compare ReLU and a smooth gated activation in compute and behavior.
4. Why calculate loss from logits with a fused cross-entropy routine rather than softmax then log manually?
5. What tests should a network-from-scratch implementation pass before training on real data?

### Answer key

1. Symmetric units receive identical activations and gradients, so they remain identical. Random/asymmetric initialization breaks symmetry while controlling variance.
2. It controls activation scale and can improve gradient flow/training stability. It does not choose a learning rate, fix bad data/objectives, or guarantee numerical stability.
3. ReLU is cheap and sparse but non-smooth with dead-unit risk. Gated smooth activations can improve expressivity/optimization but require additional projections/multiplications and tuned kernels.
4. Fused log-softmax/cross-entropy uses stable log-sum-exp and avoids materializing probabilities or taking `log(0)` after underflow.
5. Forward tiny cases, shape errors, finite-difference gradient checks, framework parity, overfit a tiny dataset, deterministic seed behavior, serialization, and loss decrease without NaNs.

### Build task

Implement a two-layer classifier using only array operations. Add stable cross-entropy, backprop, gradient checking, SGD/Adam, checkpointing, and an option for RMSNorm. Overfit 20 samples before attempting a full dataset.

---

## 8. Attention and Transformers from Scratch

### Concept map

- Scaled dot-product attention computes `softmax(QKᵀ/√d_k + mask)V`.
- Self-attention derives Q/K/V from the same sequence; cross-attention uses another source for K/V.
- Causal masking prevents access to future tokens during autoregressive training/generation.
- Multi-head attention learns multiple projected subspaces, then concatenates/merges them.
- Residual paths, normalization, MLPs, positional information, and token embeddings form a transformer block.
- Training processes shifted token targets in parallel; autoregressive inference generates sequentially and benefits from KV caching.

### Worked example — why scale dot products

If query/key components have variance near 1, their dot product variance grows with dimension `d_k`. Dividing by `√d_k` keeps logits in a range where softmax is less likely to saturate, improving gradient behavior.

### Practice questions

1. For `Q:[b,h,s_q,d]` and `K:[b,h,s_k,d]`, what is the attention-score shape?
2. Why must the causal mask be applied before softmax, and what value is commonly used conceptually?
3. What does a positional representation add that token embeddings alone lack?
4. Why does KV caching save compute but consume memory proportional to cached tokens?
5. How do grouped-query and multi-query attention change KV heads and serving behavior?

### Answer key

1. `Q @ K.transpose(-2,-1)` gives `[b,h,s_q,s_k]`.
2. Future/disallowed logits must receive effectively negative infinity so their softmax probability becomes zero. Masking after softmax would require renormalization and risks leakage.
3. Attention over an unordered set of embeddings cannot distinguish order by itself. Positional information lets the model represent sequence position/relative relationships.
4. Prior K/V are reused rather than recomputed for every new token, but each layer retains their tensors for every live past token.
5. They use fewer KV heads than query heads, reducing KV memory/bandwidth. Query heads share/map to KV heads, changing shapes/kernels but not eliminating attention.

### Build task

Implement masked single-head attention, then multi-head attention and one pre-norm decoder block. Add shape/mask tests and compare full-sequence logits with token-by-token inference using a KV cache.

---

## 9. Reinforcement Learning and Policy Optimization

### Concept map

- An MDP defines states, actions, transition dynamics, rewards, and discounting.
- A policy maps states/observations to action distributions.
- A value function estimates expected return; an advantage compares an action with a baseline.
- DQN learns action values for discrete actions with replay/target stabilization.
- Policy gradients optimize expected return directly but can have high variance.
- PPO constrains updates using clipped probability ratios; reasoning-model variants still depend on reward quality, sampling, and stable updates.

### Worked example — discounted return

For rewards `[1, 0, 2]` and discount `γ=0.9`, return from the first step is:

```text
G₀ = 1 + 0.9×0 + 0.9²×2 = 2.62
```

Discounting encodes how future rewards are valued; it is not simply a numerical trick.

### Practice questions

1. Why can maximizing a poorly designed reward make observed behavior worse?
2. What role does an advantage baseline play in policy-gradient variance?
3. Why use a target network and replay buffer in DQN, and what new issues do they add?
4. In PPO, why can unconstrained repeated optimization on one batch destabilize the policy?
5. For LLM reasoning optimization, what must be versioned about generated rollouts and rewards?

### Answer key

1. The agent exploits what is measured rather than the intended goal—reward hacking/specification gaming. Use multiple constraints, audits, adversarial tests, and inspect trajectories, not only reward.
2. Subtracting a state-dependent baseline preserves the expected policy-gradient direction while reducing variance; advantage indicates whether an action did better than expected.
3. Replay reduces correlation and reuses experience; a target network makes bootstrapped targets change more slowly. Replay can become stale/off-policy and consumes memory; target update schedules add tuning.
4. Large policy changes invalidate the data distribution/importance ratios and can collapse behavior. Clipping/KL controls, limited epochs, normalization, and monitoring constrain the step.
5. Policy/model/tokenizer revision, sampling parameters/seeds, prompts/tasks, tool/environment version, reward/verifier version, reference policy, filtering, and training assignment.

### Build task

Implement a multi-armed bandit, REINFORCE on a tiny environment, and a clipped-ratio update on fixed trajectories. Plot reward plus policy entropy/KL so improvement and collapse are both visible.

---

## 10. Fine-Tuning, LoRA, QLoRA, Data, and Evaluation

### Concept map

- Fine-tuning changes model parameters for desired behavior/domain/task.
- LoRA learns low-rank updates to selected matrices while base weights remain frozen.
- QLoRA stores the frozen base in low precision while training adapters with higher-precision compute/state.
- Data quality, diversity, deduplication, rights, formatting, and train/eval separation often matter more than raw row count.
- Fine-tuning is for behavior/skill/style adaptation; frequently changing factual knowledge is often better retrieved.

### Worked example — LoRA parameter count

For a matrix `W ∈ R^(d_out × d_in)`, LoRA uses `B ∈ R^(d_out × r)` and `A ∈ R^(r × d_in)`. Trainable parameters are:

```text
r(d_out + d_in)
```

Instead of `d_out × d_in`. With both dimensions 4096 and `r=16`, LoRA trains `16×8192=131,072` values versus `16,777,216` in the full matrix—before considering which layers receive adapters.

### Practice questions

1. When should RAG be preferred over fine-tuning?
2. What does a low-rank update assume, and how would you detect an insufficient rank?
3. Why can quantized base weights reduce training memory without making every optimizer/activation tensor 4-bit?
4. What leakage makes a fine-tuning benchmark look falsely strong?
5. Why keep a base-model and prompt/RAG baseline during fine-tuning?

### Answer key

1. When knowledge changes, citations/provenance matter, access control varies, or the model must use an external private corpus. Fine-tuning can complement RAG for behavior.
2. The useful update lies approximately in a low-dimensional subspace. Increase/target rank or layers and inspect training/validation/task slices if both optimization and capacity appear limited.
3. QLoRA quantizes frozen storage but computation, adapter gradients, activations, and optimizer state need formats that preserve learning signal; memory pools are different.
4. Duplicate/near-duplicate examples across splits, benchmark answers in training/context, selecting checkpoints on the test set, or contamination from generated teacher data.
5. To prove the added training cost and complexity beats simpler alternatives and to detect regressions/catastrophic forgetting outside the narrow task.

### Build task

Prepare a small legally usable dataset with train/validation/locked-test splits and slice labels. Train one LoRA configuration, log exact artifacts/hyperparameters, compare with prompting/RAG baselines, and publish both wins and regressions.

---

## 11. MLOps, Reproducibility, Deployment, and Monitoring

### Concept map

- Reproducibility requires code, data, environment, configuration, seed, and artifact lineage.
- Experiment tracking compares hypotheses, not just stores metrics.
- Data validation detects schema/range/distribution/leakage issues before training.
- CI tests code/contracts; continuous training is justified only when new data and gates warrant it.
- Deployment uses immutable artifacts, shadow/canary gates, rollback, and model/data monitoring.
- Drift does not automatically mean retrain; first determine whether product quality changed and why.

### Worked example — minimum model release record

```yaml
release: fraud-model-v17
code_commit: exact-sha
environment_image: immutable-digest
training_data: dataset-snapshot-v42
feature_schema: fraud-features-v8
model_artifact: content-hash
hyperparameters: tracked-run-1082
offline_eval: report-v17
serving_contract: input-output-schema-v5
rollout: shadow-then-canary
rollback: fraud-model-v16
```

### Practice questions

1. Why is a random seed insufficient for reproducibility?
2. Distinguish data drift, concept drift, label drift, and pipeline bugs.
3. What should block a model release even if aggregate accuracy improves?
4. Why can automatic retraining on recent production labels amplify harm?
5. What must a rollback restore besides model weights?

### Answer key

1. Hardware/kernels, library versions, nondeterministic operations, data order/snapshot, preprocessing, and environment also affect results. Some systems cannot be bitwise deterministic; document acceptable reproducibility.
2. Data drift changes inputs; concept drift changes relationship between inputs/targets; label drift changes class prevalence; pipeline bugs change data/feature computation incorrectly. Responses differ.
3. Critical-slice/safety/fairness regression, data leakage, schema incompatibility, unacceptable latency/cost, calibration failure, or inability to reproduce/rollback.
4. Feedback/selection bias, delayed/noisy labels, model-influenced outcomes, attacks, and missing counterfactuals can teach the system its own mistakes. Validate and gate data/training.
5. Preprocessing/features, schema, dependencies/runtime, calibration/thresholds, routing, prompt/policy where applicable, and compatible data/index artifacts.

### Build task

Create a local reproducible ML pipeline: version data, validate schema, train, log experiments, run slice gates, package an API, emit metrics, perform a canary simulation, and restore the previous complete serving profile.

---

## 12. Research Reproduction, Ablations, and Technical Writing

### Concept map

- A research claim is interpreted through assumptions, baseline, metric, dataset, compute, implementation, and uncertainty.
- Reproduction rebuilds the reported experiment closely enough to test a claim.
- Replication tests whether the conclusion holds in another reasonable setting.
- An ablation removes or changes one component to identify causal contribution.
- Negative results and boundary conditions are valuable when methodology is sound.
- A paper/report should separate observation, inference, speculation, and limitation.

### Worked example — turn a headline into a testable claim

Headline: “Technique X makes inference 2× faster.”

Rewrite:

```text
On model revision M, hardware H, engine E, workload distribution W,
quality gate Q, and latency constraint S, configuration X produces
2× SLO-compliant output goodput versus baseline B, with confidence
interval C and no material regression on evaluation suite V.
```

Now every symbol is an artifact or measurement that another engineer can inspect.

### Practice questions

1. Why is comparing a new method with an untuned or obsolete baseline weak evidence?
2. What does an ablation establish, and what can it still fail to prove?
3. Why report confidence intervals/distributions instead of only means?
4. What belongs in an experiment manifest?
5. How should a reproduction report a failure to match the paper?

### Answer key

1. The gain may come from baseline neglect rather than the method. Use the strongest fair baseline, matched budgets, and transparent tuning.
2. It estimates contribution in the tested system by removing/changing one part. Interactions, replacement effects, and external validity may still prevent broad causal conclusions.
3. Means hide variability, skew, tails, and small-sample uncertainty. Decisions need effect size plus uncertainty and operationally relevant percentiles.
4. Code/data/model versions, environment/hardware, configuration, seeds, preprocessing, workload, commands, metrics, raw outputs, failure handling, and resource budget.
5. State exact deviations, diagnostics, sensitivity tests, and plausible explanations without claiming the original is false. Publish enough evidence to continue investigation.

### Build task

Choose one small paper or systems claim with runnable code. Reconstruct the baseline, reproduce the main metric, perform at least two ablations, test one boundary where the technique stops helping, and write a report with artifacts, uncertainty, limitations, and negative results.

---

## Cumulative Capstone

Build and defend one small research-to-production system:

1. Derive the core equation and verify it by hand.
2. Implement the operation from scratch with shape and gradient tests.
3. Compare with a framework primitive.
4. Train or adapt a small model with reproducible data and experiment tracking.
5. Evaluate overall and critical slices with uncertainty.
6. Package and deploy an immutable version with observability and rollback.
7. Reproduce one external claim and run an ablation.
8. Publish an engineering note that states assumptions, failures, cost, and where the approach should not be used.

## Primary References

- [Fanout AI Research public roadmap](https://fanout.sh/roadmaps/ai-research?track=ai)
- [Fanout ML math roadmap](https://www.fanout.sh/blog/ml-math-roadmap-for-engineers-without-a-math-degree)
- [Fanout Machine Learning Mathematics](https://www.fanout.sh/ml-math)
- [AI Engineering Design](ai-engineering-design.md)
- [AI System Design](ai-system-design.md)
- [Inference Engineering](inference-engineering.md)

**Completion standard:** You should be able to derive a small case, implement it, test it, explain its failure modes, and connect it to model or system behavior. Recognizing a formula or framework name is not mastery.

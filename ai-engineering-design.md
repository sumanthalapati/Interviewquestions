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

---

## LLM Concepts {#llm-concepts}

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

## RAG (Retrieval-Augmented Generation) {#rag}

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

## AI Agents {#agents}

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

## Prompt Engineering {#prompt-engineering}

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

## LLM Evaluation {#evaluation}

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

## Vector Databases {#vector-db}

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

## Fine-tuning vs Prompting {#fine-tuning}

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

## Context Engineering {#context-engineering}

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

## Multi-Agent Systems {#multi-agent}

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

## Deployment & Monitoring {#deployment}

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

---

**Key Takeaway**: LLM apps require iteration, evaluation, and monitoring. Start simple (prompting), scale to complex (agents, fine-tuning) only when needed.

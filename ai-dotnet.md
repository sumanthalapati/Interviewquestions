# AI in .NET Interview Questions

## Foundations & Ecosystem

**Q1: What are the main Microsoft libraries and frameworks for AI/ML in .NET?**

The primary options are:
- **ML.NET**: Microsoft's open-source, cross-platform ML framework for .NET — train models in C#/F# without Python.
- **Semantic Kernel**: An open-source SDK for integrating LLMs (like GPT-4, Claude) into .NET applications with plugins, planners, and memory.
- **Azure OpenAI SDK for .NET** (`Azure.AI.OpenAI`): Official client for Azure OpenAI Service.
- **Microsoft.Extensions.AI**: A unified abstraction layer (middleware pattern) over different AI providers introduced in .NET 9.
- **ONNX Runtime**: Run ONNX models (exported from PyTorch/TensorFlow) in .NET at high performance.
- **TorchSharp**: .NET bindings for LibTorch (PyTorch's C++ backend).

**Q2: What is ML.NET and what types of tasks does it support?**

ML.NET is a cross-platform ML framework that lets .NET developers train and consume models without needing Python or data science expertise. It supports:
- Binary and multi-class classification
- Regression
- Clustering (K-Means)
- Anomaly detection
- Recommendation (matrix factorization)
- Text featurization and NLP
- Image classification (via TensorFlow/ONNX transfer learning)
- Time series forecasting

It uses a pipeline-based API where you chain data transforms and trainers.

**Q3: What is Semantic Kernel and how does it differ from ML.NET?**

ML.NET is for traditional ML — training models on tabular/structured data. Semantic Kernel is an orchestration framework for LLM-powered applications. It lets you combine LLM calls, native code functions (called plugins), memory/vector stores, and planning into AI "agents." Think of it as a bridge between LLMs and your application logic — similar to LangChain but built for .NET.

---

## Semantic Kernel

**Q4: What are the core concepts in Semantic Kernel?**

- **Kernel**: The central orchestrator that holds AI services, plugins, and configuration.
- **Plugins**: Collections of functions (either native C# or semantic/prompt-based) that the AI can call.
- **KernelFunction**: A single callable unit — annotated with `[KernelFunction]` for native code or defined as a prompt template.
- **ChatCompletionService / TextGenerationService**: Abstractions over AI model providers (Azure OpenAI, OpenAI, Hugging Face, etc.).
- **Memory / VectorStore**: Stores embeddings for semantic search and retrieval-augmented generation (RAG).
- **Planner**: Automatically decomposes a user goal into a sequence of function calls.
- **Filters**: Middleware for pre/post-processing of function calls — used for logging, safety, caching.

**Q5: How do you set up Semantic Kernel with Azure OpenAI in a .NET application?**

```csharp
using Microsoft.SemanticKernel;

var kernel = Kernel.CreateBuilder()
    .AddAzureOpenAIChatCompletion(
        deploymentName: "gpt-4",
        endpoint: "https://your-resource.openai.azure.com/",
        apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_KEY")!)
    .Build();

var result = await kernel.InvokePromptAsync("What is the capital of France?");
Console.WriteLine(result);
```

**Q6: What is a Semantic Kernel Plugin and how do you create one?**

A plugin is a class with methods decorated with `[KernelFunction]` and optionally `[Description]` attributes. The description helps the AI understand when and how to call the function.

```csharp
public class WeatherPlugin {
    [KernelFunction]
    [Description("Gets current weather for a given city")]
    public string GetWeather(
        [Description("The city name")] string city) {
        // Call real weather API
        return $"The weather in {city} is 22°C and sunny.";
    }
}

// Register in kernel
kernel.Plugins.AddFromType<WeatherPlugin>();
```

**Q7: What is Retrieval-Augmented Generation (RAG) and how do you implement it in .NET?**

RAG grounds LLM responses in your own data by retrieving relevant chunks from a vector store before generating an answer. The flow is: embed the user query → find semantically similar documents in the vector store → inject them as context into the LLM prompt.

In .NET with Semantic Kernel:
1. Chunk and embed your documents using an embedding model (e.g., `text-embedding-ada-002`).
2. Store vectors in a vector database (Azure AI Search, Qdrant, Chroma, Postgres with pgvector, in-memory).
3. At query time, embed the question, search the store, retrieve top-k chunks.
4. Construct a prompt with the retrieved context and the user question.

```csharp
// Add memory store
kernel.ImportPluginFromObject(
    new TextMemoryPlugin(memoryStore), "memory");

// Search memory and answer
var answer = await kernel.InvokePromptAsync(
    "Answer based on context: {{memory.recall 'user question'}} \n\nQuestion: {{$input}}",
    new KernelArguments { ["input"] = userQuestion });
```

**Q8: What are Kernel Filters in Semantic Kernel and why are they useful?**

Filters are hooks that run before and after function invocations, similar to ASP.NET middleware. Types include `IFunctionInvocationFilter`, `IPromptRenderFilter`, and `IAutoFunctionInvocationFilter`. Use cases: logging, token usage tracking, PII redaction, content safety checks, caching responses, and A/B testing different prompts.

```csharp
public class LoggingFilter : IFunctionInvocationFilter {
    public async Task OnFunctionInvocationAsync(
        FunctionInvocationContext context, Func<FunctionInvocationContext, Task> next) {
        Console.WriteLine($"Calling: {context.Function.Name}");
        await next(context);
        Console.WriteLine($"Completed: {context.Function.Name}");
    }
}
```

---

## Azure OpenAI & LLM Integration

**Q9: What is the difference between Azure OpenAI and OpenAI API in a .NET context?**

Azure OpenAI is hosted on Azure infrastructure, offering enterprise features: private endpoints, VNet integration, content filtering, data residency guarantees, and Azure RBAC. The OpenAI API is the public endpoint. In .NET, `Azure.AI.OpenAI` supports both; `Microsoft.SemanticKernel` abstracts both behind `IChatCompletionService`. Azure OpenAI is preferred for enterprise scenarios due to compliance requirements.

**Q10: How do you implement streaming responses from an LLM in .NET?**

Use `GetStreamingChatMessageContentsAsync` in Semantic Kernel or `CompleteChatStreamingAsync` in the Azure.AI.OpenAI SDK. This returns an `IAsyncEnumerable<T>` which you consume with `await foreach`.

```csharp
await foreach (var chunk in kernel.InvokePromptStreamingAsync("Tell me a story")) {
    Console.Write(chunk);
}
```

In ASP.NET Core, pair this with `IAsyncEnumerable` or Server-Sent Events (SSE) to stream to the browser.

**Q11: How do you handle token limits and context window management?**

Strategies include: chunking documents before embedding, summarizing conversation history when it grows too long (rolling summary), using a vector memory to retrieve only relevant context rather than the full history, and counting tokens proactively with a tokenizer library (`SharpToken` for GPT models) before sending requests.

**Q12: What is function calling / tool use in LLMs and how does it work in .NET?**

Function calling lets the LLM request that your application invoke specific functions and return results. The model outputs a structured JSON object indicating which function to call and with what arguments. In Semantic Kernel, this is handled automatically via `ToolCallBehavior.AutoInvokeKernelFunctions` — the kernel intercepts the model's tool call request, invokes the matching plugin function, and feeds the result back to the model.

---

## ML.NET

**Q13: Walk through the ML.NET pipeline for a binary classification task.**

```csharp
var mlContext = new MLContext();

// 1. Load data
var data = mlContext.Data.LoadFromTextFile<SentimentData>("data.csv", separatorChar: ',');

// 2. Split
var split = mlContext.Data.TrainTestSplit(data, testFraction: 0.2);

// 3. Build pipeline
var pipeline = mlContext.Transforms.Text
    .FeaturizeText("Features", nameof(SentimentData.Text))
    .Append(mlContext.BinaryClassification.Trainers
        .SdcaLogisticRegression(labelColumnName: "Label", featureColumnName: "Features"));

// 4. Train
var model = pipeline.Fit(split.TrainSet);

// 5. Evaluate
var predictions = model.Transform(split.TestSet);
var metrics = mlContext.BinaryClassification.Evaluate(predictions);
Console.WriteLine($"AUC: {metrics.AreaUnderRocCurve}");

// 6. Save
mlContext.Model.Save(model, data.Schema, "model.zip");
```

**Q14: How do you use a pre-trained ONNX model in .NET?**

Export your model from PyTorch/TensorFlow as ONNX, then load it in ML.NET via `mlContext.Transforms.ApplyOnnxModel()`. Alternatively use the `Microsoft.ML.OnnxRuntime` package directly for lower-level control. ONNX Runtime supports CPU, CUDA GPU, and DirectML (Windows GPU) execution providers.

**Q15: What is AutoML in ML.NET?**

`mlContext.Auto()` provides automated machine learning — it tries multiple algorithms and hyperparameter combinations within a time budget and returns the best pipeline. Useful for quickly finding a good baseline model without manual trial and error.

---

## Vector Databases & Embeddings

**Q16: What vector databases are supported by Semantic Kernel in .NET?**

Semantic Kernel's `IVectorStore` abstraction supports: Azure AI Search, Azure Cosmos DB (with vector search), Qdrant, Chroma, Pinecone, Weaviate, Redis, Postgres (pgvector), SQLite (with vector extension), and an in-memory store for development. The `Microsoft.SemanticKernel.Connectors.*` NuGet packages provide the implementations.

**Q17: What are text embeddings and how are they used in AI applications?**

Embeddings are dense numerical vector representations of text that capture semantic meaning. Texts with similar meaning have vectors close together in the embedding space (measured by cosine similarity). Used for: semantic search, RAG context retrieval, document clustering, duplicate detection, and recommendation systems. In .NET, generate embeddings via `ITextEmbeddingGenerationService` in Semantic Kernel.

---

## Microsoft.Extensions.AI

**Q18: What is Microsoft.Extensions.AI and why was it introduced?**

`Microsoft.Extensions.AI` (introduced with .NET 9) provides a common set of abstractions (`IChatClient`, `IEmbeddingGenerator`) over different AI providers. Its goal is to allow library authors and framework builders to write AI-aware code without coupling to a specific provider. It follows the `Microsoft.Extensions.*` pattern familiar from logging and dependency injection, including middleware support for caching, logging, and telemetry.

**Q19: How does Microsoft.Extensions.AI integrate with the .NET DI container?**

```csharp
// Program.cs
builder.Services.AddChatClient(new OpenAIClient(apiKey).AsChatClient("gpt-4o"))
    .UseLogging()
    .UseOpenTelemetry()
    .UseDistributedCache();

// In a service
public class MyService(IChatClient chatClient) {
    public async Task<string> AskAsync(string question) {
        var response = await chatClient.CompleteAsync(question);
        return response.Message.Text;
    }
}
```

---

## Agents & Agentic Patterns

**Q20: What is an AI agent and how do you build one in .NET?**

An AI agent is an LLM-powered system that can perceive inputs, reason, and take actions (call tools, search memory, execute code) in a loop to accomplish a goal. In Semantic Kernel, you build agents using `ChatCompletionAgent` or `OpenAIAssistantAgent`. You define the agent's instructions, register plugins as tools, and invoke the agent with a thread/conversation.

**Q21: What is the difference between single-agent and multi-agent architectures?**

Single-agent: one LLM handles all reasoning and tool use. Multi-agent: multiple specialized agents collaborate — an orchestrator agent delegates tasks to sub-agents (e.g., a "research agent" and a "writing agent"). Semantic Kernel's `AgentGroupChat` enables multi-agent scenarios with termination conditions and selection strategies. Multi-agent systems improve reliability for complex tasks but add coordination complexity.

**Q22: What is prompt injection and how do you defend against it in .NET AI applications?**

Prompt injection is an attack where malicious content in user input or retrieved documents manipulates the LLM's behavior (e.g., "Ignore previous instructions and..."). Defenses: use Kernel Filters to sanitize inputs, separate system instructions from user-provided content, use Azure Content Safety API for pre/post filtering, limit tool permissions to least-privilege, and validate structured outputs against a schema rather than trusting free-form LLM output.

---

## Performance & Production

**Q23: How do you implement caching for LLM calls in .NET?**

Use `Microsoft.Extensions.AI`'s `UseDistributedCache()` middleware which caches responses by hashing the prompt. For Semantic Kernel, implement a custom `IFunctionInvocationFilter` that checks a cache before invoking the LLM. Semantic caching (cache by embedding similarity rather than exact match) reduces redundant API calls for similar questions.

**Q24: How do you observe and monitor AI workloads in .NET?**

Use OpenTelemetry — both Semantic Kernel and `Microsoft.Extensions.AI` emit spans and metrics compatible with the OpenTelemetry Gen AI semantic conventions. Key metrics to track: token consumption (input/output), latency per model call, function call counts, error rates, and cost estimates. Export to Azure Monitor, Prometheus, or Jaeger.

**Q25: What strategies reduce latency in .NET AI applications?**

Streaming responses (`IAsyncEnumerable`) improves perceived latency. Parallel tool execution when multiple independent tool calls are needed. Response caching for repeated queries. Choosing smaller/faster models for simpler classification subtasks. Batching embedding requests. Using Azure OpenAI's provisioned throughput (PTU) for consistent low latency under load.

---

## Ethics & Responsible AI

**Q26: How do you implement content safety in a .NET AI application?**

Use Azure AI Content Safety service (`Azure.AI.ContentSafety` SDK) to screen inputs and outputs for harmful content (violence, hate speech, self-harm, sexual content). Apply Semantic Kernel filters to invoke content safety checks automatically on every prompt and response. For enterprise deployments, configure Azure OpenAI's built-in content filters.

**Q27: What is grounding and why does it matter?**

Grounding means anchoring LLM responses to factual, verifiable sources rather than relying solely on the model's parametric knowledge. Ungrounded LLMs hallucinate. RAG is the primary grounding technique — the model is instructed to answer only from retrieved documents and cite its sources. Grounding is critical for applications where accuracy matters (legal, medical, financial).

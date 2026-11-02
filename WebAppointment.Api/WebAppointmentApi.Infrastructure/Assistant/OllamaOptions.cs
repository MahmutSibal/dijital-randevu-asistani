namespace WebAppointmentApi.Infrastructure.Assistant;

public sealed class OllamaOptions
{
    public string BaseUrl { get; set; } = "http://localhost:11434";

    public string Model { get; set; } = "gemma4:12b";

    /// <summary>
    /// Default for letting the model reason before answering, streamed separately. Off by
    /// default: with gemma4:12b it turns a ~3 s answer into ~60 s. Clients can ask per request.
    /// </summary>
    public bool Think { get; set; }

    /// <summary>
    /// Context window in tokens. Ollama's default (4096) is filled by the instructions, the
    /// catalog and a photo, after which every new token forces a slow context shift.
    /// </summary>
    public int ContextLength { get; set; } = 8192;

    /// <summary>
    /// File (relative to the WebApi content root) holding the assistant's instructions,
    /// sent as the system message of every conversation.
    /// </summary>
    public string SystemPromptFile { get; set; } = "AssistantPrompt.md";
}

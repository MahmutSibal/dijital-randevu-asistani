namespace WebAppointmentApi.Application.Assistant.Dtos;

public sealed class AssistantChatMessageDto
{
    /// <summary>"user" or "assistant".</summary>
    public string Role { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    /// <summary>Photos attached to a user message (prescription, report, appointment slip…), base64 JPEG/PNG.</summary>
    public List<string>? Images { get; set; }
}

public sealed class AssistantChatRequest
{
    /// <summary>The whole conversation so far, ending with the latest user message.</summary>
    public List<AssistantChatMessageDto> Messages { get; set; } = new();

    /// <summary>
    /// Let the model reason before answering (shown as "thinking"). Much slower; when null
    /// the server default (Ollama:Think) applies.
    /// </summary>
    public bool? Think { get; set; }
}

/// <summary>One streamed piece of the assistant's reply.</summary>
public sealed record AssistantChatChunk(string Thinking, string Content, bool Done);

using WebAppointmentApi.Application.Assistant.Dtos;

namespace WebAppointmentApi.Application.Assistant.Abstractions;

public interface IAssistantChatClient
{
    /// <summary>Name of the model that answers, for display in clients.</summary>
    string Model { get; }

    /// <summary>The assistant's instructions followed by <paramref name="knowledge"/>.</summary>
    Task<string> BuildSystemPromptAsync(string? knowledge, CancellationToken ct);

    /// <summary>
    /// Streams the model's reasoning and answer for <paramref name="messages"/>, with
    /// <paramref name="systemPrompt"/> (from <see cref="BuildSystemPromptAsync"/>) as the system message.
    /// <paramref name="think"/> overrides the configured reasoning setting.
    /// Throws <see cref="AssistantUnavailableException"/> if the model server can't be used.
    /// </summary>
    IAsyncEnumerable<AssistantChatChunk> StreamAsync(
        IReadOnlyList<AssistantChatMessageDto> messages,
        string systemPrompt,
        bool? think,
        CancellationToken ct);
}

public sealed class AssistantUnavailableException : Exception
{
    public AssistantUnavailableException(string message, Exception? inner = null) : base(message, inner) { }
}

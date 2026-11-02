using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using WebAppointmentApi.Application.Assistant.Abstractions;
using WebAppointmentApi.Application.Assistant.Dtos;

namespace WebAppointmentApi.Infrastructure.Assistant;

/// <summary>Streams chat replies from a local Ollama server's /api/chat endpoint.</summary>
public sealed class OllamaChatClient : IAssistantChatClient
{
    private readonly HttpClient _http;
    private readonly OllamaOptions _options;
    private readonly ILogger<OllamaChatClient> _logger;

    public OllamaChatClient(HttpClient http, IOptions<OllamaOptions> options, ILogger<OllamaChatClient> logger)
    {
        _http = http;
        _options = options.Value;
        _logger = logger;
    }

    public string Model => _options.Model;

    public async Task<string> BuildSystemPromptAsync(string? knowledge, CancellationToken ct) =>
        string.Join("\n\n", new[] { await LoadSystemPromptAsync(ct), knowledge }
            .Where(s => !string.IsNullOrWhiteSpace(s)));

    public async IAsyncEnumerable<AssistantChatChunk> StreamAsync(
        IReadOnlyList<AssistantChatMessageDto> messages,
        string systemPrompt,
        bool? think,
        [EnumeratorCancellation] CancellationToken ct)
    {
        using var response = await SendAsync(messages, systemPrompt, think ?? _options.Think, ct);
        await using var body = await response.Content.ReadAsStreamAsync(ct);
        using var reader = new StreamReader(body);

        // Ollama streams one JSON object per line (NDJSON).
        while (await reader.ReadLineAsync(ct) is { } line)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;

            var chunk = JsonSerializer.Deserialize<OllamaChunk>(line);
            if (chunk is null) continue;
            if (!string.IsNullOrEmpty(chunk.Error)) throw new AssistantUnavailableException(chunk.Error);

            yield return new AssistantChatChunk(
                chunk.Message?.Thinking ?? string.Empty,
                chunk.Message?.Content ?? string.Empty,
                chunk.Done);

            if (chunk.Done) yield break;
        }
    }

    private async Task<HttpResponseMessage> SendAsync(
        IReadOnlyList<AssistantChatMessageDto> messages,
        string systemPrompt,
        bool think,
        CancellationToken ct)
    {
        var payload = new List<object>();
        if (systemPrompt.Length > 0) payload.Add(new { role = "system", content = systemPrompt });
        payload.AddRange(messages.Select(m => m.Images is { Count: > 0 }
            ? (object)new { role = m.Role, content = m.Content, images = m.Images }
            : new { role = m.Role, content = m.Content }));

        using var request = new HttpRequestMessage(HttpMethod.Post, "api/chat")
        {
            Content = JsonContent.Create(new
            {
                model = _options.Model,
                messages = payload,
                stream = true,
                think,
                options = new { num_ctx = _options.ContextLength }
            })
        };

        HttpResponseMessage response;
        try
        {
            response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Ollama could not be reached at {BaseUrl}.", _options.BaseUrl);
            throw new AssistantUnavailableException("Yapay zekâ sunucusuna şu an ulaşılamıyor.", ex);
        }

        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(ct);
            response.Dispose();
            _logger.LogWarning("Ollama returned {Status}: {Body}", (int)response.StatusCode, body);
            throw new AssistantUnavailableException(ErrorText(body) ?? "Yapay zekâ sunucusu isteği reddetti.");
        }

        return response;
    }

    /// <summary>
    /// Reads the instructions file, which the WebApi project copies next to its binaries at build time.
    /// </summary>
    private async Task<string?> LoadSystemPromptAsync(CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_options.SystemPromptFile)) return null;

        var path = Path.IsPathRooted(_options.SystemPromptFile)
            ? _options.SystemPromptFile
            : Path.Combine(AppContext.BaseDirectory, _options.SystemPromptFile);
        if (!File.Exists(path))
        {
            _logger.LogWarning("Assistant prompt file not found at {Path}; chatting without instructions.", path);
            return null;
        }

        return await File.ReadAllTextAsync(path, ct);
    }

    private static string? ErrorText(string body)
    {
        try
        {
            return JsonSerializer.Deserialize<OllamaChunk>(body)?.Error;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private sealed class OllamaChunk
    {
        [JsonPropertyName("message")]
        public OllamaMessage? Message { get; set; }

        [JsonPropertyName("done")]
        public bool Done { get; set; }

        [JsonPropertyName("error")]
        public string? Error { get; set; }
    }

    private sealed class OllamaMessage
    {
        [JsonPropertyName("content")]
        public string? Content { get; set; }

        [JsonPropertyName("thinking")]
        public string? Thinking { get; set; }
    }
}

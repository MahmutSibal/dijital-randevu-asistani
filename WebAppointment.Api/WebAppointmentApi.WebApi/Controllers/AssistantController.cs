using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Assistant.Abstractions;
using WebAppointmentApi.Application.Assistant.Dtos;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>
/// Chat with the AI assistant. The mobile app talks only to this API; the API forwards the
/// conversation to Ollama and streams the reply back as NDJSON, one JSON object per line:
/// <c>{"thinking":"…","content":"…","done":false}</c>, or <c>{"error":"…"}</c> if it fails mid-stream.
/// A question asked before is answered from the database in one line with <c>"cached":true</c>.
/// Anonymous for now, since the mobile app has no sign-in yet; the global rate limiter applies.
/// </summary>
[ApiController]
[Route("api/assistant")]
public sealed class AssistantController : ControllerBase
{
    private const int MaxMessages = 50;
    private const int MaxMessageLength = 8000;
    private const int MaxImages = 4;                 // per conversation
    private const int MaxImageBase64Length = 8_000_000; // ~6 MB photo

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IAssistantChatClient _assistant;
    private readonly IAssistantKnowledge _knowledge;
    private readonly IAssistantAnswerCache _answers;

    public AssistantController(
        IAssistantChatClient assistant,
        IAssistantKnowledge knowledge,
        IAssistantAnswerCache answers)
    {
        _assistant = assistant;
        _knowledge = knowledge;
        _answers = answers;
    }

    [HttpGet]
    public IActionResult Info() => Ok(new { model = _assistant.Model });

    [HttpPost("chat")]
    public async Task Chat([FromBody] AssistantChatRequest request, CancellationToken ct)
    {
        var error = Validate(request);
        if (error is not null)
        {
            await WritePlainAsync(StatusCodes.Status400BadRequest, error, ct);
            return;
        }

        // The model only knows the hospitals, departments and doctors that really exist here.
        var knowledge = await _knowledge.DescribeCatalogAsync(ct);
        var systemPrompt = await _assistant.BuildSystemPromptAsync(knowledge, ct);

        // A conversation's first question can be answered from earlier identical questions;
        // follow-ups depend on the conversation so far and always go to the model.
        // Answers about a photo depend on the photo, so those are never reused.
        var question = request.Messages.Count == 1 && request.Messages[0].Images is not { Count: > 0 }
            ? request.Messages[0].Content
            : null;
        var contextHash = AssistantQuestion.Hash(_assistant.Model + "\n" + systemPrompt);
        if (question is not null)
        {
            var saved = await _answers.FindAsync(question, contextHash, ct);
            if (saved is not null)
            {
                StartStream();
                await WriteLineAsync(new { thinking = "", content = saved, done = true, cached = true }, ct);
                return;
            }
        }

        await using var chunks = _assistant.StreamAsync(request.Messages, systemPrompt, request.Think, ct).GetAsyncEnumerator(ct);

        // Connect to the model before committing to a 200, so an unreachable server is a 503.
        bool hasChunk;
        try
        {
            hasChunk = await chunks.MoveNextAsync();
        }
        catch (AssistantUnavailableException ex)
        {
            await WritePlainAsync(StatusCodes.Status503ServiceUnavailable, ex.Message, ct);
            return;
        }

        StartStream();

        var answer = new StringBuilder();
        var finished = false;
        try
        {
            while (hasChunk)
            {
                var chunk = chunks.Current;
                answer.Append(chunk.Content);
                finished |= chunk.Done;
                await WriteLineAsync(chunk, ct);
                hasChunk = await chunks.MoveNextAsync();
            }

            // Only complete answers are worth reusing.
            if (question is not null && finished && answer.Length > 0)
            {
                await _answers.SaveAsync(question, contextHash, answer.ToString(), _assistant.Model, ct);
            }
        }
        catch (AssistantUnavailableException ex)
        {
            await WriteLineAsync(new { error = ex.Message }, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // The app stopped the reply; nothing left to send.
        }
    }

    private static string? Validate(AssistantChatRequest request)
    {
        var messages = request.Messages;
        if (messages is null || messages.Count == 0) return "Mesaj boş olamaz.";
        if (messages.Count > MaxMessages) return "Sohbet çok uzun. Lütfen yeni bir sohbet başlatın.";
        if (messages.Any(m => m.Role is not ("user" or "assistant"))) return "Geçersiz mesaj rolü.";
        if (messages.Any(m => (m.Content?.Length ?? 0) > MaxMessageLength)) return "Mesaj çok uzun.";
        if (messages[^1].Role != "user" || string.IsNullOrWhiteSpace(messages[^1].Content))
            return "Son mesaj kullanıcıdan gelmeli.";

        var images = messages.SelectMany(m => m.Images ?? new List<string>()).ToList();
        if (messages.Any(m => m.Role == "assistant" && m.Images is { Count: > 0 }))
            return "Fotoğraf sadece kullanıcı mesajına eklenebilir.";
        if (images.Count > MaxImages) return $"Bir sohbette en fazla {MaxImages} fotoğraf gönderilebilir.";
        if (images.Any(i => i.Length > MaxImageBase64Length)) return "Fotoğraf çok büyük.";
        if (images.Any(i => !IsBase64Image(i))) return "Fotoğraf okunamadı. JPEG veya PNG gönderin.";
        return null;
    }

    /// <summary>JPEG ("/9j/") or PNG ("iVBOR") data, base64 encoded without a data: prefix.</summary>
    private static bool IsBase64Image(string base64)
    {
        if (!(base64.StartsWith("/9j/", StringComparison.Ordinal) || base64.StartsWith("iVBOR", StringComparison.Ordinal)))
            return false;
        Span<byte> probe = stackalloc byte[3];
        return Convert.TryFromBase64String(base64[..4], probe, out _);
    }

    private void StartStream()
    {
        Response.ContentType = "application/x-ndjson; charset=utf-8";
        Response.Headers.CacheControl = "no-cache";
        HttpContext.Features.Get<IHttpResponseBodyFeature>()?.DisableBuffering();
    }

    private async Task WriteLineAsync(object value, CancellationToken ct)
    {
        await JsonSerializer.SerializeAsync(Response.Body, value, value.GetType(), JsonOptions, ct);
        await Response.Body.WriteAsync("\n"u8.ToArray(), ct);
        await Response.Body.FlushAsync(ct);
    }

    private async Task WritePlainAsync(int status, string message, CancellationToken ct)
    {
        Response.StatusCode = status;
        Response.ContentType = "text/plain; charset=utf-8";
        await Response.WriteAsync(message, ct);
    }
}

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using WebAppointmentApi.Application.Assistant.Abstractions;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Assistant;

public sealed class AssistantAnswerCache : IAssistantAnswerCache
{
    private readonly AppDbContext _db;
    private readonly IDateTimeProvider _clock;
    private readonly ILogger<AssistantAnswerCache> _logger;

    public AssistantAnswerCache(AppDbContext db, IDateTimeProvider clock, ILogger<AssistantAnswerCache> logger)
    {
        _db = db;
        _clock = clock;
        _logger = logger;
    }

    public async Task<string?> FindAsync(string question, string contextHash, CancellationToken ct)
    {
        var key = AssistantQuestion.Key(question);
        if (key is null) return null;

        var saved = await _db.AssistantAnswers
            .SingleOrDefaultAsync(x => x.ContextHash == contextHash && x.QuestionKey == key, ct);
        if (saved is null) return null;

        saved.HitCount++;
        saved.LastHitAtUtc = _clock.UtcNow;
        await _db.SaveChangesAsync(ct);
        return saved.Answer;
    }

    public async Task SaveAsync(string question, string contextHash, string answer, string model, CancellationToken ct)
    {
        var key = AssistantQuestion.Key(question);
        if (key is null || string.IsNullOrWhiteSpace(answer)) return;

        _db.AssistantAnswers.Add(new AssistantAnswer
        {
            QuestionKey = key,
            ContextHash = contextHash,
            Question = question.Trim()[..Math.Min(question.Trim().Length, 2000)],
            Answer = answer.Trim(),
            Model = model,
            CreatedAtUtc = _clock.UtcNow,
        });

        try
        {
            await _db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex)
        {
            // Two people asked the same new question at once; the first answer saved wins.
            _logger.LogInformation(ex, "Assistant answer for {Key} was already saved.", key);
        }
    }
}

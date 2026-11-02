using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

/// <summary>
/// A saved AI assistant answer, reused when the same question is asked again while the
/// assistant's instructions and the hospital/doctor catalog are unchanged.
/// </summary>
public sealed class AssistantAnswer : IMultiTenant
{
    public long Id { get; set; }

    /// <summary>The question normalized for matching (lower-case, single spaces, no trailing punctuation).</summary>
    public string QuestionKey { get; set; } = string.Empty;

    /// <summary>Hash of the instructions and catalog the answer was generated with.</summary>
    public string ContextHash { get; set; } = string.Empty;

    /// <summary>The question as first asked.</summary>
    public string Question { get; set; } = string.Empty;

    public string Answer { get; set; } = string.Empty;

    public string Model { get; set; } = string.Empty;

    /// <summary>How many times the saved answer was served instead of asking the model.</summary>
    public int HitCount { get; set; }

    public DateTimeOffset CreatedAtUtc { get; set; }

    public DateTimeOffset? LastHitAtUtc { get; set; }

    public int TenantId { get; set; }
}

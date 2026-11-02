using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

/// <summary>A pending two-step sign-in: the password was right, the phone code is still due.</summary>
public sealed class LoginChallenge : IMultiTenant
{
    public Guid Id { get; set; }
    public int TenantId { get; set; }

    public Guid UserId { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public string CodeSalt { get; set; } = string.Empty;

    public DateTimeOffset ExpiresAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public DateTimeOffset? UsedAtUtc { get; set; }
}

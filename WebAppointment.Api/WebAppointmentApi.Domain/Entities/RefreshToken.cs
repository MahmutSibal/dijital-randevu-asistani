using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

public sealed class RefreshToken : IMultiTenant
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    public string TokenHash { get; set; } = string.Empty;
    public DateTimeOffset ExpiresAtUtc { get; set; }

    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset? RevokedAtUtc { get; set; }

    /// <summary>
    /// Shared by every token of one sign-in as it is rotated, so the chain shows up as a
    /// single session in "Aktif oturumlarım" and can be ended at once.
    /// </summary>
    public Guid SessionId { get; set; }
    public string? Device { get; set; }
    public string? IpAddress { get; set; }

    public bool IsRevoked => RevokedAtUtc != null;
    public bool IsExpired => DateTimeOffset.UtcNow >= ExpiresAtUtc;

    public int TenantId { get; set; }
}

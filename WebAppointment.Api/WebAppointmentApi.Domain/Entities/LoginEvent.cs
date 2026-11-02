using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

/// <summary>One sign-in attempt on a known account, shown to the user as their login history.</summary>
public sealed class LoginEvent : IMultiTenant
{
    public long Id { get; set; }
    public int TenantId { get; set; }

    public Guid UserId { get; set; }
    public DateTimeOffset AtUtc { get; set; }
    public bool Success { get; set; }

    public string? IpAddress { get; set; }
    public string? Device { get; set; }
}

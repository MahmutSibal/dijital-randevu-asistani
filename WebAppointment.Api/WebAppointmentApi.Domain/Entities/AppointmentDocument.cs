using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

/// <summary>
/// An appointment certificate issued to a patient. Anyone holding the verification code can
/// check it against <see cref="PayloadJson"/>, the snapshot taken when it was issued.
/// </summary>
public sealed class AppointmentDocument : IMultiTenant
{
    public Guid Id { get; set; }
    public int TenantId { get; set; }

    public string Code { get; set; } = string.Empty;

    public Guid AppointmentId { get; set; }
    public Guid UserId { get; set; }

    public DateTimeOffset IssuedAtUtc { get; set; }
    public string PayloadJson { get; set; } = string.Empty;
}

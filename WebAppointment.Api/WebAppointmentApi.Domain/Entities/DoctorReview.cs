using WebAppointmentApi.Domain.Common;

namespace WebAppointmentApi.Domain.Entities;

/// <summary>A patient's rating of a completed appointment; one per appointment.</summary>
public sealed class DoctorReview : IMultiTenant
{
    public long Id { get; set; }
    public int TenantId { get; set; }

    public Guid AppointmentId { get; set; }
    public Guid UserId { get; set; }
    public int DoctorId { get; set; }

    public int Stars { get; set; }
    public string? Comment { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
}

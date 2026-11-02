namespace WebAppointmentApi.Application.Reviews;

public sealed record CreateReviewRequest(int Stars, string? Comment);

public sealed record ReviewDto(
    long Id,
    Guid AppointmentId,
    int Stars,
    string? Comment,
    string PatientInitials,
    DateTimeOffset CreatedAtUtc);

public sealed record DoctorRatingDto(int DoctorId, double Average, int Count, IReadOnlyList<ReviewDto> Latest);

public interface IDoctorReviewService
{
    /// <summary>Rates one of the user's own completed appointments, once.</summary>
    Task<ReviewDto> CreateAsync(Guid appointmentId, Guid userId, CreateReviewRequest request, CancellationToken ct);

    /// <summary>The user's reviews keyed by appointment, so the app knows which ones are rated.</summary>
    Task<IReadOnlyList<ReviewDto>> ListMineAsync(Guid userId, CancellationToken ct);

    Task<DoctorRatingDto> GetDoctorRatingAsync(int doctorId, CancellationToken ct);

    /// <summary>Average stars for many doctors at once (doctor id → (average, count)).</summary>
    Task<IReadOnlyDictionary<int, (double Average, int Count)>> GetAveragesAsync(CancellationToken ct);
}

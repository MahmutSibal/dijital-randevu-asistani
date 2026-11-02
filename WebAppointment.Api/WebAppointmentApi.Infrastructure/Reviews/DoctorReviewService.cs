using Microsoft.EntityFrameworkCore;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Application.Reviews;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Domain.Enums;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Reviews;

public sealed class DoctorReviewService : IDoctorReviewService
{
    private readonly AppDbContext _db;
    private readonly IDateTimeProvider _clock;

    public DoctorReviewService(AppDbContext db, IDateTimeProvider clock)
    {
        _db = db;
        _clock = clock;
    }

    public async Task<ReviewDto> CreateAsync(Guid appointmentId, Guid userId, CreateReviewRequest request, CancellationToken ct)
    {
        if (request.Stars is < 1 or > 5)
            throw new FluentValidation.ValidationException(
                [new FluentValidation.Results.ValidationFailure("Stars", "Puan 1 ile 5 arasında olmalıdır.")]);
        var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        if (comment?.Length > 1000)
            throw new FluentValidation.ValidationException(
                [new FluentValidation.Results.ValidationFailure("Comment", "Yorum en fazla 1000 karakter olabilir.")]);

        var appointment = await _db.Appointments.AsNoTracking().SingleOrDefaultAsync(x => x.Id == appointmentId, ct)
            ?? throw new NotFoundException("Randevu bulunamadı.");
        if (appointment.UserId != userId)
            throw new ForbiddenException("Yalnızca kendi randevunuzu değerlendirebilirsiniz.");
        if (appointment.Status != AppointmentStatus.Completed)
            throw new ConflictException("Yalnızca tamamlanan randevular değerlendirilebilir.");
        if (await _db.DoctorReviews.AnyAsync(x => x.AppointmentId == appointmentId, ct))
            throw new ConflictException("Bu randevuyu zaten değerlendirdiniz.");

        var review = new DoctorReview
        {
            TenantId = appointment.TenantId,
            AppointmentId = appointmentId,
            UserId = userId,
            DoctorId = appointment.DoctorId,
            Stars = request.Stars,
            Comment = comment,
            CreatedAtUtc = _clock.UtcNow,
        };
        _db.DoctorReviews.Add(review);
        await _db.SaveChangesAsync(ct);
        return (await ToDtosAsync([review], ct))[0];
    }

    public async Task<IReadOnlyList<ReviewDto>> ListMineAsync(Guid userId, CancellationToken ct)
    {
        var reviews = await _db.DoctorReviews.AsNoTracking().Where(x => x.UserId == userId).ToListAsync(ct);
        return await ToDtosAsync(reviews, ct);
    }

    public async Task<DoctorRatingDto> GetDoctorRatingAsync(int doctorId, CancellationToken ct)
    {
        var all = _db.DoctorReviews.AsNoTracking().Where(x => x.DoctorId == doctorId);
        var count = await all.CountAsync(ct);
        var average = count == 0 ? 0 : await all.AverageAsync(x => x.Stars, ct);
        var latest = await all.OrderByDescending(x => x.CreatedAtUtc).Take(10).ToListAsync(ct);
        return new DoctorRatingDto(doctorId, Math.Round(average, 1), count, await ToDtosAsync(latest, ct));
    }

    public async Task<IReadOnlyDictionary<int, (double Average, int Count)>> GetAveragesAsync(CancellationToken ct)
    {
        var rows = await _db.DoctorReviews.AsNoTracking()
            .GroupBy(x => x.DoctorId)
            .Select(g => new { DoctorId = g.Key, Average = g.Average(x => x.Stars), Count = g.Count() })
            .ToListAsync(ct);
        return rows.ToDictionary(x => x.DoctorId, x => (Math.Round(x.Average, 1), x.Count));
    }

    /// <summary>Reviews are public, so only the reviewer's initials are shown ("A. Y.").</summary>
    private async Task<IReadOnlyList<ReviewDto>> ToDtosAsync(IReadOnlyList<DoctorReview> reviews, CancellationToken ct)
    {
        var userIds = reviews.Select(x => x.UserId).Distinct().ToList();
        var names = await _db.Patients.AsNoTracking()
            .Where(x => userIds.Contains(x.UserId))
            .Select(x => new { x.UserId, x.FirstName, x.LastName })
            .ToDictionaryAsync(x => x.UserId, ct);

        static string Initial(string s) => string.IsNullOrWhiteSpace(s) ? "" : char.ToUpperInvariant(s.Trim()[0]) + ".";
        return reviews.Select(r => new ReviewDto(
                r.Id,
                r.AppointmentId,
                r.Stars,
                r.Comment,
                names.TryGetValue(r.UserId, out var n) ? $"{Initial(n.FirstName)} {Initial(n.LastName)}".Trim() : "Hasta",
                r.CreatedAtUtc))
            .ToList();
    }
}

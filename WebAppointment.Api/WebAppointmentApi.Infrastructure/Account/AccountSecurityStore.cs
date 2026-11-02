using Microsoft.EntityFrameworkCore;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Account;

public sealed class AccountSecurityStore : IAccountSecurityStore
{
    private const int HistorySize = 20;

    private readonly AppDbContext _db;
    private readonly IClientInfoProvider _client;
    private readonly IDateTimeProvider _clock;

    public AccountSecurityStore(AppDbContext db, IClientInfoProvider client, IDateTimeProvider clock)
    {
        _db = db;
        _client = client;
        _clock = clock;
    }

    public async Task RecordLoginAsync(Guid userId, int tenantId, bool success, CancellationToken ct)
    {
        _db.LoginEvents.Add(new LoginEvent
        {
            TenantId = tenantId,
            UserId = userId,
            AtUtc = _clock.UtcNow,
            Success = success,
            IpAddress = _client.IpAddress,
            Device = _client.Device,
        });
        await _db.SaveChangesAsync(ct);
    }

    public async Task<AccountSecurityDto> GetAsync(Guid userId, CancellationToken ct)
    {
        var history = await _db.LoginEvents.AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.AtUtc)
            .Take(HistorySize)
            .Select(x => new LoginEventDto(x.AtUtc, x.Success, x.IpAddress, x.Device))
            .ToListAsync(ct);

        // The newest success is the session asking; the one before it is "your last login".
        var previous = history.Where(x => x.Success).Skip(1).FirstOrDefault();
        var lastFailed = history.FirstOrDefault(x => !x.Success);

        var user = await FindUserAsync(userId, ct);
        return new AccountSecurityDto(previous, lastFailed, ToConsent(user), history);
    }

    public async Task<KvkkConsentDto> AcceptKvkkAsync(Guid userId, string version, CancellationToken ct)
    {
        if (version != KvkkPolicy.CurrentVersion)
            throw new ConflictException("Aydınlatma metni güncellendi; lütfen güncel metni onaylayın.");

        var user = await FindUserAsync(userId, ct);
        user.KvkkConsentVersion = version;
        user.KvkkConsentAtUtc = _clock.UtcNow;
        await _db.SaveChangesAsync(ct);
        return ToConsent(user);
    }

    public async Task<IReadOnlyList<SessionDto>> ListSessionsAsync(Guid userId, Guid? currentSessionId, CancellationToken ct)
    {
        var now = _clock.UtcNow;
        var tokens = await _db.RefreshTokens.AsNoTracking()
            .Where(x => x.UserId == userId)
            .Select(x => new { x.Id, x.SessionId, x.CreatedAtUtc, x.ExpiresAtUtc, x.RevokedAtUtc, x.Device, x.IpAddress })
            .ToListAsync(ct);

        // Tokens from before sessions existed are each their own session.
        return tokens
            .GroupBy(x => x.SessionId == Guid.Empty ? x.Id : x.SessionId)
            .Where(g => g.Any(x => x.RevokedAtUtc == null && x.ExpiresAtUtc > now))
            .Select(g =>
            {
                var latest = g.MaxBy(x => x.CreatedAtUtc)!;
                return new SessionDto(
                    g.Key,
                    latest.Device,
                    latest.IpAddress,
                    g.Min(x => x.CreatedAtUtc),
                    latest.CreatedAtUtc,
                    g.Key == currentSessionId);
            })
            .OrderByDescending(x => x.IsCurrent)
            .ThenByDescending(x => x.LastActiveAtUtc)
            .ToList();
    }

    public async Task<int> EndSessionsAsync(Guid userId, Guid? sessionId, Guid? keep, CancellationToken ct)
    {
        var now = _clock.UtcNow;
        var active = await _db.RefreshTokens
            .Where(x => x.UserId == userId && x.RevokedAtUtc == null)
            .ToListAsync(ct);

        Guid SessionOf(RefreshToken t) => t.SessionId == Guid.Empty ? t.Id : t.SessionId;
        var ending = active.Where(t => sessionId is { } id ? SessionOf(t) == id : SessionOf(t) != keep).ToList();
        if (sessionId is not null && ending.Count == 0)
            throw new NotFoundException("Oturum bulunamadı ya da zaten sonlandırılmış.");

        foreach (var t in ending) t.RevokedAtUtc = now;
        await _db.SaveChangesAsync(ct);
        return ending.Select(SessionOf).Distinct().Count();
    }

    public async Task<object> ExportAsync(Guid userId, CancellationToken ct)
    {
        var user = await FindUserAsync(userId, ct);
        var patient = await _db.Patients.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId, ct);
        var dependents = await _db.Dependents.AsNoTracking()
            .Where(x => x.GuardianUserId == userId)
            .Select(x => new { x.FullName, x.TcKimlikNo, x.BirthDate, Relation = x.Relation.ToString() })
            .ToListAsync(ct);
        var appointments = await _db.Appointments.AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.StartAt)
            .Select(x => new
            {
                x.StartAt,
                Status = x.Status.ToString(),
                Doctor = x.Doctor!.Title + " " + x.Doctor.Name,
                Department = x.Doctor.Department!.Name,
                Hospital = x.Doctor.Department.Hospital!.Name,
                ForDependent = x.Dependent != null ? x.Dependent.FullName : null,
                x.CancellationReason,
            })
            .ToListAsync(ct);
        var logins = await _db.LoginEvents.AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.AtUtc)
            .Take(100)
            .Select(x => new { x.AtUtc, x.Success, x.IpAddress, x.Device })
            .ToListAsync(ct);
        var reviews = await _db.DoctorReviews.AsNoTracking()
            .Where(x => x.UserId == userId)
            .Select(x => new { x.AppointmentId, x.Stars, x.Comment, x.CreatedAtUtc })
            .ToListAsync(ct);

        return new
        {
            GeneratedAtUtc = _clock.UtcNow,
            Account = new
            {
                Role = user.Role.ToString(),
                Email = user.Email,
                user.KvkkConsentVersion,
                user.KvkkConsentAtUtc,
                user.TwoFactorEnabled,
            },
            Patient = patient is null ? null : new
            {
                patient.TcKimlikNo,
                patient.FirstName,
                patient.LastName,
                patient.Phone,
                patient.BirthDate,
                HealthProfile = new
                {
                    patient.BloodType,
                    patient.Allergies,
                    patient.ChronicDiseases,
                    patient.Medications,
                    patient.EmergencyContactName,
                    patient.EmergencyContactPhone,
                },
            },
            Dependents = dependents,
            Appointments = appointments,
            Reviews = reviews,
            LoginHistory = logins,
        };
    }

    private async Task<User> FindUserAsync(Guid userId, CancellationToken ct)
        => await _db.Users.SingleOrDefaultAsync(x => x.Id == userId, ct)
           ?? throw new NotFoundException("Kullanıcı bulunamadı.");

    private static KvkkConsentDto ToConsent(User user) => new(
        KvkkPolicy.CurrentVersion,
        user.KvkkConsentVersion,
        user.KvkkConsentAtUtc,
        user.KvkkConsentVersion == KvkkPolicy.CurrentVersion);
}

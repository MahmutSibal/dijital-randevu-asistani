using Microsoft.EntityFrameworkCore;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Account;

public sealed class SecurityOverviewService : ISecurityOverviewService
{
    private readonly AppDbContext _db;
    private readonly IDateTimeProvider _clock;

    public SecurityOverviewService(AppDbContext db, IDateTimeProvider clock)
    {
        _db = db;
        _clock = clock;
    }

    public async Task<SecurityOverviewDto> GetAsync(CancellationToken ct)
    {
        var now = _clock.UtcNow;
        var since = now.AddHours(-24);

        var events = await _db.LoginEvents.AsNoTracking()
            .Where(x => x.AtUtc >= since)
            .Select(x => new { x.AtUtc, x.Success })
            .ToListAsync(ct);

        var activeSessions = await _db.RefreshTokens.AsNoTracking()
            .Where(x => x.RevokedAtUtc == null && x.ExpiresAtUtc > now)
            .Select(x => x.SessionId == Guid.Empty ? x.Id : x.SessionId)
            .Distinct()
            .CountAsync(ct);

        var twoFactorUsers = await _db.Users.AsNoTracking().CountAsync(x => x.TwoFactorEnabled, ct);

        var locked = (await _db.LoginLockouts.AsNoTracking()
                .Where(x => x.LockedUntilUtc != null && x.LockedUntilUtc > now)
                .ToListAsync(ct))
            .Select(x => new LockedAccountDto(AccountLabel(x.NormalizedEmail), x.FailedCount, x.LockedUntilUtc!.Value, x.LastIpAddress))
            .ToList();

        var failures = await (
                from e in _db.LoginEvents.AsNoTracking()
                where !e.Success
                join u in _db.Users.AsNoTracking() on e.UserId equals u.Id
                join p in _db.Patients.AsNoTracking() on u.Id equals p.UserId into pj
                from p in pj.DefaultIfEmpty()
                orderby e.AtUtc descending
                select new
                {
                    e.AtUtc,
                    Role = u.Role.ToString(),
                    u.Email,
                    FirstName = p != null ? p.FirstName : null,
                    LastName = p != null ? p.LastName : null,
                    e.IpAddress,
                    e.Device,
                })
            .Take(20)
            .ToListAsync(ct);

        // Index 0 is 23 hours ago, index 23 the current hour.
        var byHour = new int[24];
        foreach (var e in events.Where(x => !x.Success))
        {
            var hoursAgo = (int)Math.Floor((now - e.AtUtc).TotalHours);
            if (hoursAgo is >= 0 and < 24) byHour[23 - hoursAgo]++;
        }

        return new SecurityOverviewDto(
            events.Count(x => x.Success),
            events.Count(x => !x.Success),
            activeSessions,
            twoFactorUsers,
            locked,
            failures.Select(f => new FailedLoginDto(
                    f.AtUtc,
                    f.FirstName != null ? $"{f.FirstName} {f.LastName}" : f.Email,
                    f.Role,
                    f.IpAddress,
                    f.Device))
                .ToList(),
            byHour);
    }

    /// <summary>Lockout keys are "TC:12345678901" for patients and the e-mail for staff.</summary>
    private static string AccountLabel(string key)
    {
        if (!key.StartsWith("TC:", StringComparison.Ordinal)) return key.ToLowerInvariant();
        var tc = key[3..];
        return tc.Length == 11 ? $"T.C. {tc[..3]}******{tc[9..]}" : "T.C. ***";
    }
}

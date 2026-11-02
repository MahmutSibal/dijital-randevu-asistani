namespace WebAppointmentApi.Application.Account;

public sealed record LockedAccountDto(string Account, int FailedCount, DateTimeOffset LockedUntilUtc, string? LastIpAddress);

public sealed record FailedLoginDto(DateTimeOffset AtUtc, string? UserLabel, string? Role, string? IpAddress, string? Device);

/// <summary>Admin "Güvenlik" panel: sign-in activity across the system.</summary>
public sealed record SecurityOverviewDto(
    int SuccessfulLogins24h,
    int FailedLogins24h,
    int ActiveSessions,
    int TwoFactorUsers,
    IReadOnlyList<LockedAccountDto> LockedAccounts,
    IReadOnlyList<FailedLoginDto> RecentFailures,
    IReadOnlyList<int> FailedByHour);

public interface ISecurityOverviewService
{
    Task<SecurityOverviewDto> GetAsync(CancellationToken ct);
}

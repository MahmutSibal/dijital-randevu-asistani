namespace WebAppointmentApi.Application.Account;

/// <summary>The KVKK disclosure text lives in the app; bumping this asks every user to accept again.</summary>
public static class KvkkPolicy
{
    public const string CurrentVersion = "2026.1";
}

public sealed record LoginEventDto(DateTimeOffset AtUtc, bool Success, string? IpAddress, string? Device);

public sealed record KvkkConsentDto(
    string CurrentVersion,
    string? AcceptedVersion,
    DateTimeOffset? AcceptedAtUtc,
    bool IsUpToDate);

/// <summary>
/// PreviousLogin is the successful sign-in before the current one ("Son girişiniz");
/// LastFailedLogin the most recent failed attempt, if any.
/// </summary>
public sealed record AccountSecurityDto(
    LoginEventDto? PreviousLogin,
    LoginEventDto? LastFailedLogin,
    KvkkConsentDto Kvkk,
    IReadOnlyList<LoginEventDto> History);

public sealed record AcceptKvkkRequest(string Version);

/// <summary>One sign-in that is still active (its refresh token chain is not revoked).</summary>
public sealed record SessionDto(
    Guid Id,
    string? Device,
    string? IpAddress,
    DateTimeOffset StartedAtUtc,
    DateTimeOffset LastActiveAtUtc,
    bool IsCurrent);

public sealed record DeletionRequestDto(string TicketNo);

public interface IAccountSecurityStore
{
    Task<IReadOnlyList<SessionDto>> ListSessionsAsync(Guid userId, Guid? currentSessionId, CancellationToken ct);

    /// <summary>Ends one session, or every session except <paramref name="keep"/> when id is null.</summary>
    Task<int> EndSessionsAsync(Guid userId, Guid? sessionId, Guid? keep, CancellationToken ct);

    /// <summary>Everything stored about the user (KVKK md. 11), as a JSON-friendly object.</summary>
    Task<object> ExportAsync(Guid userId, CancellationToken ct);

    /// <summary>Records a sign-in attempt with the caller's IP address and device.</summary>
    Task RecordLoginAsync(Guid userId, int tenantId, bool success, CancellationToken ct);

    Task<AccountSecurityDto> GetAsync(Guid userId, CancellationToken ct);

    Task<KvkkConsentDto> AcceptKvkkAsync(Guid userId, string version, CancellationToken ct);
}

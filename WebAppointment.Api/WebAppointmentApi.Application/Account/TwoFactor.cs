using WebAppointmentApi.Domain.Entities;

namespace WebAppointmentApi.Application.Account;

/// <summary>
/// Thrown by a sign-in whose password was right but which still needs the phone code.
/// The controller turns it into a 202 with the challenge to complete.
/// </summary>
public sealed class TwoFactorRequiredException : Exception
{
    public TwoFactorRequiredException(Guid challengeId, string maskedPhone, string code)
        : base("TWO_FACTOR_REQUIRED")
    {
        ChallengeId = challengeId;
        MaskedPhone = maskedPhone;
        Code = code;
    }

    public Guid ChallengeId { get; }
    public string MaskedPhone { get; }

    /// <summary>The code itself; only shown to the client in Development, where no SMS goes out.</summary>
    public string Code { get; }
}

public sealed record TwoFactorLoginRequest(Guid ChallengeId, string Code);

public sealed record TwoFactorSettingRequest(bool Enabled);

public sealed record TwoFactorStatusDto(bool Enabled, string? MaskedPhone);

public interface ITwoFactorService
{
    /// <summary>Sends a code to <paramref name="phone"/> and returns the exception to throw.</summary>
    Task<TwoFactorRequiredException> StartAsync(User user, string phone, CancellationToken ct);

    /// <summary>Checks the code; returns the user to sign in, or throws.</summary>
    Task<User> VerifyAsync(Guid challengeId, string code, CancellationToken ct);

    Task<TwoFactorStatusDto> GetAsync(Guid userId, CancellationToken ct);

    Task<TwoFactorStatusDto> SetEnabledAsync(Guid userId, bool enabled, CancellationToken ct);
}

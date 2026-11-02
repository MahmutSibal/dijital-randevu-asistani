using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Domain.Enums;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Account;

public sealed class TwoFactorService : ITwoFactorService
{
    private const int MaxAttempts = 5;
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(5);

    private readonly AppDbContext _db;
    private readonly IPhoneVerificationSender _sender;
    private readonly IDateTimeProvider _clock;
    private readonly ILogger<TwoFactorService> _logger;

    public TwoFactorService(
        AppDbContext db,
        IPhoneVerificationSender sender,
        IDateTimeProvider clock,
        ILogger<TwoFactorService> logger)
    {
        _db = db;
        _sender = sender;
        _clock = clock;
        _logger = logger;
    }

    public async Task<TwoFactorRequiredException> StartAsync(User user, string phone, CancellationToken ct)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6", CultureInfo.InvariantCulture);
        var salt = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
        var challenge = new LoginChallenge
        {
            Id = Guid.NewGuid(),
            TenantId = user.TenantId,
            UserId = user.Id,
            CodeHash = Hash(code, salt),
            CodeSalt = salt,
            ExpiresAtUtc = _clock.UtcNow.Add(Lifetime),
        };
        _db.LoginChallenges.Add(challenge);
        await _db.SaveChangesAsync(ct);

        try
        {
            await _sender.SendCodeAsync(phone, code, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or InvalidOperationException or TaskCanceledException)
        {
            // Without the WhatsApp bridge the code only reaches the app in Development.
            _logger.LogWarning(ex, "Two-factor code could not be sent to the user's phone. UserId={UserId}", user.Id);
        }

        return new TwoFactorRequiredException(challenge.Id, MaskPhone(phone), code);
    }

    public async Task<User> VerifyAsync(Guid challengeId, string code, CancellationToken ct)
    {
        var challenge = await _db.LoginChallenges.SingleOrDefaultAsync(x => x.Id == challengeId, ct);
        var now = _clock.UtcNow;
        if (challenge is null || challenge.UsedAtUtc is not null || challenge.ExpiresAtUtc <= now
            || challenge.FailedAttempts >= MaxAttempts)
        {
            throw new UnauthorizedException("Doğrulama kodunun süresi doldu. Lütfen yeniden giriş yapın.");
        }

        if (!string.Equals(challenge.CodeHash, Hash((code ?? "").Trim(), challenge.CodeSalt), StringComparison.Ordinal))
        {
            challenge.FailedAttempts++;
            await _db.SaveChangesAsync(ct);
            var left = MaxAttempts - challenge.FailedAttempts;
            throw new UnauthorizedException(left > 0
                ? $"Doğrulama kodu hatalı. Kalan deneme hakkınız: {left}."
                : "Doğrulama kodu çok kez hatalı girildi. Lütfen yeniden giriş yapın.");
        }

        challenge.UsedAtUtc = now;
        await _db.SaveChangesAsync(ct);
        return await _db.Users.SingleAsync(x => x.Id == challenge.UserId, ct);
    }

    public async Task<TwoFactorStatusDto> GetAsync(Guid userId, CancellationToken ct)
    {
        var user = await _db.Users.AsNoTracking().SingleAsync(x => x.Id == userId, ct);
        var phone = await PhoneOfAsync(userId, ct);
        return new TwoFactorStatusDto(user.TwoFactorEnabled, phone is null ? null : MaskPhone(phone));
    }

    public async Task<TwoFactorStatusDto> SetEnabledAsync(Guid userId, bool enabled, CancellationToken ct)
    {
        var user = await _db.Users.SingleAsync(x => x.Id == userId, ct);
        var phone = await PhoneOfAsync(userId, ct);
        if (enabled && (user.Role != UserRole.Patient || string.IsNullOrWhiteSpace(phone)))
            throw new ConflictException("İki adımlı doğrulama için hesabınızda kayıtlı bir telefon numarası olmalı.");

        user.TwoFactorEnabled = enabled;
        await _db.SaveChangesAsync(ct);
        return new TwoFactorStatusDto(enabled, phone is null ? null : MaskPhone(phone));
    }

    private Task<string?> PhoneOfAsync(Guid userId, CancellationToken ct)
        => _db.Patients.AsNoTracking().Where(x => x.UserId == userId).Select(x => x.Phone).FirstOrDefaultAsync(ct);

    /// <summary>"5551112233" → "*******233"</summary>
    private static string MaskPhone(string phone)
    {
        var digits = new string(phone.Where(char.IsDigit).ToArray());
        return digits.Length <= 3 ? digits : new string('*', digits.Length - 3) + digits[^3..];
    }

    private static string Hash(string code, string salt)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(salt + ":" + code)));
}

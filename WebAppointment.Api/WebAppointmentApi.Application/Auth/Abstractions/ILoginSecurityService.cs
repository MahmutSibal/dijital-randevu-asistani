namespace WebAppointmentApi.Application.Auth.Abstractions;

public interface ILoginSecurityService
{
    Task EnsureNotLockedAsync(string normalizedEmail, CancellationToken ct);

    /// <summary>Counts a failed attempt and returns how many are left before the lock (0 = now locked).</summary>
    Task<int> RegisterFailureAsync(string normalizedEmail, string? ipAddress, CancellationToken ct);

    Task RegisterSuccessAsync(string normalizedEmail, CancellationToken ct);
}

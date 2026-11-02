using WebAppointmentApi.Domain.Entities;

namespace WebAppointmentApi.Application.Common.Abstractions;

public interface ITokenService
{
    /// <param name="sessionId">Written as the "sid" claim, so a revoked session's access tokens stop working.</param>
    (string AccessToken, DateTimeOffset ExpiresAtUtc) CreateAccessToken(User user, Guid? sessionId = null);
    string CreateRefreshToken();
    string HashRefreshToken(string refreshToken);
}

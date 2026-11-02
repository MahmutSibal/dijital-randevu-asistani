using System.Security.Claims;

namespace WebAppointmentApi.WebApi.Security;

public static class SessionClaims
{
    /// <summary>
    /// The "sid" claim written by JwtTokenService; inbound claim mapping may have renamed it
    /// to <see cref="ClaimTypes.Sid"/>. Null for tokens issued before sessions existed.
    /// </summary>
    public static Guid? SessionIdOf(ClaimsPrincipal? principal)
    {
        var value = principal?.FindFirst("sid")?.Value ?? principal?.FindFirst(ClaimTypes.Sid)?.Value;
        return Guid.TryParse(value, out var id) ? id : null;
    }
}

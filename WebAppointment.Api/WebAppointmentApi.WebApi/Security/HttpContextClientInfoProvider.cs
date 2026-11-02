using WebAppointmentApi.Application.Common.Abstractions;

namespace WebAppointmentApi.WebApi.Security;

public sealed class HttpContextClientInfoProvider : IClientInfoProvider
{
    private readonly IHttpContextAccessor _http;

    public HttpContextClientInfoProvider(IHttpContextAccessor http)
    {
        _http = http;
    }

    public string? IpAddress => _http.HttpContext?.Connection?.RemoteIpAddress?.ToString();

    public string? Device
    {
        get
        {
            var headers = _http.HttpContext?.Request.Headers;
            var value = headers?["X-Client-Device"].FirstOrDefault() ?? headers?.UserAgent.FirstOrDefault();
            return string.IsNullOrWhiteSpace(value) ? null : value.Length > 200 ? value[..200] : value;
        }
    }
}

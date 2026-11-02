namespace WebAppointmentApi.Application.Common.Abstractions;

public interface IClientInfoProvider
{
    string? IpAddress { get; }

    /// <summary>The app's X-Client-Device header, else the User-Agent.</summary>
    string? Device { get; }
}

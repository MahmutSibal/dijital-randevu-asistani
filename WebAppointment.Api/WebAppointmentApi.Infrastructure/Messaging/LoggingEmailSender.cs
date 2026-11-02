using Microsoft.Extensions.Logging;
using WebAppointmentApi.Application.Common.Abstractions;

namespace WebAppointmentApi.Infrastructure.Messaging;

/// <summary>
/// Used instead of Brevo when no Brevo API key is configured (local development):
/// writes the e-mail to the log so verification codes can be read from the API console.
/// </summary>
public sealed class LoggingEmailSender : IEmailSender
{
    private readonly ILogger<LoggingEmailSender> _logger;

    public LoggingEmailSender(ILogger<LoggingEmailSender> logger)
    {
        _logger = logger;
    }

    public Task SendAsync(string toEmail, string subject, string htmlBody, CancellationToken ct)
    {
        _logger.LogWarning(
            "Brevo is not configured; e-mail not sent. To={To} Subject={Subject} Body={Body}",
            toEmail,
            subject,
            htmlBody);
        return Task.CompletedTask;
    }
}

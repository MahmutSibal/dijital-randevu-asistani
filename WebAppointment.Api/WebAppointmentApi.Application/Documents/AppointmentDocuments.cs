namespace WebAppointmentApi.Application.Documents;

/// <summary>
/// An appointment certificate as issued. Personal details are masked so the public
/// verification page can show it to whoever holds the code.
/// </summary>
public sealed record AppointmentDocumentDto(
    string Code,
    DateTimeOffset IssuedAtUtc,
    string PatientName,
    string MaskedTcKimlikNo,
    string Hospital,
    string Department,
    string Doctor,
    DateTimeOffset StartAt,
    string Status);

public interface IAppointmentDocumentService
{
    /// <summary>Issues a new certificate for one of the user's own appointments.</summary>
    Task<AppointmentDocumentDto> IssueAsync(Guid appointmentId, Guid userId, CancellationToken ct);

    /// <summary>Returns the certificate for a verification code, or null if none was issued.</summary>
    Task<AppointmentDocumentDto?> VerifyAsync(string code, CancellationToken ct);
}

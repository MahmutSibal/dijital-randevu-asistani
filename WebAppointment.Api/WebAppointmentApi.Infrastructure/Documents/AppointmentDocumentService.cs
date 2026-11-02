using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Application.Documents;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Domain.Enums;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Documents;

public sealed class AppointmentDocumentService : IAppointmentDocumentService
{
    // No 0/O, 1/I so a code read off paper can be typed back.
    private const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    private readonly AppDbContext _db;
    private readonly IDateTimeProvider _clock;

    public AppointmentDocumentService(AppDbContext db, IDateTimeProvider clock)
    {
        _db = db;
        _clock = clock;
    }

    public async Task<AppointmentDocumentDto> IssueAsync(Guid appointmentId, Guid userId, CancellationToken ct)
    {
        var appointment = await _db.Appointments.AsNoTracking()
            .Include(x => x.Dependent)
            .Include(x => x.Doctor!).ThenInclude(d => d.Department!).ThenInclude(d => d.Hospital)
            .SingleOrDefaultAsync(x => x.Id == appointmentId, ct)
            ?? throw new NotFoundException("Randevu bulunamadı.");
        if (appointment.UserId != userId)
            throw new ForbiddenException("Bu randevu için belge alamazsınız.");

        string name, tc;
        if (appointment.Dependent is { } dependent)
        {
            (name, tc) = (dependent.FullName, dependent.TcKimlikNo);
        }
        else
        {
            var patient = await _db.Patients.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId, ct)
                ?? throw new NotFoundException("Hasta kaydı bulunamadı.");
            (name, tc) = ($"{patient.FirstName} {patient.LastName}", patient.TcKimlikNo);
        }

        var doctor = appointment.Doctor;
        var document = new AppointmentDocument
        {
            Id = Guid.NewGuid(),
            TenantId = appointment.TenantId,
            Code = NewCode(),
            AppointmentId = appointment.Id,
            UserId = userId,
            IssuedAtUtc = _clock.UtcNow,
        };
        var dto = new AppointmentDocumentDto(
            document.Code,
            document.IssuedAtUtc,
            MaskName(name),
            MaskTc(tc),
            doctor?.Department?.Hospital?.Name ?? "",
            doctor?.Department?.Name ?? "",
            doctor is null ? "" : $"{doctor.Title} {doctor.Name}".Trim(),
            appointment.StartAt,
            StatusText(appointment.Status));
        document.PayloadJson = JsonSerializer.Serialize(dto);

        _db.AppointmentDocuments.Add(document);
        await _db.SaveChangesAsync(ct);
        return dto;
    }

    public async Task<AppointmentDocumentDto?> VerifyAsync(string code, CancellationToken ct)
    {
        var normalized = code.Trim().ToUpperInvariant();
        var document = await _db.AppointmentDocuments.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Code == normalized, ct);
        return document is null ? null : JsonSerializer.Deserialize<AppointmentDocumentDto>(document.PayloadJson);
    }

    /// <summary>RB-XXXX-XXXX-XXXX</summary>
    private static string NewCode()
    {
        Span<char> chars = stackalloc char[12];
        for (var i = 0; i < chars.Length; i++)
            chars[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        return $"RB-{chars[..4]}-{chars[4..8]}-{chars[8..]}";
    }

    /// <summary>"Ayşe Yılmaz" → "Ay** Yı****"</summary>
    private static string MaskName(string name) => string.Join(' ',
        name.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(p => p.Length <= 2 ? p : p[..2] + new string('*', p.Length - 2)));

    /// <summary>"12345678901" → "123******01"</summary>
    private static string MaskTc(string tc)
        => tc.Length == 11 ? tc[..3] + new string('*', 6) + tc[9..] : new string('*', tc.Length);

    private static string StatusText(AppointmentStatus status) => status switch
    {
        AppointmentStatus.Pending => "Onay bekliyor",
        AppointmentStatus.Approved => "Onaylandı",
        AppointmentStatus.Cancelled => "İptal edildi",
        AppointmentStatus.Completed => "Tamamlandı",
        AppointmentStatus.NoShow => "Gelinmedi",
        _ => status.ToString(),
    };
}

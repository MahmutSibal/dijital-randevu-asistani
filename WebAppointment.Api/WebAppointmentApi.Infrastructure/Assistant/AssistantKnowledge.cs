using System.Text;
using Microsoft.EntityFrameworkCore;
using WebAppointmentApi.Application.Assistant.Abstractions;
using WebAppointmentApi.Domain.Enums;
using WebAppointmentApi.Infrastructure.Data;

namespace WebAppointmentApi.Infrastructure.Assistant;

public sealed class AssistantKnowledge : IAssistantKnowledge
{
    private readonly AppDbContext _db;

    public AssistantKnowledge(AppDbContext db)
    {
        _db = db;
    }

    public async Task<string> DescribeCatalogAsync(CancellationToken ct)
    {
        var hospitals = await _db.Hospitals
            .AsNoTracking()
            .Where(h => !h.IsDeleted)
            .OrderBy(h => h.Name)
            .Select(h => new
            {
                h.Name,
                h.Type,
                h.Address,
                Departments = h.Departments
                    .Where(d => !d.IsDeleted)
                    .OrderBy(d => d.Name)
                    .Select(d => new
                    {
                        d.Name,
                        // Only doctors patients can actually book.
                        Doctors = d.Doctors
                            .Where(x => x.IsActive && x.ProfileStatus == DoctorProfileStatus.Approved)
                            .OrderBy(x => x.Name)
                            .Select(x => x.Title + " " + x.Name)
                            .ToList()
                    })
                    .ToList()
            })
            .ToListAsync(ct);

        var sb = new StringBuilder("## Sistemdeki kayıtlar\n");
        if (hospitals.Count == 0)
        {
            sb.AppendLine("Sistemde henüz kayıtlı hastane yok; bu yüzden şu an randevu alınamaz.");
            return sb.ToString();
        }

        foreach (var h in hospitals)
        {
            var type = h.Type == HospitalType.Private ? "özel hastane" : "devlet hastanesi";
            sb.Append("- ").Append(h.Name).Append(" (").Append(type);
            if (!string.IsNullOrWhiteSpace(h.Address)) sb.Append(", ").Append(h.Address);
            sb.AppendLine(")");

            if (h.Departments.Count == 0)
            {
                sb.AppendLine("  - Henüz bölüm yok.");
                continue;
            }

            foreach (var d in h.Departments)
            {
                sb.Append("  - ").Append(d.Name).Append(": ");
                sb.AppendLine(d.Doctors.Count == 0 ? "randevu verilebilecek doktor yok" : string.Join(", ", d.Doctors));
            }
        }

        return sb.ToString();
    }
}

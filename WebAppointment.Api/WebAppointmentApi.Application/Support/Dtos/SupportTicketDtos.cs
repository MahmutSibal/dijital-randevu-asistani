namespace WebAppointmentApi.Application.Support.Dtos;

/// <summary>A support request as stored in the "Talepler" Google Sheet (via n8n).</summary>
public sealed record SupportTicketDto(
    string TalepNo,
    string OlusturmaTarihi,
    string AdSoyad,
    string Iletisim,
    string Kategori,
    string Oncelik,
    string Konu,
    string Aciklama,
    string Durum,
    string GuncellemeTarihi,
    string YetkiliNotu);

public sealed class CreateSupportTicketRequest
{
    public string AdSoyad { get; set; } = string.Empty;

    /// <summary>Phone or e-mail to reach the requester.</summary>
    public string? Iletisim { get; set; }

    public string Kategori { get; set; } = SupportTicketRules.Categories[0];

    public string Oncelik { get; set; } = "Normal";

    public string Konu { get; set; } = string.Empty;

    public string Aciklama { get; set; } = string.Empty;
}

public sealed class UpdateSupportTicketStatusRequest
{
    public string Durum { get; set; } = string.Empty;

    /// <summary>Note from staff, shown to the requester. Null keeps the current note.</summary>
    public string? Not { get; set; }
}

public static class SupportTicketRules
{
    public static readonly string[] Categories = ["Randevu", "Teknik Sorun", "Şikâyet", "Öneri", "Diğer"];
    public static readonly string[] Priorities = ["Düşük", "Normal", "Yüksek"];
    public static readonly string[] Statuses = ["Açık", "İşlemde", "Çözüldü", "Kapatıldı"];
}

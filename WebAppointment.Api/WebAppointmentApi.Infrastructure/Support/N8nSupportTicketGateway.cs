using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Application.Support.Abstractions;
using WebAppointmentApi.Application.Support.Dtos;

namespace WebAppointmentApi.Infrastructure.Support;

/// <summary>Calls the n8n workflow's webhooks (destek/talep, sorgula, durum, liste).</summary>
public sealed class N8nSupportTicketGateway : ISupportTicketGateway
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _http;
    private readonly ILogger<N8nSupportTicketGateway> _logger;

    public N8nSupportTicketGateway(HttpClient http, ILogger<N8nSupportTicketGateway> logger)
    {
        _http = http;
        _logger = logger;
    }

    public async Task<SupportTicketDto> CreateAsync(CreateSupportTicketRequest request, string? userId, CancellationToken ct)
    {
        using var response = await SendAsync(() => _http.PostAsJsonAsync("destek/talep", new
        {
            kullaniciId = userId ?? string.Empty,
            adSoyad = request.AdSoyad,
            iletisim = request.Iletisim ?? string.Empty,
            kategori = request.Kategori,
            oncelik = request.Oncelik,
            konu = request.Konu,
            aciklama = request.Aciklama,
        }, ct));
        return (await ReadRowAsync(response, ct)).Ticket;
    }

    public async Task<SupportTicketDto?> FindAsync(string talepNo, CancellationToken ct)
    {
        using var response = await SendAsync(() =>
            _http.GetAsync($"destek/sorgula?talepNo={Uri.EscapeDataString(talepNo)}", ct));
        if (await IsTicketNotFoundAsync(response, ct)) return null;
        return (await ReadRowAsync(response, ct)).Ticket;
    }

    public async Task<IReadOnlyList<(SupportTicketDto Ticket, string UserId)>> ListAsync(CancellationToken ct)
    {
        using var response = await SendAsync(() => _http.GetAsync("destek/liste", ct));
        await EnsureOkAsync(response, ct);
        var rows = await response.Content.ReadFromJsonAsync<List<SheetRow>>(Json, ct) ?? [];
        // An empty sheet comes back as one empty item.
        return rows.Where(r => !string.IsNullOrWhiteSpace(r.TalepNo)).Select(r => (r.ToDto(), r.KullaniciId ?? "")).ToList();
    }

    public async Task<SupportTicketDto?> UpdateStatusAsync(string talepNo, UpdateSupportTicketStatusRequest request, CancellationToken ct)
    {
        using var response = await SendAsync(() => _http.PostAsJsonAsync("destek/durum", new
        {
            talepNo,
            durum = request.Durum,
            not = request.Not,
        }, ct));
        if (await IsTicketNotFoundAsync(response, ct)) return null;
        return (await ReadRowAsync(response, ct)).Ticket;
    }

    /// <summary>
    /// The workflow answers an unknown ticket with 404 {"error": …}; n8n itself answers 404
    /// {"code":404,"message":"…not registered"} when the workflow isn't published.
    /// </summary>
    private static async Task<bool> IsTicketNotFoundAsync(HttpResponseMessage response, CancellationToken ct)
    {
        if (response.StatusCode != HttpStatusCode.NotFound) return false;
        return ErrorText(await response.Content.ReadAsStringAsync(ct)) is not null;
    }

    private async Task<HttpResponseMessage> SendAsync(Func<Task<HttpResponseMessage>> send)
    {
        if (_http.BaseAddress is null)
            throw new SupportUnavailableException("Destek sistemi yapılandırılmamış.");
        try
        {
            return await send();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            _logger.LogWarning(ex, "n8n support workflow could not be reached.");
            throw new SupportUnavailableException("Destek sistemine şu an ulaşılamıyor.", ex);
        }
    }

    private async Task<(SupportTicketDto Ticket, string UserId)> ReadRowAsync(HttpResponseMessage response, CancellationToken ct)
    {
        await EnsureOkAsync(response, ct);
        var row = await response.Content.ReadFromJsonAsync<SheetRow>(Json, ct)
            ?? throw new SupportUnavailableException("Destek sisteminden boş yanıt geldi.");
        return (row.ToDto(), row.KullaniciId ?? "");
    }

    private async Task EnsureOkAsync(HttpResponseMessage response, CancellationToken ct)
    {
        if (response.IsSuccessStatusCode) return;
        var body = await response.Content.ReadAsStringAsync(ct);
        if (response.StatusCode == HttpStatusCode.BadRequest)
            throw new FluentValidation.ValidationException(
                [new FluentValidation.Results.ValidationFailure("", ErrorText(body) ?? "Talep bilgileri geçersiz.")]);
        if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
        {
            _logger.LogError("n8n rejected the support API key ({Status}).", (int)response.StatusCode);
            throw new SupportUnavailableException("Destek sistemi bağlantısı yetkilendirilmemiş.");
        }
        if (response.StatusCode == HttpStatusCode.NotFound && ErrorText(body) is { } notFound)
            throw new NotFoundException(notFound);
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            _logger.LogError("n8n support webhook is not registered; is the workflow published? {Body}", body);
            throw new SupportUnavailableException("Destek otomasyonu şu an etkin değil.");
        }
        _logger.LogWarning("n8n support workflow returned {Status}: {Body}", (int)response.StatusCode, body);
        throw new SupportUnavailableException("Destek sistemi isteği işleyemedi.");
    }

    private static string? ErrorText(string body)
    {
        try
        {
            return JsonDocument.Parse(body).RootElement.TryGetProperty("error", out var e) ? e.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>A sheet row as n8n returns it (column headers as property names).</summary>
    private sealed class SheetRow
    {
        public string? TalepNo { get; set; }
        public string? OlusturmaTarihi { get; set; }
        public string? KullaniciId { get; set; }
        public string? AdSoyad { get; set; }
        public string? Iletisim { get; set; }
        public string? Kategori { get; set; }
        public string? Oncelik { get; set; }
        public string? Konu { get; set; }
        public string? Aciklama { get; set; }
        public string? Durum { get; set; }
        public string? GuncellemeTarihi { get; set; }
        public string? YetkiliNotu { get; set; }

        public SupportTicketDto ToDto() => new(
            TalepNo ?? "", OlusturmaTarihi ?? "", AdSoyad ?? "", Iletisim ?? "", Kategori ?? "",
            Oncelik ?? "", Konu ?? "", Aciklama ?? "", Durum ?? "", GuncellemeTarihi ?? "", YetkiliNotu ?? "");
    }
}

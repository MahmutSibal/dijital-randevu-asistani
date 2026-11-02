using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Support.Abstractions;
using WebAppointmentApi.Application.Support.Dtos;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>
/// Support requests ("destek talepleri"). The API validates and authorizes; the n8n workflow
/// "Hastane Destek Talepleri" numbers them and keeps them in Google Sheets.
/// Anyone can open a request and look it up by its number; signed-in users also see their own
/// list; hospital admins and the super admin see all requests and change their status.
/// </summary>
[ApiController]
[Route("api/support/tickets")]
public sealed partial class SupportTicketsController : ControllerBase
{
    private readonly ISupportTicketGateway _tickets;

    public SupportTicketsController(ISupportTicketGateway tickets)
    {
        _tickets = tickets;
    }

    [HttpPost]
    [AllowAnonymous]
    public Task<IActionResult> Create([FromBody] CreateSupportTicketRequest request, CancellationToken ct) => Run(async () =>
    {
        var error = Validate(request);
        if (error is not null) return BadRequest(error);
        var ticket = await _tickets.CreateAsync(request, CurrentUserId(), ct);
        return CreatedAtAction(nameof(Get), new { talepNo = ticket.TalepNo }, ticket);
    });

    [HttpGet("{talepNo}")]
    [AllowAnonymous]
    public Task<IActionResult> Get([FromRoute] string talepNo, CancellationToken ct) => Run(async () =>
    {
        var no = Normalize(talepNo);
        if (no is null) return BadRequest("Talep numarası DT-YYYYAAGG-XXXXX biçiminde olmalıdır.");
        var ticket = await _tickets.FindAsync(no, ct);
        return ticket is null ? NotFound("Bu numarayla bir talep bulunamadı.") : Ok(ticket);
    });

    [HttpGet("mine")]
    [Authorize]
    public Task<IActionResult> Mine(CancellationToken ct) => Run(async () =>
    {
        var userId = CurrentUserId();
        var all = await _tickets.ListAsync(ct);
        return Ok(all.Where(x => x.UserId == userId).Select(x => x.Ticket).Reverse().ToList());
    });

    [HttpGet]
    [Authorize(Roles = "Admin,HospitalAdmin")]
    public Task<IActionResult> All([FromQuery] string? durum, CancellationToken ct) => Run(async () =>
    {
        var all = (await _tickets.ListAsync(ct)).Select(x => x.Ticket);
        if (!string.IsNullOrWhiteSpace(durum)) all = all.Where(t => t.Durum == durum);
        return Ok(all.Reverse().ToList());
    });

    [HttpPatch("{talepNo}/status")]
    [Authorize(Roles = "Admin,HospitalAdmin")]
    public Task<IActionResult> UpdateStatus(
        [FromRoute] string talepNo,
        [FromBody] UpdateSupportTicketStatusRequest request,
        CancellationToken ct) => Run(async () =>
    {
        var no = Normalize(talepNo);
        if (no is null) return BadRequest("Talep numarası DT-YYYYAAGG-XXXXX biçiminde olmalıdır.");
        if (!SupportTicketRules.Statuses.Contains(request.Durum))
            return BadRequest($"Durum şunlardan biri olmalıdır: {string.Join(", ", SupportTicketRules.Statuses)}.");
        if (request.Not is { Length: > 1000 }) return BadRequest("Not en fazla 1000 karakter olabilir.");
        var ticket = await _tickets.UpdateStatusAsync(no, request, ct);
        return ticket is null ? NotFound("Bu numarayla bir talep bulunamadı.") : Ok(ticket);
    });

    private async Task<IActionResult> Run(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (SupportUnavailableException ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, ex.Message);
        }
    }

    private static string? Validate(CreateSupportTicketRequest r)
    {
        if (string.IsNullOrWhiteSpace(r.AdSoyad)) return "Ad soyad zorunludur.";
        if (string.IsNullOrWhiteSpace(r.Konu)) return "Konu zorunludur.";
        if (string.IsNullOrWhiteSpace(r.Aciklama)) return "Açıklama zorunludur.";
        if (r.AdSoyad.Length > 120 || (r.Iletisim?.Length ?? 0) > 120) return "Ad soyad ve iletişim en fazla 120 karakter olabilir.";
        if (r.Konu.Length > 200) return "Konu en fazla 200 karakter olabilir.";
        if (r.Aciklama.Length > 4000) return "Açıklama en fazla 4000 karakter olabilir.";
        if (!SupportTicketRules.Categories.Contains(r.Kategori))
            return $"Kategori şunlardan biri olmalıdır: {string.Join(", ", SupportTicketRules.Categories)}.";
        if (!SupportTicketRules.Priorities.Contains(r.Oncelik))
            return $"Öncelik şunlardan biri olmalıdır: {string.Join(", ", SupportTicketRules.Priorities)}.";
        return null;
    }

    /// <summary>"dt-20261102-k7q2x" → "DT-20261102-K7Q2X"; null when it isn't a ticket number.</summary>
    private static string? Normalize(string talepNo)
    {
        var no = talepNo.Trim().ToUpperInvariant();
        return TicketNumber().IsMatch(no) ? no : null;
    }

    private string? CurrentUserId() =>
        User.Identity?.IsAuthenticated == true
            ? User.FindFirstValue(JwtRegisteredClaimNames.Sub) ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
            : null;

    [GeneratedRegex(@"^DT-\d{8}-[A-Z0-9]{5}$")]
    private static partial Regex TicketNumber();
}

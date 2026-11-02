using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Support.Abstractions;
using WebAppointmentApi.Application.Support.Dtos;
using WebAppointmentApi.WebApi.Security;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>
/// The signed-in user's account security: login history, KVKK consent and data rights,
/// two-step sign-in and active sessions.
/// </summary>
[ApiController]
[Route("api/account")]
[Authorize]
public sealed class AccountSecurityController : ControllerBase
{
    private readonly IAccountSecurityStore _store;
    private readonly ITwoFactorService _twoFactor;
    private readonly IUserContext _user;

    public AccountSecurityController(IAccountSecurityStore store, ITwoFactorService twoFactor, IUserContext user)
    {
        _store = store;
        _twoFactor = twoFactor;
        _user = user;
    }

    [HttpGet("security")]
    [ProducesResponseType(typeof(AccountSecurityDto), StatusCodes.Status200OK)]
    public Task<AccountSecurityDto> Get(CancellationToken ct) => _store.GetAsync(_user.UserId, ct);

    [HttpPost("kvkk")]
    [ProducesResponseType(typeof(KvkkConsentDto), StatusCodes.Status200OK)]
    public Task<KvkkConsentDto> AcceptKvkk([FromBody] AcceptKvkkRequest request, CancellationToken ct)
        => _store.AcceptKvkkAsync(_user.UserId, request.Version, ct);

    [HttpGet("two-factor")]
    public Task<TwoFactorStatusDto> GetTwoFactor(CancellationToken ct) => _twoFactor.GetAsync(_user.UserId, ct);

    [HttpPut("two-factor")]
    public Task<TwoFactorStatusDto> SetTwoFactor([FromBody] TwoFactorSettingRequest request, CancellationToken ct)
        => _twoFactor.SetEnabledAsync(_user.UserId, request.Enabled, ct);

    [HttpGet("sessions")]
    public Task<IReadOnlyList<SessionDto>> Sessions(CancellationToken ct)
        => _store.ListSessionsAsync(_user.UserId, SessionClaims.SessionIdOf(User), ct);

    [HttpDelete("sessions/{sessionId:guid}")]
    public async Task<IActionResult> EndSession(Guid sessionId, CancellationToken ct)
    {
        await _store.EndSessionsAsync(_user.UserId, sessionId, keep: null, ct);
        return NoContent();
    }

    /// <summary>"Tüm diğer cihazlardan çıkış yap".</summary>
    [HttpPost("sessions/end-others")]
    public async Task<IActionResult> EndOtherSessions(CancellationToken ct)
    {
        var ended = await _store.EndSessionsAsync(_user.UserId, sessionId: null, SessionClaims.SessionIdOf(User), ct);
        return Ok(new { ended });
    }

    /// <summary>KVKK md. 11: everything stored about the user.</summary>
    [HttpGet("export")]
    public Task<object> Export(CancellationToken ct) => _store.ExportAsync(_user.UserId, ct);

    /// <summary>
    /// Account deletion goes through the support desk (n8n → Sheets) so staff can check open
    /// appointments and legal retention first; the user gets a ticket number to follow.
    /// </summary>
    [HttpPost("deletion-request")]
    [Authorize(Roles = "Patient")]
    public async Task<DeletionRequestDto> RequestDeletion(
        [FromServices] ISupportTicketGateway support,
        [FromServices] IPatientRepository patients,
        CancellationToken ct)
    {
        var patient = await patients.FindByUserIdAsync(_user.UserId, ct);
        var ticket = await support.CreateAsync(new CreateSupportTicketRequest
        {
            AdSoyad = patient is null ? "Hasta" : $"{patient.FirstName} {patient.LastName}",
            Iletisim = patient?.Phone,
            Kategori = "Diğer",
            Oncelik = "Yüksek",
            Konu = "KVKK - Hesap silme talebi",
            Aciklama = "Hasta, KVKK md. 11 kapsamında hesabının ve kişisel verilerinin silinmesini talep etti. "
                + "Açık randevular ve yasal saklama süreleri kontrol edildikten sonra işlem yapılmalıdır.",
        }, _user.UserId.ToString(), ct);
        return new DeletionRequestDto(ticket.TalepNo);
    }
}

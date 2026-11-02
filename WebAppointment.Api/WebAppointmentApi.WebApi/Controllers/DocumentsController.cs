using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Documents;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>Appointment certificates with a verification code, and the public check of that code.</summary>
[ApiController]
[Route("api/documents")]
public sealed class DocumentsController : ControllerBase
{
    private readonly IAppointmentDocumentService _documents;
    private readonly IUserContext _user;

    public DocumentsController(IAppointmentDocumentService documents, IUserContext user)
    {
        _documents = documents;
        _user = user;
    }

    [HttpPost("appointments/{appointmentId:guid}")]
    [Authorize(Roles = "Patient")]
    [ProducesResponseType(typeof(AppointmentDocumentDto), StatusCodes.Status200OK)]
    public Task<AppointmentDocumentDto> Issue(Guid appointmentId, CancellationToken ct)
        => _documents.IssueAsync(appointmentId, _user.UserId, ct);

    [HttpGet("verify/{code}")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(AppointmentDocumentDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AppointmentDocumentDto>> Verify(string code, CancellationToken ct)
    {
        var document = await _documents.VerifyAsync(code, ct);
        return document is null
            ? NotFound(new { error = "Bu doğrulama koduyla düzenlenmiş bir belge bulunamadı." })
            : Ok(document);
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Common.Abstractions;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>The signed-in patient's own name and contact details, for greeting them in the app.</summary>
[ApiController]
[Route("api/patient/me")]
[Authorize(Roles = "Patient")]
public sealed class PatientMeController : ControllerBase
{
    private readonly IPatientRepository _patients;
    private readonly IUserContext _user;

    public PatientMeController(IPatientRepository patients, IUserContext user)
    {
        _patients = patients;
        _user = user;
    }

    public sealed record PatientMeDto(string FirstName, string LastName, string Phone);

    [HttpGet]
    [ProducesResponseType(typeof(PatientMeDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PatientMeDto>> Get(CancellationToken ct)
    {
        var patient = await _patients.FindByUserIdAsync(_user.UserId, ct);
        if (patient is null)
            return NotFound("Hasta profili bulunamadı.");

        return Ok(new PatientMeDto(patient.FirstName, patient.LastName, patient.Phone));
    }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Account;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>Sign-in activity for the admin "Güvenlik" tab.</summary>
[ApiController]
[Route("api/admin/security")]
[Authorize(Roles = "Admin")]
public sealed class AdminSecurityController : ControllerBase
{
    private readonly ISecurityOverviewService _overview;

    public AdminSecurityController(ISecurityOverviewService overview) => _overview = overview;

    [HttpGet]
    public Task<SecurityOverviewDto> Get(CancellationToken ct) => _overview.GetAsync(ct);
}

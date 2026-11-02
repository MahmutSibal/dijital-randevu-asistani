using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Reviews;

namespace WebAppointmentApi.WebApi.Controllers;

/// <summary>Patients rate completed appointments; ratings are shown when choosing a doctor.</summary>
[ApiController]
public sealed class ReviewsController : ControllerBase
{
    private readonly IDoctorReviewService _reviews;
    private readonly IUserContext _user;

    public ReviewsController(IDoctorReviewService reviews, IUserContext user)
    {
        _reviews = reviews;
        _user = user;
    }

    [HttpPost("api/appointments/{appointmentId:guid}/review")]
    [Authorize(Roles = "Patient")]
    public Task<ReviewDto> Create(Guid appointmentId, [FromBody] CreateReviewRequest request, CancellationToken ct)
        => _reviews.CreateAsync(appointmentId, _user.UserId, request, ct);

    [HttpGet("api/reviews/mine")]
    [Authorize(Roles = "Patient")]
    public Task<IReadOnlyList<ReviewDto>> Mine(CancellationToken ct) => _reviews.ListMineAsync(_user.UserId, ct);

    [HttpGet("api/reviews/doctors/{doctorId:int}")]
    [AllowAnonymous]
    public Task<DoctorRatingDto> Doctor(int doctorId, CancellationToken ct) => _reviews.GetDoctorRatingAsync(doctorId, ct);

    /// <summary>{ "12": { "average": 4.5, "count": 8 }, ... } for every rated doctor.</summary>
    [HttpGet("api/reviews/doctors/averages")]
    [AllowAnonymous]
    public async Task<IActionResult> Averages(CancellationToken ct)
    {
        var averages = await _reviews.GetAveragesAsync(ct);
        return Ok(averages.ToDictionary(
            x => x.Key.ToString(),
            x => new { average = x.Value.Average, count = x.Value.Count }));
    }
}

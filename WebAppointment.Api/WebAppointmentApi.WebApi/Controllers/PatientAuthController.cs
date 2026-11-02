using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Application.Auth.Abstractions;
using WebAppointmentApi.Application.Auth.Dtos;
using WebAppointmentApi.Application.Patients.Dtos;

namespace WebAppointmentApi.WebApi.Controllers;

[ApiController]
[Route("api/auth/patient")]
public sealed class PatientAuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly IHostEnvironment _env;

    public PatientAuthController(IAuthService auth, IHostEnvironment env)
    {
        _auth = auth;
        _env = env;
    }

    // Hasta kayıt: e-posta tamamen kaldırıldı
    [HttpPost("register")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    public Task<LoginResponse> Register([FromBody] CreatePatientNoEmailRequest request, CancellationToken ct)
    {
        var mapped = new CreatePatientRequest(
            Email: null,
            Password: request.Password,
            TcKimlikNo: request.TcKimlikNo,
            FirstName: request.FirstName,
            LastName: request.LastName,
            Phone: request.Phone,
            BirthDate: request.BirthDate
        );
        return _auth.RegisterAsync(mapped, ct);
    }

    [HttpPost("register/request-code")]
    [AllowAnonymous]
    public async Task<IActionResult> RequestPhoneCode([FromBody] PhoneVerificationRequest request, CancellationToken ct)
    {
        await _auth.RequestPhoneVerificationCodeAsync(request, ct);
        return NoContent();
    }

    [HttpPost("register/confirm")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    public Task<LoginResponse> RegisterConfirm([FromBody] RegisterWithPhoneVerificationRequest request, CancellationToken ct)
        => _auth.RegisterWithPhoneVerificationAsync(request, ct);

    // Hasta giriş: TC + şifre. İki adımlı doğrulama açıksa 202 ile kod beklenir.
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> Login([FromBody] PatientLoginRequest request, CancellationToken ct)
    {
        var mapped = new LoginRequest(
            Email: null,
            TcKimlikNo: request.TcKimlikNo,
            Password: request.Password,
            RecaptchaToken: request.RecaptchaToken
        );
        try
        {
            return Ok(await _auth.LoginAsync(mapped, ct));
        }
        catch (TwoFactorRequiredException challenge)
        {
            return Accepted(new
            {
                twoFactorRequired = true,
                challengeId = challenge.ChallengeId,
                maskedPhone = challenge.MaskedPhone,
                // No SMS goes out in local development, so show the code there.
                devCode = _env.IsDevelopment() ? challenge.Code : null,
            });
        }
    }

    [HttpPost("login/verify-code")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    public Task<LoginResponse> VerifyCode([FromBody] TwoFactorLoginRequest request, CancellationToken ct)
        => _auth.CompleteTwoFactorLoginAsync(request, ct);

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ForgotPassword([FromBody] PatientForgotPasswordRequest request, CancellationToken ct)
    {
        await _auth.ForgotPatientPasswordAsync(request, ct);
        return NoContent();
    }
}

using WebAppointmentApi.Application.Appointments.Abstractions;
using WebAppointmentApi.Application.Appointments.Dtos;
using WebAppointmentApi.Application.Appointments.State;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Common.Exceptions;
using WebAppointmentApi.Application.Patients.Services;
using WebAppointmentApi.Domain.Entities;
using WebAppointmentApi.Domain.Enums;

namespace WebAppointmentApi.Application.Appointments.Services;

public sealed class DoctorAppointmentService : IDoctorAppointmentService
{
    private readonly IAppointmentRepository _appointments;
    private readonly IDoctorRepository _doctors;
    private readonly IPatientRepository _patients;
    private readonly IDateTimeProvider _clock;
    private readonly IAppointmentStateMachine _stateMachine;

    public DoctorAppointmentService(
        IAppointmentRepository appointments,
        IDoctorRepository doctors,
        IPatientRepository patients,
        IDateTimeProvider clock,
        IAppointmentStateMachine stateMachine)
    {
        _appointments = appointments;
        _doctors = doctors;
        _patients = patients;
        _clock = clock;
        _stateMachine = stateMachine;
    }

    public async Task<IReadOnlyList<DoctorAppointmentDto>> GetMyAsync(Guid doctorUserId, CancellationToken ct)
    {
        var doctor = await _doctors.FindByUserIdAsync(doctorUserId, ct);
        if (doctor is null)
        {
            throw new ForbiddenException("Doctor profile not found for current user.");
        }

        var list = await _appointments.ListByDoctorIdAsync(doctor.Id, ct);

        var names = new Dictionary<Guid, string>();
        foreach (var userId in list.Select(x => x.UserId).Distinct())
        {
            var patient = await _patients.FindByUserIdAsync(userId, ct);
            if (patient is not null) names[userId] = $"{patient.FirstName} {patient.LastName}".Trim();
        }

        return list.Select(x => new DoctorAppointmentDto(
                Id: x.Id,
                PatientUserId: x.UserId,
                PatientEmail: x.User?.Email ?? string.Empty,
                DoctorId: x.DoctorId,
                StartAtUtc: x.StartAt.ToUniversalTime(),
                EndAtUtc: x.EndAt.ToUniversalTime(),
                Status: x.Status.ToString(),
                PatientName: x.Dependent?.FullName
                    ?? names.GetValueOrDefault(x.UserId)
                    ?? x.User?.Email
                    ?? string.Empty,
                ForDependent: x.DependentId is not null))
            .ToList();
    }

    public async Task<DoctorPatientInfoDto> GetPatientInfoAsync(Guid doctorUserId, Guid appointmentId, CancellationToken ct)
    {
        var doctor = await _doctors.FindByUserIdAsync(doctorUserId, ct)
            ?? throw new ForbiddenException("Doctor profile not found for current user.");

        // Looking it up among the doctor's own appointments also enforces ownership.
        var appt = (await _appointments.ListByDoctorIdAsync(doctor.Id, ct)).FirstOrDefault(x => x.Id == appointmentId)
            ?? throw new NotFoundException("Randevu bulunamadı.");

        var patient = await _patients.FindByUserIdAsync(appt.UserId, ct)
            ?? throw new NotFoundException("Hasta bulunamadı.");
        var holder = $"{patient.FirstName} {patient.LastName}".Trim();

        // The health profile belongs to the account holder, so only show it for their own visits.
        var own = appt.Dependent is null;
        return new DoctorPatientInfoDto(
            PatientName: appt.Dependent?.FullName ?? holder,
            ForDependent: !own,
            DependentRelation: appt.Dependent?.Relation.ToString(),
            AccountHolderName: holder,
            Phone: patient.Phone,
            // Patients added by an admin can have no birth date (DateOnly default).
            BirthDate: own ? (patient.BirthDate == default ? null : patient.BirthDate) : appt.Dependent!.BirthDate,
            BloodType: own ? patient.BloodType : null,
            Allergies: own ? patient.Allergies : null,
            ChronicDiseases: own ? patient.ChronicDiseases : null,
            Medications: own ? patient.Medications : null,
            EmergencyContactName: own ? patient.EmergencyContactName : null,
            EmergencyContactPhone: own ? patient.EmergencyContactPhone : null);
    }

    public async Task ApproveAsync(Guid doctorUserId, Guid appointmentId, CancellationToken ct)
    {
        var doctor = await _doctors.FindByUserIdAsync(doctorUserId, ct);
        if (doctor is null)
        {
            throw new ForbiddenException("Doctor profile not found for current user.");
        }

        var appt = await _appointments.FindByIdAsync(appointmentId, ct);
        if (appt is null)
        {
            throw new NotFoundException("Appointment not found.");
        }

        if (appt.DoctorId != doctor.Id)
        {
            throw new ForbiddenException("Cannot manage another doctor's appointment.");
        }

        _stateMachine.Transition(appt, AppointmentStatus.Approved, _clock.UtcNow);

        await _appointments.AddLogAsync(new AppointmentLog
        {
            AppointmentId = appt.Id,
            Action = "Approved",
            CreatedAtUtc = _clock.UtcNow,
        }, ct);

        await _appointments.AddNotificationAsync(new Notification
        {
            AppointmentId = appt.Id,
            UserId = appt.UserId,
            Message = "Randevunuz onaylandı.",
            CreatedAtUtc = _clock.UtcNow,
            IsSent = false,
        }, ct);

        await _appointments.SaveChangesAsync(ct);
    }

    public async Task CompleteAsync(Guid doctorUserId, Guid appointmentId, CancellationToken ct)
    {
        var doctor = await _doctors.FindByUserIdAsync(doctorUserId, ct);
        if (doctor is null)
        {
            throw new ForbiddenException("Doctor profile not found for current user.");
        }

        var appt = await _appointments.FindByIdAsync(appointmentId, ct);
        if (appt is null)
        {
            throw new NotFoundException("Appointment not found.");
        }

        if (appt.DoctorId != doctor.Id)
        {
            throw new ForbiddenException("Cannot manage another doctor's appointment.");
        }

        _stateMachine.Transition(appt, AppointmentStatus.Completed, _clock.UtcNow);

        await _appointments.AddLogAsync(new AppointmentLog
        {
            AppointmentId = appt.Id,
            Action = "Completed",
            CreatedAtUtc = _clock.UtcNow,
        }, ct);

        await _appointments.AddNotificationAsync(new Notification
        {
            AppointmentId = appt.Id,
            UserId = appt.UserId,
            Message = "Randevunuz tamamlandı.",
            CreatedAtUtc = _clock.UtcNow,
            IsSent = false,
        }, ct);

        await _appointments.SaveChangesAsync(ct);

        await AdjustNoShowScoreAsync(appt.UserId, NoShowScoring.AttendedOrConfirmedBonus, ct);
    }

    public async Task MarkNoShowAsync(Guid doctorUserId, Guid appointmentId, CancellationToken ct)
    {
        var doctor = await _doctors.FindByUserIdAsync(doctorUserId, ct);
        if (doctor is null)
        {
            throw new ForbiddenException("Doctor profile not found for current user.");
        }

        var appt = await _appointments.FindByIdAsync(appointmentId, ct);
        if (appt is null)
        {
            throw new NotFoundException("Appointment not found.");
        }

        if (appt.DoctorId != doctor.Id)
        {
            throw new ForbiddenException("Cannot manage another doctor's appointment.");
        }

        _stateMachine.Transition(appt, AppointmentStatus.NoShow, _clock.UtcNow);

        await _appointments.AddLogAsync(new AppointmentLog
        {
            AppointmentId = appt.Id,
            Action = "NoShow",
            CreatedAtUtc = _clock.UtcNow,
        }, ct);

        await _appointments.SaveChangesAsync(ct);

        await AdjustNoShowScoreAsync(appt.UserId, NoShowScoring.NoShowPenalty, ct);
    }

    private async Task AdjustNoShowScoreAsync(Guid patientUserId, int delta, CancellationToken ct)
    {
        var patient = await _patients.FindByUserIdAsync(patientUserId, ct);
        if (patient is null)
        {
            return;
        }

        patient.NoShowScore = NoShowScoring.Apply(patient.NoShowScore, delta);
        await _patients.SaveChangesAsync(ct);
    }
}

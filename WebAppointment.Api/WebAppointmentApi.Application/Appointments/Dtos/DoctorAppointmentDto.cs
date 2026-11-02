namespace WebAppointmentApi.Application.Appointments.Dtos;

public sealed record DoctorAppointmentDto(
    Guid Id,
    Guid PatientUserId,
    string PatientEmail,
    int DoctorId,
    DateTimeOffset StartAtUtc,
    DateTimeOffset EndAtUtc,
    string Status,
    // Who is being examined: the dependent's name when booked for one, else the patient's.
    string PatientName = "",
    bool ForDependent = false
);

/// <summary>What a doctor sees about the patient of one of their appointments.</summary>
public sealed record DoctorPatientInfoDto(
    string PatientName,
    bool ForDependent,
    string? DependentRelation,
    string AccountHolderName,
    string Phone,
    DateOnly? BirthDate,
    string? BloodType,
    string? Allergies,
    string? ChronicDiseases,
    string? Medications,
    string? EmergencyContactName,
    string? EmergencyContactPhone
);

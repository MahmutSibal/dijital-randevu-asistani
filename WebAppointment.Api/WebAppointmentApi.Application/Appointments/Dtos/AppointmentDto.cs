namespace WebAppointmentApi.Application.Appointments.Dtos;

public sealed record AppointmentDto(
    Guid Id,
    Guid UserId,
    int DoctorId,
    string DoctorName,
    string DepartmentName,
    DateTimeOffset AppointmentDateUtc,
    string Status,
    int? DependentId,
    string? DependentFullName,
    // Filled for the patient's own list, for "Yol tarifi" and the calendar entry.
    string? HospitalName = null,
    string? HospitalAddress = null,
    double? HospitalLatitude = null,
    double? HospitalLongitude = null
);

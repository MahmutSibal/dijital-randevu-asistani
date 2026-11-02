namespace WebAppointmentApi.Application.Assistant.Abstractions;

/// <summary>Describes what is currently in the system, so the assistant only talks about real records.</summary>
public interface IAssistantKnowledge
{
    /// <summary>Hospitals, their departments and bookable doctors, as text for the model.</summary>
    Task<string> DescribeCatalogAsync(CancellationToken ct);
}

using WebAppointmentApi.Application.Support.Dtos;

namespace WebAppointmentApi.Application.Support.Abstractions;

/// <summary>
/// Support requests are kept in Google Sheets by an n8n workflow; this is the API's way in.
/// Throws <see cref="SupportUnavailableException"/> when the automation can't be reached.
/// </summary>
public interface ISupportTicketGateway
{
    Task<SupportTicketDto> CreateAsync(CreateSupportTicketRequest request, string? userId, CancellationToken ct);

    /// <summary>Null when no ticket has this number.</summary>
    Task<SupportTicketDto?> FindAsync(string talepNo, CancellationToken ct);

    /// <summary>Every ticket, with the user id it was created by (empty for guests).</summary>
    Task<IReadOnlyList<(SupportTicketDto Ticket, string UserId)>> ListAsync(CancellationToken ct);

    /// <summary>Null when no ticket has this number.</summary>
    Task<SupportTicketDto?> UpdateStatusAsync(string talepNo, UpdateSupportTicketStatusRequest request, CancellationToken ct);
}

public sealed class SupportUnavailableException : Exception
{
    public SupportUnavailableException(string message, Exception? inner = null) : base(message, inner) { }
}

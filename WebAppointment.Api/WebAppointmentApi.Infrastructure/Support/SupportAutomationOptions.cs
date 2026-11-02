namespace WebAppointmentApi.Infrastructure.Support;

/// <summary>The n8n "Hastane Destek Talepleri" workflow (section "SupportAutomation").</summary>
public sealed class SupportAutomationOptions
{
    /// <summary>n8n webhook base, e.g. https://example.app.n8n.cloud/webhook/</summary>
    public string BaseUrl { get; set; } = string.Empty;

    /// <summary>Header the workflow's Header Auth credential checks.</summary>
    public string ApiKeyHeader { get; set; } = "X-Destek-Anahtari";

    /// <summary>Shared secret; set via user secrets, never committed.</summary>
    public string ApiKey { get; set; } = string.Empty;
}

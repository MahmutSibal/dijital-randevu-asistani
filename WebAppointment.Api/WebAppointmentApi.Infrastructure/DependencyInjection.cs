using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using WebAppointmentApi.Application.Common.Abstractions;
using WebAppointmentApi.Application.Auth.Abstractions;
using WebAppointmentApi.Application.Waitlist.Abstractions;
using WebAppointmentApi.Application.Assistant.Abstractions;
using WebAppointmentApi.Infrastructure.Assistant;
using WebAppointmentApi.Application.Support.Abstractions;
using WebAppointmentApi.Infrastructure.Support;
using WebAppointmentApi.Application.Account;
using WebAppointmentApi.Infrastructure.Account;
using WebAppointmentApi.Application.Documents;
using WebAppointmentApi.Infrastructure.Documents;
using WebAppointmentApi.Application.Reviews;
using WebAppointmentApi.Infrastructure.Reviews;
using WebAppointmentApi.Infrastructure.BackgroundJobs;
using WebAppointmentApi.Infrastructure.Data;
using WebAppointmentApi.Infrastructure.Messaging;
using WebAppointmentApi.Infrastructure.Repositories;
using WebAppointmentApi.Infrastructure.Security;

namespace WebAppointmentApi.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
        {
            var cs = configuration.GetConnectionString("DefaultConnection");
            options.UseSqlServer(cs);
        });

        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IPatientRepository, PatientRepository>();
        services.AddScoped<IDepartmentRepository, DepartmentRepository>();
        services.AddScoped<IDoctorRepository, DoctorRepository>();
        services.AddScoped<IDoctorAvailabilityRepository, DoctorAvailabilityRepository>();
        services.AddScoped<IDoctorTimeOffRepository, DoctorTimeOffRepository>();
        services.AddScoped<IHolidayRepository, HolidayRepository>();
        services.AddScoped<IHospitalRepository, HospitalRepository>();
            services.AddScoped<IDependentRepository, DependentRepository>();
            services.AddScoped<IAppointmentRepository, AppointmentRepository>();
        services.AddScoped<IAuditLogRepository, AuditLogRepository>();
        services.AddScoped<ILoginLockoutRepository, LoginLockoutRepository>();
        services.AddScoped<IWaitlistRepository, WaitlistRepository>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IReportRepository, ReportRepository>();
        services.AddScoped<INotificationRepository, NotificationRepository>();
        services.AddScoped<IPhoneVerificationRepository, PhoneVerificationRepository>();
        services.AddScoped<IEmailVerificationRepository, EmailVerificationRepository>();
        services.AddScoped<ISmaCaseRepository, SmaCaseRepository>();
        services.AddScoped<ISiteSettingsRepository, SiteSettingsRepository>();

        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
        services.AddSingleton<ITokenService, JwtTokenService>();
        services.AddSingleton<IBackgroundJobQueue, BackgroundJobQueue>();
        services.AddHostedService<QueuedBackgroundService>();
        services.AddHostedService<AppointmentReminderService>();
        services.AddHostedService<WhatsAppBridgeProcessService>();

        services.AddHttpClient<INviKimlikService, NviKimlikService>();

        services.Configure<WhatsAppBridgeOptions>(configuration.GetSection("WhatsAppBridge"));
        services.AddHttpClient<IPhoneVerificationSender, WhatsAppPhoneVerificationSender>((sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<WhatsAppBridgeOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl);
        });

        services.AddHttpClient<IWhatsAppMessageSender, WhatsAppMessageSender>((sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<WhatsAppBridgeOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl);
        });

        services.AddHttpClient<IWhatsAppBridgeStatusClient, WhatsAppBridgeStatusClient>((sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<WhatsAppBridgeOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            client.Timeout = TimeSpan.FromSeconds(5);
        });

        services.Configure<BrevoOptions>(configuration.GetSection("Brevo"));
        var brevoKey = configuration["Brevo:ApiKey"];
        if (string.IsNullOrWhiteSpace(brevoKey) || brevoKey.StartsWith("__", StringComparison.Ordinal))
        {
            // No real key (e.g. the "__SET_VIA_USER_SECRETS__" placeholder): log e-mails instead.
            services.AddSingleton<IEmailSender, LoggingEmailSender>();
        }
        else
        {
            services.AddHttpClient<IEmailSender, BrevoEmailSender>((sp, client) =>
            {
                client.BaseAddress = new Uri("https://api.brevo.com/v3/");
                var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<BrevoOptions>>().Value;
                client.DefaultRequestHeaders.Add("api-key", options.ApiKey);
            });
        }

        services.Configure<OllamaOptions>(configuration.GetSection("Ollama"));
        services.AddScoped<IAssistantKnowledge, AssistantKnowledge>();
        services.AddScoped<IAssistantAnswerCache, AssistantAnswerCache>();
        services.AddScoped<IAccountSecurityStore, AccountSecurityStore>();
        services.AddScoped<IAppointmentDocumentService, AppointmentDocumentService>();
        services.AddScoped<ITwoFactorService, TwoFactorService>();
        services.AddScoped<ISecurityOverviewService, SecurityOverviewService>();
        services.AddScoped<IDoctorReviewService, DoctorReviewService>();
        services.AddHttpClient<IAssistantChatClient, OllamaChatClient>((sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<OllamaOptions>>().Value;
            client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            // Thinking models can take minutes on a long answer; the caller's token ends the request.
            client.Timeout = Timeout.InfiniteTimeSpan;
        });

        // Support requests: n8n workflow "Hastane Destek Talepleri" → Google Sheets.
        services.Configure<SupportAutomationOptions>(configuration.GetSection("SupportAutomation"));
        services.AddHttpClient<ISupportTicketGateway, N8nSupportTicketGateway>((sp, client) =>
        {
            var options = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<SupportAutomationOptions>>().Value;
            if (!string.IsNullOrWhiteSpace(options.BaseUrl))
                client.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            if (!string.IsNullOrWhiteSpace(options.ApiKey))
                client.DefaultRequestHeaders.Add(options.ApiKeyHeader, options.ApiKey);
            client.Timeout = TimeSpan.FromSeconds(30);
        });

        services.Configure<GoogleAuthOptions>(configuration.GetSection("GoogleAuth"));
        services.AddScoped<IGoogleIdTokenValidator, GoogleIdTokenValidator>();

        services.Configure<RecaptchaOptions>(configuration.GetSection("Recaptcha"));
        services.AddHttpClient<IRecaptchaValidator, RecaptchaValidator>(client =>
        {
            client.BaseAddress = new Uri("https://www.google.com/");
        });

        return services;
    }
}

using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace WebAppointmentApi.Application.Assistant.Abstractions;

/// <summary>
/// Saved assistant answers. An answer is reused only for the same question asked as the
/// first message of a conversation, with the same model, instructions and catalog
/// (<c>contextHash</c>), so it goes stale automatically when any of those change.
/// </summary>
public interface IAssistantAnswerCache
{
    /// <summary>The saved answer for <paramref name="question"/>, counting the hit; null if none.</summary>
    Task<string?> FindAsync(string question, string contextHash, CancellationToken ct);

    Task SaveAsync(string question, string contextHash, string answer, string model, CancellationToken ct);
}

public static partial class AssistantQuestion
{
    public const int MaxKeyLength = 450;

    private static readonly CultureInfo Turkish = CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>
    /// Matching key: Turkish lower-case, whitespace collapsed, trailing punctuation dropped,
    /// so "Randevu nasıl alırım?" and "randevu nasıl  alırım" match. Null if too long to cache.
    /// </summary>
    public static string? Key(string question)
    {
        var key = Spaces().Replace(question.Trim().ToLower(Turkish), " ").TrimEnd('?', '!', '.', ' ');
        return key.Length is 0 or > MaxKeyLength ? null : key;
    }

    public static string Hash(string text) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)));

    [GeneratedRegex(@"\s+")]
    private static partial Regex Spaces();
}

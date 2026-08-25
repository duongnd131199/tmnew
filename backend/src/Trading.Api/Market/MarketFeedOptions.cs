using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace Trading.Api.Market;

public sealed class MarketFeedOptions
{
    public const string SectionName = "MarketFeed";

    public string IngestKey { get; init; } = string.Empty;

    public int StaleAfterSeconds { get; init; } = 5;
}

public sealed class MarketFeedKeyValidator
{
    private readonly byte[] _configuredKey;

    public MarketFeedKeyValidator(IOptions<MarketFeedOptions> options)
    {
        _configuredKey = Encoding.UTF8.GetBytes(options.Value.IngestKey);
    }

    public bool IsAuthorized(string? suppliedKey)
    {
        if (_configuredKey.Length < 16 || string.IsNullOrEmpty(suppliedKey))
        {
            return false;
        }

        var supplied = Encoding.UTF8.GetBytes(suppliedKey);
        return supplied.Length == _configuredKey.Length &&
            CryptographicOperations.FixedTimeEquals(supplied, _configuredKey);
    }
}

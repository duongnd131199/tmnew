namespace Trading.Domain.Market;

public sealed record MarketTick(
    string Symbol,
    decimal Bid,
    decimal Ask,
    DateTimeOffset Timestamp,
    string Source);

public sealed record MarketCandle(
    string Symbol,
    string Timeframe,
    DateTimeOffset Time,
    decimal Open,
    decimal High,
    decimal Low,
    decimal Close,
    long Volume);

public static class MarketSymbols
{
    public static string Normalize(string symbol)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(symbol);
        var normalized = symbol.Trim().ToUpperInvariant();
        if (normalized.Length > 32 ||
            normalized.Any(character =>
                !char.IsAsciiLetterOrDigit(character) &&
                character is not '+' and not '-' and not '.' and not '_'))
        {
            throw new ArgumentException("Invalid market symbol.", nameof(symbol));
        }

        return normalized;
    }
}

public static class MarketTimeframes
{
    public static readonly IReadOnlyList<string> Supported =
    [
        "M1",
        "M5",
        "M15",
        "M30",
        "H1",
        "H4",
        "D1",
        "W1",
        "MN"
    ];

    public static string Normalize(string timeframe)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(timeframe);
        var normalized = timeframe.Trim().ToUpperInvariant();
        if (!Supported.Contains(normalized))
        {
            throw new ArgumentException(
                $"Unsupported market timeframe '{timeframe}'.",
                nameof(timeframe));
        }

        return normalized;
    }

    public static DateTimeOffset BucketStart(
        DateTimeOffset timestamp,
        string timeframe)
    {
        var normalized = Normalize(timeframe);
        var utc = timestamp.ToUniversalTime();
        var value = utc.UtcDateTime;
        return normalized switch
        {
            "M1" => Utc(value.Year, value.Month, value.Day, value.Hour, value.Minute),
            "M5" => Utc(value.Year, value.Month, value.Day, value.Hour, value.Minute / 5 * 5),
            "M15" => Utc(value.Year, value.Month, value.Day, value.Hour, value.Minute / 15 * 15),
            "M30" => Utc(value.Year, value.Month, value.Day, value.Hour, value.Minute / 30 * 30),
            "H1" => Utc(value.Year, value.Month, value.Day, value.Hour),
            "H4" => Utc(value.Year, value.Month, value.Day, value.Hour / 4 * 4),
            "D1" => Utc(value.Year, value.Month, value.Day),
            "W1" => Utc(value.Year, value.Month, value.Day)
                .AddDays(-(value.DayOfWeek is DayOfWeek.Sunday
                    ? 6
                    : (int)value.DayOfWeek - (int)DayOfWeek.Monday)),
            "MN" => Utc(value.Year, value.Month, 1),
            _ => throw new ArgumentOutOfRangeException(nameof(timeframe))
        };
    }

    private static DateTimeOffset Utc(
        int year,
        int month,
        int day,
        int hour = 0,
        int minute = 0) =>
        new(year, month, day, hour, minute, 0, TimeSpan.Zero);
}

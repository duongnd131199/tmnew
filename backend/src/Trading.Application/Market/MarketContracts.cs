using Trading.Domain.Market;

namespace Trading.Application.Market;

public interface IMarketDataStore
{
    bool UpsertTick(MarketTick tick);

    IReadOnlyList<MarketCandle> ApplyTick(MarketTick tick);

    void SeedCandles(
        string symbol,
        string timeframe,
        IReadOnlyCollection<MarketCandle> candles);

    MarketTick? GetQuote(string symbol);

    IReadOnlyList<MarketTick> GetQuotes(IReadOnlyCollection<string>? symbols = null);

    IReadOnlyList<MarketCandle> GetCandles(
        string symbol,
        string timeframe,
        int limit);
}

public interface IMarketRealtimePublisher
{
    Task PublishQuoteAsync(
        MarketTick tick,
        CancellationToken cancellationToken);

    Task PublishCandleAsync(
        MarketCandle candle,
        CancellationToken cancellationToken);
}

public sealed class MarketFeedService
{
    private readonly IMarketDataStore _store;
    private readonly IMarketRealtimePublisher _publisher;

    public MarketFeedService(
        IMarketDataStore store,
        IMarketRealtimePublisher publisher)
    {
        _store = store;
        _publisher = publisher;
    }

    public async Task<bool> IngestTickAsync(
        MarketTick tick,
        CancellationToken cancellationToken = default)
    {
        var normalized = NormalizeTick(tick);
        if (!_store.UpsertTick(normalized))
        {
            return false;
        }

        var updatedCandles = _store.ApplyTick(normalized);
        var publications = new List<Task>(updatedCandles.Count + 1)
        {
            _publisher.PublishQuoteAsync(normalized, cancellationToken)
        };
        publications.AddRange(updatedCandles.Select(candle =>
            _publisher.PublishCandleAsync(candle, cancellationToken)));
        await Task.WhenAll(publications);

        return true;
    }

    public void SeedCandles(
        string symbol,
        string timeframe,
        IReadOnlyCollection<MarketCandle> candles)
    {
        var normalizedSymbol = MarketSymbols.Normalize(symbol);
        var normalizedTimeframe = MarketTimeframes.Normalize(timeframe);
        var normalized = candles
            .Select(candle => NormalizeCandle(
                candle with
                {
                    Symbol = normalizedSymbol,
                    Timeframe = normalizedTimeframe
                }))
            .OrderBy(candle => candle.Time)
            .ToArray();
        _store.SeedCandles(normalizedSymbol, normalizedTimeframe, normalized);
    }

    public static MarketTick NormalizeTick(MarketTick tick)
    {
        if (tick.Bid <= 0 || tick.Ask <= 0 || tick.Ask < tick.Bid)
        {
            throw new ArgumentException("Bid and ask must form a valid positive quote.");
        }

        if (tick.Timestamp == default)
        {
            throw new ArgumentException("Tick timestamp is required.");
        }

        return tick with
        {
            Symbol = MarketSymbols.Normalize(tick.Symbol),
            Timestamp = tick.Timestamp.ToUniversalTime(),
            Source = string.IsNullOrWhiteSpace(tick.Source)
                ? "MT5"
                : tick.Source.Trim()
        };
    }

    private static MarketCandle NormalizeCandle(MarketCandle candle)
    {
        if (candle.Open <= 0 ||
            candle.High <= 0 ||
            candle.Low <= 0 ||
            candle.Close <= 0 ||
            candle.High < candle.Low ||
            candle.High < candle.Open ||
            candle.High < candle.Close ||
            candle.Low > candle.Open ||
            candle.Low > candle.Close ||
            candle.Volume < 0)
        {
            throw new ArgumentException("Invalid OHLC candle.");
        }

        return candle with
        {
            Symbol = MarketSymbols.Normalize(candle.Symbol),
            Timeframe = MarketTimeframes.Normalize(candle.Timeframe),
            Time = MarketTimeframes.BucketStart(
                candle.Time,
                candle.Timeframe)
        };
    }
}

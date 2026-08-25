using System.Collections.Concurrent;
using Trading.Application.Market;
using Trading.Domain.Market;

namespace Trading.Infrastructure.Market;

public sealed class InMemoryMarketDataStore : IMarketDataStore
{
    private const int MaximumCandlesPerSeries = 5_000;
    private readonly ConcurrentDictionary<string, MarketTick> _quotes =
        new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, CandleBuffer> _series =
        new(StringComparer.Ordinal);

    public bool UpsertTick(MarketTick tick)
    {
        while (true)
        {
            if (!_quotes.TryGetValue(tick.Symbol, out var current))
            {
                if (_quotes.TryAdd(tick.Symbol, tick))
                {
                    return true;
                }

                continue;
            }

            if (tick.Timestamp < current.Timestamp)
            {
                return false;
            }

            if (tick.Timestamp == current.Timestamp &&
                tick.Bid == current.Bid &&
                tick.Ask == current.Ask &&
                string.Equals(tick.Source, current.Source, StringComparison.Ordinal))
            {
                return false;
            }

            if (_quotes.TryUpdate(tick.Symbol, tick, current))
            {
                return true;
            }
        }
    }

    public IReadOnlyList<MarketCandle> ApplyTick(MarketTick tick)
    {
        var updated = new List<MarketCandle>(MarketTimeframes.Supported.Count);
        foreach (var timeframe in MarketTimeframes.Supported)
        {
            var buffer = GetBuffer(tick.Symbol, timeframe);
            var candle = buffer.ApplyTick(tick, timeframe);
            if (candle is not null)
            {
                updated.Add(candle);
            }
        }

        return updated;
    }

    public void SeedCandles(
        string symbol,
        string timeframe,
        IReadOnlyCollection<MarketCandle> candles) =>
        GetBuffer(symbol, timeframe).Seed(candles);

    public MarketTick? GetQuote(string symbol)
    {
        _quotes.TryGetValue(MarketSymbols.Normalize(symbol), out var quote);
        return quote;
    }

    public IReadOnlyList<MarketTick> GetQuotes(
        IReadOnlyCollection<string>? symbols = null)
    {
        if (symbols is null || symbols.Count == 0)
        {
            return _quotes.Values
                .OrderBy(quote => quote.Symbol, StringComparer.Ordinal)
                .ToArray();
        }

        return symbols
            .Select(MarketSymbols.Normalize)
            .Distinct(StringComparer.Ordinal)
            .Select(symbol => _quotes.TryGetValue(symbol, out var quote)
                ? quote
                : null)
            .Where(quote => quote is not null)
            .Cast<MarketTick>()
            .ToArray();
    }

    public IReadOnlyList<MarketCandle> GetCandles(
        string symbol,
        string timeframe,
        int limit) =>
        GetBuffer(
            MarketSymbols.Normalize(symbol),
            MarketTimeframes.Normalize(timeframe))
        .Get(Math.Clamp(limit, 1, 2_000));

    private CandleBuffer GetBuffer(string symbol, string timeframe) =>
        _series.GetOrAdd(
            $"{symbol}|{timeframe}",
            _ => new CandleBuffer(MaximumCandlesPerSeries));

    private sealed class CandleBuffer
    {
        private readonly int _capacity;
        private readonly object _gate = new();
        private readonly SortedDictionary<long, MarketCandle> _candles = [];

        public CandleBuffer(int capacity)
        {
            _capacity = capacity;
        }

        public void Seed(IReadOnlyCollection<MarketCandle> candles)
        {
            lock (_gate)
            {
                foreach (var candle in candles)
                {
                    _candles[candle.Time.ToUnixTimeSeconds()] = candle;
                }

                Trim();
            }
        }

        public MarketCandle? ApplyTick(MarketTick tick, string timeframe)
        {
            var bucket = MarketTimeframes.BucketStart(tick.Timestamp, timeframe);
            var key = bucket.ToUnixTimeSeconds();
            lock (_gate)
            {
                if (_candles.TryGetValue(key, out var current))
                {
                    var updated = current with
                    {
                        High = Math.Max(current.High, tick.Bid),
                        Low = Math.Min(current.Low, tick.Bid),
                        Close = tick.Bid,
                        Volume = current.Volume + 1
                    };
                    _candles[key] = updated;
                    return updated;
                }

                if (_candles.Count > 0 && key < _candles.Keys.Last())
                {
                    return null;
                }

                var created = new MarketCandle(
                    tick.Symbol,
                    timeframe,
                    bucket,
                    tick.Bid,
                    tick.Bid,
                    tick.Bid,
                    tick.Bid,
                    1);
                _candles[key] = created;
                Trim();
                return created;
            }
        }

        public IReadOnlyList<MarketCandle> Get(int limit)
        {
            lock (_gate)
            {
                return _candles.Values
                    .TakeLast(limit)
                    .ToArray();
            }
        }

        private void Trim()
        {
            while (_candles.Count > _capacity)
            {
                _candles.Remove(_candles.Keys.First());
            }
        }
    }
}

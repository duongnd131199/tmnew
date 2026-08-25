using Trading.Application.Market;
using Trading.Domain.Market;
using Trading.Infrastructure.Market;

namespace Trading.UnitTests;

public sealed class MarketFeedServiceTests
{
    [Fact]
    public async Task TickUpdatesQuoteAndEverySupportedLiveCandle()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new RecordingPublisher();
        var service = new MarketFeedService(store, publisher);
        var timestamp = new DateTimeOffset(
            2026,
            7,
            31,
            8,
            17,
            21,
            TimeSpan.Zero);

        var accepted = await service.IngestTickAsync(
            new MarketTick("xauusd+", 4104.12m, 4104.25m, timestamp, "Exness"));

        Assert.True(accepted);
        var quote = Assert.IsType<MarketTick>(store.GetQuote("XAUUSD+"));
        Assert.Equal(4104.12m, quote.Bid);
        Assert.Equal(4104.25m, quote.Ask);
        Assert.Single(publisher.Quotes);
        Assert.Equal(MarketTimeframes.Supported.Count, publisher.Candles.Count);
        Assert.All(
            MarketTimeframes.Supported,
            timeframe => Assert.Single(
                store.GetCandles("XAUUSD+", timeframe, 360)));
    }

    [Fact]
    public async Task SeededCandleKeepsOpenAndExpandsWithLiveTick()
    {
        var store = new InMemoryMarketDataStore();
        var service = new MarketFeedService(store, new RecordingPublisher());
        var bucket = new DateTimeOffset(
            2026,
            7,
            31,
            8,
            0,
            0,
            TimeSpan.Zero);
        service.SeedCandles(
            "XAUUSD+",
            "H4",
            [
                new MarketCandle(
                    "XAUUSD+",
                    "H4",
                    bucket,
                    4100m,
                    4105m,
                    4098m,
                    4102m,
                    120)
            ]);

        await service.IngestTickAsync(
            new MarketTick(
                "XAUUSD+",
                4107m,
                4107.13m,
                bucket.AddMinutes(17),
                "MT5"));

        var candle = Assert.Single(
            store.GetCandles("XAUUSD+", "H4", 360));
        Assert.Equal(4100m, candle.Open);
        Assert.Equal(4107m, candle.High);
        Assert.Equal(4098m, candle.Low);
        Assert.Equal(4107m, candle.Close);
        Assert.Equal(121, candle.Volume);
    }

    [Fact]
    public async Task OlderTickCannotMoveRealtimeStateBackwards()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new RecordingPublisher();
        var service = new MarketFeedService(store, publisher);
        var now = DateTimeOffset.UtcNow;

        await service.IngestTickAsync(
            new MarketTick("EURUSD", 1.16m, 1.1601m, now, "MT5"));
        var accepted = await service.IngestTickAsync(
            new MarketTick(
                "EURUSD",
                1.14m,
                1.1401m,
                now.AddMilliseconds(-1),
                "MT5"));

        Assert.False(accepted);
        Assert.Equal(1.16m, store.GetQuote("EURUSD")?.Bid);
        Assert.Single(publisher.Quotes);
    }

    [Fact]
    public async Task ExactDuplicateTickIsPublishedOnce()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new RecordingPublisher();
        var service = new MarketFeedService(store, publisher);
        var timestamp = new DateTimeOffset(
            2026,
            8,
            20,
            10,
            15,
            30,
            TimeSpan.Zero);
        var tick = new MarketTick(
            "XAUUSD+",
            4488.10m,
            4488.36m,
            timestamp,
            "Exness");

        Assert.True(await service.IngestTickAsync(tick));
        Assert.False(await service.IngestTickAsync(tick));

        var quote = Assert.IsType<MarketTick>(store.GetQuote("XAUUSD+"));
        Assert.Equal(4488.10m, quote.Bid);
        Assert.Equal(4488.36m, quote.Ask);
        Assert.Single(publisher.Quotes);
    }

    [Fact]
    public async Task DistinctSameMillisecondTicksRemainOrdered()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new RecordingPublisher();
        var service = new MarketFeedService(store, publisher);
        var timestamp = DateTimeOffset.UtcNow;

        Assert.True(await service.IngestTickAsync(
            new MarketTick("XAUUSD+", 4488.10m, 4488.36m, timestamp, "Exness")));
        Assert.True(await service.IngestTickAsync(
            new MarketTick("XAUUSD+", 4488.11m, 4488.37m, timestamp, "Exness")));

        Assert.Equal(
            [4488.10m, 4488.11m],
            publisher.Quotes.Select(quote => quote.Bid));
        Assert.Equal(4488.11m, store.GetQuote("XAUUSD+")?.Bid);
    }

    [Fact]
    public async Task TickStartsQuoteAndAllCandlePublicationsTogether()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new GatedPublisher(
            expectedStarts: MarketTimeframes.Supported.Count + 1);
        var service = new MarketFeedService(store, publisher);

        var ingestion = service.IngestTickAsync(
            new MarketTick(
                "XAUUSD+",
                4488.10m,
                4488.36m,
                DateTimeOffset.UtcNow,
                "Exness"));

        try
        {
            var completed = await Task.WhenAny(
                publisher.AllStarted,
                Task.Delay(TimeSpan.FromMilliseconds(250)));
            Assert.Same(publisher.AllStarted, completed);
            Assert.Equal(MarketTimeframes.Supported.Count + 1, publisher.Started);
        }
        finally
        {
            publisher.Release();
            await ingestion;
        }
    }

    private sealed class RecordingPublisher : IMarketRealtimePublisher
    {
        public List<MarketTick> Quotes { get; } = [];

        public List<MarketCandle> Candles { get; } = [];

        public Task PublishQuoteAsync(
            MarketTick tick,
            CancellationToken cancellationToken)
        {
            lock (Quotes)
            {
                Quotes.Add(tick);
            }

            return Task.CompletedTask;
        }

        public Task PublishCandleAsync(
            MarketCandle candle,
            CancellationToken cancellationToken)
        {
            lock (Candles)
            {
                Candles.Add(candle);
            }

            return Task.CompletedTask;
        }
    }

    private sealed class GatedPublisher : IMarketRealtimePublisher
    {
        private readonly int _expectedStarts;
        private readonly TaskCompletionSource _allStarted = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource _release = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private int _started;

        public GatedPublisher(int expectedStarts)
        {
            _expectedStarts = expectedStarts;
        }

        public int Started => Volatile.Read(ref _started);

        public Task AllStarted => _allStarted.Task;

        public Task PublishQuoteAsync(
            MarketTick tick,
            CancellationToken cancellationToken) => StartPublication();

        public Task PublishCandleAsync(
            MarketCandle candle,
            CancellationToken cancellationToken) => StartPublication();

        public void Release() => _release.TrySetResult();

        private Task StartPublication()
        {
            if (Interlocked.Increment(ref _started) == _expectedStarts)
            {
                _allStarted.TrySetResult();
            }

            return _release.Task;
        }
    }
}

using Trading.Api.Market;
using Trading.Application.Market;
using Trading.Domain.Market;
using Trading.Infrastructure.Market;

namespace Trading.IntegrationTests;

public sealed class MarketTickIngestionQueueTests
{
    [Fact]
    public async Task OrderedBurstPublishesEveryTickAndKeepsLatestQuote()
    {
        var store = new InMemoryMarketDataStore();
        var publisher = new RecordingPublisher();
        var service = new MarketFeedService(store, publisher);
        var queue = new MarketTickIngestionQueue(service, capacity: 64);
        await queue.StartAsync(CancellationToken.None);

        try
        {
            var start = DateTimeOffset.UtcNow;
            var ticks = Enumerable.Range(0, 50)
                .Select(index => new MarketTick(
                    "XAUUSD+",
                    4400m + index,
                    4400.20m + index,
                    start.AddMilliseconds(index),
                    "test"))
                .ToArray();

            await queue.EnqueueAsync(ticks, CancellationToken.None);
            await WaitUntilAsync(() => publisher.QuoteCount == 50);

            Assert.Equal(
                ticks.Select(tick => tick.Bid),
                publisher.Quotes.Select(tick => tick.Bid));
            Assert.Equal(ticks[^1].Bid, store.GetQuote("XAUUSD+")?.Bid);
        }
        finally
        {
            await queue.StopAsync(CancellationToken.None);
            queue.Dispose();
        }
    }

    [Fact]
    public async Task BoundedQueueBackpressuresProducerUntilCapacityIsReleased()
    {
        var publisher = new FirstQuoteGatedPublisher();
        var service = new MarketFeedService(
            new InMemoryMarketDataStore(),
            publisher);
        var queue = new MarketTickIngestionQueue(service, capacity: 1);
        await queue.StartAsync(CancellationToken.None);
        var start = DateTimeOffset.UtcNow;

        try
        {
            await queue.EnqueueAsync(
                [Tick(1, start)],
                CancellationToken.None);
            await publisher.FirstQuoteStarted;
            await queue.EnqueueAsync(
                [Tick(2, start.AddMilliseconds(1))],
                CancellationToken.None);

            var blockedWrite = queue.EnqueueAsync(
                [Tick(3, start.AddMilliseconds(2))],
                CancellationToken.None).AsTask();
            Assert.False(blockedWrite.IsCompleted);

            publisher.Release();
            await blockedWrite.WaitAsync(TimeSpan.FromSeconds(2));
        }
        finally
        {
            publisher.Release();
            await queue.StopAsync(CancellationToken.None);
            queue.Dispose();
        }
    }

    [Fact]
    public async Task StopDrainsQueuedTicksWithoutUnhandledFailure()
    {
        var publisher = new RecordingPublisher();
        var queue = new MarketTickIngestionQueue(
            new MarketFeedService(new InMemoryMarketDataStore(), publisher),
            capacity: 8);
        await queue.StartAsync(CancellationToken.None);
        var start = DateTimeOffset.UtcNow;
        await queue.EnqueueAsync(
            Enumerable.Range(0, 8)
                .Select(index => Tick(index, start.AddMilliseconds(index)))
                .ToArray(),
            CancellationToken.None);

        await queue.StopAsync(CancellationToken.None);
        queue.Dispose();

        Assert.Equal(8, publisher.QuoteCount);
    }

    [Fact]
    public async Task PublisherFailureDoesNotStopFollowingTicks()
    {
        var publisher = new FirstQuoteFailingPublisher();
        var queue = new MarketTickIngestionQueue(
            new MarketFeedService(new InMemoryMarketDataStore(), publisher),
            capacity: 4);
        await queue.StartAsync(CancellationToken.None);
        var start = DateTimeOffset.UtcNow;

        await queue.EnqueueAsync(
            [Tick(1, start), Tick(2, start.AddMilliseconds(1))],
            CancellationToken.None);
        await WaitUntilAsync(() => publisher.SuccessfulQuoteCount == 1);
        await queue.StopAsync(CancellationToken.None);
        queue.Dispose();

        Assert.Equal(2, publisher.QuoteAttempts);
    }

    private static MarketTick Tick(int index, DateTimeOffset timestamp) =>
        new(
            "XAUUSD+",
            4400m + index,
            4400.20m + index,
            timestamp,
            "test");

    private static async Task WaitUntilAsync(Func<bool> condition)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        while (!condition())
        {
            await Task.Delay(10, timeout.Token);
        }
    }

    private sealed class RecordingPublisher : IMarketRealtimePublisher
    {
        private readonly object _gate = new();
        private readonly List<MarketTick> _quotes = [];

        public int QuoteCount
        {
            get
            {
                lock (_gate)
                {
                    return _quotes.Count;
                }
            }
        }

        public IReadOnlyList<MarketTick> Quotes
        {
            get
            {
                lock (_gate)
                {
                    return _quotes.ToArray();
                }
            }
        }

        public Task PublishQuoteAsync(
            MarketTick tick,
            CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                _quotes.Add(tick);
            }

            return Task.CompletedTask;
        }

        public Task PublishCandleAsync(
            MarketCandle candle,
            CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class FirstQuoteGatedPublisher : IMarketRealtimePublisher
    {
        private readonly TaskCompletionSource _firstStarted = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource _release = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private int _quoteCount;

        public Task FirstQuoteStarted => _firstStarted.Task;

        public Task PublishQuoteAsync(
            MarketTick tick,
            CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref _quoteCount) == 1)
            {
                _firstStarted.TrySetResult();
                return _release.Task;
            }

            return Task.CompletedTask;
        }

        public Task PublishCandleAsync(
            MarketCandle candle,
            CancellationToken cancellationToken) => Task.CompletedTask;

        public void Release() => _release.TrySetResult();
    }

    private sealed class FirstQuoteFailingPublisher : IMarketRealtimePublisher
    {
        private int _quoteAttempts;
        private int _successfulQuoteCount;

        public int QuoteAttempts => Volatile.Read(ref _quoteAttempts);

        public int SuccessfulQuoteCount => Volatile.Read(
            ref _successfulQuoteCount
        );

        public Task PublishQuoteAsync(
            MarketTick tick,
            CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref _quoteAttempts) == 1)
            {
                throw new InvalidOperationException("simulated SignalR failure");
            }

            Interlocked.Increment(ref _successfulQuoteCount);
            return Task.CompletedTask;
        }

        public Task PublishCandleAsync(
            MarketCandle candle,
            CancellationToken cancellationToken) => Task.CompletedTask;
    }
}

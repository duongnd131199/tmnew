using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Trading.Api.Controllers;
using Trading.Api.Market;
using Trading.Application.Market;
using Trading.Domain.Market;
using Trading.Infrastructure.Market;

namespace Trading.IntegrationTests;

public sealed class MarketFeedBatchContractTests
{
    private const string FeedKey = "local-test-feed-key-123456";

    [Fact]
    public async Task LiteralCamelCaseBatchIsAcceptedInOrder()
    {
        const string json = """
            {
              "ticks": [
                {"symbol":"XAUUSD+","bid":4488.10,"ask":4488.36,"timeMsc":1787210000000,"source":"Exness"},
                {"symbol":"XAUUSD+","bid":4488.11,"ask":4488.37,"timeMsc":1787210000050,"source":"Exness"}
              ]
            }
            """;
        var request = JsonSerializer.Deserialize<TickBatchIngestRequest>(
            json,
            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });
        Assert.NotNull(request);

        var fixture = await ControllerFixture.StartAsync(authorized: true);
        await using (fixture)
        {
            var result = await fixture.Controller.IngestTickBatch(
                request,
                CancellationToken.None);

            Assert.IsType<AcceptedResult>(result);
            await WaitUntilAsync(() => fixture.Publisher.QuoteCount == 2);
            Assert.Equal(
                [4488.10m, 4488.11m],
                fixture.Publisher.Quotes.Select(tick => tick.Bid));
            Assert.Equal(4488.11m, fixture.Store.GetQuote("XAUUSD+")?.Bid);
        }
    }

    [Fact]
    public async Task BatchRequiresFeedKeyAndEnforcesSizeBounds()
    {
        var unauthorized = await ControllerFixture.StartAsync(authorized: false);
        await using (unauthorized)
        {
            var result = await unauthorized.Controller.IngestTickBatch(
                new TickBatchIngestRequest([ValidRequest(0)]),
                CancellationToken.None);
            Assert.IsType<UnauthorizedResult>(result);
        }

        var fixture = await ControllerFixture.StartAsync(authorized: true);
        await using (fixture)
        {
            var empty = await fixture.Controller.IngestTickBatch(
                new TickBatchIngestRequest([]),
                CancellationToken.None);
            var oversized = await fixture.Controller.IngestTickBatch(
                new TickBatchIngestRequest(
                    Enumerable.Range(0, 257).Select(ValidRequest).ToArray()),
                CancellationToken.None);

            Assert.Equal(StatusCodes.Status400BadRequest, StatusCode(empty));
            Assert.Equal(StatusCodes.Status400BadRequest, StatusCode(oversized));
            Assert.Equal(0, fixture.Publisher.QuoteCount);
        }
    }

    [Fact]
    public async Task InvalidItemRejectsWholeBatchBeforeEnqueue()
    {
        var fixture = await ControllerFixture.StartAsync(authorized: true);
        await using (fixture)
        {
            var result = await fixture.Controller.IngestTickBatch(
                new TickBatchIngestRequest(
                [
                    ValidRequest(0),
                    ValidRequest(1) with { Ask = 1m }
                ]),
                CancellationToken.None);

            Assert.Equal(StatusCodes.Status400BadRequest, StatusCode(result));
            await Task.Delay(50);
            Assert.Equal(0, fixture.Publisher.QuoteCount);
            Assert.Null(fixture.Store.GetQuote("XAUUSD+"));
        }
    }

    [Fact]
    public async Task ExistingSingleTickEndpointUsesOrderedQueue()
    {
        var fixture = await ControllerFixture.StartAsync(authorized: true);
        await using (fixture)
        {
            var result = await fixture.Controller.IngestTick(
                ValidRequest(0),
                CancellationToken.None);

            Assert.IsType<AcceptedResult>(result);
            await WaitUntilAsync(() => fixture.Publisher.QuoteCount == 1);
            Assert.Equal(4488.10m, fixture.Store.GetQuote("XAUUSD+")?.Bid);
        }
    }

    private static TickIngestRequest ValidRequest(int index) =>
        new(
            "XAUUSD+",
            4488.10m + index,
            4488.36m + index,
            1_787_210_000_000 + index,
            "Exness");

    private static int? StatusCode(IActionResult result) =>
        result switch
        {
            ObjectResult { Value: ProblemDetails details } objectResult =>
                details.Status ?? objectResult.StatusCode,
            ObjectResult objectResult => objectResult.StatusCode,
            StatusCodeResult statusCodeResult => statusCodeResult.StatusCode,
            _ => null
        };

    private static async Task WaitUntilAsync(Func<bool> condition)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        while (!condition())
        {
            await Task.Delay(10, timeout.Token);
        }
    }

    private sealed class ControllerFixture : IAsyncDisposable
    {
        private ControllerFixture(
            MarketFeedController controller,
            MarketTickIngestionQueue queue,
            InMemoryMarketDataStore store,
            RecordingPublisher publisher)
        {
            Controller = controller;
            Queue = queue;
            Store = store;
            Publisher = publisher;
        }

        public MarketFeedController Controller { get; }

        public MarketTickIngestionQueue Queue { get; }

        public InMemoryMarketDataStore Store { get; }

        public RecordingPublisher Publisher { get; }

        public static async Task<ControllerFixture> StartAsync(bool authorized)
        {
            var store = new InMemoryMarketDataStore();
            var publisher = new RecordingPublisher();
            var feed = new MarketFeedService(store, publisher);
            var queue = new MarketTickIngestionQueue(feed, capacity: 512);
            await queue.StartAsync(CancellationToken.None);
            var validator = new MarketFeedKeyValidator(
                Options.Create(new MarketFeedOptions { IngestKey = FeedKey }));
            var controller = new MarketFeedController(feed, queue, validator)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext()
                }
            };
            if (authorized)
            {
                controller.Request.Headers["X-Market-Feed-Key"] = FeedKey;
            }

            return new ControllerFixture(controller, queue, store, publisher);
        }

        public async ValueTask DisposeAsync()
        {
            await Queue.StopAsync(CancellationToken.None);
            Queue.Dispose();
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
}

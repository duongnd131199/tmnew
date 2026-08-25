using System.Threading.Channels;
using Microsoft.Extensions.Logging.Abstractions;
using Trading.Application.Market;
using Trading.Domain.Market;

namespace Trading.Api.Market;

public sealed class MarketTickIngestionQueue : BackgroundService
{
    public const int DefaultCapacity = 4096;

    private readonly MarketFeedService _feed;
    private readonly Channel<MarketTick> _channel;
    private readonly ILogger<MarketTickIngestionQueue> _logger;

    public MarketTickIngestionQueue(
        MarketFeedService feed,
        int capacity = DefaultCapacity,
        ILogger<MarketTickIngestionQueue>? logger = null)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(capacity);
        _feed = feed;
        _logger = logger ?? NullLogger<MarketTickIngestionQueue>.Instance;
        _channel = Channel.CreateBounded<MarketTick>(
            new BoundedChannelOptions(capacity)
            {
                SingleReader = true,
                SingleWriter = false,
                FullMode = BoundedChannelFullMode.Wait
            });
    }

    public async ValueTask EnqueueAsync(
        IReadOnlyList<MarketTick> ticks,
        CancellationToken cancellationToken)
    {
        foreach (var tick in ticks)
        {
            await _channel.Writer.WriteAsync(tick, cancellationToken);
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _channel.Writer.TryComplete();
        await base.StopAsync(cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var tick in _channel.Reader.ReadAllAsync())
        {
            try
            {
                await _feed.IngestTickAsync(tick, CancellationToken.None);
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Market tick publication failed for {Symbol} at {Timestamp}.",
                    tick.Symbol,
                    tick.Timestamp);
            }
        }
    }
}

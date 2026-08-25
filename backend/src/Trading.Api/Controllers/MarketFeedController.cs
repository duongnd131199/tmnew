using Microsoft.AspNetCore.Mvc;
using Trading.Api.Market;
using Trading.Application.Market;
using Trading.Domain.Market;

namespace Trading.Api.Controllers;

[ApiController]
[Route("api/market/feed")]
public sealed class MarketFeedController : ControllerBase
{
    private const string FeedKeyHeader = "X-Market-Feed-Key";
    private readonly MarketFeedService _feed;
    private readonly MarketTickIngestionQueue _queue;
    private readonly MarketFeedKeyValidator _keyValidator;

    public MarketFeedController(
        MarketFeedService feed,
        MarketTickIngestionQueue queue,
        MarketFeedKeyValidator keyValidator)
    {
        _feed = feed;
        _queue = queue;
        _keyValidator = keyValidator;
    }

    [HttpPost("ticks")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> IngestTick(
        [FromBody] TickIngestRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsAuthorized())
        {
            return Unauthorized();
        }

        try
        {
            var tick = ToNormalizedTick(request);
            await _queue.EnqueueAsync([tick], cancellationToken);
            return Accepted();
        }
        catch (ArgumentException exception)
        {
            return InvalidRequest(exception.Message);
        }
    }

    [HttpPost("ticks/batch")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> IngestTickBatch(
        [FromBody] TickBatchIngestRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsAuthorized())
        {
            return Unauthorized();
        }

        if (request.Ticks is not { Count: >= 1 and <= 256 })
        {
            return InvalidRequest("Tick batch must contain between 1 and 256 items.");
        }

        try
        {
            var ticks = request.Ticks
                .Select(ToNormalizedTick)
                .ToArray();
            await _queue.EnqueueAsync(ticks, cancellationToken);
            return Accepted();
        }
        catch (ArgumentException exception)
        {
            return InvalidRequest(exception.Message);
        }
    }

    [HttpPost("candles/seed")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public IActionResult SeedCandles([FromBody] CandleSeedRequest request)
    {
        if (!IsAuthorized())
        {
            return Unauthorized();
        }

        try
        {
            var candles = request.Candles
                .Select(candle => new MarketCandle(
                    request.Symbol,
                    request.Timeframe,
                    DateTimeOffset.FromUnixTimeSeconds(candle.Time),
                    candle.Open,
                    candle.High,
                    candle.Low,
                    candle.Close,
                    candle.Volume))
                .ToArray();
            _feed.SeedCandles(request.Symbol, request.Timeframe, candles);
            return Accepted(new { count = candles.Length });
        }
        catch (ArgumentException exception)
        {
            return InvalidRequest(exception.Message);
        }
    }

    private bool IsAuthorized() =>
        _keyValidator.IsAuthorized(Request.Headers[FeedKeyHeader].FirstOrDefault());

    private BadRequestObjectResult InvalidRequest(string detail) =>
        BadRequest(new ValidationProblemDetails
        {
            Detail = detail,
            Status = StatusCodes.Status400BadRequest
        });

    private static MarketTick ToNormalizedTick(TickIngestRequest request) =>
        MarketFeedService.NormalizeTick(
            new MarketTick(
                request.Symbol,
                request.Bid,
                request.Ask,
                DateTimeOffset.FromUnixTimeMilliseconds(request.TimeMsc),
                request.Source ?? "MT5"));
}

public sealed record TickIngestRequest(
    string Symbol,
    decimal Bid,
    decimal Ask,
    long TimeMsc,
    string? Source);

public sealed record TickBatchIngestRequest(
    IReadOnlyList<TickIngestRequest>? Ticks);

public sealed record CandleSeedRequest(
    string Symbol,
    string Timeframe,
    IReadOnlyList<CandleIngestItem> Candles);

public sealed record CandleIngestItem(
    long Time,
    decimal Open,
    decimal High,
    decimal Low,
    decimal Close,
    long Volume);

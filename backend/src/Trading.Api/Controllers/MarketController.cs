using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Trading.Api.Market;
using Trading.Application.Market;
using Trading.Domain.Market;

namespace Trading.Api.Controllers;

[ApiController]
[Route("api/market")]
public sealed class MarketController : ControllerBase
{
    private readonly IMarketDataStore _store;
    private readonly MarketFeedOptions _options;

    public MarketController(
        IMarketDataStore store,
        IOptions<MarketFeedOptions> options)
    {
        _store = store;
        _options = options.Value;
    }

    [HttpGet("quotes")]
    [ProducesResponseType<IReadOnlyList<MarketTick>>(StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<MarketTick>> GetQuotes(
        [FromQuery] string? symbols)
    {
        try
        {
            var requested = string.IsNullOrWhiteSpace(symbols)
                ? null
                : symbols
                    .Split(',', StringSplitOptions.RemoveEmptyEntries)
                    .Select(MarketSymbols.Normalize)
                    .ToArray();
            return Ok(_store.GetQuotes(requested));
        }
        catch (ArgumentException exception)
        {
            return ValidationProblem(exception.Message);
        }
    }

    [HttpGet("quotes/{symbol}")]
    [ProducesResponseType<MarketTick>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<MarketTick> GetQuote(string symbol)
    {
        try
        {
            var quote = _store.GetQuote(symbol);
            return quote is null ? NotFound() : Ok(quote);
        }
        catch (ArgumentException exception)
        {
            return ValidationProblem(exception.Message);
        }
    }

    [HttpGet("candles")]
    [ProducesResponseType<IReadOnlyList<MarketCandle>>(StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<MarketCandle>> GetCandles(
        [FromQuery] string symbol,
        [FromQuery] string timeframe,
        [FromQuery] int limit = 360)
    {
        try
        {
            return Ok(_store.GetCandles(symbol, timeframe, limit));
        }
        catch (ArgumentException exception)
        {
            return ValidationProblem(exception.Message);
        }
    }

    [HttpGet("status")]
    public IActionResult GetStatus()
    {
        var quotes = _store.GetQuotes();
        var latest = quotes
            .OrderByDescending(quote => quote.Timestamp)
            .FirstOrDefault();
        var staleAfter = TimeSpan.FromSeconds(
            Math.Clamp(_options.StaleAfterSeconds, 1, 120));
        var connected = latest is not null &&
            DateTimeOffset.UtcNow - latest.Timestamp <= staleAfter;
        return Ok(new
        {
            connected,
            quoteCount = quotes.Count,
            lastTickAt = latest?.Timestamp,
            source = latest?.Source
        });
    }
}

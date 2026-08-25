using Microsoft.AspNetCore.SignalR;
using Trading.Application.Market;
using Trading.Domain.Market;

namespace Trading.Realtime.Market;

public sealed class MarketHub : Hub
{
    public Task SubscribeSymbols(IReadOnlyCollection<string> symbols) =>
        Task.WhenAll(
            symbols
                .Select(MarketSymbols.Normalize)
                .Distinct(StringComparer.Ordinal)
                .Select(symbol => Groups.AddToGroupAsync(
                    Context.ConnectionId,
                    MarketGroups.Quote(symbol))));

    public Task UnsubscribeSymbols(IReadOnlyCollection<string> symbols) =>
        Task.WhenAll(
            symbols
                .Select(MarketSymbols.Normalize)
                .Distinct(StringComparer.Ordinal)
                .Select(symbol => Groups.RemoveFromGroupAsync(
                    Context.ConnectionId,
                    MarketGroups.Quote(symbol))));

    public Task SubscribeChart(string symbol, string timeframe) =>
        Groups.AddToGroupAsync(
            Context.ConnectionId,
            MarketGroups.Chart(
                MarketSymbols.Normalize(symbol),
                MarketTimeframes.Normalize(timeframe)));

    public Task UnsubscribeChart(string symbol, string timeframe) =>
        Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            MarketGroups.Chart(
                MarketSymbols.Normalize(symbol),
                MarketTimeframes.Normalize(timeframe)));
}

public sealed class SignalRMarketRealtimePublisher : IMarketRealtimePublisher
{
    private readonly IHubContext<MarketHub> _hub;

    public SignalRMarketRealtimePublisher(IHubContext<MarketHub> hub)
    {
        _hub = hub;
    }

    public Task PublishQuoteAsync(
        MarketTick tick,
        CancellationToken cancellationToken) =>
        _hub.Clients
            .Group(MarketGroups.Quote(tick.Symbol))
            .SendAsync("QuoteUpdated", tick, cancellationToken);

    public Task PublishCandleAsync(
        MarketCandle candle,
        CancellationToken cancellationToken) =>
        _hub.Clients
            .Group(MarketGroups.Chart(candle.Symbol, candle.Timeframe))
            .SendAsync("CandleUpdated", candle, cancellationToken);
}

internal static class MarketGroups
{
    public static string Quote(string symbol) => $"quote:{symbol}";

    public static string Chart(string symbol, string timeframe) =>
        $"chart:{symbol}:{timeframe}";
}

using System.Text.Json;
using Trading.Api.Market;
using Trading.Application.Market;
using Trading.Infrastructure.Market;
using Trading.Realtime.Market;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy =
            JsonNamingPolicy.CamelCase;
    });
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.Configure<MarketFeedOptions>(
    builder.Configuration.GetSection(MarketFeedOptions.SectionName));
builder.Services.AddSingleton<MarketFeedKeyValidator>();
builder.Services.AddSingleton<IMarketDataStore, InMemoryMarketDataStore>();
builder.Services.AddSingleton<IMarketRealtimePublisher, SignalRMarketRealtimePublisher>();
builder.Services.AddSingleton<MarketFeedService>();
builder.Services.AddSingleton<MarketTickIngestionQueue>();
builder.Services.AddSingleton<IHostedService>(provider =>
    provider.GetRequiredService<MarketTickIngestionQueue>());
builder.Services
    .AddSignalR()
    .AddJsonProtocol(options =>
    {
        options.PayloadSerializerOptions.PropertyNamingPolicy =
            JsonNamingPolicy.CamelCase;
    });
builder.Services.AddCors(options =>
{
    options.AddPolicy(
        "Mobile",
        policy => policy
            .AllowAnyHeader()
            .AllowAnyMethod()
            .SetIsOriginAllowed(_ => true)
            .AllowCredentials());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("Mobile");
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapHub<MarketHub>("/hubs/market");

app.Run();

public partial class Program;

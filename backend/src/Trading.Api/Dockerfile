FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY Trading.sln ./
COPY src/Trading.Api/Trading.Api.csproj src/Trading.Api/
COPY src/Trading.Application/Trading.Application.csproj src/Trading.Application/
COPY src/Trading.Domain/Trading.Domain.csproj src/Trading.Domain/
COPY src/Trading.Infrastructure/Trading.Infrastructure.csproj src/Trading.Infrastructure/
COPY src/Trading.Realtime/Trading.Realtime.csproj src/Trading.Realtime/
COPY src/Trading.Workers/Trading.Workers.csproj src/Trading.Workers/
COPY tests/Trading.UnitTests/Trading.UnitTests.csproj tests/Trading.UnitTests/
COPY tests/Trading.IntegrationTests/Trading.IntegrationTests.csproj tests/Trading.IntegrationTests/
COPY tests/Trading.ArchitectureTests/Trading.ArchitectureTests.csproj tests/Trading.ArchitectureTests/
RUN dotnet restore Trading.sln

COPY . .
RUN dotnet publish src/Trading.Api/Trading.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Trading.Api.dll"]

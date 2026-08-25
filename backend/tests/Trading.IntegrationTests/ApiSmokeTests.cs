namespace Trading.IntegrationTests;

public sealed class ApiSmokeTests
{
    [Fact]
    public void ApiAssemblyCanBeLoaded()
    {
        var assemblyName = typeof(Api.AssemblyReference).Assembly.GetName().Name;

        Assert.Equal("Trading.Api", assemblyName);
    }
}


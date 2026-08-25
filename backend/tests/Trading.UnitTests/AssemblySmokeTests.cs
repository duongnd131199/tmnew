namespace Trading.UnitTests;

public sealed class AssemblySmokeTests
{
    [Fact]
    public void DomainAssemblyCanBeLoaded()
    {
        var assemblyName = typeof(Domain.AssemblyReference).Assembly.GetName().Name;

        Assert.Equal("Trading.Domain", assemblyName);
    }
}


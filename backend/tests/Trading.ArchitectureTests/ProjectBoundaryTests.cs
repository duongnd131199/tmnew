namespace Trading.ArchitectureTests;

public sealed class ProjectBoundaryTests
{
    [Fact]
    public void DomainDoesNotReferenceOuterLayers()
    {
        var references = typeof(Domain.AssemblyReference)
            .Assembly
            .GetReferencedAssemblies()
            .Select(assembly => assembly.Name);

        Assert.DoesNotContain("Trading.Application", references);
        Assert.DoesNotContain("Trading.Infrastructure", references);
        Assert.DoesNotContain("Trading.Api", references);
    }
}


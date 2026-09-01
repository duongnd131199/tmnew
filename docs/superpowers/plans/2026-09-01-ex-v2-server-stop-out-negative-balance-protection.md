# EX V2 Server Stop Out and Negative Balance Protection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add server-authoritative automatic Stop Out, complete exit history, transactional realtime delivery, and auditable Negative Balance Protection to the virtual EX V2 production service.

**Architecture:** EX V2 subscribes to market SignalR ticks, coalesces affected accounts, and evaluates each account with one frozen quote snapshot. Every trading mutation shares a transaction-owned SQL account lock; a Stop Out atomically closes all positions, cancels pending orders, writes `D-null` when needed, increments one account data version, and enqueues account-scoped outbox events.

**Tech Stack:** .NET 8, ASP.NET Core, Entity Framework Core, SQL Server guarded SQL migrations, SignalR client/server, xUnit, Swashbuckle/OpenAPI, systemd/nginx production deployment.

**Spec:** `docs/superpowers/specs/2026-09-01-ex-v2-stop-out-negative-balance-protection-design.md`

## Global Constraints

- Production source is `/opt/ex-v2-api-src`; implementation starts from audited commit `a9dc3f75c78a43f24f48dd2dcccfbd1876849bd1` in an isolated worktree.
- Read `/opt/ex-v2-api-src/README.md` and every document listed in the spec's Confirmed Production Baseline before editing.
- Preserve the pre-existing dirty source tree and the separate worktree that owns migration `006`; never stage or overwrite those changes.
- Reconcile migrations `005` and `006`, then use `007` for this additive migration, verification, and guarded rollback.
- Use an isolated SQL database supplied through `EXV2_TEST_SQL_CONNECTION`; never run tests or test mutations against production.
- The system remains virtual-money only. Do not add an MT5/broker execution adapter or broker ticket contract.
- The Stop Out trigger is rounded authoritative `Equity <= 0`, including exactly zero.
- Use .NET `decimal`; USD currency money is rounded to two digits with `MidpointRounding.AwayFromZero`.
- BUY risk/close uses Bid; SELL risk/close uses Ask. One immutable snapshot prices the complete run.
- No HTTP/SignalR/network call is allowed while a SQL transaction or `sp_getapplock` is held.
- All create/close/partial-close/cancel/protection/Stop Out paths use the same account lock.
- Numeric close volume is validated and rejected when invalid or above remaining; the server never clamps it.
- Realtime is written transactionally to an account-scoped outbox and published only after commit.
- `RiskWorkerEnabled` and `StopOutExecutionEnabled` default to `false` in production configuration.
- Before every Task 2-10 commit, run `dotnet build ExV2.sln --no-restore` plus that task's focused tests; build must have zero warnings/errors.
- Unit, compatibility, all original 116 SQL integration cases, and every new case in this plan must genuinely execute and pass before deployment.
- Do not upload a Flutter build or TestFlight build from this server plan.

---

### Task 1: Create an Isolated Server Worktree and Establish a Trustworthy Baseline

**Files:**
- Read: `/opt/ex-v2-api-src/README.md`
- Read: `/opt/ex-v2-api-src/docs/ex-v2-architecture.md`
- Read: `/opt/ex-v2-api-src/docs/ex-v2-deployment.md`
- Read: `/opt/ex-v2-api-src/docs/ex-v2-rollback.md`
- Read: `/opt/ex-v2-api-src/docs/ex-v2-database-migration.md`
- Read: `/opt/ex-v2-api-src/docs/ex-v2-api-contract.md`
- Read: `/opt/ex-v2-api-src/docs/openapi-v2.json`
- No product file is modified in this task.

**Interfaces:**
- Consumes: audited source commit and a securely supplied isolated SQL test connection.
- Produces: a clean implementation worktree, a reconciled migration sequence through `006`, and a baseline where every server test truly runs.

- [ ] **Step 1: Invoke the worktree skill and create the feature worktree**

Use `superpowers:using-git-worktrees`. Create branch
`feature/ex-v2-stop-out-nbp` from
`a9dc3f75c78a43f24f48dd2dcccfbd1876849bd1`; do not branch from the dirty
working directory.

- [ ] **Step 2: Verify worktree identity and isolation**

Run:

```bash
git rev-parse HEAD
git branch --show-current
git status --short
git worktree list --porcelain
```

Expected: HEAD is the audited commit plus only reviewed prerequisite commits,
branch is `feature/ex-v2-stop-out-nbp`, and the new worktree is clean.

- [ ] **Step 3: Reconcile migration ownership before creating `007`**

Record the owner, branch, and reviewed commit status of the existing `005`
payment-attribution files and the worktree that reserved `006`. Do not copy or
merge their unrelated source merely to fill migration numbers. Merge a
`005/006` commit only when it is independently reviewed, accepted, and a real
prerequisite of this release. Run:

```bash
find database/migrations database/verify database/rollback -maxdepth 1 -type f -print | sort
```

Expected: no two files claim the same number; ownership of `005/006` is
recorded; `007` is reserved for this plan. Before production migration, the
execution report must state whether each earlier number was applied or remains
reserved, without deploying its unrelated source through this feature.

- [ ] **Step 4: Require the isolated SQL test environment**

Run without printing the value:

```bash
test -n "${EXV2_TEST_SQL_CONNECTION:-}"
```

Expected: exit `0`. If it exits nonzero, stop this plan until an isolated test
database is provisioned. Never substitute the production connection.

- [ ] **Step 5: Run the complete baseline**

Run:

```bash
dotnet build ExV2.sln
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --no-build
dotnet test tests/ExV2.CompatibilityTests/ExV2.CompatibilityTests.csproj --no-build
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --no-build
```

Expected: build has zero warnings/errors; Unit `46/46`, Compatibility `3/3`,
and Integration `116/116` pass with SQL lifecycle setup visibly executing.
If the counts differ, record the exact discovered counts and require zero
failures plus evidence that no test returned early for a missing connection.

- [ ] **Step 6: Save the baseline evidence outside git**

Store command, exit code, counts, commit, and UTC timestamp in the execution
report. Do not commit connection strings, test database names, credentials,
tokens, or raw production logs.

---

### Task 2: Implement Pure Decimal Account Risk Rules

**Files:**
- Create: `/opt/ex-v2-api-src/src/ExV2.Domain/Trading/AccountRiskRules.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.UnitTests/AccountRiskRulesTests.cs`

**Interfaces:**
- Consumes: normalized side (`BUY`/`SELL`), remaining volume, entry price, Bid/Ask, contract size, leverage, accrued commission/swap, and account Balance.
- Produces: `AccountRiskRules.Calculate(AccountRiskInput)`, `AccountRiskCalculation`, `PositionRiskCalculation`, and `AccountRiskRules.RequiresStopOut(decimal)`.

- [ ] **Step 1: Write failing BUY/SELL, rounding, margin, and trigger tests**

Create tests with these exact cases:

```csharp
[Theory]
[InlineData("BUY", "100", "90", "91", "-10", "90")]
[InlineData("SELL", "100", "109", "110", "-10", "110")]
public void Calculate_uses_exit_side_quote(
    string side,
    string entryRaw,
    string bidRaw,
    string askRaw,
    string expectedNetRaw,
    string expectedExitRaw)
{
    var entry = decimal.Parse(entryRaw, CultureInfo.InvariantCulture);
    var bid = decimal.Parse(bidRaw, CultureInfo.InvariantCulture);
    var ask = decimal.Parse(askRaw, CultureInfo.InvariantCulture);
    var expectedNet = decimal.Parse(expectedNetRaw, CultureInfo.InvariantCulture);
    var expectedExit = decimal.Parse(expectedExitRaw, CultureInfo.InvariantCulture);
    var result = AccountRiskRules.Calculate(new AccountRiskInput(
        Currency: "USD",
        Balance: 10m,
        Leverage: 100m,
        Positions:
        [
            new PositionRiskInput(
                Guid.Parse("00000000-0000-0000-0000-000000000001"),
                side,
                1m,
                entry,
                bid,
                ask,
                1m,
                0m,
                0m,
                DateTimeOffset.Parse("2026-09-01T00:00:00Z"))
        ]));

    Assert.Equal(expectedNet, result.Positions.Single().NetProfit);
    Assert.Equal(expectedExit, result.Positions.Single().ExitPrice);
    Assert.Equal(0m, result.Equity);
    Assert.True(AccountRiskRules.RequiresStopOut(result.Equity));
}

[Theory]
[InlineData("0.004", "0", true)]
[InlineData("0.005", "0.01", false)]
[InlineData("-0.004", "0", true)]
[InlineData("-0.005", "-0.01", true)]
public void RoundUsd_and_trigger_are_deterministic(
    string rawValue,
    string roundedValue,
    bool triggers)
{
    var raw = decimal.Parse(rawValue, CultureInfo.InvariantCulture);
    var rounded = decimal.Parse(roundedValue, CultureInfo.InvariantCulture);
    Assert.Equal(rounded, AccountRiskRules.RoundCurrency("USD", raw));
    Assert.Equal(triggers, AccountRiskRules.RequiresStopOut(rounded));
}
```

Also assert deterministic ordering by net loss, opened time, then position ID;
commission/swap inclusion; `Margin = volume * contract * sideQuote / leverage`;
Free Margin; Margin Level; unsupported currency; zero/negative leverage; and
invalid side.

- [ ] **Step 2: Run the new unit tests and verify RED**

Run:

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~AccountRiskRulesTests
```

Expected: compile/test failure because the risk types do not exist.

- [ ] **Step 3: Implement the immutable risk types and calculation**

Implement these signatures:

```csharp
namespace ExV2.Domain.Trading;

public sealed record PositionRiskInput(
    Guid PositionId,
    string Side,
    decimal RemainingVolume,
    decimal EntryPrice,
    decimal Bid,
    decimal Ask,
    decimal ContractSize,
    decimal Commission,
    decimal Swap,
    DateTimeOffset OpenedAtUtc);

public sealed record AccountRiskInput(
    string Currency,
    decimal Balance,
    decimal Leverage,
    IReadOnlyList<PositionRiskInput> Positions);

public sealed record PositionRiskCalculation(
    Guid PositionId,
    decimal ExitPrice,
    decimal GrossProfit,
    decimal Commission,
    decimal Swap,
    decimal NetProfit,
    decimal Margin,
    DateTimeOffset OpenedAtUtc);

public sealed record AccountRiskCalculation(
    decimal Balance,
    decimal Equity,
    decimal Margin,
    decimal FreeMargin,
    decimal MarginLevel,
    IReadOnlyList<PositionRiskCalculation> Positions);

public static class AccountRiskRules
{
    public static decimal RoundCurrency(string currency, decimal value) =>
        currency.ToUpperInvariant() switch
        {
            "USD" => Math.Round(value, 2, MidpointRounding.AwayFromZero),
            _ => throw new ArgumentOutOfRangeException(nameof(currency))
        };

    public static bool RequiresStopOut(decimal roundedEquity) =>
        roundedEquity <= 0m;

    public static AccountRiskCalculation Calculate(AccountRiskInput input)
    {
        ArgumentNullException.ThrowIfNull(input);
        if (input.Leverage <= 0m)
            throw new ArgumentOutOfRangeException(nameof(input.Leverage));

        var calculated = input.Positions.Select(position =>
        {
            if (position.PositionId == Guid.Empty)
                throw new ArgumentOutOfRangeException(nameof(position.PositionId));
            if (position.RemainingVolume <= 0m)
                throw new ArgumentOutOfRangeException(nameof(position.RemainingVolume));
            if (position.EntryPrice <= 0m || position.Bid <= 0m || position.Ask <= 0m)
                throw new ArgumentOutOfRangeException(nameof(position.EntryPrice));
            if (position.ContractSize <= 0m)
                throw new ArgumentOutOfRangeException(nameof(position.ContractSize));

            var side = position.Side.Trim().ToUpperInvariant();
            var exitPrice = side switch
            {
                "BUY" => position.Bid,
                "SELL" => position.Ask,
                _ => throw new ArgumentOutOfRangeException(nameof(position.Side))
            };
            var marginPrice = side == "BUY" ? position.Ask : position.Bid;
            var rawGross = side == "BUY"
                ? (exitPrice - position.EntryPrice) * position.ContractSize *
                  position.RemainingVolume
                : (position.EntryPrice - exitPrice) * position.ContractSize *
                  position.RemainingVolume;
            var gross = RoundCurrency(input.Currency, rawGross);
            var commission = RoundCurrency(input.Currency, position.Commission);
            var swap = RoundCurrency(input.Currency, position.Swap);
            var net = RoundCurrency(input.Currency, gross + commission + swap);
            var margin = RoundCurrency(
                input.Currency,
                position.RemainingVolume * position.ContractSize * marginPrice /
                input.Leverage);

            return new PositionRiskCalculation(
                position.PositionId,
                exitPrice,
                gross,
                commission,
                swap,
                net,
                margin,
                position.OpenedAtUtc);
        }).OrderBy(position => position.NetProfit)
          .ThenBy(position => position.OpenedAtUtc)
          .ThenBy(position => position.PositionId)
          .ToArray();

        var balance = RoundCurrency(input.Currency, input.Balance);
        var equity = RoundCurrency(
            input.Currency,
            balance + calculated.Sum(position => position.NetProfit));
        var margin = RoundCurrency(
            input.Currency,
            calculated.Sum(position => position.Margin));
        var freeMargin = RoundCurrency(input.Currency, equity - margin);
        var marginLevel = margin == 0m
            ? 0m
            : Math.Round(equity / margin * 100m, 2,
                MidpointRounding.AwayFromZero);

        return new AccountRiskCalculation(
            balance,
            equity,
            margin,
            freeMargin,
            marginLevel,
            calculated);
    }
}
```

Round every money component through `RoundCurrency`; do not round volume or
price. Add `using System.Globalization;` to the test file for string-based
decimal attribute data.

- [ ] **Step 4: Run focused and complete unit tests**

Run:

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~AccountRiskRulesTests
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj
```

Expected: all focused cases and the complete unit project pass.

- [ ] **Step 5: Commit the pure domain rules**

```bash
git add src/ExV2.Domain/Trading/AccountRiskRules.cs tests/ExV2.UnitTests/AccountRiskRulesTests.cs
git commit -m "feat: add deterministic account risk rules"
```

---

### Task 3: Add the Additive Stop Out, Adjustment, and Trading Outbox Schema

**Files:**
- Create: `/opt/ex-v2-api-src/database/migrations/007_add_stop_out_negative_balance_protection.sql`
- Create: `/opt/ex-v2-api-src/database/verify/verify_007_stop_out_negative_balance_protection.sql`
- Create: `/opt/ex-v2-api-src/database/rollback/007_remove_stop_out_negative_balance_protection.sql`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Persistence/Entities/V2Entities.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Persistence/Entities/LegacyEntities.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Persistence/ExV2DbContext.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/StopOutSchemaTests.cs`

**Interfaces:**
- Consumes: existing `TradingAccount`, `V2Order`, `V2Position`, `V2Deal`, and `MobileSyncVersion` identities.
- Produces: `V2AccountRiskState`, `V2StopOutRun`, `V2AccountAdjustment`, `V2TradingOutboxMessage`, new order/deal fields, and database uniqueness/lookup indexes.

- [ ] **Step 1: Write failing EF/schema assertions**

Assert all four tables, foreign keys, rowversions, filtered indexes, and these
unique constraints:

```csharp
AssertUnique("V2StopOutRuns", "TradingAccountId", "RiskVersion");
AssertUnique("V2AccountAdjustments", "StopOutRunId", "AdjustmentType");
AssertUnique("V2Orders", "ServerCommandKey");
AssertUnique("V2Deals", "ExecutionKey");
AssertUnique("V2TradingOutboxMessages", "LogicalEventKey");
```

Assert new currency columns use `decimal(18,2)`, price/volume retain the
existing `decimal(18,6)` mapping, all existing orders default to `Role = entry`,
and `TradingAccounts.RowVersion` is mapped as a concurrency token.

- [ ] **Step 2: Run schema tests and verify RED**

Run:

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~StopOutSchemaTests
```

Expected: failures for missing tables/columns/indexes.

- [ ] **Step 3: Write guarded migration `007`**

The migration must create these columns and keys:

```sql
CREATE TABLE dbo.V2AccountRiskStates (
    TradingAccountId uniqueidentifier NOT NULL PRIMARY KEY,
    Balance decimal(18,2) NOT NULL,
    Equity decimal(18,2) NOT NULL,
    Margin decimal(18,2) NOT NULL,
    FreeMargin decimal(18,2) NOT NULL,
    MarginLevel decimal(18,2) NOT NULL,
    QuoteSnapshotId nvarchar(128) NOT NULL,
    EvaluatedAtUtc datetime2(7) NOT NULL,
    RiskVersion bigint NOT NULL,
    RowVersion rowversion NOT NULL,
    CONSTRAINT FK_V2AccountRiskStates_TradingAccounts
        FOREIGN KEY (TradingAccountId) REFERENCES dbo.TradingAccounts(Id)
);

CREATE TABLE dbo.V2StopOutRuns (
    Id uniqueidentifier NOT NULL PRIMARY KEY,
    TradingAccountId uniqueidentifier NOT NULL,
    RiskVersion bigint NOT NULL,
    QuoteSnapshotId nvarchar(128) NOT NULL,
    TriggerBalance decimal(18,2) NOT NULL,
    TriggerEquity decimal(18,2) NOT NULL,
    FinalBalance decimal(18,2) NOT NULL,
    FinalEquity decimal(18,2) NOT NULL,
    Status nvarchar(32) NOT NULL,
    CorrelationId uniqueidentifier NOT NULL,
    StartedAtUtc datetime2(7) NOT NULL,
    CompletedAtUtc datetime2(7) NULL,
    RowVersion rowversion NOT NULL,
    CONSTRAINT UQ_V2StopOutRuns_Account_RiskVersion
        UNIQUE (TradingAccountId, RiskVersion),
    CONSTRAINT FK_V2StopOutRuns_TradingAccounts
        FOREIGN KEY (TradingAccountId) REFERENCES dbo.TradingAccounts(Id)
);
```

Create the remaining tables with these contracts:

```sql
CREATE TABLE dbo.V2AccountAdjustments (
    Id uniqueidentifier NOT NULL PRIMARY KEY,
    TradingAccountId uniqueidentifier NOT NULL,
    StopOutRunId uniqueidentifier NOT NULL,
    AdjustmentType nvarchar(64) NOT NULL,
    DisplayCode nvarchar(32) NOT NULL,
    Currency nvarchar(8) NOT NULL,
    Amount decimal(18,2) NOT NULL,
    BalanceBefore decimal(18,2) NOT NULL,
    BalanceAfter decimal(18,2) NOT NULL,
    CorrelationId uniqueidentifier NOT NULL,
    CreatedAtUtc datetime2(7) NOT NULL,
    RowVersion rowversion NOT NULL,
    CONSTRAINT UQ_V2AccountAdjustments_Run_Type
        UNIQUE (StopOutRunId, AdjustmentType),
    CONSTRAINT FK_V2AccountAdjustments_Accounts
        FOREIGN KEY (TradingAccountId) REFERENCES dbo.TradingAccounts(Id),
    CONSTRAINT FK_V2AccountAdjustments_Runs
        FOREIGN KEY (StopOutRunId) REFERENCES dbo.V2StopOutRuns(Id)
);

CREATE TABLE dbo.V2TradingOutboxMessages (
    EventId uniqueidentifier NOT NULL PRIMARY KEY,
    TradingAccountId uniqueidentifier NOT NULL,
    DataVersion bigint NOT NULL,
    EventType nvarchar(128) NOT NULL,
    LogicalEventKey nvarchar(256) NOT NULL,
    CorrelationId uniqueidentifier NOT NULL,
    StopOutRunId uniqueidentifier NULL,
    PayloadJson nvarchar(max) NOT NULL,
    CreatedAtUtc datetime2(7) NOT NULL,
    PublishedAtUtc datetime2(7) NULL,
    AttemptCount int NOT NULL CONSTRAINT DF_V2TradingOutbox_Attempts DEFAULT 0,
    NextAttemptAtUtc datetime2(7) NOT NULL,
    QuarantinedAtUtc datetime2(7) NULL,
    LastErrorCode nvarchar(128) NULL,
    RowVersion rowversion NOT NULL,
    CONSTRAINT UQ_V2TradingOutbox_LogicalEventKey UNIQUE (LogicalEventKey),
    CONSTRAINT FK_V2TradingOutbox_Accounts
        FOREIGN KEY (TradingAccountId) REFERENCES dbo.TradingAccounts(Id),
    CONSTRAINT FK_V2TradingOutbox_Runs
        FOREIGN KEY (StopOutRunId) REFERENCES dbo.V2StopOutRuns(Id)
);
```

Add nullable `PositionId`, `StopOutRunId`,
`LegacyTradeOrderId`, `Role`, `ExecutionReason`, and `ServerCommandKey` to
`V2Orders`. Add nullable `OpeningOrderId`, `Commission`, `Swap`, `NetProfit`,
`StopOutRunId`, and `ExecutionKey` to `V2Deals`. Add
`TradingAccounts.RowVersion`. Add indexes for `(Status, Symbol,
TradingAccountId)` open-position fan-out, `(TradingAccountId, Status)` pending
orders, and unpublished outbox dispatch.

Use the existing primary-key store type of `TradeOrders.Id` for
`LegacyTradeOrderId` and assert that equality in `StopOutSchemaTests`; do not
guess or convert the legacy key type. Create filtered unique indexes for
non-null `V2Orders.ServerCommandKey` and `V2Deals.ExecutionKey` so multiple
historical nulls remain legal.

Every `CREATE`/`ALTER` is guarded by metadata checks and is safe to rerun.
Backfill existing `V2Orders.Role` to `entry`, then make it non-null with that
default. Never synthesize historical exit orders.

- [ ] **Step 4: Add matching EF entities and mappings**

Add `DbSet<>` entries and configure:

```csharp
builder.Entity<V2StopOutRun>()
    .HasIndex(x => new { x.TradingAccountId, x.RiskVersion })
    .IsUnique();
builder.Entity<V2AccountAdjustment>()
    .HasIndex(x => new { x.StopOutRunId, x.AdjustmentType })
    .IsUnique();
builder.Entity<V2TradingOutboxMessage>()
    .HasIndex(x => x.LogicalEventKey)
    .IsUnique();
```

Map money fields to `decimal(18,2)`, retain existing price/volume mappings,
and mark every rowversion with `.IsRowVersion()`.

- [ ] **Step 5: Write verification and guarded rollback SQL**

`verify_007...sql` must throw when any required table, column, default, index,
foreign key, precision, or unique constraint is absent. The rollback begins
with:

```sql
IF EXISTS (SELECT 1 FROM dbo.V2StopOutRuns)
   OR EXISTS (SELECT 1 FROM dbo.V2AccountAdjustments)
   OR EXISTS (SELECT 1 FROM dbo.V2TradingOutboxMessages)
    THROW 51007, 'Rollback 007 refused because Stop Out production data exists.', 1;
```

Only after that guard may it drop additive objects in reverse dependency
order. Binary rollback remains the preferred production response.

- [ ] **Step 6: Apply migration and verification only to isolated SQL**

Use the repository's documented migration runner with
`EXV2_TEST_SQL_CONNECTION`; then run the verification script twice to prove
idempotent verification. Do not print the connection value.

- [ ] **Step 7: Run focused and complete integration tests**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~StopOutSchemaTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj
```

Expected: schema tests and all 116 integration cases pass.

- [ ] **Step 8: Commit schema and entity changes**

```bash
git add database/migrations/007_add_stop_out_negative_balance_protection.sql database/verify/verify_007_stop_out_negative_balance_protection.sql database/rollback/007_remove_stop_out_negative_balance_protection.sql src/ExV2.Infrastructure/Persistence/Entities/V2Entities.cs src/ExV2.Infrastructure/Persistence/Entities/LegacyEntities.cs src/ExV2.Infrastructure/Persistence/ExV2DbContext.cs tests/ExV2.IntegrationTests/StopOutSchemaTests.cs
git commit -m "feat: add stop out persistence schema"
```

---

### Task 4: Add the Shared Transaction-Owned Trading Account Lock

**Files:**
- Create: `/opt/ex-v2-api-src/src/ExV2.Application/Trading/TradingAccountLockContracts.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlTradingAccountLock.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlTradingService.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/TradingAccountLockTests.cs`
- Modify: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs`

**Interfaces:**
- Consumes: trading account ID and a database-only mutation delegate; external quote work has already completed.
- Produces: `ITradingAccountLock.ExecuteAsync<T>` that owns Serializable transaction, application lock, complete-operation retry, save, and commit.

- [ ] **Step 1: Write concurrency tests that expose the current lost-update risk**

Use two independent service scopes/DbContexts. Block the first mutation after
lock acquisition, start a second mutation on the same account, and assert the
second cannot enter its financial write until the first commits. Add a second
case proving two different accounts do not block each other.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~TradingAccountLockTests
```

Expected: the same-account operations overlap or lose a Balance update because
the common lock does not exist.

- [ ] **Step 3: Define and implement the lock contract**

```csharp
namespace ExV2.Application.Trading;

public interface ITradingAccountLock
{
    Task<T> ExecuteAsync<T>(
        Guid tradingAccountId,
        Func<CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken);
}
```

`SqlTradingAccountLock` executes parameterized SQL equivalent to:

```sql
DECLARE @result int;
EXEC @result = sys.sp_getapplock
    @Resource = @resource,
    @LockMode = 'Exclusive',
    @LockOwner = 'Transaction',
    @LockTimeout = 5000;
SELECT @result;
```

The resource is `trading-account:{accountId:D}`. On each of at most three
attempts, begin a new Serializable transaction, acquire the transaction-owned
lock, invoke the delegate, call `SaveChangesAsync`, and commit. A SQL deadlock
`1205` or application-lock timeout/cancel rolls back that whole attempt before
the wrapper retries with a new transaction. Exhaustion throws a typed
`TradingAccountBusyException` mapped to stable HTTP 409 code
`TRADING_ACCOUNT_BUSY`.

- [ ] **Step 4: Route existing trading mutations through the common lock**

In each create, close, partial-close, cancel, and protection mutation:

1. fetch external quote before opening the SQL transaction;
2. call `ITradingAccountLock.ExecuteAsync`;
3. re-read account/order/position state inside the delegate;
4. validate and add all persistence/outbox changes; and
5. let the wrapper save and commit.

Do not make quote or SignalR calls inside the delegate.

- [ ] **Step 5: Run lock, lifecycle, unit, and compatibility tests**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~TradingAccountLockTests|FullyQualifiedName~MarketOrderLifecycleTests"
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj
dotnet test tests/ExV2.CompatibilityTests/ExV2.CompatibilityTests.csproj
```

Expected: serialized same-account writes, parallel different-account writes,
and all existing lifecycle/contract behavior pass.

- [ ] **Step 6: Commit the shared account lock**

```bash
git add src/ExV2.Application/Trading/TradingAccountLockContracts.cs src/ExV2.Infrastructure/Trading/SqlTradingAccountLock.cs src/ExV2.Infrastructure/Trading/SqlTradingService.cs src/ExV2.Api/Program.cs tests/ExV2.IntegrationTests/TradingAccountLockTests.cs tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs
git commit -m "refactor: serialize trading mutations by account"
```

---

### Task 5: Replace Direct Trading SignalR Publishing with a Transactional Outbox

**Files:**
- Modify: `/opt/ex-v2-api-src/src/ExV2.Application/Realtime/RealtimeContracts.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Realtime/SqlTradingOutboxWriter.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Api/Realtime/TradingOutboxDispatcher.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Realtime/TradingHub.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlTradingService.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/TradingOutboxTests.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.UnitTests/TradingEventEnvelopeTests.cs`

**Interfaces:**
- Consumes: account ID, data version, correlation/run ID, event type, and typed payload inside the caller's transaction.
- Produces: `ITradingOutboxWriter.EnqueueAsync`, durable `TradingEventEnvelope`, and retrying account-group dispatch.

- [ ] **Step 1: Write failing envelope, commit-order, retry, and dedupe tests**

Define cases proving:

- an event cannot be observed before its SQL transaction commits;
- rollback removes the outbox record;
- simulated hub failure leaves `PublishedAtUtc` null;
- retry publishes once logically and marks the row;
- duplicate `LogicalEventKey` creates one row; and
- dispatch targets only `account:{accountId:D}`, never all clients.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~TradingEventEnvelopeTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~TradingOutboxTests
```

Expected: missing envelope/writer/dispatcher failures.

- [ ] **Step 3: Define the event/outbox interfaces**

```csharp
public sealed record TradingEventEnvelope(
    Guid EventId,
    Guid AccountId,
    long DataVersion,
    string EventType,
    Guid CorrelationId,
    Guid? StopOutRunId,
    object Payload);

public interface ITradingOutboxWriter
{
    Task EnqueueAsync(
        TradingEventEnvelope envelope,
        string logicalEventKey,
        CancellationToken cancellationToken);
}
```

Serialize with the API's configured JSON options. Reject empty event type,
nonpositive data version, empty logical key, and mismatched account IDs.

- [ ] **Step 4: Implement writer and dispatcher**

The writer adds `V2TradingOutboxMessage` to the caller's DbContext without
calling `SaveChanges` independently. The dispatcher:

1. reads unpublished rows in created/event order;
2. deserializes the envelope;
3. sends the event type/payload to authenticated group
   `account:{AccountId:D}`;
4. marks `PublishedAtUtc` only after send succeeds; and
5. increments attempt/next-attempt with bounded exponential backoff on failure.

Read at most 100 rows per one-second dispatcher pass. Retry after
`1, 2, 4, 8, 16, 32, 60, 60, 60, 60` seconds. After ten failed attempts,
leave the row unpublished, set quarantine metadata, and report unhealthy
status without deleting it.

- [ ] **Step 5: Replace direct post-commit trading publishes**

In `SqlTradingService`, enqueue order/position/deal/history/summary events
inside the mutation transaction. Remove direct hub calls from the close flow.
Retain the public event names until the new typed Stop Out events arrive.

- [ ] **Step 6: Run focused and lifecycle tests**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~TradingEventEnvelopeTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~TradingOutboxTests|FullyQualifiedName~MarketOrderLifecycleTests"
```

Expected: commit-order/retry/dedupe tests and existing lifecycle cases pass.

- [ ] **Step 7: Commit the transactional outbox**

```bash
git add src/ExV2.Application/Realtime/RealtimeContracts.cs src/ExV2.Infrastructure/Realtime/SqlTradingOutboxWriter.cs src/ExV2.Api/Realtime/TradingOutboxDispatcher.cs src/ExV2.Api/Realtime/TradingHub.cs src/ExV2.Api/Program.cs src/ExV2.Infrastructure/Trading/SqlTradingService.cs tests/ExV2.IntegrationTests/TradingOutboxTests.cs tests/ExV2.UnitTests/TradingEventEnvelopeTests.cs
git commit -m "feat: publish trading events through outbox"
```

---

### Task 6: Extract Common Position Execution and Create Real Exit Orders

**Files:**
- Create: `/opt/ex-v2-api-src/src/ExV2.Application/Trading/PositionExecutionContracts.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlPositionExecutionService.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlTradingService.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Mappings/DealDtoMapper.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Mappings/LegacyDtoMapper.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Modify: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs`
- Modify: `/opt/ex-v2-api-src/tests/ExV2.UnitTests/TradingRulesTests.cs`

**Interfaces:**
- Consumes: locked account/position state, frozen exit price, nullable requested volume, reason, command key, correlation ID, and optional Stop Out run ID.
- Produces: `IPositionExecutionService.ExecuteCloseAsync(PositionExecutionCommand, CancellationToken)` and `PositionExecutionResult` without committing independently.

- [ ] **Step 1: Add failing manual-close execution tests**

Cover:

- null/omitted volume recalculates full remaining after lock;
- numeric full and partial close;
- zero/negative/over-remaining/invalid lot-step rejection;
- BUY creates SELL/out exit order/deal and no SELL position;
- SELL creates BUY/out exit order/deal and no BUY position;
- closing deal `OrderId` points to exit order and `OpeningOrderId` to entry;
- Balance applies rounded profit/commission/swap/net once; and
- same command key replays without duplicate order/deal.

- [ ] **Step 2: Run focused lifecycle tests and verify RED**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~MarketOrderLifecycleTests
```

Expected: new assertions fail because close has no exit order/common service.

- [ ] **Step 3: Define execution commands/results**

```csharp
public sealed record PositionExecutionCommand(
    Guid TradingAccountId,
    Guid PositionId,
    decimal? RequestedVolume,
    decimal ExitPrice,
    string Currency,
    string ExecutionReason,
    string ServerCommandKey,
    Guid CorrelationId,
    Guid? StopOutRunId);

public sealed record PositionExecutionResult(
    Guid PositionId,
    Guid ClosingOrderId,
    Guid DealId,
    decimal ClosedVolume,
    decimal RemainingVolume,
    decimal GrossProfit,
    decimal Commission,
    decimal Swap,
    decimal NetProfit,
    decimal BalanceAfter);

public interface IPositionExecutionService
{
    Task<PositionExecutionResult> ExecuteCloseAsync(
        PositionExecutionCommand command,
        CancellationToken cancellationToken);
}
```

- [ ] **Step 4: Implement execution without starting or committing a transaction**

Require an active transaction/account lock. Re-read the position, calculate
`closeVolume = RequestedVolume ?? RemainingVolume`, validate against current
remaining/lot step, create role `exit` order, create opposite-side `out` deal,
update position and legacy order, and apply rounded net profit to Balance and
stored Equity exactly once. Use `ServerCommandKey`/unique constraints for
replay. Never call market, hub, or `CommitAsync` from this service.

- [ ] **Step 5: Refactor manual close to call the common execution service**

`SqlTradingService.ClosePositionAsync` fetches the quote before SQL
transaction, acquires the account lock, selects Bid for BUY/Ask for SELL,
calls `ExecuteCloseAsync`, writes idempotency/audit/version/outbox, commits,
and returns the mapped committed position result.

- [ ] **Step 6: Run rules, lifecycle, compatibility, and OpenAPI tests**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~TradingRulesTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~MarketOrderLifecycleTests
dotnet test tests/ExV2.CompatibilityTests/ExV2.CompatibilityTests.csproj
```

Expected: exact volume, exit-order/history links, idempotency, and legacy
compatibility pass.

- [ ] **Step 7: Commit common execution**

```bash
git add src/ExV2.Application/Trading/PositionExecutionContracts.cs src/ExV2.Infrastructure/Trading/SqlPositionExecutionService.cs src/ExV2.Infrastructure/Trading/SqlTradingService.cs src/ExV2.Infrastructure/Mappings/DealDtoMapper.cs src/ExV2.Infrastructure/Mappings/LegacyDtoMapper.cs src/ExV2.Api/Program.cs tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs tests/ExV2.UnitTests/TradingRulesTests.cs
git commit -m "feat: persist canonical position exit executions"
```

---

### Task 7: Implement the Atomic Stop Out and D-null State Machine

**Files:**
- Create: `/opt/ex-v2-api-src/src/ExV2.Application/Trading/AccountRiskContracts.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Trading/SqlStopOutService.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/StopOutLifecycleTests.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/StopOutConcurrencyTests.cs`

**Interfaces:**
- Consumes: account ID and one immutable, complete, fresh `AccountQuoteSnapshot`.
- Produces: `IAccountRiskService.EvaluateAndExecuteAsync`, implemented by `SqlStopOutService`, plus persisted risk state, one optional completed run, complete closing/cancellation history, final zero Balance/Equity, audit, version, and outbox events.

- [ ] **Step 1: Write failing Stop Out lifecycle tests**

Create isolated SQL fixtures for:

```csharp
[Theory]
[InlineData("0.01", false)]
[InlineData("0.00", true)]
[InlineData("-0.01", true)]
public async Task Equity_threshold_is_exact(string equityRaw, bool executes)
```

Parse `equityRaw` with `decimal.Parse(equityRaw,
CultureInfo.InvariantCulture)` inside the test before arranging the fixture.

Add cases for all positions closed, all pending orders canceled, deterministic
worst-loss ordering, positive/zero/negative post-close balance, exact `D-null`
amount, commission/swap before adjustment, complete history links, final
Balance/Equity zero, no opposite position, and original history preserved.

- [ ] **Step 2: Write failing concurrency/recovery tests**

Use two service scopes and fault injection to prove:

- two simultaneous ticks produce one run/execution set;
- manual close racing Stop Out cannot over-close;
- retry after commit returns the completed run;
- exception before commit leaves no run/deal/cancellation/adjustment/outbox;
- duplicate logical events are impossible; and
- stale/incomplete snapshot is rejected before financial writes.

- [ ] **Step 3: Run focused tests and verify RED**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~StopOutLifecycleTests|FullyQualifiedName~StopOutConcurrencyTests"
```

Expected: missing contracts/service failures.

- [ ] **Step 4: Define quote snapshot and service contracts**

```csharp
public sealed record AccountQuote(
    string Symbol,
    decimal Bid,
    decimal Ask,
    DateTimeOffset SourceTimeUtc,
    long Sequence);

public sealed record AccountQuoteSnapshot(
    string SnapshotId,
    DateTimeOffset CapturedAtUtc,
    IReadOnlyDictionary<string, AccountQuote> Quotes);

public sealed record StopOutEvaluationResult(
    long RiskVersion,
    decimal Equity,
    bool Triggered,
    Guid? StopOutRunId,
    long? DataVersion);

public enum StopOutExecutionMode
{
    ObserveOnly,
    Execute
}

public interface IAccountRiskService
{
    Task<StopOutEvaluationResult> EvaluateAndExecuteAsync(
        Guid tradingAccountId,
        AccountQuoteSnapshot snapshot,
        StopOutExecutionMode mode,
        CancellationToken cancellationToken);
}

public interface IStopOutService : IAccountRiskService
{
}
```

- [ ] **Step 5: Implement the locked transactional state machine**

Follow the exact 16-step Stop Out Transaction in the spec. Validate every
position symbol exists in the frozen snapshot and every source time is no more
than 30 seconds old. Set `RiskVersion` to the locked prior value plus one. For
`Equity > 0`, commit the risk row only. For `Equity <= 0`, insert/replay the unique run, call common
execution for every sorted position, cancel every pending order with
`ExecutionReason = stop-out`, calculate post-close Balance, insert one
`NegativeBalanceProtection` adjustment when negative, assert final Balance and
Equity equal zero, increment data version once, enqueue typed events, mark run
completed, and commit.

Use deterministic command keys:

- close: `stop-out:{runId:D}:position:{positionId:D}`;
- cancel: `stop-out:{runId:D}:cancel:{orderId:D}`;
- adjustment uniqueness: `(runId, NegativeBalanceProtection)`; and
- event: `stop-out:{runId:D}:event:{eventType}:{entityId-or-runId}`.

When mode is `ObserveOnly`, calculate and persist risk state but do not create a
run, close/cancel, adjust, bump public data version, or enqueue trading events.
The worker passes the mode explicitly; the service never reads process-global
feature flags.

- [ ] **Step 6: Run focused lifecycle/concurrency tests**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~StopOutLifecycleTests|FullyQualifiedName~StopOutConcurrencyTests"
```

Expected: every threshold, atomicity, idempotency, race, history, and D-null
case passes.

- [ ] **Step 7: Run complete server tests**

```bash
dotnet test ExV2.sln --no-build
```

Expected: zero failures and no SQL integration test early exit.

- [ ] **Step 8: Commit the Stop Out state machine**

```bash
git add src/ExV2.Application/Trading/AccountRiskContracts.cs src/ExV2.Infrastructure/Trading/SqlStopOutService.cs src/ExV2.Api/Program.cs tests/ExV2.IntegrationTests/StopOutLifecycleTests.cs tests/ExV2.IntegrationTests/StopOutConcurrencyTests.cs
git commit -m "feat: execute atomic automatic stop out"
```

---

### Task 8: Add Hybrid Market Tick Intake, Coalescing, and Reconciliation

**Files:**
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/ExV2.Infrastructure.csproj`
- Create: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Market/SignalRMarketTickSource.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Market/MarketPriceClient.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Api/Realtime/MarketRiskWorker.cs`
- Create: `/opt/ex-v2-api-src/src/ExV2.Api/Realtime/RiskWorkerOptions.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.UnitTests/MarketRiskWorkerTests.cs`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/MarketRiskReconciliationTests.cs`

**Interfaces:**
- Consumes: market `QuoteUpdated` events and REST snapshot recovery.
- Produces: latest-quote cache, bounded account single-flight queue, five-second safety sweep, startup/reconnect reconciliation, and observation/execution feature switches.

- [ ] **Step 1: Write failing tick cache and worker tests**

Prove:

- out-of-order sequence/timestamp cannot replace a newer quote;
- 100 ticks for one queued account yield one active evaluation plus at most one
  follow-up using the newest snapshot;
- different accounts can evaluate concurrently within configured capacity;
- startup and reconnect enumerate all open-position accounts;
- five-second reconciliation catches an already-negative account;
- stale/missing multi-symbol quotes requeue without calling Stop Out; and
- `StopOutExecutionEnabled = false` evaluates/persists risk but never closes.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~MarketRiskWorkerTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~MarketRiskReconciliationTests
```

Expected: missing tick source/worker/options failures.

- [ ] **Step 3: Add SignalR client dependency and latest-quote source**

Add `Microsoft.AspNetCore.SignalR.Client` version `8.0.21`. Implement:

```csharp
public interface IMarketTickSource
{
    event Func<AccountQuote, CancellationToken, Task> QuoteUpdated;
    bool TryCreateSnapshot(IReadOnlyCollection<string> symbols,
        out AccountQuoteSnapshot snapshot);
    Task StartAsync(CancellationToken cancellationToken);
}
```

Connect to the existing market hub, subscribe to `QuoteUpdated`, reject older
updates, and refresh the cache through the existing REST price client after
startup/reconnect. Do not change `/opt/server-market-api`.

Build `SnapshotId` as lowercase SHA-256 hex over UTF-8 lines sorted by symbol:
`SYMBOL|sequence|bid|ask|sourceTimeUtc-in-O-format`. This identity is diagnostic
and idempotency evidence; financial execution still validates current locked
positions against the complete snapshot.

- [ ] **Step 4: Implement worker options and queue**

```csharp
public sealed class RiskWorkerOptions
{
    public bool RiskWorkerEnabled { get; init; }
    public bool StopOutExecutionEnabled { get; init; }
    public int ReconciliationIntervalSeconds { get; init; } = 5;
    public int MaxConcurrentAccounts { get; init; } = 4;
}
```

Use a bounded `Channel<Guid>` with capacity 1024, a concurrent queued/running
set, and an account-needs-rerun marker. Query accounts through indexed open positions by
updated symbol. The full safety sweep enumerates all accounts with open
positions. Capture quotes before invoking `IAccountRiskService`.

- [ ] **Step 5: Register hosted services and disabled-by-default configuration**

Bind options from configuration, validate positive interval/concurrency, and
register tick source/worker. When `RiskWorkerEnabled` is false, do not connect
or queue. When only execution is false, pass
`StopOutExecutionMode.ObserveOnly`; otherwise pass
`StopOutExecutionMode.Execute`.

- [ ] **Step 6: Run focused worker/reconciliation tests**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~MarketRiskWorkerTests
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter FullyQualifiedName~MarketRiskReconciliationTests
```

Expected: tick ordering, coalescing, reconnect, sweep, quote rejection, and
observation-mode cases pass.

- [ ] **Step 7: Commit hybrid risk intake**

```bash
git add src/ExV2.Infrastructure/ExV2.Infrastructure.csproj src/ExV2.Infrastructure/Market/SignalRMarketTickSource.cs src/ExV2.Infrastructure/Market/MarketPriceClient.cs src/ExV2.Api/Realtime/MarketRiskWorker.cs src/ExV2.Api/Realtime/RiskWorkerOptions.cs src/ExV2.Api/Program.cs tests/ExV2.UnitTests/MarketRiskWorkerTests.cs tests/ExV2.IntegrationTests/MarketRiskReconciliationTests.cs
git commit -m "feat: evaluate account risk from market ticks"
```

---

### Task 9: Expose Versioned Authoritative History and Complete OpenAPI

**Files:**
- Modify: `/opt/ex-v2-api-src/src/ExV2.Application/Trading/TradingDtos.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Application/Accounts/AccountDtos.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Application/Realtime/RealtimeContracts.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Controllers/TradingController.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Controllers/HistoryController.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Controllers/MobileAccountController.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/OpenApi/LinkedAccountHeadersOperationFilter.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/OpenApi/DealSchemaFilter.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Realtime/LegacyChangeMonitor.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Accounts/SqlAccountReadService.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Mappings/DealDtoMapper.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Infrastructure/Mappings/LegacyDtoMapper.cs`
- Modify: `/opt/ex-v2-api-src/docs/openapi-v2.json`
- Create: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/StopOutHistoryContractTests.cs`
- Modify: `/opt/ex-v2-api-src/tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs`

**Interfaces:**
- Consumes: committed V2/legacy history, account sync version, closing links, and NBP ledger rows.
- Produces: unchanged response envelopes plus `X-Server-Data-Version`, optional typed history fields, complete order/deal/position/transaction history, and synchronized runtime/static OpenAPI.

- [ ] **Step 1: Write failing HTTP/history contract tests**

Assert:

- Bootstrap, orders, deals, positions, transactions, and summary responses
  include identical `X-Server-Data-Version` for an unchanged account;
- a mutation increments the version once;
- order History returns legacy entry plus V2 role `exit` without duplicates;
- exit deal returns `orderId`, `openingOrderId`, commission, swap, net profit,
  execution reason, and Stop Out run ID;
- transaction History returns one typed `D-null` adjustment;
- summary separates trading profit from adjustment and reconciles net change;
- one detected legacy change increments version under the account lock and
  enqueues one invalidation without a direct hub send;
- close Swagger documents nullable/full semantics, headers, 200 schema, and
  stable 400/401/404/409/503 responses; and
- runtime Swagger exactly matches checked-in path/schema/header coverage.

- [ ] **Step 2: Run focused contract tests and verify RED**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~StopOutHistoryContractTests|FullyQualifiedName~MarketOrderLifecycleTests"
```

Expected: header/history/OpenAPI assertions fail.

- [ ] **Step 3: Add optional DTO fields and versioned read result**

Define internally:

```csharp
public sealed record VersionedResult<T>(long DataVersion, T Value);
```

Extend deal/order/transaction DTOs with nullable additive fields from the spec.
Add `Adjustment` to History summary while keeping it separate from
`RealizedProfit`; `NetChange` includes its Balance effect. Keep public JSON
envelopes/lists unchanged. Controllers write:

```csharp
Response.Headers["X-Server-Data-Version"] = result.DataVersion.ToString(
    CultureInfo.InvariantCulture);
return Ok(result.Value);
```

- [ ] **Step 4: Make reads version-consistent**

`GetBootstrapAsync` uses snapshot isolation when available; otherwise read
version before/after and retry the complete read when it changes. Every
History reader fetches its rows and version in one transaction. Do not bump
public data version for risk-only tick updates.

`GetSummaryAsync` uses `AccountRiskRules` and the same fresh Bid/Ask, currency
rounding, contract size, leverage, commission, and swap semantics as the risk
worker. Remove the old stored-Equity/on-read-Equity split from returned API
state. After a completed Stop Out it returns the committed zero risk/account
state.

Refactor `LegacyChangeMonitor` so it cannot independently publish direct
financial SignalR events or race an account data-version increment. When it
detects an external legacy change, acquire the shared account lock, increment
one data version, and enqueue `AccountSnapshotInvalidated` through the trading
outbox. Its pre-existing unrelated dirty work must be reconciled explicitly,
not overwritten.

- [ ] **Step 5: Project complete history without heuristic dedupe**

Return legacy original orders plus V2 `Role = exit` orders. Use
`LegacyTradeOrderId` for explicit merge identity. Map new exit deal links and
money fields. Union `V2AccountAdjustments` into transactions with type
`NegativeBalanceProtection`, display code `D-null`, positive amount, before
and after Balance. Preserve all historical records and pagination ordering.

- [ ] **Step 6: Expand mutation-wide OpenAPI filters and regenerate static JSON**

Rename/generalize the header filter so all mutations document
`Idempotency-Key` and `X-Correlation-Id`, and all versioned reads document
`X-Server-Data-Version`. Regenerate `docs/openapi-v2.json` from the tested
runtime build; do not hand-edit a divergent subset.

- [ ] **Step 7: Run contract, compatibility, and complete test suites**

```bash
dotnet test tests/ExV2.IntegrationTests/ExV2.IntegrationTests.csproj --filter "FullyQualifiedName~StopOutHistoryContractTests|FullyQualifiedName~MarketOrderLifecycleTests"
dotnet test tests/ExV2.CompatibilityTests/ExV2.CompatibilityTests.csproj
dotnet test ExV2.sln --no-build
```

Expected: history/version/OpenAPI assertions pass and the complete solution has
zero failures with real SQL integration execution.

- [ ] **Step 8: Commit contracts and authoritative history**

```bash
git add src/ExV2.Application/Trading/TradingDtos.cs src/ExV2.Application/Accounts/AccountDtos.cs src/ExV2.Application/Realtime/RealtimeContracts.cs src/ExV2.Api/Controllers/TradingController.cs src/ExV2.Api/Controllers/HistoryController.cs src/ExV2.Api/Controllers/MobileAccountController.cs src/ExV2.Api/OpenApi/LinkedAccountHeadersOperationFilter.cs src/ExV2.Api/OpenApi/DealSchemaFilter.cs src/ExV2.Api/Realtime/LegacyChangeMonitor.cs src/ExV2.Infrastructure/Accounts/SqlAccountReadService.cs src/ExV2.Infrastructure/Mappings/DealDtoMapper.cs src/ExV2.Infrastructure/Mappings/LegacyDtoMapper.cs docs/openapi-v2.json tests/ExV2.IntegrationTests/StopOutHistoryContractTests.cs tests/ExV2.IntegrationTests/MarketOrderLifecycleTests.cs
git commit -m "feat: expose versioned stop out history"
```

---

### Task 10: Add Health Diagnostics and Deployment Documentation

**Files:**
- Create: `/opt/ex-v2-api-src/src/ExV2.Api/Health/TradingRiskHealthCheck.cs`
- Modify: `/opt/ex-v2-api-src/src/ExV2.Api/Program.cs`
- Modify: `/opt/ex-v2-api-src/docs/ex-v2-architecture.md`
- Modify: `/opt/ex-v2-api-src/docs/ex-v2-deployment.md`
- Modify: `/opt/ex-v2-api-src/docs/ex-v2-rollback.md`
- Modify: `/opt/ex-v2-api-src/docs/ex-v2-database-migration.md`
- Create: `/opt/ex-v2-api-src/tests/ExV2.UnitTests/TradingRiskHealthCheckTests.cs`

**Interfaces:**
- Consumes: tick-source connection/freshness, worker queue state, consecutive invariant failures, unpublished/quarantined outbox counts, and feature-switch state.
- Produces: sanitized health output and exact operational runbooks for observation, enablement, rollback, and additive-schema retention.

- [ ] **Step 1: Write failing health tests**

Assert healthy observation mode with fresh quotes, degraded stale quote cache,
unhealthy bounded invariant failures, degraded outbox backlog, unhealthy
quarantined events, and output that excludes account codes, balances, tokens,
connection strings, and payload JSON.

- [ ] **Step 2: Run tests and verify RED**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~TradingRiskHealthCheckTests
```

Expected: health check type is missing.

- [ ] **Step 3: Implement and register the health check**

Return only aggregate counters, UTC freshness age, switch state, and stable
reason codes. Register it in the existing readiness pipeline without exposing
secrets or per-account financial values.

- [ ] **Step 4: Update architecture/deploy/migration/rollback runbooks**

Document exact component ownership, both disabled-by-default switches,
five-second reconciliation, observation mode, migration `007` verification,
binary-first rollback, outbox recovery, and the prohibition on destructive SQL
rollback after Stop Out/NBP data exists.

- [ ] **Step 5: Run docs-sensitive compatibility and health tests**

```bash
dotnet test tests/ExV2.UnitTests/ExV2.UnitTests.csproj --filter FullyQualifiedName~TradingRiskHealthCheckTests
dotnet test tests/ExV2.CompatibilityTests/ExV2.CompatibilityTests.csproj
git diff --check
```

Expected: tests pass and no whitespace errors.

- [ ] **Step 6: Commit health and operational documentation**

```bash
git add src/ExV2.Api/Health/TradingRiskHealthCheck.cs src/ExV2.Api/Program.cs docs/ex-v2-architecture.md docs/ex-v2-deployment.md docs/ex-v2-rollback.md docs/ex-v2-database-migration.md tests/ExV2.UnitTests/TradingRiskHealthCheckTests.cs
git commit -m "docs: add stop out operations and health gates"
```

---

### Task 11: Run the Complete Server Release Gate and Stage the Production Rollout

**Files:**
- Verify only: all files changed in Tasks 2-10.
- Generated release: a timestamped publish directory outside the source tree.
- Create: `/opt/ex-v2-api-src/docs/ex-v2-stop-out-server-implementation-report.md`

**Interfaces:**
- Consumes: reviewed commits from Tasks 2-10, isolated SQL test evidence, migration/rollback scripts, and disabled-by-default configuration.
- Produces: a release artifact proven in observation mode, then an explicitly enabled virtual Stop Out deployment with a binary rollback point.

- [ ] **Step 1: Run the complete clean release gate**

```bash
dotnet clean ExV2.sln
dotnet build ExV2.sln -c Release
dotnet test ExV2.sln -c Release --no-build
git diff --check
git status --short
```

Expected: zero warnings/errors/failures; all SQL tests genuinely run; worktree
contains no uncommitted source changes.

- [ ] **Step 2: Rehearse migration and binary rollback on isolated SQL/release paths**

Restore a schema copy, apply `007`, run `verify_007`, start the release with
both switches false, verify health/OpenAPI, swap to the previous binary, and
verify the previous binary remains healthy with additive schema present.

- [ ] **Step 3: Create production backups using the documented commands**

Create a SQL backup under `/var/opt/mssql/backup` and a timestamped copy of
`/var/www/trochoi.top/ex-v2-api`. Record paths and checksums without printing
the environment file or connection string. Abort if either backup cannot be
verified.

- [ ] **Step 4: Apply and verify migration `007`**

Use the guarded production migration procedure in
`docs/ex-v2-database-migration.md`, then run `verify_007`. Do not execute the
rollback file.

- [ ] **Step 5: Deploy binary with execution disabled**

Publish Release output to a new timestamped directory, atomically swap the
service directory, restart `ex-v2-api.service`, and verify service, public
health, internal/public Swagger parity, database readiness, market dependency,
and outbox dispatcher. Both switches remain false.

- [ ] **Step 6: Enable observation mode only**

Set `RiskWorkerEnabled=true` and `StopOutExecutionEnabled=false` through the
existing secure environment mechanism, restart once, and verify fresh quote
age, risk evaluations, queue depth, and zero financial mutations using a
dedicated virtual test account.

- [ ] **Step 7: Enable Stop Out execution and run virtual acceptance smoke**

Set `StopOutExecutionEnabled=true`, restart once, and use only the dedicated
virtual account to demonstrate:

1. Equity greater than zero stays open;
2. Equity exactly zero closes all/cancels all;
3. Equity below zero closes all/cancels all and creates one `D-null`;
4. final Balance/Equity are zero;
5. exit deals do not create opposite positions; and
6. retry/reconnect does not duplicate records.

- [ ] **Step 8: Verify monitoring and rollback readiness**

Confirm Stop Out, outbox, quote freshness, lock contention, and error metrics
are healthy. Keep the prior binary directory and SQL backup. If any invariant
fails, set `StopOutExecutionEnabled=false` immediately and perform binary
rollback while retaining additive schema/history.

- [ ] **Step 9: Record the server handoff**

Write `docs/ex-v2-stop-out-server-implementation-report.md` containing release hash, migration verification,
test counts, health evidence, feature-switch state, virtual smoke IDs, and
rollback paths. Redact credentials, tokens, connection strings, account codes,
and financial payloads. This report becomes the input to the separate Flutter
implementation plan. Commit it with:

```bash
git add docs/ex-v2-stop-out-server-implementation-report.md
git commit -m "docs: record EX V2 stop out deployment"
```

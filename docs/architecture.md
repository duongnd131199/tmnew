# Architecture

The repository is split into two independently buildable applications:

- `mobile`: Android-first Flutter client.
- `backend`: ASP.NET Core API, application/domain layers, infrastructure,
  realtime, workers, and test projects.

Backend dependencies point inward: Application depends on Domain;
Infrastructure depends on Application and Domain; API composes Application,
Infrastructure, and Realtime; Workers composes Application and Infrastructure.

TASK-001 only establishes project boundaries and buildable entry points. No
trading, persistence, realtime feed, or external infrastructure is implemented.

## Local infrastructure

TASK-002 adds Docker Compose services for SQL Server 2022 Developer and Redis.
Both services use named volumes, health checks, a private bridge network, and
credentials supplied through an ignored `.env` file. The compose file exposes
the database ports for local development only.

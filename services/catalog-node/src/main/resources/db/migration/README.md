# Database migrations

Place this service's versioned Flyway SQL migrations in this directory.

Example filename:
  V1__create_initial_schema.sql

Rules:
- The service developer owns the schema and SQL contents.
- Use Flyway versioned migration names: V1__, V2__, V3__, etc.
- Do not edit a migration that has already been applied; add a new version.
- Rename and replace the contents of the .sql.example file before using it.
- Set migration.enabled: true only when actual .sql migration files exist.
- Platform CI uploads SQL files for the platform-managed Flyway Job.

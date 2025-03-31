/*
RayMigrator SQL-Template:
-------------------------
- DatabaseLogging_Insert
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-11-30

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\DatabaseLogging_Insert.sql

Function:
- Inserts new log-entries into logging-table on the target database (not executed by serilog but by RayMigrator-internal framework)

Available parameter:


Mandatory behaviour and return values:

--------------------------------------------------------------------------------------------------------

General instructions how to modify or create database-specific RayMigrator SQL-templates:
*/


INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationLog]
(
	[LogLevelId],
	[MigrationEventId],
	[RunModeId],
	[ProductId],
	[MigrationRunId],
	[Environment],
	[ReleaseVersion],
	[TargetGroupAlias],
	[TargetAlias],
	[Filename],
	[FileOrderId],
	[FileBlockId],
	[Message],
	[CreatedAt]
)
VALUES
(
	@LogLevelId,
	@MigrationEventId,
	@RunModeId,
	@ProductId,
	@MigrationRunId,
	@Environment,
	@ReleaseVersion,
	@TargetGroupAlias,
	@TargetAlias,
	@Filename,
	@FileOrderId,
	@FileBlockId,
	@Message,
	SYSUTCDATETIME()
);

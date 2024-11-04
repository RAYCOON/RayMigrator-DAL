/*
RayMigrator SQL-Template:
-------------------------
- Repository_Create
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-08-30

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\Repository_Create.sql

Function:
- Creates all repository-tables for the use of RayMigrator on the target database.

Mandatory behaviour:
- Returns a negative value if if the prerequisites are NOT met to use logging on the given target database.
- Returns '0' if logging-table needs to be created on the target database.
- Returns '1' if logging-table is already created on the target database.

--------------------------------------------------------------------------------------------------------

General instructions how to modify or create database-specific RayMigrator SQL-templates:

- Always (!) end this SQL-script using a SELECT '[ResultCode],[message]' command!
- Always (!) supply an ErrorMessage for 'Error'-ResultCodes below zero (-n..-1), otherwise migrations will abort with an error.
- Always (!) use a single comma to separate ResultCode from Message like SELECT '-1,My error description'

Parameter 1: ResultCode: [OK: 0..n, ERROR: -n..-1]
- ResultCodes from zero and above (0..n) will be interpreted as an 'OK' result
- ResultCodes below zero (-n..-1) will be interpreted as 'Error' and will abort migration execution
- ResultCodes below zero (-n..-1) MUST be provided with a comma-separated, trailing ErrorMessage

Parameter 2: ErrorMessage (without any comma(s) please!)
- All Messages may contain Placeholders like '{CFG:SchemaName}', {CFG:TableBaseName}
- Replacement of placeholders depends on the currently executed TemplateType:
    > All Logging_* templates will get CFG: values from the corresponding appsetting-properties in the 'Logging' section of RayMigrator
    > All Repository_* templates will get CFG: values from the corresponding appsetting-properties in the Repository-section of RayMigrator:TargetGroups[0..n]
- Messages for ResultCodes below zero (-n..-1) will be logged at LogLevel 'Error'
- Messages for 'OK' ResultCodes will be logged at LogLevel 'Debug' using Parameter 2 as message
- Do NOT use any comma(s) in your ErrorMessage or message
*/

BEGIN TRANSACTION;

BEGIN TRY

	-- Create schema section -------------------------------------------------

	IF NOT EXISTS (SELECT TOP(1) 1 FROM sys.schemas WHERE name = '{CFG:SchemaName}')
	BEGIN
		EXEC('CREATE SCHEMA {CFG:SchemaName}'); -- AUTHORIZATION dbo  -- replace 'dbo' by schema owner
	END;

	-- Create tables section -------------------------------------------------

	-- Table {CFG:SchemaName}.{CFG:TableBaseName}Migration

	CREATE TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration]
	(
	 [Id] Int IDENTITY(1,1) NOT NULL,
	 [{CFG:TableBaseName}MigrationRunId] Int NOT NULL,
	 [{CFG:TableBaseName}MigrationResultId] Tinyint NOT NULL,
     [Environment] Nvarchar(100) NOT NULL,
	 [TargetGroupAlias] Nvarchar(100) NOT NULL,
	 [TargetAlias] Nvarchar(100) NOT NULL,
	 [FileName] Nvarchar(4000) NOT NULL,
	 [FileId] Int NOT NULL,
	 [FileHash] Varchar(100) NOT NULL,
     [NumberOfBlocksInFile] Int NOT NULL,
     [BlockId] Int NOT NULL,
	 [Description] Nvarchar(1000) NULL,
	 [MigrationSettingsJson] Nvarchar(max) NOT NULL,
	 [StartedAt] Datetime2 CONSTRAINT [DF_StartedAt] DEFAULT SYSUTCDATETIME() NOT NULL,
	 [FinishedAt] Datetime2 NULL
	);
    ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT [PK_{CFG:TableBaseName}Migration] PRIMARY KEY ([Id]);
    CREATE INDEX [IX_Environment_MigGroupAlias_DestAlias_FileName] ON [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ([Environment],[TargetGroupAlias],[TargetAlias],[FileName]);

	CREATE TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunResult]
	(
	 [Id] Tinyint NOT NULL,
	 [Name] Varchar(50) NOT NULL,
	 [Description] Varchar(200) NOT NULL
	)
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunResult] ADD CONSTRAINT [PK_{CFG:TableBaseName}MigrationRunResult] PRIMARY KEY ([Id])

	CREATE TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode]
	(
	 [Id] Tinyint NOT NULL,
	 [Name] Varchar(50) NOT NULL,
	 [Description] Varchar(200) NOT NULL
	)
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode] ADD CONSTRAINT [PK_{CFG:TableBaseName}MigrationRunMode] PRIMARY KEY ([Id])

	CREATE TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult]
	(
	 [Id] Tinyint NOT NULL,
	 [Name] Varchar(50) NOT NULL,
	 [Description] Varchar(200) NOT NULL
	)
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult] ADD CONSTRAINT [PK_{CFG:TableBaseName}MigrationResult] PRIMARY KEY ([Id])

	CREATE TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]
	(
	 [Id] Int IDENTITY(1,1) NOT NULL,
	 [{CFG:TableBaseName}MigrationRunResultId] Tinyint NOT NULL,
	 [RunModeId] Tinyint NOT NULL,
	 [RayMigratorVersion] Varchar(50) NOT NULL,
	 [MigrationRunSettingsJson] Nvarchar(max) NOT NULL,
	 [StartedAt] Datetime2 CONSTRAINT [DF_Run_StartedAt] DEFAULT SYSUTCDATETIME() NOT NULL,
	 [FinishedAt] Datetime2 NULL
	)
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT [PK_{CFG:TableBaseName}MigrationRun] PRIMARY KEY ([Id])

	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT [{CFG:TableBaseName}Result_{CFG:TableBaseName}] FOREIGN KEY ([{CFG:TableBaseName}MigrationResultId]) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult] ([Id]) ON UPDATE NO ACTION ON DELETE NO ACTION
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT [{CFG:TableBaseName}RunResult_{CFG:TableBaseName}Run] FOREIGN KEY ([{CFG:TableBaseName}MigrationRunResultId]) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunResult] ([Id]) ON UPDATE NO ACTION ON DELETE NO ACTION
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT [{CFG:TableBaseName}Run_{CFG:TableBaseName}] FOREIGN KEY ([{CFG:TableBaseName}MigrationRunId]) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ([Id]) ON UPDATE NO ACTION ON DELETE NO ACTION
	ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT [{CFG:TableBaseName}RunMode_{CFG:TableBaseName}Run] FOREIGN KEY ([RunModeId]) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode] ([Id]) ON UPDATE NO ACTION ON DELETE NO ACTION


	-- Data for Table "{CFG:TableBaseName}RunResult"
	INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunResult] ([Id], [Name], [Description])
	VALUES
		(0, 'Undefined', 'Result value not set.'),
		(10, 'MigrationRunStarted', 'Migration process has started and is currently running.'),
		(50, 'ApplicationStartupException', 'RayMigrator aborted due to issue(s) during startup process.'),
		(51, 'ConfigurationValidationException', 'RayMigrator aborted due to configuration issue(s).'),
		(52, 'MigrationExecutionException', 'Error executing SQL migration file.'),
		(98, 'InternalException', 'Migration stopped due to internal error(s).'),
		(99, 'UnhandledException', 'Migration stopped due to unhandled error(s).'),
		(100, 'Ok', 'All database-migrations successfully executed.');

	-- Data for Table "{CFG:TableBaseName}RunMode"
	INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode] ([Id], [Name], [Description])
	VALUES
		(0, 'Undefined', 'Invalid RunMode value. RunMode has not been set properly.'),
		(10, 'Validate', 'Validates configuration and all migration files. Does NOT perform actual migration against target databases.'),
		(20, 'Simulate', 'Validates configuration and all migration files. Simulates the entire migration process. Does NOT perform actual migration against target databases.'),
		(100, 'Migrate', 'Validates configuration and all migration files. Performs actual migrations against target databases.');

	-- Data for Table "{CFG:TableBaseName}Result"
	INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult] ([Id], [Name], [Description])
	VALUES
		(0, 'Undefined', 'Result-value not set'),
		(10, 'Running', 'Migration is currently running'),
		(99, 'Error', 'Error executing migration step'),
		(100, 'Ok', 'Migration step successfully executed with a positive result');

	COMMIT TRANSACTION;
	
	SELECT '0,RayMigrator repository-tables with master data successfully created';

END TRY
BEGIN CATCH
    
	-- Rollback transaction on error
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    DECLARE @ErrorInfo NVARCHAR(MAX);

    SET @ErrorInfo =
        'Error Number: [' + ISNULL(CAST(REPLACE(ERROR_NUMBER(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Severity: [' + ISNULL(CAST(REPLACE(ERROR_SEVERITY(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error State: [' + ISNULL(CAST(REPLACE(ERROR_STATE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Line: [' + ISNULL(CAST(REPLACE(ERROR_LINE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Message: ' + ISNULL(REPLACE(ERROR_MESSAGE(), ',','-'), N'NULL');

	SELECT '-99,Error executing MSSqlServer\Templates\Repository_Create.sql: Could NOT create RayMigrator repository. ErrorInfo: ' + @ErrorInfo;

END CATCH;

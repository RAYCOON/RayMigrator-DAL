/*
[RayMigratorTemplate]
TemplateType = "Repository_CheckCreate"
DatabaseType = "SqlServer"
Author = "RAYCOON.com GmbH (https://raycoon.com)"
Version = "2025-02-12.1"
Function: "Checks for repository existence and completeness. Creates RayMigrator infrastructure on the target database if necessary. Returns the VersionId."
Behaviour = """
- Returns a negative value on error.
- Returns a positive value as existing or new VersionId.
"""
Parameter = """
- @RayMigratorVersion: The RayMigrator version number, e.g. 1.0.3.2
- @RepositoryDatabaseType: The DatabaseType the repository resides in, e.g. SqlServer
"""
*/
/*
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

-- Mandatory RepositoryVersion: DO NOT change manually, otherwise repository-inconsistencies may occur that results in migration errors !!!
DECLARE @RepositoryVersion VARCHAR(20) = '2025-02-12.1';
--DECLARE @RayMigratorVersion varchar(20) = '2025-02-13.1';
--DECLARE @RepositoryDatabaseType varchar(20) = 'SqlServer';

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY

	DECLARE 
		@VersionId INT,
		@VersionIdString VARCHAR(10),
		@NumberOfRows INT,
		@NumberOfTablesFound INT;

	SELECT 
		@NumberOfTablesFound = COUNT(*) 
	FROM sys.tables t
	INNER JOIN sys.schemas s 
		ON t.schema_id = s.schema_id
	WHERE 
		s.name = '{CFG:SchemaName}'
		AND t.name IN (
			'{CFG:TableBaseName}MigratorVersion',
			'{CFG:TableBaseName}Product',
			'{CFG:TableBaseName}MigrationRun',
			'{CFG:TableBaseName}MigrationRunMeta',
			'{CFG:TableBaseName}Migration',
			'{CFG:TableBaseName}MigrationHistory',
			'{CFG:TableBaseName}MigrationRunMode',
			'{CFG:TableBaseName}MigrationOperation',
			'{CFG:TableBaseName}MigrationResult',
			'{CFG:TableBaseName}MigrationState'
		);

	BEGIN TRANSACTION;

		-- Check for [Version]-Table and therefore for repository-existence

		IF OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigratorVersion', 'U') IS NOT NULL
		BEGIN

			-- Check for repository completeness
			IF (@NumberOfTablesFound != 10)
			BEGIN
				COMMIT TRANSACTION;

				SELECT '-1,RayMigrator repository incomplete or corrupt. Repository contains [' + CAST(@NumberOfTablesFound AS VARCHAR(10)) + '] tables instead of [11].';
				RETURN;
			END;

			-- Try to get VersionId
			SELECT 
				@VersionId = Id
			FROM 
				[{CFG:SchemaName}].[{CFG:TableBaseName}MigratorVersion] WITH (TABLOCKX, HOLDLOCK)
			WHERE 
				RepositoryVersion = @RepositoryVersion
				AND RepositoryDatabaseType = @RepositoryDatabaseType
				AND CreatedByRayMigratorVersion = @RayMigratorVersion;

			SET @NumberOfRows = @@rowcount;

			IF (@NumberOfRows = 1)
			BEGIN
				SET @VersionIdString = CAST(@VersionId AS VARCHAR(10));

				COMMIT TRANSACTION;
				SELECT @VersionIdString + ',RayMigrator repository already exists. Using VersionId [' + @VersionIdString + '].';
				RETURN;
			END
			ELSE IF (@NumberOfRows = 0)
			BEGIN

				-- VersionId does not yet exist. Create new VersionId
				INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigratorVersion] 
				(
					RepositoryVersion,
					RepositoryDatabaseType,
					CreatedByRayMigratorVersion,
					CreatedAt
				) 
				VALUES 
				(
					@RepositoryVersion,
					@RepositoryDatabaseType,
					@RayMigratorVersion,
					SYSUTCDATETIME()
				);

				SET @VersionId = SCOPE_IDENTITY();

				COMMIT TRANSACTION;
				SET @VersionIdString = CAST(@VersionId AS VARCHAR(10));
				SELECT @VersionIdString + ',RayMigrator repository already exists. New VersionId [' + @VersionIdString + '] created.';
				RETURN;

			END
			ELSE
			BEGIN
				ROLLBACK TRANSACTION;

				DECLARE @ErrorString VARCHAR(MAX);
				SET @ErrorString = 'Multiple [MigratorVersion]-entries found for RepositoryVersion [' + ISNULL(@RepositoryVersion,'NULL') + '], RepositoryDatabaseType [' + ISNULL(@RepositoryDatabaseType,'NULL') + '], RayMigratorVersion [' + ISNULL(@RayMigratorVersion,'NULL') + '].';
				SELECT '-1,' + @ErrorString;
				RETURN;
			END;

		END;


		-- No [Version]-Table found. Check for repository-existence and completeness
		IF (@NumberOfTablesFound != 0)
		BEGIN
			ROLLBACK TRANSACTION;

			SELECT '-1,RayMigrator repository incomplete or corrupt. Repository contains [' + CAST(@NumberOfTablesFound AS VARCHAR(10)) + '] tables instead of the expected amount of [0].';
			RETURN;
		END;

		-- Create Schema if not exist
		IF SCHEMA_ID('{CFG:SchemaName}') IS NULL EXECUTE('CREATE SCHEMA [{CFG:SchemaName}];'); -- AUTHORIZATION ???

		-- Create repository
CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationOperation] ( 
	Id                   tinyint      NOT NULL,
	Name                 varchar(100)      NULL,
	Description          nvarchar(1000)      NULL,
	CONSTRAINT pk_MigrationOperation PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult] ( 
	Id                   tinyint      NOT NULL,
	Name                 varchar(100)      NOT NULL,
	Description          nvarchar(1000)      NULL,
	CONSTRAINT pk_MigrationResult PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode] ( 
	Id                   tinyint      NOT NULL,
	Name                 varchar(100)      NOT NULL,
	Description          nvarchar(1000)      NULL,
	CONSTRAINT pk_MigrationRunMode PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationState] ( 
	Id                   tinyint      NOT NULL,
	Name                 varchar(100)      NULL,
	Description          nvarchar(1000)      NULL,
	CONSTRAINT pk_MigrationState PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigratorVersion] ( 
	Id                   int    IDENTITY(1,1)  NOT NULL,
	RepositoryVersion    varchar(100)      NOT NULL,
	RepositoryDatabaseType varchar(100)      NOT NULL,
	CreatedByRayMigratorVersion varchar(100)      NOT NULL,
	CreatedAt            datetime2      NOT NULL,
	CONSTRAINT pk_RepositoryVersion PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Product] ( 
	Id                   int    IDENTITY(1,1)  NOT NULL,
	Name                 nvarchar(100)      NOT NULL,
	Description          nvarchar(1000)      NULL,
	CreatedAt            datetime2      NOT NULL,
	CONSTRAINT pk_Product PRIMARY KEY  ( Id ) ,
	CONSTRAINT [unq_{CFG:TableBaseName}Product] UNIQUE ( Name ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ( 
	Id                   int    IDENTITY(1,1)  NOT NULL,
	MigratorVersionId    int      NOT NULL,
	ProductId            int      NOT NULL,
	MigrationRunModeId   tinyint      NOT NULL,
	MigrationResultId    tinyint      NOT NULL,
	Environment          nvarchar(100)      NOT NULL,
	FromReleaseVersion   nvarchar(100)      NULL,
	ToReleaseVersion     nvarchar(100)      NULL,
	StartedAt            datetime2      NOT NULL,
	FinishedAt           datetime2      NULL,
	DurationInMs         bigint      NULL,
	CONSTRAINT pk_MigrationRun PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMeta] ( 
	MigrationRunId       int      NOT NULL,
	MigrationRunSettingsJson nvarchar(max)      NULL,
	Description          nvarchar(max)      NULL,
	CONSTRAINT pk_MigrationRunMeta PRIMARY KEY  ( MigrationRunId ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ( 
	Id                   int    IDENTITY(1,1)  NOT NULL,
	ProductId            int      NOT NULL,
	MigrationRunId       int      NOT NULL,
	MigrationRunModeId   tinyint      NOT NULL,
	MigrationOperationId tinyint      NOT NULL,
	MigrationResultId    tinyint      NOT NULL,
	MigrationStateId     tinyint      NOT NULL,
	Environment          nvarchar(100)      NOT NULL,
	ReleaseVersion       nvarchar(100)      NOT NULL,
	TargetGroupAlias     nvarchar(100)      NOT NULL,
	TargetAlias          nvarchar(100)      NOT NULL,
	Filename             nvarchar(200)      NOT NULL,
	FileOrderId          int      NOT NULL,
	FileUpHash           varchar(100)      NOT NULL,
	FileUpConfigHash     varchar(100)      NULL,
	FileUpBlocksHash     varchar(100)      NOT NULL,
	FileUpBlocksMigrated int      NOT NULL,
	FileUpBlocksTotal    int      NOT NULL,
	FileUpConfigJson     varchar(max)      NULL,
	MigrateDownFileExists bit      NOT NULL,
	FileDownHash         varchar(100)      NULL,
	FileDownConfigHash   varchar(100)      NULL,
	FileDownBlocksHash   varchar(100)      NULL,
	FileDownBlocksMigrated int      NULL,
	FileDownBlocksTotal  int      NULL,
	FileDownConfigJson   varchar(max)      NULL,
	StartedAt            datetime2      NULL,
	FinishedAt           datetime2      NULL,
	DurationInMs         bigint      NULL,
	CONSTRAINT pk_Migration PRIMARY KEY  ( Id ) 
 );


CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationHistory] ( 
	Id                   int    IDENTITY(1,1)  NOT NULL,
	MigrationId          int      NOT NULL,
	ProductId            int      NOT NULL,
	MigrationRunId       int      NOT NULL,
	MigrationRunModeId   tinyint      NOT NULL,
	MigrationOperationId tinyint      NOT NULL,
	MigrationResultId    tinyint      NOT NULL,
	MigrationStateId     tinyint      NOT NULL,
	Environment          nvarchar(100)      NOT NULL,
	ReleaseVersion       nvarchar(100)      NOT NULL,
	TargetGroupAlias     nvarchar(100)      NOT NULL,
	TargetAlias          nvarchar(100)      NOT NULL,
	Filename             nvarchar(200)      NOT NULL,
	FileOrderId          int      NOT NULL,
	FileUpHash           varchar(100)      NOT NULL,
	FileUpConfigHash     varchar(100)      NULL,
	FileUpBlocksHash     varchar(100)      NOT NULL,
	FileUpBlocksMigrated int      NOT NULL,
	FileUpBlocksTotal    int      NOT NULL,
	FileUpConfigJson     varchar(max)      NULL,
	MigrateDownFileExists bit      NOT NULL,
	FileDownHash         varchar(100)      NULL,
	FileDownConfigHash   varchar(100)      NULL,
	FileDownBlocksHash   varchar(100)      NULL,
	FileDownBlocksMigrated int      NULL,
	FileDownBlocksTotal  int      NULL,
	FileDownConfigJson   varchar(max)      NULL,
	StartedAt            datetime2      NULL,
	FinishedAt           datetime2      NULL,
	DurationInMs         bigint      NULL,
	CONSTRAINT pk_MigrationHistory PRIMARY KEY  ( Id ) 
 );


CREATE  INDEX ix_MigrationHistory ON [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationHistory] ( MigrationId );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_Product FOREIGN KEY ( ProductId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}Product]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_MigrationRun FOREIGN KEY ( MigrationRunId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_MigrationRunMode FOREIGN KEY ( MigrationRunModeId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_MigrationOperation FOREIGN KEY ( MigrationOperationId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationOperation]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_MigrationState FOREIGN KEY ( MigrationStateId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationState]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}Migration] ADD CONSTRAINT fk_Migration_MigrationResult FOREIGN KEY ( MigrationResultId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationHistory] ADD CONSTRAINT fk_MigrationHistory_MigrationRun FOREIGN KEY ( MigrationRunId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationHistory] ADD CONSTRAINT fk_MigrationHistory_Migration FOREIGN KEY ( MigrationId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}Migration]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationHistory] ADD CONSTRAINT fk_MigrationHistory_Product FOREIGN KEY ( ProductId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}Product]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT fk_MigrationRun_Product FOREIGN KEY ( ProductId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}Product]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT fk_MigrationRun_MigrationResult FOREIGN KEY ( MigrationResultId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT fk_MigrationRun_MigrationRunMode FOREIGN KEY ( MigrationRunModeId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] ADD CONSTRAINT fk_MigrationRun_MigratorVersion FOREIGN KEY ( MigratorVersionId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigratorVersion]( Id );


ALTER TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMeta] ADD CONSTRAINT fk_MigrationRunMeta_MigrationRun FOREIGN KEY ( MigrationRunId ) REFERENCES [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]( Id );


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'- Rollback (MigrateDown) = 5
- MigrateDown = 50
- MigrateUp = 100' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationOperation';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Unprocessed = 1,
Running = 10,
Skipped = 11,
Error= 99,
Success = 100' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationResult';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Validate = 10,
Simulate = 20,
Migrate = 100' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationRunMode';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'- Unclear = 10
  (Error on: Rollback, MigrateDown or MigrateUp w/o .down-File)
- NotMigrated = 50 
  (Migration not yet performed, RolledBack, Skipped or Ignored)
- Migrated = 100
  (MigrateUp successful)' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationState';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'From Repository''s create-script (sql-file)' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigratorVersion', @level2type=N'COLUMN',@level2name=N'RepositoryVersion';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'From appsettings.json Repository configuration' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigratorVersion', @level2type=N'COLUMN',@level2name=N'RepositoryDatabaseType';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'From RayMigrator-build' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigratorVersion', @level2type=N'COLUMN',@level2name=N'CreatedByRayMigratorVersion';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'= RayMigratorSettings for current product' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationRunMeta', @level2type=N'COLUMN',@level2name=N'MigrationRunSettingsJson';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Represents all migration-files found at time of last migration attempt' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Environment of the migration target (DEV, QA, PROD)' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'Environment';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'1st part of the path of the FilenameWithRelativePath' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'ReleaseVersion';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'2nd part of the path of the FilenameWithRelativePath' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'TargetGroupAlias';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The alias of the target database' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'TargetAlias';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Filename without (relative) path since relative path consists of ReleaseVersion, TargetGroupAlias and Filename' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'Filename';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The Id of the file''s occurence ordered by the FilenameWithRelative path - which contains of ReleaseVersion, TargetGroupAlias and Filename' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileOrderId';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash value of the entire file' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the [RayMigrator] configuration section''s content that may be empty' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpConfigHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the file''s content - excluding the [RayMigrator] configuration section''s content. Therefore it only remains the content to be executed against the target-database.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpBlocksHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The amount of blocks within a migration-file, delimited by "GO" or "\" that have already been successfully migrated' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpBlocksMigrated';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The total number of blocks - separated by a delimiter like ''GO'' or Backslash - found within the migration-file''s content.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpBlocksTotal';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'IMigrationFileSettings' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileUpConfigJson';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'True if a corresponding migration.down.sql - file exists' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'MigrateDownFileExists';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash value of the entire file' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileDownHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the [RayMigrator] configuration section''s content that may be empty' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileDownConfigHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the file''s content - excluding the [RayMigrator] configuration section''s content. Therefore it only remains the content to be executed against the target-database.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileDownBlocksHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The number of blocks - separated by a delimiter like ''GO'' or Backslash - found within the migration-file''s content.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}Migration', @level2type=N'COLUMN',@level2name=N'FileDownBlocksTotal';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Represents all migration-files found at time of last migration attempt' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory';;


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Environment of the migration target (DEV, QA, PROD)' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'Environment';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'1st part of the path of the FilenameWithRelativePath' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'ReleaseVersion';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'2nd part of the path of the FilenameWithRelativePath' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'TargetGroupAlias';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The alias of the target database' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'TargetAlias';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Filename without (relative) path since relative path consists of ReleaseVersion, TargetGroupAlias and Filename' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'Filename';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The Id of the file''s occurence ordered by the FilenameWithRelative path - which contains of ReleaseVersion, TargetGroupAlias and Filename' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileOrderId';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash value of the entire file' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the [RayMigrator] configuration section''s content that may be empty' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpConfigHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the file''s content - excluding the [RayMigrator] configuration section''s content. Therefore it only remains the content to be executed against the target-database.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpBlocksHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The amount of blocks within a migration-file, delimited by "GO" or "\" that have already been successfully migrated' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpBlocksMigrated';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The total number of blocks - separated by a delimiter like ''GO'' or Backslash - found within the migration-file''s content.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpBlocksTotal';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'IMigrationFileSettings' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileUpConfigJson';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'True if a corresponding migration.down.sql - file exists' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'MigrateDownFileExists';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash value of the entire file' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileDownHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the [RayMigrator] configuration section''s content that may be empty' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileDownConfigHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'Hash of the file''s content - excluding the [RayMigrator] configuration section''s content. Therefore it only remains the content to be executed against the target-database.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileDownBlocksHash';


execute sys.sp_addextendedproperty  @name=N'MS_Description', @value=N'The number of blocks - separated by a delimiter like ''GO'' or Backslash - found within the migration-file''s content.' , @level0type=N'SCHEMA',@level0name=N'{CFG:SchemaName}', @level1type=N'TABLE',@level1name=N'{CFG:TableBaseName}MigrationHistory', @level2type=N'COLUMN',@level2name=N'FileDownBlocksTotal';





		-- Data for Table "MigrationRunMode"
		INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode] ([Id], [Name], [Description])
		VALUES
			(10, 'Validate', 'Validates configuration and all migration files. Does NOT perform actual migration against target databases.'),
			(20, 'Simulate', 'Validates configuration and all migration files. Simulates the entire migration process. Does NOT perform actual migrations against target databases.'),
			(100, 'Migrate', 'Validates configuration and all migration files. Performs actual migrations against target databases.');

		-- Data for Table "MigrationOperation"
		INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationOperation] ([Id], [Name], [Description])
		VALUES
			(5, 'Rollback', 'Performing Rollback of current MigrationRun'),
			(50, 'MigrateDown', 'Performing Down-Migration'),
			(100, 'MigrateUp', 'Performing Up-Migration');

		-- Data for Table "MigrationResult"
		INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult] ([Id], [Name], [Description])
		VALUES
			(1, 'Unprocessed', 'Migration-file was found but has neither been processed nor migrated'),
			(10, 'Running', 'Migration process is currently running'),
			(11, 'Skipped', 'Migration process was skipped'),
            (90, 'Error', 'Migration(s) stopped due to error(s)'),
            (91, 'ManuallyTerminatedByFix', 'Migration(s) remained in a problematic or unclear state and were manually set to a terminated state'),
			(100, 'Ok', 'Migration(s) successfully executed');

		-- Data for Table "MigrationState"
		INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationState] ([Id], [Name], [Description])
		VALUES
			(10, 'Unclear', 'Migration process is currently running'),
			(11, 'NotMigrated', 'Migration process was skipped'),
			(99, 'Migrated', 'Migration(s) stopped due to error(s)');


		-- Create VersionId
		INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigratorVersion] 
		(
			RepositoryVersion,
			RepositoryDatabaseType,
			CreatedByRayMigratorVersion,
			CreatedAt
		)
		VALUES 
		(
			@RepositoryVersion,
			@RepositoryDatabaseType,
			@RayMigratorVersion,
			SYSUTCDATETIME()
		);

		SET @VersionId = SCOPE_IDENTITY();

		COMMIT TRANSACTION;

		SET @VersionIdString = CAST(@VersionId AS VARCHAR(10));
		SELECT @VersionIdString + ',RayMigrator repository-tables with master data and new VersionId [' + @VersionIdString + '] successfully created';

END TRY
BEGIN CATCH
    
    -- Rollback transaction on error
    IF (@@TRANCOUNT > 0)
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    ;THROW;
	
END CATCH;

/*
[RayMigratorTemplate]
TemplateType = "Repository_CheckCreate"
DatabaseType = "SqlServer"
Author = "RAYCOON.com GmbH (https://raycoon.com)"
Version = "2025-02-12.1"
Function = "Checks for repository existence and completeness. Creates RayMigrator infrastructure on the target database if necessary. Returns the VersionId."
Behaviour = """
- Returns a negative value on error.
- Returns '0' if logging-tables did already exist on the target database.
- Returns '1' if logging-table were created on the target database.
"""
Parameter = """
RayMigrator provides no parameters for this template.
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
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY

        IF (OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigrationLog', 'U') IS NULL)
        BEGIN
			
			BEGIN TRANSACTION;

				IF SCHEMA_ID('{CFG:SchemaName}') IS NULL EXECUTE('CREATE SCHEMA [{CFG:SchemaName}];'); -- AUTHORIZATION ???
		
				CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationEvent] ( 
					Id                   int      NOT NULL,
					Name                 varchar(100)      NOT NULL,
					Description          nvarchar(1000)      NULL,
					CONSTRAINT pk_MigrationEvent PRIMARY KEY  ( Id ) 
				 );


				CREATE  TABLE [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationLog] ( 
					Id                   bigint    IDENTITY(1,1)  NOT NULL,
					LogLevelId           tinyint      NOT NULL,
					MigrationEventId     int      NULL,
					RunModeId            tinyint      NULL,
					ProductId            int      NULL,
					MigrationRunId       int      NULL,
					Environment          nvarchar(100)      NULL,
					ReleaseVersion       nvarchar(100)      NULL,
					TargetGroupAlias     nvarchar(100)      NULL,
					TargetAlias          nvarchar(100)      NULL,
					Filename             nvarchar(300)      NULL,
					FileOrderId          int      NULL,
					FileBlockId          int      NULL,
					Message              nvarchar(max)      NULL,
					CreatedAt            datetime2  DEFAULT SYSUTCDATETIME()    NOT NULL,
					CONSTRAINT pk_Log PRIMARY KEY  ( Id ) 
				 );


				-- Master data: MigrationEvent
				INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationEvent] ([Id], [Name], [Description])
				VALUES
					(0, 'UnspecifiedEvent', N''),
					(10, 'CommandLineParsing', N''),
					(20, 'EnvironmentVariableReplacement', N''),
					(31, 'CreateDatabaseLogger', N''),
					(32, 'CreateCompositeLogger', N''),
					(40, 'ValidateRayMigratorOptions', N''),
					(50, 'CreateApplicationHost', N''),
					(60, 'InitializeDalSpecificProperties', N''),
					(70, 'ValidateConnectionStrings', N''),
					(80, 'RayMigratorServiceStart', N''),
					(100, 'CreateAndStartRayMigratorService', N''),
					(1000, 'RayMigratorServiceShutdown', N'');

			COMMIT TRANSACTION;
			
			SELECT '1,Database logging infrastructure successfully created';
			RETURN;

		END
		ELSE
		BEGIN

		    SELECT '0,Database logging infrastructure already exists';
			RETURN;

		END;

END TRY
BEGIN CATCH
    
    -- Rollback transaction on error
    IF (@@TRANCOUNT > 0)
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    ;THROW;
	
END CATCH;


/*
RayMigrator SQL-Template:
-------------------------
- DatabaseLogging_Insert
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-08-07

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\DatabaseLogging_Insert.sql

Function:
- Inserts new log-entries into logging-table on the target database (not executed by serilog but by RayMigrator-internal framework)

Available parameter:
- @LogLevelId
- @EventId
- @Message
- @MigrationRunId
- @MigrationId
- @MigrationBlockId

Mandatory behaviour and return values:
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

BEGIN TRY


    INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}Log]
    (
        [LogLevelId],
        [EventId],
        [MigrationRunId],
        [MigrationId],
        [TargetGroupAlias],
        [TargetAlias],
        [MigrationFilename],
        [MigrationFileId],
        [MigrationBlockId],
        [Message],
        [CreatedAt]
    )
    VALUES
    (
        @LogLevelId,
        @EventId,
        @MigrationRunId,
        @MigrationId,
        @TargetGroupAlias,
        @TargetAlias,
        @MigrationFilename,
        @MigrationFileId,
        @MigrationBlockId,
        @Message,
        SYSUTCDATETIME()
    );

	-- Result: OK	
	-- SELECT '0'; -- Disabled due to ExecuteScalar

END TRY
BEGIN CATCH
    
	-- Rollback transaction on error
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

	;THROW; -- Changed due to ExcecuteScalar

 --   DECLARE @ErrorInfo NVARCHAR(MAX);

 --   SET @ErrorInfo =
 --       'Error Number: [' + ISNULL(CAST(REPLACE(ERROR_NUMBER(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
 --       'Error Severity: [' + ISNULL(CAST(REPLACE(ERROR_SEVERITY(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
 --       'Error State: [' + ISNULL(CAST(REPLACE(ERROR_STATE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
 --       'Error Line: [' + ISNULL(CAST(REPLACE(ERROR_LINE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
 --       'Error Message: ' + ISNULL(REPLACE(ERROR_MESSAGE(), ',','-'), N'NULL');

	--SELECT '-99,Error executing MSSqlServer\Templates\DatabaseLogging_Insert.sql: Could NOT insert database logging entry. ErrorInfo: ' + @ErrorInfo;

END CATCH;

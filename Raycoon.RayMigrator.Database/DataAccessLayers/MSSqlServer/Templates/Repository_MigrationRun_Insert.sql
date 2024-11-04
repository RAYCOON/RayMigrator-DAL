/*
RayMigrator SQL-Template:
-------------------------
- Repository_MigrationRun_Insert
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-07-04

################################
ToDo: 
   Modify info about ResultCode and ErrorMessage since it does not apply here!
################################

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\Repository_MigrationRun_Insert.sql

Function:
- Insert the state and result of an entire migration-run into the RayMigrator repository.

Mandatory behaviour:
- Returns a positive identity value > 0 if a new entry has been created in the repository's run-table.
- Returns -99 on exception.

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

IF (@RunModeId IS NULL)
    BEGIN
        SELECT N'-98,Invalid parameter @RunModeId: Value = NULL.';
        RETURN;
    END;

IF (@RayMigratorVersion IS NULL)
    BEGIN
        SELECT N'-98,Invalid parameter @RayMigratorVersion: Value = NULL.';
        RETURN;
    END;

IF (@MigrationRunSettingsJson IS NULL)
    BEGIN
        SELECT N'-98,Invalid parameter @MigrationRunSettingsJson: Value = NULL.';
        RETURN;
    END;
	
BEGIN TRY

    DECLARE @NewRunId INT;

    INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]
	(
		[{CFG:TableBaseName}MigrationRunResultId],
        [RunModeId],
	    [RayMigratorVersion],
        [MigrationRunSettingsJson],
        [StartedAt]
	)
	VALUES
	(
		@MigrationRunResult,
        @RunModeId,
        @RayMigratorVersion,
	    @MigrationRunSettingsJson,
        SYSUTCDATETIME()
	);

	SET @NewRunId = SCOPE_IDENTITY();
    
    SELECT 
        CASE WHEN (@NewRunId IS NULL) THEN N'-1,Could not insert new MigrationRun-entry in RayMigrator repository since MigrationRun-Id IS NULL. Maybe the table definition is wrong and does not contain an auto-increment for the primary key column [Id]?'
        ELSE CAST(@NewRunId as NVARCHAR(10)) + N',New MigrationRun with Id [' + CAST(@NewRunId as NVARCHAR(10)) + N'] created'
    END;

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

	SELECT '-99,Error executing MSSqlServer\Templates\Repository_MigrationRun_Insert.sql: Could NOT insert new MigrationRun-entry in RayMigrator repository. ErrorInfo: ' + @ErrorInfo;

END CATCH;

/*
RayMigrator SQL-Template:
-------------------------
- DatabaseLogging_CheckExistence
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-07-04

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\DatabaseLogging_CheckExistence.sql

Function:
- Checks the prerequisites for logging into a database by RayMigrator (not executed by serilog but by RayMigrator-internal framework)

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

BEGIN TRY

	-- Check existence of the following 2 Tables:
	IF (OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}Log', 'U') IS NOT NULL)
	BEGIN
		-- RayMigrator-tables found
		SELECT '1,RayMigrator logging-table found';
		RETURN;
	END
	ELSE
	BEGIN
		-- RayMigrator logging-table(s) missing
		SELECT '0,RayMigrator logging-table not present';
		RETURN;
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

	SELECT '-99,Error executing MSSqlServer\Templates\DatabaseLogging_CheckExistence.sql: Could NOT check for existence of database logging infrastructure. ErrorInfo: ' + @ErrorInfo;

END CATCH;

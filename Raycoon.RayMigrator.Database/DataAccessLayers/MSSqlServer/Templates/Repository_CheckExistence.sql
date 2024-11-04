/*
RayMigrator SQL-Template:
-------------------------
- Repository_CheckExistence
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-07-04

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\Repository_CheckExistence.sql

Function:
- Checks whether the prerequisites for using RayMigrator are met on the target database.

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
	
	DECLARE @NumberOfTablesFound INT;

	SELECT @NumberOfTablesFound = SUM(result)
	FROM (
		SELECT CASE WHEN OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}Migration', 'U') IS NOT NULL THEN 1 ELSE 0 END AS result
		UNION ALL
		SELECT CASE WHEN OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigrationResult', 'U') IS NOT NULL THEN 1 ELSE 0 END
		UNION ALL
		SELECT CASE WHEN OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigrationRun', 'U') IS NOT NULL THEN 1 ELSE 0 END
		UNION ALL
		SELECT CASE WHEN OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigrationRunResult', 'U') IS NOT NULL THEN 1 ELSE 0 END
		UNION ALL
		SELECT CASE WHEN OBJECT_ID('{CFG:SchemaName}.{CFG:TableBaseName}MigrationRunMode', 'U') IS NOT NULL THEN 1 ELSE 0 END
	) AS results

	IF (@NumberOfTablesFound = 5)
	BEGIN
		-- Check MasterData 'Result'
		DECLARE @NumberOfEntries INT;
		
		SELECT @NumberOfEntries = COUNT(*) FROM [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationResult];
		IF (@NumberOfEntries = 0)
		BEGIN
			SELECT '-1,Repository exists but no master-data entries in RayMigrator-table [{CFG:SchemaName}].[{CFG:TableBaseName}Result] detected.';
			RETURN;
		END;

		-- Check MasterData 'RunResult'
		SELECT @NumberOfEntries = COUNT(*) FROM [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunResult];

		IF (@NumberOfEntries = 0)
		BEGIN
			SELECT '-2,Repository exists but no master-data entries in RayMigrator-table [{CFG:SchemaName}].[{CFG:TableBaseName}RunResult] detected.';
			RETURN;
		END;

		-- Check MasterData 'RunMode'
		SELECT @NumberOfEntries = COUNT(*) FROM [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRunMode];

		IF (@NumberOfEntries = 0)
		BEGIN
			SELECT '-3,Repository exists but no master-data entries in RayMigrator-table [{CFG:SchemaName}].[{CFG:TableBaseName}RunMode] detected.';
			RETURN;
		END;

		-- Repository found and is complete containing master data
		SELECT '1,RayMigrator repository found';
		RETURN;
	END;

	IF (@NumberOfTablesFound = 0)
	BEGIN
		SELECT '0,RayMigrator repository does not exist';
		RETURN;
	END;

	SELECT '-3,RayMigrator repository is incomplete or corrupt or variable-substitution in template-file [MSSqlServer\Templates\Repository_CheckExistence.sql] failed.';
	RETURN;

END TRY
BEGIN CATCH

    DECLARE @ErrorInfo NVARCHAR(MAX);

    SET @ErrorInfo =
        'Error Number: [' + ISNULL(CAST(REPLACE(ERROR_NUMBER(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Severity: [' + ISNULL(CAST(REPLACE(ERROR_SEVERITY(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error State: [' + ISNULL(CAST(REPLACE(ERROR_STATE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Line: [' + ISNULL(CAST(REPLACE(ERROR_LINE(), ',','-') AS NVARCHAR(255)), N'NULL') + N']. ' +
        'Error Message: ' + ISNULL(REPLACE(ERROR_MESSAGE(), ',','-'), N'NULL');

	SELECT '-99,Error executing MSSqlServer\Templates\Repository_CheckExistence.sql: Could NOT check for existence of RayMigrator repository. ErrorInfo: ' + @ErrorInfo;

END CATCH;

/*
RayMigrator SQL-Template:
-------------------------
- Repository_Migration_Insert
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-07-04

################################
ToDo: 
   Modify info about ResultCode and ErrorMessage since it does not apply here!
################################

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\Repository_Migration_Insert.sql

Function:
- Insert the state and result of migrations into the RayMigrator repository.

Mandatory behaviour:
- Returns a positive identity value > 0 if a new entry has been created in the repository's migration-table.
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

IF (@MigrationRunId IS NULL OR @MigrationRunId < 1)
    BEGIN
        SELECT N'-1,Invalid parameter @MigrationRunId: Value = [' + ISNULL(CAST(@MigrationRunId AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

IF (@MigrationResult IS NULL OR @MigrationResult < 1)
    BEGIN
        SELECT N'-2,Invalid parameter @MigrationResult: Value = [' + ISNULL(CAST(@MigrationResult AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

IF (@Environment IS NULL OR LEN(@Environment) > 100)
    BEGIN
        SELECT N'-3,Invalid parameter @Environment: Value = [' + ISNULL(@Environment, N'NULL') + N']. Value for @Environment [' + @Environment
                   + N'] must be a string with a maximum of 100 characters but currently is NULL or exceeds that length.';
        RETURN;
    END;

IF (@TargetGroupAlias IS NULL OR LEN(@TargetGroupAlias) > 100)
    BEGIN
        SELECT N'-3,Invalid parameter @TargetGroupAlias: Value = [' + ISNULL(@TargetGroupAlias, N'NULL') + N']. Value for @TargetGroupAlias [' + @TargetGroupAlias 
		+ N'] must be a string with a maximum of 100 characters but currently is NULL or exceeds that length.';
        RETURN;
    END;

IF (@TargetAlias IS NULL OR LEN(@TargetAlias) > 100)
    BEGIN
        SELECT N'-4,Invalid parameter @TargetAlias: Value = [' + ISNULL(@TargetAlias, N'NULL') + N']. Value for @TargetAlias [' + @TargetAlias 
		+ N'] must be a string with a maximum of 100 characters but currently is NULL or exceeds that length.';
        RETURN;
    END;

IF (@FileName IS NULL OR LEN(@FileName) < 1)
    BEGIN
        SELECT N'-5,Invalid parameter @FileName: Value = [' + ISNULL(@FileName, N'NULL') + N']. Value must be a string with at least 1 character.';
        RETURN;
    END;

IF (@FileId IS NULL OR @FileId < 1)
    BEGIN
        SELECT N'-6,Invalid parameter @FileId: Value = [' + ISNULL(CAST(@FileId AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

IF (@FileHash IS NULL OR LEN(@FileHash) < 1)
    BEGIN
        SELECT N'-7,Invalid parameter @FileHash: Value = [' + ISNULL(@FileHash, N'NULL') + N']. Value must be a string with at least 1 character.';
        RETURN;
    END;

IF (@NumberOfBlocksInFile IS NULL OR @NumberOfBlocksInFile < 1)
    BEGIN
        SELECT N'-8,Invalid parameter @NumberOfBlocksInFile: Value = [' + ISNULL(CAST(@NumberOfBlocksInFile AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

IF (@BlockId IS NULL OR @BlockId < 1)
    BEGIN
        SELECT N'-9,Invalid parameter @BlockId: Value = [' + ISNULL(CAST(@BlockId AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

IF (@Description IS NOT NULL AND LEN(@Description) > 1000)
    BEGIN
        SELECT N'-11,Invalid parameter @Description: Value = [' + ISNULL(@Description, N'NULL') + N']. Value for @Description [' + @Description 
		+ N'] must be a string with a maximum of 1000 characters but currently exceeds that having [' + LEN(@Description) + N'] characters: ' 
		+ SUBSTRING(@Description, 0, 100) + N' [...]'; -- show the first 100 characters
        RETURN;
    END;

IF (@MigrationSettingsJson IS NULL OR LEN(@MigrationSettingsJson) < 1)
    BEGIN
        SELECT N'-12,Invalid parameter @MigrationSettingsJson: Value = [' + ISNULL(@MigrationSettingsJson, N'NULL') + N']. Value must be a string with at least 1 character.';
        RETURN;
    END;


BEGIN TRY

	DECLARE @NewMigrationId INT;

	INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}Migration]
	(
		[{CFG:TableBaseName}MigrationRunId],
		[{CFG:TableBaseName}MigrationResultId],
	    [Environment],
		[TargetGroupAlias],
		[TargetAlias],
		[FileName],
		[FileId],
		[FileHash],
		[NumberOfBlocksInFile],
		[BlockId],
		[Description],
		[MigrationSettingsJson],
		[StartedAt]
	)
	VALUES
	(
		@MigrationRunId,
		@MigrationResult,
	    @Environment,
		@TargetGroupAlias,
		@TargetAlias,
		@FileName,
		@FileId,
		@FileHash,
		@NumberOfBlocksInFile,
		@BlockId,
		@Description,
		@MigrationSettingsJson,
		SYSUTCDATETIME()
	);

	SET @NewMigrationId = SCOPE_IDENTITY();

	IF (@NewMigrationId IS NULL)
	BEGIN  
    	SELECT N'-13,Could not insert new migration-entry in RayMigrator repository since the @NewMigrationId IS NULL. Maybe the table definition is wrong and does not contain an auto-increment for the primary key column [Id]?';
		RETURN;
    END;
        
	SELECT CAST(@NewMigrationId AS VARCHAR(10)) + N',New migration-entry with Id [' + CAST(@NewMigrationId AS VARCHAR(10)) + '] created for migration-file [' + @FileName + N'].';


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

	SELECT '-99,Error executing MSSqlServer\Templates\Repository_Migration_Insert.sql: Could NOT insert new migration-entry in RayMigrator repository. ErrorInfo: ' + @ErrorInfo;

END CATCH;
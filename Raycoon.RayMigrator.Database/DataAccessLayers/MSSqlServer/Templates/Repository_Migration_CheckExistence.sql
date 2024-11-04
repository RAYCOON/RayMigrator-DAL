/*
RayMigrator SQL-Template:
-------------------------
- Repository_Migration_CheckExistence
- Author  : RAYCOON.com GmbH (https://raycoon.com)
- Version : 2024-07-04

- Database: Microsoft SQL Server (MSSqlServer)
- Location: DataAccessLayers\MSSqlServer\Templates\Repository_Migration_CheckExistence.sql

Functionality:
--------------
1. Optionally updates the hash-value of the MigrationFile and all MigrationFile-blocks in the RayMigrator-repository (when @MigrationFilesHashUpdate = 1)
2. Checks if a specific migration has already been performed on the target database by checking the RayMigrator-repository

INPUT: available variables:
-----------------------------
- @MigrationFilesHashUpdate: 1 = Update the hash(es) of MigrationFile and hash all corresponding MigrationFile-blocks before checking, if migration has already been performed
- @MigrationFilesHashCheck:  1 = Perform hash check against repository if migration-file exists, 0 = Do NOT perform hash check
- @FileName: The name of the migration-file including the relative path
- @FileHash: The SHA265 hash of the @FileName
- @TargetGroupAlias: The Alias of the TargetGroup of the configured Target ==> see your own RayMigrator configuration!
- @TargetAlias: The Alias of the configured Target that the MigrationFile is applied to  ==> see your own RayMigrator configuration!




- @MigrationRunId:  Id of the current MigrationRun
- @MigrationId:  Index of the current MigrationFile
- @MigrationBlockId: Index of the current (migration-)block of the MigrationFile
            A block is a script-part of the MigrationFile that is delimited from the other parts using a delimiter (i.e. the 'GO'-statement in MSSqlServer syntax)
- @NumberOfBlocks: The number of sql script-blocks within this MigrationFile (1= just a single block, no entries in Table [{CFG:TableBaseName}FileBlock], otherwise: 2..n)


OUTPUT: mandatory behaviour:
-----------------------------
- ResultCode  0: 0 = Successful migration does NOT exist at all
- ResultCode  1: Successful migration exists (and is complete regarding all MigrationFileBlocks)
- ResultCode 99: Migration exists but is only partly successful regarding MigrationFileBlocks

--------------------------------------------------------------------------------------------------------

General instructions how to modify or create database-specific RayMigrator SQL-templates:

- Always (!) end this SQL-script using a SELECT '[ResultCode],[Message]' command!
- Always (!) supply an ErrorMessage for 'Error'-ResultCodes below zero (-n..-1), otherwise migrations will abort with an error.
- Always (!) use a single comma to separate ResultCode from Message like SELECT '-1,My error description'

Result-Parameter [ResultCode]: [OK: 0..n, ERROR: -n..-1]
- ResultCodes from zero and above (0..n) will be interpreted as an 'OK' result
- ResultCodes below zero (-n..-1) will be interpreted as 'Error' and will abort migration execution
- ResultCodes below zero (-n..-1) MUST be provided with a comma-separated, trailing ErrorMessage

Result-Parameter [ErrorMessage] (without any comma(s) please!)
- All Messages may contain Placeholders like '{CFG:SchemaName}', {CFG:TableBaseName}
- Replacement of placeholders depends on the currently executed TemplateType:
    > All Logging_* templates will get CFG: values from the corresponding appsetting-properties in the 'Logging' section of RayMigrator
    > All Repository_* templates will get CFG: values from the corresponding appsetting-properties in the Repository-section of RayMigrator:TargetGroups[0..n]
- Messages for ResultCodes below zero (-n..-1) will be logged at LogLevel 'Error'
- Messages for 'OK' ResultCodes will be logged at LogLevel 'Debug' using Parameter 2 as message
- Do NOT use any comma(s) in your ErrorMessage or message

Common behaviour:
- Returns a single-line, scalar SELECT-result matching the following pattern: SELECT N'[ResultCode],[Message]'
- Returns a negative integer [ResultCode] on error(s)
- Returns a positive integer [ResultCode] reflecting an OK result
- Neither the [ResultCode], nor the [Message] may contain any comma (',')
*/

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
        SELECT N'-8,Invalid parameter @NumberOfBlocksInFile: Value = [NULL]. Value must be a positive integer.';
        RETURN;
    END;

IF (@BlockId IS NULL OR @BlockId < 1)
    BEGIN
        SELECT N'-9,Invalid parameter @BlockId: Value = [' + ISNULL(CAST(@BlockId AS VARCHAR(10)), N'NULL') + N']. Value must be a positive integer.';
        RETURN;
    END;

BEGIN TRY

	/*
		-- Correct hash value of migration file in case @MigrationFilesHashUpdate = 1
		if (@MigrationFileHashUpdate = 1)
			begin
				UPDATE  [{CFG:SchemaName}].[{CFG:TableBaseName}]
				SET [FileHash] = @FileHash
				WHERE 
					[FileName] = @FileName 
					AND [TargetGroupAlias] = @TargetGroupAlias 
					AND [TargetAlias] = @TargetAlias;
			end;
	*/

	DECLARE @NumberOfRows INT;

	DECLARE @MigrationsFoundTable AS TABLE
	(
		FileHash VARCHAR(100),
		FileId INT,
		NumberOfBlocksInFile INT,
		BlockIdFound BIT
	);


	/*
	Search for TargetGroupAlias, DesinationAlias, FileName, MigrationResult ... and check:
	- FileHash OK
	- FileId OK
	- BlockId exists
	*/

	INSERT INTO @MigrationsFoundTable (FileHash, FileId, NumberOfBlocksInFile, BlockIdFound)
	SELECT 
		m.[FileHash],
		m.[FileId],
		m.[NumberOfBlocksInFile],
		MAX (CASE 
				WHEN m.[BlockId] = @BlockId THEN 1
				ELSE 0
			END) AS BlockIdFound
	FROM
		[{CFG:SchemaName}].[{CFG:TableBaseName}Migration] AS m
		INNER JOIN [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] AS mr
			ON m.[{CFG:TableBaseName}MigrationRunId] = mr.[Id]
	WHERE
	    m.[Environment] = @Environment
		AND m.[TargetGroupAlias] = @TargetGroupAlias
		AND m.[TargetAlias] = @TargetAlias
		AND m.[FileName] = @FileName
        AND m.[{CFG:TableBaseName}MigrationResultId] = 100 -- OK
        AND mr.[RunModeId] = 100 -- Migrate
	GROUP BY
		m.[FileHash],
		m.[FileId],
		m.[NumberOfBlocksInFile];	


	SET @NumberOfRows = @@rowcount;

	IF (@NumberOfRows = 0)
	BEGIN
		SELECT N'0,No migration with RunMode [Migrate] found in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'], FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N'], FileHash [' + ISNULL(CAST(@FileHash AS NVARCHAR(100)), N'NULL') + N']';
		RETURN;
	END;

	IF (@NumberOfRows > 1)
	BEGIN
		SELECT N'-5,Multiple results found for already successful migrations in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(4000)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(4000)), N'NULL') + N'], FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N'], FileHash [' + ISNULL(CAST(@FileHash AS NVARCHAR(4000)), N'NULL') + N']. This is a severe inconsitency. Please check your TargetGroupAlias, TargetAlias, migration-files and more to determine the reason for this issue!';
		RETURN;
	END;

	DECLARE @FileIdDb INT;
	DECLARE @FileHashDb VARCHAR(100);
	DECLARE @NumberOfBlocksInFileDb INT;
	DECLARE @BlockIdFoundDb BIT;

	-- @NumberOfRows = 1
	SELECT
		@FileIdDb = FileId,
		@FileHashDb = FileHash,
		@NumberOfBlocksInFileDb = NumberOfBlocksInFile,
		@BlockIdFoundDb = BlockIdFound
	FROM
		@MigrationsFoundTable;

	-- FileId has to match
	IF (@FileId != @FileIdDb) 
	BEGIN  
        SELECT N'-1,FileId mismatch found in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'] for FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N']. Expected FileId is [' + ISNULL(CAST(@FileIdDb AS NVARCHAR(10)), N'NULL') + N'] but was [' + ISNULL(CAST(@FileId AS NVARCHAR(10)), N'NULL') + N']. Most likely some migration-files were added or deleted';
		RETURN;
    END;

	-- Always check Hash(es) for File and Block
	IF (@FileHash = @FileHashDb)
	BEGIN

		-- NumberOfBlocksInFile has to match
		IF (@NumberOfBlocksInFile = @NumberOfBlocksInFileDb) 
		BEGIN  

			-- BlockId exists?
			IF (@BlockIdFoundDb = 1) 
			BEGIN  
				SELECT N'1,Successful migration found in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'], FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N'], FileHash [' + ISNULL(CAST(@FileHash AS NVARCHAR(100)), N'NULL') + N']';			
				RETURN;
			END
			ELSE
			BEGIN
				SELECT N'0,No block-migration with RunMode [Migrate] found in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'], FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N'], FileHash [' + ISNULL(CAST(@FileHash AS NVARCHAR(100)), N'NULL') + N'], FileId [' + ISNULL(CAST(@FileId AS NVARCHAR(10)), N'NULL') + N'], BlockId [' + ISNULL(CAST(@BlockId AS NVARCHAR(10)), N'NULL') + N']';
				RETURN;
			END;

		END
		ELSE
		BEGIN
        	SELECT N'-3,RayMigrator parser error: NumberOfBlocksInFile mismatch occurred, but FileHashDb is identical to current FileHash. Error occurred for repository of Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'] and FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N']. Expected NumberOfBlocksInFile is [' + ISNULL(CAST(@NumberOfBlocksInFile AS NVARCHAR(10)), N'NULL') + N'] but was [' + ISNULL(CAST(@NumberOfBlocksInFileDb AS NVARCHAR(10)), N'NULL') + N']';
			RETURN;
		END;

	END
	ELSE
	BEGIN
		SELECT N'-4,Migration found with FileHash-mismatch for migration in repository for Environment [' + ISNULL(CAST(@Environment AS NVARCHAR(100)), N'NULL') + N'], TargetGroupAlias [' + ISNULL(CAST(@TargetGroupAlias AS NVARCHAR(100)), N'NULL') + N'], TargetAlias [' + ISNULL(CAST(@TargetAlias AS NVARCHAR(100)), N'NULL') + N'], FileName [' + ISNULL(CAST(@FileName AS NVARCHAR(4000)), N'NULL') + N']. Expected FileHash [' + ISNULL(CAST(@FileHash AS NVARCHAR(100)), N'NULL') + N'] but was [' + ISNULL(CAST(@FileHashDb AS NVARCHAR(100)), N'NULL') + N']. The file has been altered after the first migration was performed';
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

	SELECT '-99,Error executing MSSqlServer\Templates\Repository_Migration_CheckExistence.sql: Could NOT check if migration exists in RayMigrator repository. ErrorInfo: ' + @ErrorInfo;

END CATCH;

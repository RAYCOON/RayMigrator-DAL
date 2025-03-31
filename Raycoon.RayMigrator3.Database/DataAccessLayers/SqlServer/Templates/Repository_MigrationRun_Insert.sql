-- noinspection SqlNoDataSourceInspectionForFile

/*
[RayMigratorTemplate]
TemplateType = "Repository_MigrationRun_Insert"
DatabaseType = "SqlServer"
Author = "RAYCOON.com GmbH (https://raycoon.com)"
Version = "2025-02-12.1"
Function: "Inserts a new MigrationRun-entry if valid and returns the new MigrationRunId."
Behaviour = """
- Returns a negative value on error.
- Returns a positive value as existing or new VersionId.
"""
Parameter = """
- @ProductId: 
- @Environment: 
- @MigrationRunModeId: 
- @MigratorVersionId:
- @MigrationResultId:
- @FromReleaseVersion:
- @ToReleaseVersion:
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

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY

    if (@FixMigrationRunIssues = 1)
    begin
        Update [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]
        SET
            [MigrationResultId] = @FixMigrationResultId,
            [FinishedAt] = sysutcdatetime()
        WHERE
            [ProductId] = @ProductId AND
            [Environment] = @Environment AND
                [MigrationRunModeId] = @MigrationRunModeId AND
            [FinishedAt] IS NULL
    end;

    IF EXISTS
        (
            SELECT TOP (1) 1 FROM [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun]
            WHERE
                [ProductId] = @ProductId AND
                [Environment] = @Environment AND
                [MigrationRunModeId] = @MigrationRunModeId AND
                [FinishedAt] IS NULL
        )
        BEGIN
            DECLARE @ProductName NVARCHAR(100);
            SELECT @ProductName = [Name] FROM [{CFG:SchemaName}].[{CFG:TableBaseName}Product] WHERE [Id] = @ProductId;

            SELECT '-1,MigrationRun for Product [' + ISNULL(@ProductName, 'NULL') + '] with Id [' + ISNULL(CAST(@ProductId AS VARCHAR(10)), 'NULL') + '] is currently in progress. Parallel migrations for the same product with MigrationRunModeId [Migrate=' + ISNULL(CAST(@MigrationRunModeId AS VARCHAR(10)), 'NULL') + '] are not allowed!'
        END
    ELSE
        BEGIN
            DECLARE @MigrationRunId INT;

            INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}MigrationRun] (MigratorVersionId, ProductId, MigrationRunModeId, MigrationResultId, Environment, FromReleaseVersion, ToReleaseVersion, StartedAt)
            VALUES (@MigratorVersionId, @ProductId, @MigrationRunModeId, @MigrationResultId, @Environment, @FromReleaseVersion, @ToReleaseVersion, SYSUTCDATETIME());

            SET @MigrationRunId = SCOPE_IDENTITY();
            SELECT CAST(@MigrationRunId AS VARCHAR(10)) + ',MigrationRun with Id [' + CAST(@MigrationRunId AS VARCHAR(10)) + '] successfully created for ProductId [' + ISNULL(CAST(@ProductId AS VARCHAR(10)), 'NULL') + ']';
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

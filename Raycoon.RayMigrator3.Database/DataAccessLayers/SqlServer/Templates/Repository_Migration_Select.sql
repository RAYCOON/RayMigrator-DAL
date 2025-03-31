/*
[RayMigratorTemplate]
TemplateType = "Repository_Migration_Select"
DatabaseType = "SqlServer"
Author = "RAYCOON.com GmbH (https://raycoon.com)"
Version = "2025-02-12.1"
Function: "Select all Migrations for a specific Product, Environment and MigrationRunMode."
Behaviour = """
- Returns null if no migrations could be found.
- Returns a list of existing migrations if migrations were found.
"""
Parameter = """
- @ProductId: The id of the product to migrate.
- @Environment: The target-environment for the migration.
- @MigrationRunModeId: The RunMode (here: always "Migrate").
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

    SELECT 
        [Id]
        ,[ProductId]
        ,[MigrationRunId]
--         ,[MigrationRunModeId]
        ,[MigrationOperationId]
        ,[MigrationResultId]
        ,[MigrationStateId]
--         ,[Environment]
        ,[ReleaseVersion]
        ,[TargetGroupAlias]
        ,[TargetAlias]
        ,[Filename]
        ,[FileOrderId]
        ,[FileUpHash]
        ,[FileUpConfigHash]
        ,[FileUpBlocksHash]
        ,[FileUpBlocksMigrated]
        ,[FileUpBlocksTotal]
--         ,[FileUpConfigJson]
        ,[MigrateDownFileExists]
        ,[FileDownHash]
        ,[FileDownConfigHash]
        ,[FileDownBlocksHash]
        ,[FileDownBlocksMigrated]
        ,[FileDownBlocksTotal]
--         ,[FileDownConfigJson]
--         ,[StartedAt]
--         ,[FinishedAt]
--         ,[DurationInMs]
    FROM
        [{CFG:SchemaName}].[{CFG:TableBaseName}Migration]
    WHERE 
        [ProductId] = @ProductId AND
        [Environment] = @Environment AND
        [MigrationRunModeId] = @MigrationRunModeId;
        
END TRY
BEGIN CATCH

    -- Rollback transaction on error
    IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        ;THROW;

END CATCH;

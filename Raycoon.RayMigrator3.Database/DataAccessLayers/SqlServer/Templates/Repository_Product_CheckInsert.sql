-- noinspection SqlNoDataSourceInspectionForFile

/*
[RayMigratorTemplate]
TemplateType = "Repository_Product_Insert"
DatabaseType = "SqlServer"
Author = "RAYCOON.com GmbH (https://raycoon.com)"
Version = "2025-02-12.1"
Function: "Inserts a new Product-entry and returns the new ProductId."
Behaviour = """
- Returns a negative value on error.
- Returns a positive value as existing or new ProductId.
"""
Parameter = """
- @Name: 
- @Description: 
- @ProductSettingsJson: 
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

    if (@Name IS NULL OR LEN(@Name) = 0)
        begin
            SELECT '-1,Product with empty name [' + ISNULL(@Name, 'NULL') + '] is not allowed!'
            return;
        end;
    
    declare 
        @ProductId int,
        @numberOfRows int;
    
    select @ProductId = [Id] from [{CFG:SchemaName}].[{CFG:TableBaseName}Product] where [Name] = @Name;
    SET @numberOfRows = @@rowcount;
    
    if (@numberOfRows = 1)
        begin
            SELECT CAST(@ProductId AS varchar(10)) + ',Product [' + @Name + '] with Id [' + CAST(@ProductId AS varchar(10)) + '] found';
            return;
        end;

    if (@numberOfRows = 0)
        begin
            INSERT INTO [{CFG:SchemaName}].[{CFG:TableBaseName}Product] (Name, Description, CreatedAt)
            VALUES (@Name, @Description, SYSUTCDATETIME());

            SET @ProductId = SCOPE_IDENTITY();
            SELECT CAST(@ProductId AS varchar(10)) + ',Product [' + @Name + '] with Id [' + CAST(@ProductId AS varchar(10)) + '] successfully created';
            return;
        end;
        
END TRY
BEGIN CATCH
    
    -- Rollback transaction on error
    IF (@@TRANCOUNT > 0)
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    ;THROW;
	
END CATCH;

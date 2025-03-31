/*
USE [Backend_1];
GO
truncate table ray.MigrationLog;

drop table dbo.person;
drop table dbo.login;
drop table dbo.sex;
GO

USE [Backend_2];
GO

drop table dbo.person;
drop table dbo.login;
drop table dbo.sex;
GO

USE [Frontend];
GO

drop table dbo.UserPreferences;
drop table dbo.UserProfile;
GO



-- Currently not implemented since not in use by RayMigrator
USE [Backend_1];
GO

DROP TABLE IF EXISTS [ray].[MigrationLog];
DROP TABLE IF EXISTS [ray].[MigrationEvent];
DROP TABLE IF EXISTS [ray].[MigrationProcess];
DROP TABLE IF EXISTS [ray].[MigrationRunMeta];
DROP TABLE IF EXISTS [ray].[MigrationHistory];
DROP TABLE IF EXISTS [ray].[Migration];
DROP TABLE IF EXISTS [ray].[MigrationRun];
DROP TABLE IF EXISTS [ray].[Product];
DROP TABLE IF EXISTS [ray].[MigratorVersion];
DROP TABLE IF EXISTS [ray].[MigrationRunMode];
DROP TABLE IF EXISTS [ray].[MigrationResult];
DROP TABLE IF EXISTS [ray].[MigrationOperation];
DROP TABLE IF EXISTS [ray].[MigrationState];

*/

SELECT '0,RayMigrator tables were NOT dropped since it is currently not implemented';

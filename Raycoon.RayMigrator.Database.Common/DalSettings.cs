namespace Raycoon.RayMigrator.Database.Common;

public class DalSettings : IDalSettings
{
    public bool UseTransaction { get; set; }
    public int DbCommandTimeoutInSeconds { get; set; }
}
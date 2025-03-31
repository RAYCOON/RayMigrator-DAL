namespace Raycoon.RayMigrator3.Database.Common;

[AttributeUsage(AttributeTargets.Class, Inherited = false)]
public class DatabaseTypeAttribute : Attribute
{
    public string DatabaseType { get; }

    public DatabaseTypeAttribute(string databaseType)
    {
        DatabaseType = databaseType;
    }
}

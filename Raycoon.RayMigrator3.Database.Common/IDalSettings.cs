namespace Raycoon.RayMigrator3.Database.Common;

/// <summary>
/// Database-specific settings for DAL execution.
/// </summary>
public interface IDalSettings
{
    /// <summary>
    /// Gets or sets a value indicating whether the SQL code should be executed within a transaction.
    /// </summary>
    /// <value>
    /// <c>true</c> if SQL code execution should be wrapped in a transaction; otherwise, <c>false</c>.
    /// </value>
    bool UseTransaction { get; set; }
    
    /// <summary>
    /// Gets or sets the maximum allowed execution time for a SQL command, measured in seconds.
    /// </summary>
    /// <value>
    /// The timeout duration in seconds, after which a running SQL command should be terminated if not completed.
    /// </value>
    int DbCommandTimeoutInSeconds { get; set; }
}

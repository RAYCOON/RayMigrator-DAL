using System.Data;
using System.Reflection;
using Microsoft.Data.SqlClient;
using Raycoon.RayMigrator3.Database.Common;

namespace Raycoon.RayMigrator3.Database.DataAccessLayers.SqlServer;

[DatabaseType("SqlServer")]
internal class DalSqlServer : DalBase, IDal
{
    private readonly string _connectionString;
    public override string DatabaseType { get; }
    public override DalSpecificProperties DalSpecificProperties { get; }

    public DalSqlServer(string connectionString)
    {
        _connectionString = connectionString;
        DatabaseType = this.GetType().GetCustomAttribute<DatabaseTypeAttribute>()!.DatabaseType;
        DalSpecificProperties = new DalSpecificProperties
        {
            SqlBlockDelimiter = "GO",
            SqlMultiLineCommentStart = "/*",
            SqlMultiLineCommentEnd = "*/",
        };
    }

    public override void CheckConnectionStringOrValidateConnection(bool validateConnection)
    {
        using (var connection = new SqlConnection(_connectionString))
        {
            if (validateConnection)
            {
                connection.Open();
                connection.Close();
            }
        }
    }

    public override async Task ExecuteNonQueryAsync(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null)
    {
        List<SqlParameter>? sqlParameterList = null;

        if (dalParameterList != null)
        {
            if (!TryGetDbSpecificSqlParameter(dalParameterList, out sqlParameterList))
            {
                return;
            }
        }

        await using (var connection = new SqlConnection(_connectionString))
        {
            await connection.OpenAsync();

            if (dalSettings.UseTransaction)
            {
                await using SqlTransaction transaction = (SqlTransaction)await connection.BeginTransactionAsync();
                try
                {
                    await using (var command = new SqlCommand(sqlCode, connection, transaction))
                    {
                        command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                        if (sqlParameterList != null)
                        {
                            command.Parameters.AddRange(sqlParameterList.ToArray());
                        }
                        await command.ExecuteNonQueryAsync();
                    }
                    await transaction.CommitAsync();
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            }
            else
            {
                await using (var command = new SqlCommand(sqlCode, connection))
                {
                    command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                    if (sqlParameterList != null)
                    {
                        command.Parameters.AddRange(sqlParameterList.ToArray());
                    }
                    await command.ExecuteNonQueryAsync();
                }
            }
        }
    }
    
    public override void ExecuteNonQuery(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null)
    {
        List<SqlParameter>? sqlParameterList = null;

        if (dalParameterList != null)
        {
            if (!TryGetDbSpecificSqlParameter(dalParameterList, out sqlParameterList))
            {
                return;
            }
        }

        using (var connection = new SqlConnection(_connectionString))
        {
            connection.Open();

            if (dalSettings.UseTransaction)
            {
                using SqlTransaction transaction = connection.BeginTransaction();
                try
                {
                    using (var command = new SqlCommand(sqlCode, connection, transaction))
                    {
                        command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                        if (sqlParameterList != null)
                        {
                            command.Parameters.AddRange(sqlParameterList.ToArray());
                        }
                        command.ExecuteNonQuery();
                    }
                    transaction.Commit();
                }
                catch
                {
                    transaction.Rollback();
                    throw;
                }
            }
            else
            {
                using (var command = new SqlCommand(sqlCode, connection))
                {
                    command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                    if (sqlParameterList != null)
                    {
                        command.Parameters.AddRange(sqlParameterList.ToArray());
                    }
                    command.ExecuteNonQuery();
                }
            }
        }
    }

    public override async Task<object?> ExecuteScalarAsync(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null)
    {
        List<SqlParameter>? sqlParameterList = null;

        if (dalParameterList != null)
        {
            if (!TryGetDbSpecificSqlParameter(dalParameterList, out sqlParameterList))
            {
                return null;
            }
        }

        await using (var connection = new SqlConnection(_connectionString))
        {
            await connection.OpenAsync();

            if (dalSettings.UseTransaction)
            {
                using SqlTransaction transaction = (SqlTransaction)await connection.BeginTransactionAsync();
                try
                {
                    await using (var command = new SqlCommand(sqlCode, connection, transaction))
                    {
                        command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                        if (sqlParameterList != null)
                        {
                            command.Parameters.AddRange(sqlParameterList.ToArray());
                        }
                        var result = await command.ExecuteScalarAsync();
                        await transaction.CommitAsync();
                        return result;
                    }
                }
                catch
                {
                    await transaction.RollbackAsync();
                    throw;
                }
            }
            else
            {
                await using (var command = new SqlCommand(sqlCode, connection))
                {
                    command.CommandTimeout = dalSettings.DbCommandTimeoutInSeconds;
                    if (sqlParameterList != null)
                    {
                        command.Parameters.AddRange(sqlParameterList.ToArray());
                    }
                    var result = await command.ExecuteScalarAsync();
                    return result;
                }
            }
        }
    }

    public override async Task<bool> IsConnectionValid(string connectionString, IDalSettings dalSettings)
    {
        try
        {
            using (var connection = new SqlConnection(connectionString))
            {
                await connection.OpenAsync();
                return true;
            }
        }
        catch
        {
            return false;
        }
    }

    // Überschreiben Sie diese Methode nur, wenn Sie spezifisches Verhalten für SQL Server benötigen
    protected override T CreateParameter<T>(DbType dbType, string parameterName, object? parameterValue)
    {
        var parameter = base.CreateParameter<T>(dbType, parameterName, parameterValue);
    
        // Hier können Sie spezifische Anpassungen für SQL Server-Parameter vornehmen
        if (parameter is SqlParameter sqlParameter)
        {
            // Spezifische Einstellungen für SQL Server
            if (dbType == DbType.String && parameterValue != null)
            {
                sqlParameter.Size = Math.Max(1, ((string)parameterValue).Length);
            }
        
            // Weitere SQL Server-spezifische Anpassungen können hier hinzugefügt werden
        }

        return parameter;
    }
    
    // Überschreiben Sie diese Methode nur, wenn Sie spezifische Konvertierungen für SQL Server benötigen
    protected override object ConvertToDbValue(object? value)
    {
        // Hier können Sie spezifische Konvertierungen für SQL Server implementieren
        // Zum Beispiel:
        if (value is DateTime dateTime)
        {
            // SQL Server unterstützt keine Datumsangaben vor 1753
            if (dateTime < new DateTime(1753, 1, 1))
            {
                return new DateTime(1753, 1, 1);
            }
        }

        return base.ConvertToDbValue(value);
    }
}
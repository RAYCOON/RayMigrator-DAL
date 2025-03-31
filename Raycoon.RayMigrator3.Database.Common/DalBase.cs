using System.Data;

namespace Raycoon.RayMigrator3.Database.Common;

public abstract class DalBase : IDal
{
    public abstract string DatabaseType { get; }
    public abstract DalSpecificProperties DalSpecificProperties { get; }

    public abstract Task ExecuteNonQueryAsync(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null);
    public abstract void ExecuteNonQuery(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null);

    public abstract Task<object?> ExecuteScalarAsync(string sqlCode, IDalSettings dalSettings, DalParameterList? dalParameterList = null);

    public abstract Task<bool> IsConnectionValid(string connectionString, IDalSettings dalSettings);

    public abstract void CheckConnectionStringOrValidateConnection(bool validateConnection);

    public virtual bool TryGetDbSpecificSqlParameter<T>(DalParameterList dalParameterList, out List<T>? sqlParameterList) where T : class, IDbDataParameter, new()
    {
        try
        {
            List<T> sqlParameters = new List<T>();

            foreach (var dalParameter in dalParameterList.GetAllParameters())
            {
                Type dalParameterType = dalParameter.Value.ParameterType;

                if (!TryGetDbTypeForType(dalParameterType, out DbType dbType))
                {
                    throw new ApplicationException($"Error converting application parameter of type [{dalParameter.Value.ParameterType}] into a DAL-specific parameter for Type [{typeof(T).Name}].");
                }

                T parameter = CreateParameter<T>(dbType, dalParameter.Value.ParameterName, dalParameter.Value.ParameterValue);
                sqlParameters.Add(parameter);
            }

            sqlParameterList = sqlParameters;
            return true;
        }
        catch (Exception ex)
        {
            throw new ApplicationException($"Error converting application ParameterList into a DAL-specific parameters for Type [{typeof(T).Name}].", ex);
        }
    }

    protected virtual T CreateParameter<T>(DbType dbType, string parameterName, object? parameterValue) where T : class, IDbDataParameter, new()
    {
        return new T
        {
            DbType = dbType,
            ParameterName = parameterName,
            Value = ConvertToDbValue(parameterValue)
        };
    }

    protected virtual object ConvertToDbValue(object? value)
    {
        return value ?? DBNull.Value;
    }

    public bool TryGetDbTypeForType(Type type, out DbType dbType)
    {
        Type? underlyingType = Nullable.GetUnderlyingType(type);
        Type effectiveType = underlyingType ?? type;

        switch (effectiveType)
        {
            case Type t when t == typeof(byte) || t == typeof(byte?):
                dbType = DbType.Byte;
                return true;
            case Type t when t == typeof(sbyte) || t == typeof(sbyte?):
                dbType = DbType.SByte;
                return true;
            case Type t when t == typeof(short) || t == typeof(short?):
                dbType = DbType.Int16;
                return true;
            case Type t when t == typeof(ushort) || t == typeof(ushort?):
                dbType = DbType.UInt16;
                return true;
            case Type t when t == typeof(int) || t == typeof(int?):
                dbType = DbType.Int32;
                return true;
            case Type t when t == typeof(uint) || t == typeof(uint?):
                dbType = DbType.UInt32;
                return true;
            case Type t when t == typeof(long) || t == typeof(long?):
                dbType = DbType.Int64;
                return true;
            case Type t when t == typeof(ulong) || t == typeof(ulong?):
                dbType = DbType.UInt64;
                return true;
            case Type t when t == typeof(float) || t == typeof(float?):
                dbType = DbType.Single;
                return true;
            case Type t when t == typeof(double) || t == typeof(double?):
                dbType = DbType.Double;
                return true;
            case Type t when t == typeof(decimal) || t == typeof(decimal?):
                dbType = DbType.Decimal;
                return true;
            case Type t when t == typeof(bool) || t == typeof(bool?):
                dbType = DbType.Boolean;
                return true;
            case Type t when t == typeof(string):
                dbType = DbType.String;
                return true;
            case Type t when t == typeof(char) || t == typeof(char?):
                dbType = DbType.StringFixedLength;
                return true;
            case Type t when t == typeof(Guid) || t == typeof(Guid?):
                dbType = DbType.Guid;
                return true;
            case Type t when t == typeof(DateTime) || t == typeof(DateTime?):
                dbType = DbType.DateTime;
                return true;
            case Type t when t == typeof(DateTimeOffset) || t == typeof(DateTimeOffset?):
                dbType = DbType.DateTimeOffset;
                return true;
            case Type t when t == typeof(byte[]):
                dbType = DbType.Binary;
                return true;
            case Type t when t == typeof(System.Xml.Linq.XElement) || t == typeof(System.Xml.XmlDocument):
                dbType = DbType.Xml;
                return true;
            default:
                dbType = default;
                return false;
        }
    }
}
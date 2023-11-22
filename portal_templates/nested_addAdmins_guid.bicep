param serverName string
param aadData object
param apiVersion string

resource serverName_aadData_objectId 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  name: '${serverName}/${aadData.objectId}'
  properties: {
    tenantId: aadData.tenantId
    principalName: aadData.principalName
    principalType: aadData.principalType
  }
}

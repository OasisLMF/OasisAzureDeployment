@description('Resource location')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object

@description('The virtual network name')
param vnetName string

@description('The name of the subnet')
param subnetName string

@description('Name of key vault')
param keyVaultName string

@description('Private DNS zone name. Will be used as <service>.<privateDNSZoneName>')
param privateDNSZoneName string = 'privatelink.postgres.database.azure.com'

@description('Azure database for PostgreSQL compute capacity in vCores (2,4,8,16,32)')
param skuCapacity int = 2

@description('Azure database for PostgreSQL sku name ')
param skuName string = 'GP_Gen5_2'

@description('Azure database for PostgreSQL Sku Size. Valid storage sizes range from minimum of 5120 MB and additional increments of 1024 MB up to maximum of 1048576 MB."}]}')
param skuSizeMB int = 5120

@description('Azure database for Postgresql Sku Tier')
param skuTier string = 'GeneralPurpose'

@description('Azure database for PostgreSQL sku family')
param skuFamily string = 'Gen5'

@description('PostgreSQL version')
param postgresqlVersion string = '11'

@description('PostgreSQL Server backup retention days')
param backupRetentionDays int = 7

@description('Geo-Redundant Backup setting')
param geoRedundantBackup string = 'Disabled'

@description('Name of database instance')
param oasisServerName string = 'oasis-${uniqueString(resourceGroup().id)}'

@description('Username for admin user')
param oasisServerAdminUsername string = 'oasisadmin'

@description('Password for admin user')
param oasisServerAdminPassword string



var privateEndpointName = 'pe-' + oasisServerName
var privateLinkServiceConnectionName = 'plink-' + oasisServerName

var privateDNSZoneId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/privateDnsZones/' + privateDNSZoneName
var vnetId = resourceId('Microsoft.Network/virtualNetworks', vnetName)

resource oasisPostgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2021-05-01-preview' = {
  name: oasisServerName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
    capacity: skuCapacity
    size: skuSizeMB
    family: skuFamily
  }
  properties: {
    version: postgresqlVersion
    backupRetentionDays: backupRetentionDays
    geoRedundantBackup: geoRedundantBackup
    administratorLogin: oasisServerAdminUsername
    administratorLoginPassword: oasisServerAdminPassword
    minimalTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    privateNetworkAccess: {
      privateEndpointConnections: [
        {
          name: privateEndpointName
          privateLinkServiceConnections: [
            {
              name: privateLinkServiceConnectionName
              privateLinkServiceId: resourceId('Microsoft.DBforPostgreSQL/servers', oasisServerName, '2017-12-01-preview')
              groupIds: [
                'sqlServer'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-03-01' = {
  name: privateDNSZoneName
  location: location
  properties: {}
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-03-01' = {
  name: '${privateDNSZoneName}/linkto/${vnetName}'
  dependsOn: [
    privateDnsZone
  ]
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Databases
resource oasisDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  name: oasisDbName
  parent: oasisPostgresqlServer
}

resource keycloakDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  name: 'keycloak'
  parent: oasisPostgresqlServer
}

resource celeryDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  name: 'celery'
  parent: oasisPostgresqlServer
}

// Secrets
resource oasisServerDbName 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-server-name'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: oasisServerName
  }
}

resource oasisServerDbAdminUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-server-admin-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: oasisServerAdminUsername
  }
}

resource oasisServerDbAdminPassword 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-server-admin-password'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: oasisServerAdminPassword
  }
}

resource oasisDbUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: 'oasis@${oasisServerName}'
  }
}

resource keycloakDbUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/keycloak-db-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: 'keycloak@${oasisServerName}'
  }
}

resource celeryDbUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/celery-db-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: 'celery@${oasisServerName}'
  }
}

output privateLinkServiceId string = oasisPostgresqlServer.id
output serverName string = oasisPostgresqlServer.name

module privateEndpoint 'private_endpoint.bicep' = {
  name: 'private-postgresql-endpoint'
  params: {
    privateEndpointName: 'private-postgresql-endpoint'
    location: location
    tags: tags
    vnetName: vnetName
    subnetName: subnetName
    privateLinkServiceId: oasisPostgresqlServer.id
    serverName: oasisPostgresqlServer.name
    keyVaultName: keyVaultName
    privateDNSZoneName: privateDNSZoneName
    privateLinkGroupId: 'postgresqlServer'
    secretHostName: 'oasis-db-server-host'
  }
}



output privateLinkServiceId string = oasisPostgresqlServer.id
output serverName string = oasisPostgresqlServer.name

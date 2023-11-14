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

// @description('Azure database for PostgreSQL compute capacity in vCores (2,4,8,16,32)')
// param skuCapacity int = 2

@description('Azure database for PostgreSQL sku name ')
param skuName string = 'GP_Gen5_2'

@description('The user assigned identity that owns the key vault')
param userAssignedIdentity object

// @description('Azure database for PostgreSQL Sku Size. Valid storage sizes range from minimum of 5120 MB and additional increments of 1024 MB up to maximum of 1048576 MB."}]}')
// param skuSizeMB int = 5120

@description('Azure database for PostgreSQL pricing tier')
@allowed([
  'Basic'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'GeneralPurpose' // 'GeneralPurpose'

// @description('Azure database for PostgreSQL sku family')
// param skuFamily string = 'Gen5'

@description('PostgreSQL version')
@allowed([
  '9.5'
  '9.6'
  '10'
  '10.0'
  '10.2'
  '11'
])
param postgresqlVersion string = '11'

// @description('PostgreSQL Server backup retention days')
// param backupRetentionDays int = 7

// @description('Geo-Redundant Backup setting')
// param geoRedundantBackup string = 'Disabled'

@description('Name of database instance')
param oasisServerName string = 'oasis-${uniqueString(resourceGroup().id)}'

@description('Username for admin user')
param oasisServerAdminUsername string = 'oasisadmin'

@secure()
@description('Password for admin user')
param oasisServerAdminPassword string

// @description('Oasis database name')
// param oasisDbName string = 'oasis'

@description('datases')
param databaseNames array = [
  'oasisdb', 'keycloak', 'celery'
]

//param singleserverName string

// resource oasisPostgreServer 'Microsoft.DBforPostgreSQL/servers@2017-12-01' existing = {
//   name: singleserverName
// }

module private_endpoint 'private_endpoint.bicep' = {
  name: 'privateEndpointName'
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

resource oasisPostgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: oasisServerName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
    // capacity: skuCapacity
    // size: '${skuSizeMB}'
    // family: skuFamily
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      name: userAssignedIdentity
      location: location
      // tags: {
      //   value: {
      //     'oasis-enterprise': true
      // }
      // }
          
    }
  }
  properties: {
    createMode: 'Default'
    version: postgresqlVersion
    administratorLogin: oasisServerAdminUsername
    administratorLoginPassword: oasisServerAdminPassword
    network: {
      delegatedSubnetResourceId: virtualNetwork::databaseSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    storage: {
      storageSizeGB: 128
    }


    // storageProfile: {
    //   storageMB: skuSizeMB
    //   backupRetentionDays: backupRetentionDays
    //   geoRedundantBackup: geoRedundantBackup
    // }
  }


  resource database 'databases' = [ for name in databaseNames: {name: name}]
  
  resource firewall 'firewallRules' = {
    name: 'allow-ip-addresses'
    properties: {
      startIpAddress: '0.0.0.0/0'
      endIpAddress: '0.0.0.0/0'      
    }
  }
}

// // Databases
// resource oasisDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
//   name: oasisDbName
//   parent: oasisPostgresqlServer
// }

// resource keycloakDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
//   name: 'keycloak'
//   parent: oasisPostgresqlServer
// }

// resource celeryDb 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
//   name: 'celery'
//   parent: oasisPostgresqlServer
// }

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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${vnetName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
  resource databaseSubnet 'subnets' = {
    name: 'database-subnet'
    properties: {
      addressPrefix: '10.0.0.0/24'
      delegations: [
        {
          name: '${vnetName}-subnet-delegation'
          properties: {
            serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
          }
        }
      ]
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${privateDNSZoneName}-private.postgres.database.azure.com'
  location: 'global'
  resource vNetLink 'virtualNetworkLinks' = {
    name: '${privateDNSZoneName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }      
    }
  }
}





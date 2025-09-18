@description('Resource location')
param location string

@description('Name of database instance')
param oasisServerName string = 'oasis-${uniqueString(resourceGroup().id)}'

@description('Username for admin user')
param oasisServerAdminUsername string = 'oasisadmin'

@description('Password for admin user')
param oasisServerAdminPassword string

@description('Oasis database name')
param oasisDbName string = 'oasis'

@description('The virtual network name')
param vnetName string

@description('The name of the subnet')
param subnetID string

@description('Name of key vault')
param keyVaultName string = 'oasisVault'

@description('PostgreSQL Server version')
param postgresVersion string

@description('Max storage allowed for a server')
param postgresStorageSizeGB int

@description('SKU of the Nodes running the server')
param postgresNodesVm string

@description('Backup retention days for the server.')
param postgresBackupRetentionDays int

@description('The tier of the particular SKU')
param postgresServerEdition string

// DB placeholder options
param authConfig object = {}
param identityData object = {}
param dataEncryptionData object = {}
param tags object = {}
param aadEnabled bool = false
param geoRedundantBackup string = 'Disabled'
param availabilityZone string = ''
param standbyAvailabilityZone string = ''
param haEnabled string = 'Disabled'


resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'private.postgres.database.azure.com'
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZones
  name: '${privateDnsZones.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/VirtualNetworks', vnetName)
    }
  }
}

resource oasisPostgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  location: location
  name: oasisServerName
  identity: (empty(identityData) ? null : identityData)
  properties: {
    createMode: 'Default'
    administratorLogin: oasisServerAdminUsername
    administratorLoginPassword: oasisServerAdminPassword
    availabilityZone: availabilityZone
    backup: {
      backupRetentionDays: postgresBackupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: haEnabled
      standbyAvailabilityZone: standbyAvailabilityZone
    }
    dataEncryption: (empty(dataEncryptionData) ? null : dataEncryptionData)
    network: {
      delegatedSubnetResourceId: subnetID
      privateDnsZoneArmResourceId: privateDnsZones.id
    }
    storage: {
      storageSizeGB: postgresStorageSizeGB

    }
    version: postgresVersion
    authConfig: (empty(authConfig) ? null : authConfig)
  }
  sku: {
    name: postgresNodesVm
    tier: postgresServerEdition
  }
  tags: tags
  dependsOn: []
}


// Databases
resource oasisDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: oasisDbName
  parent: oasisPostgresqlServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource keycloakDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: 'keycloak'
  parent: oasisPostgresqlServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource celeryDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: 'celery'
  parent: oasisPostgresqlServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
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
    value: 'oasis'
  }
}

resource keycloakDbUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/keycloak-db-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: 'keycloak'
  }
}

resource celeryDbUsername 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/celery-db-username'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: 'celery'
  }
}

resource oasisServerDbLinkName 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-server-host'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: '${oasisServerName}.postgres.database.azure.com'
  }
}

output privateLinkServiceId string = oasisPostgresqlServer.id
output serverName string = oasisPostgresqlServer.name

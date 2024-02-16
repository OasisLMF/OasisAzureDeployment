@secure()
param location string
param oasisServerName string = 'oasis-${uniqueString(resourceGroup().id)}'
param serverEdition string = 'GeneralPurpose'
param storageSizeGB int = 128
param haEnabled string = 'Disabled'
param availabilityZone string = ''
param standbyAvailabilityZone string = ''
param version string = '14'
param tags object = {}
param backupRetentionDays int = 7
param geoRedundantBackup string = 'Disable'
param vmName string = 'Standard_D4s_v3'
@description('Username for admin user')
param oasisServerAdminUsername string = 'oasisadmin'
@secure()
@description('Password for admin user')
param oasisServerAdminPassword string

@description('Oasis database name')
param oasisDbName string = 'oasis'


@description('The virtual network name')
param vnetName string

@description('The name of the subnet')
param subnetName string

@description('The name of the subnet')
param subnetID string

param identityData object = {}
param dataEncryptionData object = {}
param apiVersion string = '14'
param aadEnabled bool = false

param authConfig object = {}
param guid string = newGuid()

@description('Name of key vault')
param keyVaultName string = 'oasisVault'


resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${oasisServerName}.postgres.database.azure.com'
  location: 'global'
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
      backupRetentionDays: backupRetentionDays
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
      storageSizeGB: storageSizeGB

    }
    version: version
    authConfig: (empty(authConfig) ? null : authConfig)
  }
  sku: {
    name: vmName
    tier: serverEdition
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

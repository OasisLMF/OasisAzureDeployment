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
param subnetName string

@description('The name of the subnet')
param subnetID string

@description('Name of key vault')
param keyVaultName string = 'oasisVault'

// DB options and placeholders
param authConfig object = {}
param identityData object = {}
param dataEncryptionData object = {}
param version string = '14'
param tags object = {}
param aadEnabled bool = false
param backupRetentionDays int = 7
param geoRedundantBackup string = 'Disable'
param vmName string = 'Standard_D4s_v3'
param availabilityZone string = ''
param standbyAvailabilityZone string = ''
param serverEdition string = 'GeneralPurpose'
param storageSizeGB int = 128
param haEnabled string = 'Disabled'

// @secure()
// param privateKeyContent = secureFileContent('./private_key.pem')



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

// resource postgresqlServerCertificate 'Microsoft.DBforPostgreSQL/flexibleServers/certificates@2023-06-01-preview' = {
//   parent: oasisPostgresqlServer //flexibleServers_mydemoserver_pg_oasis_name_resource
//   name: 'myCertificate'
//   properties: {
//     publicKey: @copied-pub.crt

//     privateKey: '-----BEGIN PRIVATE KEY-----
//     MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAheqYH8tw1TOIuRE/fszh
// TM0xGh2wjE/9ipu8EgmG4CRjFfIuBSfW52nRrQWY8BdrjB/o5rlfaRZR0JKSGeZ/
// pnXi9XwViwAcuLZXucnIJwuSqydz9zuZxWHBV9S1vFuW8YzRHc07BR++W4Q6rut7
// gevTWBhZ90AluIpeigRweKNq5xR+SLETJRk2M92LY1Lk4e7xtmd+bIgvSphfyS4g
// fZSxKOtAtHhFSJeLMYklGo6D8pz4fbUMi92XA/zjGoj6sSoE9bAxfqtNy2D4+rHf
// e83WypuWPqeEAbOui9emL38ENhc7fHxALHsCEMIko4flCF/96zeMl7LR3ePdVNBg
// CwIDAQAB
//     -----END PRIVATE KEY-----'
//   }
// }

// resource myCertificate 'Microsoft.CertificateRegistration/certificates@2021-06-01' = {
//   name: 'myCertificate'
//   properties: {
//     privateKey: privateKeyContent
//     // Other properties of the certificate
//   }
// }



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

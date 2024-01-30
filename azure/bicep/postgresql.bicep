param administratorLogin string

@secure()
param administratorLoginPassword string
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

@description('Private DNS zone name. Will be used as <service>.<privateDNSZoneName>')
param privateDNSZoneName string = 'privatelink.postgres.database.azure.com'




/*  Networking - sql server   (working notes)

--> we currently use a private link to share access to the DB, the currernt MS docs says this on that method:\
VNET injected resources cannot interact with Private Link by default. If you with to use Private Link for private networking see Azure Database for PostgreSQL Flexible Server Networking with Private Link - Preview


https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking-private 
https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking-private-link

*/


resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZoneName
  location: 'global'
}



param identityData object = {}
param dataEncryptionData object = {}
param apiVersion string = '14'
param aadEnabled bool = true
@description('Active Directory Authentication')
@allowed([
  'Disabled'
  'Enabled'
])
param isActiveDirectoryAuthEnabled string = 'Enabled'

@description('PostgreSQL Authentication')
@allowed([
  'Disabled'
  'Enabled'
])
param isPostgreSQLAuthEnabled string = 'Enabled'

@description('The object ID of the Azure AD admin.')
param aadAdminObjectid string = ''

@description('Azure AD admin name')
param aadAdminName string = 'oasisaadadmin'

@description('Azure AD admin type')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param aadAdminType string = 'ServicePrincipal'

param authConfig object = {}
param guid string = newGuid()

@description('Name of key vault')
param keyVaultName string = 'oasisVault'




resource oasisPostgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  location: location
  name: oasisServerName
  identity: (empty(identityData) ? null : identityData)
  properties: {
    createMode: 'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    availabilityZone: availabilityZone
    minimalTlsVersion: '1.2'
    authConfig: {
      activeDirectoryAuth: isActiveDirectoryAuthEnabled
      passwordAuth: isPostgreSQLAuthEnabled
      tenantId: subscription().tenantId
    }
    authentication: {
      aadAuthentication: {
        login: 'Enabled'
        serverRoles: [
          'admin'
        ]
      }
      type: 'AzureADPassword'
    }
    disableLocalAuth: true
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
  }
  sku: {
    name: vmName
    tier: serverEdition
  }
  tags: tags
  dependsOn: [
    privateDnsZones
  ]
}

resource addAddUser 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
  name: 'oasisPostgresqlServer/aadadmin' // concat(oasisServerName, '-', aadAdminObjectid) //'oasisServerName-${aadAdminObjectid}'
  dependsOn: [
    oasisPostgresqlServer
  ]
  properties: {
    tenantId: subscription().tenantId
    principalType: aadAdminType
    principalName: aadAdminName
  }
}

// resource postgresqlActiveDirectoryAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = {
//   parent: oasisPostgresqlServer
//   name: 'activeDirectory'
//   properties: {
//     // administratorType: 'ActiveDirectory'
//     // login: 'PostgresAdmin'  //This is a Group in the Azure Directory
//     // sid: ''  //grab SID(object id) of the group
//     tenantId: subscription().tenantId  //tenant id
//   }
// }




// https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/flexibleservers/databases?pivots=deployment-language-bicep


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

output privateLinkServiceId string = oasisPostgresqlServer.id
output serverName string = oasisPostgresqlServer.name

/*
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
*/



// resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
//   name: 'private-postgresql-endpoint'
//   location: location
//   tags: tags
//   properties: {
//      subnet: {
//        id: subnetID
//      }
//      privateLinkServiceConnections: [
//        {
//          name: 'db-connection'
//          properties: {
//            privateLinkServiceId: oasisPostgresqlServer.id
//            groupIds: [
//             'postgresqlServer'
//            ]
//          }
//        }
//      ]
//   }
// }

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

// resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-08-01' = {
//   parent: privateEndpoint
//   name: 'default'
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: privateDNSZoneName
//         properties: {
//           privateDnsZoneId: privateDnsZones.id
//         }
//       }
//     ]
//   }
// }

resource oasisServerDbLinkName 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/oasis-db-server-host'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: '${oasisPostgresqlServer.name}.${privateDNSZoneName}'
  }
}





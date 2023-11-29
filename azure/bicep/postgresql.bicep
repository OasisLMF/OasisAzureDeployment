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

@description('Vnet data is an object which contains all parameters pertaining to vnet and subnet')
param vnetData object = {
  virtualNetworkName: 'testVnet'
  virtualNetworkId: 'testVnetId'
  subnetName: 'testSubnet'
  subnetList: [
    {
      subnetName: 'testSubnet'
      subnetNeedsUpdate: false
      subnetProperties: {}
    }
  ]
  virtualNetworkAddressPrefix: '10.0.0.0/16'
  virtualNetworkResourceGroupName: resourceGroup().name
  location: 'eastus2'
  subscriptionId: subscription().subscriptionId
  subnetProperties: {}
  isNewVnet: false
  subnetNeedsUpdate: false
  usePrivateDnsZone: false
  isNewPrivateDnsZone: false
  privateDnsSubscriptionId: subscription().subscriptionId
  privateDnsResourceGroup: resourceGroup().name
  privateDnsZoneName: 'oasisPrivateDnsZone'
  linkVirtualNetwork: false
  Network: {}
}

param identityData object = {}
param dataEncryptionData object = {}
param apiVersion string = '14'
param aadEnabled bool = false
//param aadData object = {"objectId": "", "tenantId":"", "principalName":"", "principalType":"",}
param authConfig object = {}
param guid string = newGuid()
@description('Name of key vault')
param keyVaultName string = 'oasisVault'


param virtualNetworkDeploymentName string
param virtualNetworkLinkDeploymentName string
param privateDnsZoneDeploymentName string


module privateDnsZoneDeployment '../../portal_templates/nested_privateDnsZoneDeployment.bicep' = if (vnetData.usePrivateDnsZone && vnetData.isNewPrivateDnsZone) {
  name: privateDnsZoneDeploymentName
  scope: resourceGroup(vnetData.privateDnsSubscriptionId, vnetData.privateDnsResourceGroup)
  params: {
    vnetData: vnetData
  }
}

module virtualNetworkDeployment '../../portal_templates/nested_virtualNetworkDeployment.bicep' = if (vnetData.isNewVnet || vnetData.subnetNeedsUpdate) {
  name: virtualNetworkDeploymentName
  scope: resourceGroup(vnetData.subscriptionId, vnetData.virtualNetworkResourceGroupName)
  params: {
    vnetData: vnetData
    tags: tags
  }
}

module virtualNetworkLinkDeployment '../../portal_templates/nested_virtualNetworkLinkDeployment.bicep' = if (vnetData.usePrivateDnsZone && vnetData.linkVirtualNetwork) {
  name: virtualNetworkLinkDeploymentName
  scope: resourceGroup(vnetData.privateDnsSubscriptionId, vnetData.privateDnsResourceGroup)
  params: {
    vnetData: vnetData
  }
  dependsOn: [
    privateDnsZoneDeployment
    virtualNetworkDeployment
  ]
}

/**
**/










resource oasisPostgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  location: location
  name: oasisServerName
  identity: (empty(identityData) ? null : identityData)
  properties: {
    createMode: 'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
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
    network: (empty(vnetData.Network) ? null : vnetData.Network)
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
  dependsOn: [
    virtualNetworkLinkDeployment
  ]
}


/**
module addAdmins_guid './nested_addAdmins_guid.bicep' = if (aadEnabled) {
  name: 'addAdmins-${guid}'
  params: {
    serverName: oasisServerName
    aadData: aadData
    apiVersion: apiVersion
  }
  dependsOn: [
    oasisPostgresqlServer
  ]
} 


param serverName string

resource serverName_aadData_objectId 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2022-12-01' = { 
  name: '${serverName}/${aadData.objectId}'
  properties: {
    tenantId: aadData.tenantId
    principalName: aadData.principalName
    principalType: aadData.principalType
  }
} 

*/


// module keyVault '../azure/bicep/key_vault.bicep' = {
//   name: oasisVault
//   params: {
//     keyVaultName: 
//     tags: {
//     }
//     userAssignedIdentity: {
//     }
//   }
// }

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


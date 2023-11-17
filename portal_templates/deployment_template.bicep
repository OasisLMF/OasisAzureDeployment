param administratorLogin string

@secure()
param administratorLoginPassword string
param location string
param serverName string
param serverEdition string
param storageSizeGB int
param haEnabled string = 'Disabled'
param availabilityZone string = ''
param standbyAvailabilityZone string = ''
param version string
param tags object = {}
param storageAutogrow string = 'Disabled'
param backupRetentionDays int
param geoRedundantBackup string
param vmName string = 'Standard_D4s_v3'

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
  privateDnsZoneName: 'testPrivateDnsZone'
  linkVirtualNetwork: false
  Network: {}
}
param virtualNetworkDeploymentName string
param virtualNetworkLinkDeploymentName string
param privateDnsZoneDeploymentName string
param identityData object = {}
param dataEncryptionData object = {}
param apiVersion string = '2022-12-01'
param aadEnabled bool = false
param aadData object = {}
param authConfig object = {}
param iopsTier string = ''
param storageIops int = 0
param throughput int = 0
param storageType string = ''
param guid string = newGuid()

module privateDnsZoneDeployment './nested_privateDnsZoneDeployment.bicep' = if (vnetData.usePrivateDnsZone && vnetData.isNewPrivateDnsZone) {
  name: privateDnsZoneDeploymentName
  scope: resourceGroup(vnetData.privateDnsSubscriptionId, vnetData.privateDnsResourceGroup)
  params: {
    vnetData: vnetData
  }
}

module virtualNetworkDeployment './nested_virtualNetworkDeployment.bicep' = if (vnetData.isNewVnet || vnetData.subnetNeedsUpdate) {
  name: virtualNetworkDeploymentName
  scope: resourceGroup(vnetData.subscriptionId, vnetData.virtualNetworkResourceGroupName)
  params: {
    vnetData: vnetData
    tags: tags
  }
}

module virtualNetworkLinkDeployment './nested_virtualNetworkLinkDeployment.bicep' = if (vnetData.usePrivateDnsZone && vnetData.linkVirtualNetwork) {
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

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@[parameters(\'apiVersion\')]' = {
  location: location
  name: serverName
  identity: (empty(identityData) ? json('null') : identityData)
  properties: {
    createMode: 'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    availabilityZone: availabilityZone
    Backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: haEnabled
      standbyAvailabilityZone: standbyAvailabilityZone
    }
    dataencryption: (empty(dataEncryptionData) ? json('null') : dataEncryptionData)
    Network: (empty(vnetData.Network) ? json('null') : vnetData.Network)
    Storage: {
      StorageSizeGB: storageSizeGB
      Type: (empty(storageType) ? json('null') : storageType)
      Autogrow: storageAutogrow
      tier: (empty(iopsTier) ? json('null') : iopsTier)
      Iops: ((storageIops == 0) ? json('null') : storageIops)
      Throughput: ((throughput == 0) ? json('null') : throughput)
    }
    version: version
    authConfig: (empty(authConfig) ? json('null') : authConfig)
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

module addAdmins_guid './nested_addAdmins_guid.bicep' = if (aadEnabled) {
  name: 'addAdmins-${guid}'
  params: {
    serverName: serverName
    aadData: aadData
    apiVersion: apiVersion
  }
  dependsOn: [
    server
  ]
}
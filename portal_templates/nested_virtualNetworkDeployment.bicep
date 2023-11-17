@description('Vnet data is an object which contains all parameters pertaining to vnet and subnet')
param vnetData object
param tags object

resource vnetData_virtualNetworkName_vnetData_subnet 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = if (vnetData.subnetNeedsUpdate) {
  name: '${vnetData.virtualNetworkName}/${vnetData.subnetName}'
  properties: vnetData.subnetProperties
}

resource vnetData_virtualNetwork 'Microsoft.Network/virtualNetworks@2020-05-01' = if (vnetData.isNewVnet) {
  name: vnetData.virtualNetworkName
  location: vnetData.location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetData.virtualNetworkAddressPrefix
      ]
    }
    subnets: [for j in range(0, length(vnetData.subnetList)): {
      name: vnetData.subnetList[j].subnetName
      properties: vnetData.subnetList[j].subnetProperties
    }]
  }
}
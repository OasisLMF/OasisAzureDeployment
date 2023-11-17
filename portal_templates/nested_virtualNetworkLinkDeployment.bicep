@description('Vnet data is an object which contains all parameters pertaining to vnet and subnet')
param vnetData object

resource vnetData_privateDnsZoneName_vnetData_virtualNetworkId 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${vnetData.privateDnsZoneName}/${uniqueString(vnetData.virtualNetworkId)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetData.virtualNetworkId
    }
    registrationEnabled: false
  }
}
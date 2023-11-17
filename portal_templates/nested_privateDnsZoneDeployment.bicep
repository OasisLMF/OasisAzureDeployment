@description('Vnet data is an object which contains all parameters pertaining to vnet and subnet')
param vnetData object

resource vnetData_privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: vnetData.privateDnsZoneName
  location: 'global'
  tags: {}
  properties: {}
}
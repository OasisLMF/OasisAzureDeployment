param name string = 'oasis-flex-server'
param location string = 'northcentralus'
@secure()
param adminPassword string
param databasesNames array = ['oasisdb', 'keycloak', 'celery']

var pgServerPrefix = '${name}-postgres-server'

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: 'psqladmin'
    administratorLoginPassword: adminPassword
    version: '14'
    storage: {
      storageSizeGB: 128
    }    
    network: {
      delegatedSubnetResourceId: virtualNetwork::databaseSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
  }

  resource database 'databases' = [for name in databasesNames: {
    name: name }
  ]  

  resource firewallAzure 'firewallRules' = {
    name: 'allow-ip-addresses'
    properties: {
      startIpAddress:'0.0.0.0'
      endIpAddress: '0.0.0.0'      
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${name}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
  }

  resource databaseSubnet 'subnets' = {
    name: 'database-subnet'
    properties: {
      addressPrefix:'10.0.0.0/24'
      delegations: [
        {
          name: '${name}-subnet-delegation'
          properties: {
            serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
          }
        }
      ]      
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${pgServerPrefix}-private.postgres.database.azure.com'
  location: 'global'
  resource vNetLink 'virtualNetworkLinks' = {
    name: '${pgServerPrefix}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }      
    }
  }
}




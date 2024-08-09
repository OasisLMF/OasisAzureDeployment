@description('Resource location')
param location string = resourceGroup().location

@description('Blob Storage account name')
param oasisBlobStorageAccountName string = substring('blob${uniqueString(resourceGroup().id)}', 0, 17)

@description('Azure storage SKU type')
@allowed([
    'Premium_LRS'
    'Premium_ZRS'
    'Standard_GRS'
    'Standard_GZRS'
    'Standard_LRS'
    'Standard_RAGRS'
    'Standard_RAGZRS'
    'Standard_ZRS'
])
param oasisBlobStorageAccountSKU string = 'Premium_LRS'

@description('Tags for the resources')
param tags object

@description('Name of secret to store name of storage account')
param oasisBlobNameSecretName string = 'oasisblob-name'

@description('Name of secret to store key to storage account')
param oasisBlobKeySecretName string = 'oasisblob-key'

@description('Blob Container name for oasis shared file system')
param serverContainerName string = 'server'

@description('Blob Container name for model files')
param modelsContainerName string = 'models'

@description('Blob Container name for model files')
param logsContainerName string = 'logs'

@description('Name of key vault')
param keyVaultName string

@description('The virtual network address prefixes')
param allowedCidrRanges array = []

@description('The sub network ID to allow access from')
param subnetId string

var allAccess = empty(allowedCidrRanges) || contains(allowedCidrRanges, '0.0.0.0/0')
var defaultNetworkAction = allAccess ? 'Allow' : 'Deny'
var allowedCidrRangesCleaned = allAccess ? [] : allowedCidrRanges


resource blobFs 'Microsoft.Storage/storageAccounts@2021-09-01' = {
    name: oasisBlobStorageAccountName
    location: location
    sku: {
        name: oasisBlobStorageAccountSKU
    }
    kind: 'BlockBlobStorage'
    tags: tags
    properties: {
        allowSharedKeyAccess: true
        allowBlobPublicAccess: false
        supportsHttpsTrafficOnly: true
        minimumTlsVersion: 'TLS1_2'
        networkAcls: {
            bypass: 'Logging, AzureServices'
            virtualNetworkRules: [
                {
                    id: subnetId
                }
            ]
            ipRules: [for cidr in allowedCidrRangesCleaned: {
                value: replace(cidr, '/32', '')
                action: 'Allow'
            }]
            defaultAction: defaultNetworkAction
        }
    }
}


resource blobFsSecret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/${oasisBlobKeySecretName}'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: '${listKeys(blobFs.id, blobFs.apiVersion).keys[0].value}'
  }
}

resource blobFsNameSecret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = {
  name: '${keyVaultName}/${oasisBlobNameSecretName}'
  tags: tags
  properties: {
    attributes: {
      enabled: true
    }
    value: oasisBlobStorageAccountName
  }
}

// resource serverContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
//   name: '${blobFs.name}/default/${serverContainerName}'
// }
// 
// resource modelsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
//   name: '${blobFs.name}/default/${modelsContainerName}'
// }

resource modelsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${blobFs.name}/default/${logsContainerName}'
}

output oasisBlobNameSecretName string = oasisBlobNameSecretName
output oasisBlobKeySecretName string = oasisBlobKeySecretName
// output serverBlobContainerName string = serverContainerName
// output modelsBlobContainerName string = modelsContainerName
// output logsBlobContainerName string = logsContainerName

@description('Resource location')
param location string = resourceGroup().location

@description('The Tenant Id that should be used throughout the deployment.')
param tenantId string = subscription().tenantId

@description('The name of the Key Vault.')
param keyVaultName string

@description('Tags for the resources')
param tags object

@description('The user assigned identity that owns the key vault')
param userAssignedIdentity object

@description('Current user object id - if set will add access for this user to the key vault')
param currentUserObjectId string = ''

//param certificateName string = 'cert-${uniqueString(resourceGroup().id)}'

// @secure()
// param pass string

var accessPolicies = concat([
    {
     tenantId: tenantId
     permissions: {
       secrets: [
         'get'
         'list'
       ]
     }
     objectId: userAssignedIdentity.properties.principalId
    }
], empty(currentUserObjectId) == true ? [] : [
    {
     tenantId: tenantId
     permissions: {
       secrets: [
         'all'
       ]
       certificates: [
         'all'
       ]
     }
     objectId: currentUserObjectId
    }
])

// param secrets array = [
//   {
//     name: 'postgres-cert'
//     filePath: './private-key.pem'
//   }
// ]

// resource postgrescert 'Microsoft.KeyVault/vaults/certificates@2021-06-01-preview' = {
//   //parent: keyVault
//   name: '${keyVault.name}/${certificateName}'
//   properties: {
//     certificatePolicy: {
//       issuerParameters: {
//         name: 'Unknown'
//       }
//       keyProperties: {
//         keyType: 'RSA'
//         keySize: 2048
//         reuseKey: false
//       }
//       x509CertificateProperties: {
//         subject: 'CN=my-certificate'
//         validityInMonths: 12
//       }
//     }
//     //value: pass
//   }
// }
  
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    
    enableSoftDelete: false
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: tenantId
    accessPolicies: accessPolicies
  }
}

output keyVaultName string = keyVaultName
output keyVaultUri string = keyVault.properties.vaultUri

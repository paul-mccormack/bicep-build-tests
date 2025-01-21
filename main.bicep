
//uncomment the parameter below to trigger a warning
param notused string = 'unused'

@description('Azure region for deployment')
param location string = resourceGroup().location

//Edit this to provide a prefix for your storage account name.  Max 11 characters.
@description('Prefix for the Storage Account Name.  This would normally be the descriptive part of the name. Letters and numbers only, Max Length 11 characters')
@maxLength(11)
param storageAccountPrefix string = 'pmcmodops'

@description('Creates a globally unique name for the storage account from storageAccountPrefix and generated unique characters.')
var stgName = toLower('${storageAccountPrefix}${uniqueString(resourceGroup().id)}')

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
@description('Storage account SKU.  Allowed values only')
param storageSku string = 'Standard_LRS'

@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
@description('Storage account type.  Allowed values only.  Default is StorageV2')
param storageKind string = 'StorageV2'

@minLength(3)
@maxLength(63)
@description('Blob container name.  minimum 3 maximum 63 characters.  lowercase letters, numbers and - only.')
param containerName string = 'blobs'

@allowed([
  'None'
  'Blob'
  'Container'
])
@description('Container public access.  Allowed list only.  Default is None.')
param containerPublicAccess string = 'None'

resource stg 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: stgName
  location: location 
  sku: {
    name: storageSku
  }
  kind: storageKind
}

@description('Deploy blob service')
resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: stg
  name: 'default'
}

@description('Deploy blob container')
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blob
  name: toLower(containerName)
  properties: {
    publicAccess: containerPublicAccess
  }
}

//uncomment the output below to trigger an error causing the deployment to fail
//output leakedsecret string = stg.listKeys().keys[0].value

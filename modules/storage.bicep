param location string = resourceGroup().location

@description('Prefix of the storage account')
param prefix string

@description('The redundancy required for the account')
param skuName string = 'Standard_LRS'

@description('Tags for the storage resources.')
param tags object

resource storageAcct 'Microsoft.Storage/storageAccounts@2021-02-01' =  {
  name: '${prefix}${uniqueString(resourceGroup().id)}'
  kind: 'StorageV2'
  location: location
  tags: tags
  sku: {
    name: skuName
  }
}

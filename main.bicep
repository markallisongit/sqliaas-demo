@description('local administrator password for the Azure SQL Virtual Machines')
@secure()
param adminPassword string

@description('IP Address to allow to the public endpoint')
param allowPublicIp string

@description('Name of the backups storage account')
param backupAccountNamePrefix string

@description('data disk configurations for the Azure Virtual Machines')
param dataDisks array

@description('Suffix to make deployment names unique')
param deploymentNameSuffix string = utcNow()

@description('The environment')
@allowed([
  'prod'
  'test'
])
param environment string

@description('The network location')
param location string = deployment().location

@description('Network security group name.')
param networkSecurityGroupName string

@description('Security rules')
param resourceGroupName string

@description('Subnet range')
param subnetAddressRange string

@description('Name of the subnet')
param subnetName string

@description('Azure SQL Virtual Machine name')
param vmName string

param vmSize string

@description('Virtual network IP address range.')
param vnetAddressRange string

@description('Vnet name')
param vnetName string

// this script sets SQL Server and SQL Server Agent to delayed Start to avoid race condition
var script = 'sc.exe config SQLSERVERAGENT start= delayed-auto; sc.exe config MSSQLSERVER start= delayed-auto;'

var securityRules = [
  {
    name: 'let-me-in'
    properties: {
      priority: 1000
      sourceAddressPrefix: allowPublicIp
      protocol: 'Tcp'
      destinationPortRanges: [
        1433
        3389
      ]
      access: 'Allow'
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
    }
  }
]

var tags = {
  'Contact': 'home@markallison.co.uk'
  'Project': 'Azure demo'
  'Env': environment
  'Description': 'Demo for article https://markallison.co.uk/sqliaas-problem/'
}

// create the resource group
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module storageAcct 'modules/storage.bicep' =  {
  name: 'storageDeployment.${deploymentNameSuffix}'
  params: {
    location: location
    prefix: backupAccountNamePrefix
    tags: tags    
  }
  scope: rg
}

module vnet './modules/network.bicep' = {
  name: 'networkDeployment.${deploymentNameSuffix}'
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupName
    securityRules: securityRules
    subnetAddressRange: subnetAddressRange
    subnetName: subnetName
    tags: tags
    vnetAddressRange: vnetAddressRange
    vnetName: vnetName
  }
  scope: rg
}

module vm './modules/vm.bicep' = {
  name: 'vmDeployment.${deploymentNameSuffix}'
  params: {
    adminPassword: adminPassword
    backupAccountNamePrefix: backupAccountNamePrefix
    dataDisks: dataDisks
    location: location
    subnetName: subnetName
    tags: tags
    vmName: vmName
    vmSize: vmSize
    vnetName: vnetName
  }
  scope: rg
  dependsOn: [
    vnet
    storageAcct
  ]
}

module vm_run_cmd './modules/vm-run-cmd.bicep' = {
  name: 'setSqlDelayedStart.${deploymentNameSuffix}'
  params: {
    name: '${vmName}/sqlDelayedStart'
    location: location
    script: script
    timeoutInSeconds: 120
  }
  scope: rg
  dependsOn: [
    vm
  ]
}

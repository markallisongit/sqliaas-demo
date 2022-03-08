@description('local administrator user name for the Azure SQL Virtual Machines')
param adminUserName string = 'mark'

@description('Time to auto shutdown the VM')
param autoShutdownTime string = '20:00'

@description('Enable auto shutdown the VM')
param autoShutdownEnabled bool = true

@description('local administrator password for the Azure SQL Virtual Machines')
@secure()
param adminPassword string

@description('Name of the backups storage account')
param backupAccountNamePrefix string

@description('Logical Disk Numbers (LUN) for SQL data disks.')
param dataDisksLUNs array = [
  0
]

@description('data disk configurations for the Azure Virtual Machines')
param dataDisks array

@description('Default path for SQL data files.')
param dataPath string = 'F:\\SQLData'

@description('Name of the subnet that the Azure SQL Virtual Machines are connected to')
param subnetName string

param location string = resourceGroup().location

@description('Default path for SQL log files.')
param logPath string = 'G:\\SQLLog'

@description('Logical Disk Numbers (LUN) for SQL log disks.')
param logDisksLUNs array = [
  1
]

@description('Azure SQL Virtual Machines OS Disk type')
param osDiskType string  = 'Premium_LRS'

@description('Public Ip address Sku')
param pipSku string  = 'Basic'

@description('Number of days to keep sql backups')
param sqlAutobackupRetentionPeriod int = 14

@description('SQL Patching day')
param sqlAutopatchingDayOfWeek string = 'Sunday'

@description('SQL Patching day')
param sqlAutopatchingStartHour int = 2

@description('Patching window duration (minutes)')
param sqlAutopatchingWindowDuration int = 120

@description('SQL server connectivity option')
@allowed([
  'LOCAL'
  'PRIVATE'
  'PUBLIC'
])
param sqlConnectivityType string = 'PRIVATE'

@description('SQL server port')
param sqlPortNumber int = 1433

@description('SQL Server Image SKU')
param sqlImageSku string = 'sqldev-gen2'

@description('Select the version of SQL Server Image type')
param sqlServerImageType string = 'sql2019-ws2022'

@description('SQL server license type')
@allowed([
  'AHUB'
  'PAYG'
  'DR'
])
param sqlServerLicenseType string = 'PAYG'

@description('SQL server workload type')
@allowed([
  'DW'
  'GENERAL'
  'OLTP'
])
param sqlStorageWorkloadType string = 'GENERAL'

param tags object

@description('Default path for SQL Temp DB files. Use the fast local temp disk')
param tempDBPath string = 'D:\\SQLTemp'

@description('Azure SQL Virtual Machine name')
param vmName string

@description('Size for the Azure Virtual Machines')
param vmSize string

@description('Name of the VNet that the Azure SQL Virtual Machines are connected to')
param vnetName string

var nicName = '${vmName}-nic1'
var pipName = '${vmName}-pip1'
var vmFqdn = '${vmName}.${location}.cloudapp.azure.com'
var backupAccountName = '${backupAccountNamePrefix}${uniqueString(resourceGroup().id)}'

// this is the existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: vnetName
}

// This is the existing subnet in the existing vnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: subnetName
  parent: vnet
}

// the public ip address of the VM
resource pip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: pipSku
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: vmName
      fqdn: vmFqdn
    }
  }
}

// a network interface must be created first and assigned the IP address
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    enableAcceleratedNetworking: false
  }
}

// this section defines the VM configuration
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: sqlServerImageType
        sku: sqlImageSku
        version: 'latest'
      }
      dataDisks: [for (disk, i) in dataDisks: {
        lun: i
        createOption: disk.createOption
        caching: disk.caching
        writeAcceleratorEnabled: disk.writeAcceleratorEnabled
        diskSizeGB: disk.diskSizeGB
        managedDisk: {
          storageAccountType: disk.storageAccountType
        }
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', nicName)
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUserName
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  dependsOn: [
    nic
  ]
}

// this shuts down the VM at the end of the day, if enabled
resource vmschedule 'Microsoft.DevTestLab/schedules@2018-09-15' = if (autoShutdownEnabled) {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime      
    }
    timeZoneId: 'UTC'
    targetResourceId: resourceId('Microsoft.Compute/virtualMachines', vmName)
  }
  dependsOn: [
    vm
  ]
}


// this extension installs SQL Server
resource sql_vm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2017-03-01-preview' = {
  name: vmName
  location: location
  properties: {
    virtualMachineResourceId: resourceId('Microsoft.Compute/virtualMachines', vmName)
    sqlManagement: 'Full'
    sqlServerLicenseType: sqlServerLicenseType
    autoPatchingSettings: {
      enable: true
      dayOfWeek: sqlAutopatchingDayOfWeek
      maintenanceWindowStartingHour: sqlAutopatchingStartHour
      maintenanceWindowDuration: sqlAutopatchingWindowDuration
    }
    autoBackupSettings: {
      enable: true
      retentionPeriod: sqlAutobackupRetentionPeriod
      storageAccountUrl: reference(resourceId( 'Microsoft.Storage/storageAccounts', backupAccountName), '2018-07-01').primaryEndpoints.blob
      storageAccessKey: first(listKeys(resourceId( 'Microsoft.Storage/storageAccounts', backupAccountName), '2018-07-01').keys).value
      enableEncryption: false
      backupSystemDbs: true
      backupScheduleType: 'Automated'
      storageContainerName: vmName
    }
    storageConfigurationSettings: {
      diskConfigurationType: 'NEW'
      storageWorkloadType: sqlStorageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLUNs
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLUNs
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDBPath
      }
    }
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: sqlConnectivityType
        port: sqlPortNumber
        sqlAuthUpdateUserName: adminUserName
        sqlAuthUpdatePassword: adminPassword
      }
      additionalFeaturesServerConfigurations: {
        isRServicesEnabled: false
      }
    }
  }
  dependsOn: [
    vm
  ]
}

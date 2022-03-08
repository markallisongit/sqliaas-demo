[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]      $Location = "uksouth",    
    [Parameter (Mandatory = $false)] [string]        $Environment = "test"
)
$ErrorActionPreference = 'Stop'

# Get my public IP
Write-Verbose "Getting public IP"
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# obviously don't do this, this is just for convenience, use key vault
$adminPassword = ConvertTo-SecureString 'MySec3rePa$$wordlol' -AsPlainText -Force

Write-Verbose "Reading parameters file"
$p = Get-Content ./parameters/$Environment.$Location.json -Raw | ConvertFrom-Json
$vmName = $p.parameters.vmName.value
$rg = $p.parameters.ResourceGroupName.value

# start the VM if already deployed
Write-Verbose "Starting VM $($vmName), if exists"
try {
    Get-AzVM -ResourceGroupName $rg -Name $vmName |  Start-AzVM
}
catch {
    Write-Warning "VM not found, skipping start."
}

Write-Verbose "Deploying template"
New-AzDeployment -Name deploy.$(Get-Date -Format "yyyyMMdd.HHmmss") `
    -Location $Location `
    -TemplateFile ./main.bicep `
    -TemplateParameterFile "./parameters/$Environment.$Location.json" `
    -allowPublicIp $ip `
    -adminPassword $adminPassword `
    -environment $Environment
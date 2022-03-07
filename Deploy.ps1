[cmdletbinding()]
param (
    [Parameter (Mandatory = $false)]  [string]      $Location = "uksouth",    
    [Parameter (Mandatory = $false)] [string]        $Environment = "test"
)

# Get my public IP
$ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# obviously don't do this, this is just for convenience, use key vault
$adminPassword = ConvertTo-SecureString 'MySec3rePa$$wordlol' -AsPlainText -Force

New-AzDeployment -Name deploy.$(Get-Date -Format "yyyyMMdd.HHmmss") `
    -Location $Location `
    -TemplateFile ./main.bicep `
    -TemplateParameterFile "./parameters/$Environment.$Location.json" `
    -allowPublicIp $ip `
    -adminPassword $adminPassword `
    -environment $Environment
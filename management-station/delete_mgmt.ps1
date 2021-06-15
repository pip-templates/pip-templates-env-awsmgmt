#!/usr/bin/env pwsh

param
(
    [Alias("Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Parameter(Mandatory=$false, Position=1)]
    [string] $ConfigPrefix = "environment",

    [Alias("Resources")]
    [Parameter(Mandatory=$false, Position=2)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePrefix
)

$ErrorActionPreference = "Stop"

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../common/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Set default parameter values
if (($ResourcePath -eq $null) -or ($ResourcePath -eq ""))
{
    $ResourcePath = ConvertTo-EnvResourcePath -ConfigPath $ConfigPath
}
if (($ResourcePrefix -eq $null) -or ($ResourcePrefix -eq "")) 
{ 
    $ResourcePrefix = $ConfigPrefix 
}

# Read config and resources
$config = Read-EnvConfig -ConfigPath $ConfigPath
$resources = Read-EnvResources -ResourcePath $ResourcePath

# Configure AWS cli
$env:AWS_ACCESS_KEY_ID = Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.access_id"
$env:AWS_SECRET_ACCESS_KEY = Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.access_key"
$env:AWS_DEFAULT_REGION = Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region"

# Delete aws mgmt resources
Write-Host "Destroying CloudFormation stack and EC2 resources of management station..."
$stackName = "mgmt-$(Get-EnvMapValue -Map $config -Key "environment.name")"
aws cloudformation delete-stack --region $(Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region") --stack-name $stackName | Out-Null
Write-Host "CloudFormation stack and EC2 resources destroyed."

# Cleanup resources file
Remove-EnvMapValue -Map $resources -Key "mgmt.private_ip"
Remove-EnvMapValue -Map $resources -Key "mgmt.public_ip"
Remove-EnvMapValue -Map $resources -Key "mgmt.id"
Remove-EnvMapValue -Map $resources -Key "mgmt.sg_id"

Write-EnvResources -Path $ConfigPath -Resources $resources

#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$false, Position=0)]
    [string] $ConfigPath
)

$ErrorActionPreference = "Stop"

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../lib/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Read config and resources
$config = Read-EnvConfig -Path $ConfigPath
$resources = Read-EnvResources -Path $ConfigPath

# Configure AWS cli
$env:AWS_ACCESS_KEY_ID = $config.aws_access_id
$env:AWS_SECRET_ACCESS_KEY = $config.aws_access_key 
$env:AWS_DEFAULT_REGION = $config.aws_region 

# Delete aws mgmt resources
Write-Host "Destroying CloudFormation stack and EC2 resources of management station..."
$stackName = "mgmt-$($config.env_name)"
aws cloudformation delete-stack --region $config.aws_region --stack-name $stackName | Out-Null
Write-Host "CloudFormation stack and EC2 resources destroyed."

# Cleanup resources file
$resources.mgmt_private_ip = $null
$resources.mgmt_public_ip = $null
$resources.mgmt_id = $null
$resources.mgmt_sg_id = $null

# Write k8s resources
Write-EnvResources -Path $ConfigPath -Resources $resources

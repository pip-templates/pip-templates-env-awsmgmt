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

# Create key pair
if ($config.mgmt_instance_keypair_new) {
    # Register key pair on aws
    $publicKey = (Get-Content -Path "$path/../config/$($config.mgmt_instance_keypair_name).pub" ) | Out-String
    $null = aws ec2 import-key-pair --region $config.aws_region --key-name $config.mgmt_instance_keypair_name --public-key-material $publicKey

    Write-Host "Created keypair $($config.mgmt_instance_keypair_name) on aws account."
}

# Prepare CloudFormation template
Build-EnvTemplate -InputPath "$($path)/../templates/cloudformation_mgmt.yml" -OutputPath "$($path)/../temp/cloudformation_mgmt.yml" -Params1 $config -Params2 $resources

# Create management station
Write-Host "Creating management station AWS EC2 instance..."
$stackName = "mgmt-$($config.env_name)"
aws cloudformation create-stack --region $config.aws_region --stack-name $stackName --template-body "file://$($path)/../temp/cloudformation_mgmt.yml"

# Check for error
if ($LastExitCode -ne 0) {
    Write-Error "Can't create cloudformation stack $stackName. Watch logs above or check aws console and make sure it doesn't exists."
}

# Wait until stack creation is completed
Write-Host "Waiting for AWS EC2 instance to be created. It may take up to 10 minutes..."
aws cloudformation wait stack-create-complete --region $config.aws_region --stack-name $stackName

# Check for error
if ($LastExitCode -ne 0) {
    Write-Error "Can't create vm resources. Watch logs above or AWS CloudFormation stack $stackName events."
} else {
    Write-Host "Management station created."
}

Write-Host "Get Describe for created instance."
$out = (aws cloudformation describe-stacks --region $config.aws_region --stack-name $stackName  | ConvertFrom-Json) 

# Check for error
if ($LastExitCode -ne 0) {
    Write-Error "Can't get describe of stack $stackName"
} else {
    Write-Host "Received the describe of stack $stackName ."
}

Write-Host "Resource handling"
$outputs = ConvertOutputToResources -Outputs $out.Stacks.Outputs

# Get output resources
$resources.mgmt_private_ip = $outputs.PrivateIp.Trim()
$resources.mgmt_public_ip = $outputs.PublicIp.Trim()
$resources.mgmt_id = $outputs.InstanceId
$resources.mgmt_sg_id = $outputs.MgmtSecurityGroupId

# Open access to allowed IP addresses if required
foreach ($cidr in $config.mgmt_ssh_allowed_cidr_blocks) {
    # Add ip to db security group 
    aws ec2 authorize-security-group-ingress `
        --group-id $resources.mgmt_sg_id `
        --protocol tcp `
        --port 22 `
        --cidr $cidr
    
    if ($LastExitCode -eq 0) {
        Write-Host "Opened port 22 on mgmt station for '$cidr'"
    }
}

# Write AWS EC2 resources
Write-EnvResources -Path $ConfigPath -Resources $resources

Write-Host "Resources Saved"

# Copy whole project to mgmt station
# Define os type by full path
if ($config.copy_project_to_mgmt_station) {
   if($IsMacOS)
    {
        # macos
        ssh "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip)" -i "$path/../config/$($config.mgmt_instance_keypair_name)" "mkdir -p /home/$($config.mgmt_instance_username)"
        Write-Host "Copying pip-templates-envmgmt to mgmt station..."
        Set-Location "$($path)/.."
        $tmp = (Get-Item -Path ".\").FullName
        $null = scp -i "$path/../config/$($config.mgmt_instance_keypair_name)" -r $tmp "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip):/home/$($config.mgmt_instance_username)"
        
        $tmp = "$($tmp)/config"
        $null = scp -i "$path/../config/$($config.mgmt_instance_keypair_name)" -r $tmp "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip):/home/$($config.mgmt_instance_username)"
    }
    else {
        if ($path[0] -eq "/") {
            # ubuntu
            ssh "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip)" -i "$path/../config/$($config.mgmt_instance_keypair_name)" "mkdir -p /home/$($config.mgmt_instance_username)"
            Write-Host "Copying pip-templates-envmgmt to mgmt station..."
            $null = scp -i "$path/../config/$($config.mgmt_instance_keypair_name)" -r "$path/.." "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip):/home/$($config.mgmt_instance_username)"
        } else {
            # windows
            ssh "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip)" -i "$path/../config/$($config.mgmt_instance_keypair_name)" "mkdir -p /home/$($config.mgmt_instance_username)/pip-templates-envmgmt"
            Write-Host "Copying pip-templates-envmgmt to mgmt station..."
            $null = scp -i "$path/../config/$($config.mgmt_instance_keypair_name)" -r "$path/../*" "$($config.mgmt_instance_username)@$($resources.mgmt_public_ip):/home/$($config.mgmt_instance_username)/pip-templates-envmgmt"
        }
    }

    # Copy this project to mgmt station with configs and resources
    Write-Host "Proceed the environment creation on mgmt station:"
    Write-Host "ssh $($config.mgmt_instance_username)@$($resources.mgmt_public_ip) -i $path/../config/$($config.mgmt_instance_keypair_name)"
    Write-Host "cd ~/pip-templates-envmgmt" 
}



#!/usr/bin/env pwsh

param
(
    [Alias("Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Parameter(Mandatory=$false, Position=1)]
    [string] $ConfigPrefix = "mgmt",

    [Alias("Resources")]
    [Parameter(Mandatory=$false, Position=2)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePrefix,

    [Parameter(Mandatory=$false, Position=4)]
    [string] $AWSPrefix = "aws",
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

# Create key pair
if (Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.keypair_new") 
{
    # Register key pair on aws
    $keyPairName = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.keypair_name"
    $publicKey = (Get-Content -Path "$path/../config/$keyPairName.pub" ) | Out-String
    $null = aws ec2 import-key-pair --region $(Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region") --key-name $keyPairName --public-key-material $publicKey

    Write-Host "Created keypair $keyPairName on aws account."
}

# Prepare CloudFormation template
$templateParams = @{ 
    vpc = Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.vpc"
    mgmt_subnet_zone = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.subnet_zone"
    mgmt_subnet_cidr = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.subnet_cidr"
    mgmt_instance_type = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.type"
    mgmt_instance_ami = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.ami"
    mgmt_instance_keypair_name = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.keypair_name"
    env_name = Get-EnvMapValue -Map $config -Key "environment.name"
}
Build-EnvTemplate -InputPath "$($path)/templates/cloudformation_mgmt.yml" -OutputPath "$($path)/../temp/cloudformation_mgmt.yml" -Params1 $templateParams

# Create management station
Write-Host "Creating management station AWS EC2 instance..."
$stackName = "mgmt-$(Get-EnvMapValue -Map $config -Key "environment.name")"
aws cloudformation create-stack --region $(Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region") --stack-name $stackName --template-body "file://$($path)/../temp/cloudformation_mgmt.yml"

# Check for error
if ($LastExitCode -ne 0) 
{
    Write-Error "Can't create cloudformation stack $stackName. Watch logs above or check aws console and make sure it doesn't exists."
}

# Wait until stack creation is completed
Write-Host "Waiting for AWS EC2 instance to be created. It may take up to 10 minutes..."
aws cloudformation wait stack-create-complete --region $(Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region") --stack-name $stackName

# Check for error
if ($LastExitCode -ne 0) 
{
    Write-Error "Can't create vm resources. Watch logs above or AWS CloudFormation stack $stackName events."
} 
else 
{
    Write-Host "Management station created."
}

Write-Host "Get Describe for created instance."
$out = (aws cloudformation describe-stacks --region $(Get-EnvMapValue -Map $config -Key "hw.$AWSPrefix.region") --stack-name $stackName  | ConvertFrom-Json) 

# Check for error
if ($LastExitCode -ne 0) 
{
    Write-Error "Can't get describe of stack $stackName"
} 
else 
{
    Write-Host "Received the describe of stack $stackName"
}

Write-Host "Resource handling"
$outputs = ConvertOutputToResources -Outputs $out.Stacks.Outputs

# Get output resources
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix" -Value @{}
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.private_ip" -Value $outputs.PrivateIp.Trim()
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.public_ip" -Value $outputs.PublicIp.Trim()
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.id" -Value $outputs.InstanceId
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.sg_id" -Value $outputs.MgmtSecurityGroupId

# Open access to allowed IP addresses if required
foreach ($cidr in Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.ssh_allowed_cidr_blocks") {
    # Add ip to db security group 
    aws ec2 authorize-security-group-ingress `
        --group-id $(Get-EnvMapValue -Map $resources -Key "$ResourcePrefix.sg_id") `
        --protocol tcp `
        --port 22 `
        --cidr $cidr
    
    if ($LastExitCode -eq 0) 
    {
        Write-Host "Opened port 22 on mgmt station for '$cidr'"
    }
}

# Write AWS EC2 resources
Write-EnvResources -ResourcePath $ResourcePath -Resources $resources

Write-Host "Resources Saved"

# Copy whole project to mgmt station
# Define os type by full path
if (Get-EnvMapValue -Map $config -Key "$HWConfigPrefix.copy_project_to_mgmt_station") {
   
    Write-Host "Copying environment management project to mgmt station..."
    $keyPairName = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.keypair_name"
    $mgmtUser = Get-EnvMapValue -Map $config -Key "hw.$ConfigPrefix.username"
    $mgmtIp = Get-EnvMapValue -Map $resources -Key "mgmt.public_ip"
    if($IsMacOS) {
        # macos
        Set-Location "$($path)/.."
        $tmp = (Get-Item -Path ".\").FullName
        scp -o StrictHostKeyChecking=accept-new -i "$path/../config/$($keyPairName).pem" -r $tmp "$($mgmtUser)@$($mgmtIp):/home/$($mgmtUser)/pip-env-template"
    }
    else {
        if ($path[0] -eq "/") {
            # ubuntu
            scp -o StrictHostKeyChecking=accept-new -i "$path/../config/$($keyPairName).pem" -r "$path/.." `
                "$($mgmtUser)@$($mgmtIp):/home/$($mgmtUser)/pip-env-template"
        } else {
            # windows
            ssh -o StrictHostKeyChecking=accept-new "$($mgmtUser)@$($mgmtIp)" -i "$path/../config/$($keyPairName).pem" `
                "mkdir -p /home/$($mgmtUser)/pip-env-template"
            scp -i "$path/../config/$($keyPairName).pem" -r "$path/../*" `
                "$($mgmtUser)@$($mgmtIp):/home/$($mgmtUser)/pip-env-template"
        }
    }

    # Check for error
    if ($LastExitCode -ne 0) {
        Write-Error "Can't copy project to mgmt station. Read logs above..."
    }

    Write-Host "Done copying."

    Set-EnvMapValue -Map $resources -Key "mgmt.ssh_cmd" -Value "ssh $($mgmtUser)@$($mgmtIp) -i $path/../config/$($keyPairName).pem"
    Write-EnvResources -ResourcePath $HWResourcePath -Resources $resources

    Write-Host "To continue environment creation on mgmt station use commands:"
    Write-Host $(Get-EnvMapValue -Map $resources -Key "$HWResourcePrefix.mgmt.ssh_cmd")
    Write-Host "cd ~/pip-env-template"

    # Set permissions to protected key
    ssh "$($mgmtUser)@$($mgmtIp)" -i "$path/../config/$($keyPairName).pem" `
        "chmod 600 /home/$($mgmtUser)/pip-env-template/config/$($keyPairName).pem"
    # Set permissions to scripts
    ssh "$($mgmtUser)@$($mgmtIp)" -i "$path/../config/$($keyPairName).pem" `
        "chmod +x /home/$($mgmtUser)pip-env-template/*.sh /home/$($mgmtUser)/pip-env-template/*.ps1"
}

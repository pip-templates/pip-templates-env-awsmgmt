#!/usr/bin/env pwsh

param
(
    [Alias("c", "Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Alias("r", "Resources")]
    [Parameter(Mandatory=$false, Position=1)]
    [string] $ResourcePath
)

# Stop on error
$ErrorActionPreference = "Stop"

# Load common functions
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }
. "$($rootPath)/common/include.ps1"
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }

# Set default parameter values
if (($ResourcePath -eq $null) -or ($ResourcePath -eq ""))
{
    $ResourcePath = ConvertTo-EnvResourcePath -ConfigPath $ConfigPath
}

###################################################################
# Create management station
. "$($rootPath)/management-station/create.ps1" -ConfigPath $ConfigPath -ConfigPrefix "mgmt" -ResourcePath $ResourcePath -ResourcePrefix "mgmt"
###################################################################

# TODO: INSERT ANY HW COMPONENT HERE

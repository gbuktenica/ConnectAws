<#
    .SYNOPSIS
        Connect to a number of AWS Accounts in a tennant

    .PARAMETER InvokeCommands
        Used with InvokeArguments to all another PowerShell script at the completion of this script but without ending the process.

    .PARAMETER Pipeline
        Used when this script is called by a pipeline and therefore interactive logon and switching of subscriptions is not possible.

    .EXAMPLE

    .NOTES
        License      : MIT License
        Copyright (c): 2025 Glen Buktenica
        Release      : v0.0.1 20250122
#>
[CmdletBinding()]
Param(
    [Parameter()]
    [ValidateSet('Dev', 'Prod')]
    [string]
    $Environment = "Prod",
    $InvokeCommands,
    [String]
    $InvokeArguments,
    [switch]
    $Pipeline
)

function Import-Dependencies {
    param (
        [Parameter()]
        [array]
        $Modules,
        [Parameter()]
        [string]
        $SaveVerbosePreference
    )
    foreach ($Module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $Module -Verbose:$false)) {
            Write-Output "Installing module $Module"
            $global:VerbosePreference = 'SilentlyContinue'
            Install-Module -Name $Module -ErrorAction Stop -Verbose:$false -Scope CurrentUser -Force -AllowClobber | Out-Null
            $global:VerbosePreference = $SaveVerbosePreference
        } else {
            Write-Verbose "Module $Module already installed."
        }
    }

    foreach ($Module in $Modules) {
        if (-not (Get-Module -Name $Module -Verbose:$false)) {
            Write-Output "Importing $Module module"
            $global:VerbosePreference = 'SilentlyContinue'
            Import-Module -Name $Module -ErrorAction Stop -Verbose:$false | Out-Null
            $global:VerbosePreference = $SaveVerbosePreference
        } else {
            Write-Verbose "module $Module already imported."
        }
    }
    Write-Output "Finished Importing modules"
}

if (-not (Test-Path "$PsScriptRoot\Connect-Aws.json")) {
    $StartAccountId = Read-Host "Enter the first Account ID"
    $StartUrl = Read-Host "Enter the Start URL"
    $Region = Read-Host "Enter the Start Region"
    $Json = @{
        $Environment = [ordered]@{
            StartAccountId = $StartAccountId
            StartUrl       = $StartUrl
            Region         = $Region
        }
    }
    $Json | ConvertTo-Json | Out-File -FilePath "$PsScriptRoot\Connect-Aws.json"
}
$JsonParameters = Get-Content "$PsScriptRoot\Connect-Aws.json" -Raw -ErrorAction Stop | ConvertFrom-Json
$StartAccountId = $JsonParameters.$Environment.StartAccountId
$StartUrl = $JsonParameters.$Environment.StartUrl
$Region = $JsonParameters.$Environment.Region

Import-Dependencies -Modules @("AWS.Tools.Installer") -SaveVerbosePreference $global:VerbosePreference
Install-AWSToolsModule AWS.Tools.EC2, AWS.Tools.S3, AWS.Tools.Common -CleanUp -Confirm:$false
#Import-Dependencies -Modules @("AWS.Tools.Common") -SaveVerbosePreference $global:VerbosePreference

$Params = @{
    ProfileName        = $Environment
    AccountId          = $StartAccountId
    StartUrl           = $StartUrl
    Region             = $Region
    SSORegion          = $Region
    RoleName           = 'global.vmcontributor'
    RegistrationScopes = "sso:account:access"
    SessionName        = "sso-session"
}
$Params
Initialize-AWSSSOConfiguration @Params
﻿[cmdletbinding(DefaultParameterSetName ='build')]
param(
    # actions
    [Parameter(ParameterSetName='build',Position=0)]
    [switch]$build,
    [Parameter(ParameterSetName='clean',Position=0)]
    [switch]$clean,

    #[Parameter(ParameterSetName='getversion',Position=0)]
    #[switch]$getversion,
    #[Parameter(ParameterSetName='updateversion',Position=0)]
    #[switch]$updateversion,
    
    # build parameters
    [Parameter(ParameterSetName='build',Position=1)]
    [switch]$cleanBeforeBuild,

    [Parameter(ParameterSetName='build',Position=2)]
    [switch]$publishToNuget,

    [Parameter(ParameterSetName='build',Position=3)]
    [string]$nugetApiKey = ($env:NuGetApiKey),

    [Parameter(ParameterSetName='build',Position=4)]
    [string]$nugetUrl = $null,

    #[Parameter(ParameterSetName='build',Position=5)]
    #[switch]$skipTests,

    # updateversion parameters
    [Parameter(ParameterSetName='updateversion',Position=1,Mandatory=$true)]
    [string]$newversion
)

$env:IsDeveloperMachine=$true

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$global:NuGetPsBuildSettings = New-Object PSObject -Property @{
    toolsDir = "$env:LOCALAPPDATA\LigerShark\tools\"
    nugetDownloadUrl = 'http://nuget.org/nuget.exe'
}

<#
.SYNOPSIS
    This will return nuget from the $toolsDir. If it is not there then it
    will automatically be downloaded before the call completes.
#>
function Get-Nuget{
    [cmdletbinding()]
    param(
        $toolsDir = $global:NuGetPsBuildSettings.toolsDir,
        $nugetDownloadUrl = $global:NuGetPsBuildSettings.nugetDownloadUrl
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null 
        }

        $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
        
        if(!(Test-Path $nugetDestPath)){
            $nugetDir = ([System.IO.Path]::GetDirectoryName($nugetDestPath))
            if(!(Test-Path $nugetDir)){
                New-Item -Path $nugetDir -ItemType Directory | Out-Null
            }

            'Downloading nuget.exe' | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath) | Out-Null

            # double check that is was written to disk
            if(!(Test-Path $nugetDestPath)){
                throw 'unable to download nuget'
            }
        }

        # return the path of the file
        $nugetDestPath
    }
}


function PublishNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [string]$nugetPackages,

        [Parameter(Position=1)]
        $nugetApiKey,

        [Parameter(Position=2)]
        [string]$nugetUrl
    )
    process{
        foreach($nugetPackage in $nugetPackages){
            $pkgPath = (get-item $nugetPackage).FullName
            $cmdArgs = @('push',$pkgPath,$nugetApiKey,'-NonInteractive')
            
            if($nugetUrl -and !([string]::IsNullOrWhiteSpace($nugetUrl))){
                $cmdArgs += "-source"
                $cmdArgs += $nugetUrl
            }

            'Publishing nuget package with the following args: [nuget.exe {0}]' -f ($cmdArgs -join ' ') | Write-Verbose
            &(Get-Nuget) $cmdArgs
        }
    }
}

function Build{
    [cmdletbinding()]
    param()
    process{
        'Starting build' | Write-Output
        if($publishToNuget){ $cleanBeforeBuild = $true }

        if($cleanBeforeBuild){
            Clean
        }

        $outputRoot = Join-Path $scriptDir "OutputRoot"
        $nugetDevRepo = 'C:\temp\nuget\localrepo\'

        if(!(Test-Path $outputRoot)){
            'Creating output folder [{0}]' -f $outputRoot | Write-Output
            New-Item $outputRoot -ItemType Directory
        }

        $outputRoot = (Get-Item $outputRoot).FullName
        # call nuget to create the package

        $nuspecFiles = @((get-item(Join-Path $scriptDir "nuget-powershell.nuspec")).FullName)

        $nuspecFiles | ForEach-Object {
            $nugetArgs = @('pack',$_,'-o',$outputRoot)
            'Calling nuget.exe with the command:[nuget.exe {0}]' -f  ($nugetArgs -join ' ') | Write-Output
            &(Get-Nuget) $nugetArgs    
        }

        if(Test-Path $nugetDevRepo){
            Get-ChildItem -Path $outputRoot '*.nupkg' | Copy-Item -Destination $nugetDevRepo
        }

        if(!$skipTests){
            Run-Tests
        }

        if($publishToNuget){
            (Get-ChildItem -Path $outputRoot '*.nupkg').FullName | PublishNuGetPackage -nugetApiKey $nugetApiKey -nugetUrl $nugetUrl
        }
    }
}

function Load-Pester{
    [cmdletbinding()]
    param(
        $pesterDir = (resolve-path (Join-Path $scriptDir 'contrib\pester\'))
    )
    process{
        if(!(Get-Module pester)){
            if($env:PesterDir -and (test-path $env:PesterDir)){
                $pesterDir = $env:PesterDir
            }

            if(!(Test-Path $pesterDir)){
                throw ('Pester dir not found at [{0}]' -f $pesterDir)
            }
            $modFile = (Join-Path $pesterDir 'Pester.psm1')
            'Loading pester from [{0}]' -f $modFile | Write-Verbose
            Import-Module (Join-Path $pesterDir 'Pester.psm1')
        }
    }
}

function Run-Tests{
    [cmdletbinding()]
    param(
        $testDirectory = (join-path $scriptDir tests)
    )
    begin{ 
        Load-Pester
    }
    process{
        # go to the tests directory and run pester
        push-location
        set-location $testDirectory

        $pesterArgs = @{}
        if($env:ExitOnPesterFail -eq $true){
            $pesterArgs.Add('-EnableExit',$true)
        }
        if($env:PesterEnableCodeCoverage -eq $true){
            $pesterArgs.Add('-CodeCoverage','..\nuget-powershell.psm1')
        }

        Invoke-Pester @pesterArgs
        pop-location
    }
}

function Clean{
    [cmdletbinding()]
    param()
    process{
        $outputRoot = Join-Path $scriptDir "OutputRoot"
        if((Test-Path $outputRoot)){
            'Removing directory: [{0}]' -f $outputRoot | Write-Output
            Remove-Item $outputRoot -Recurse -Force
        }
        else{
            'Output folder [{0}] doesn''t exist skipping deletion' -f $outputRoot | Write-Output
        }
    }
}

### begin script

# set build as default action if not specified
if(!($build) -and !($clean)){
    $build = $true
}

if($build){ Build }
#elseif($getversion){ GetExistingVersion }
#elseif($updateversion){ UpdateVersion -newversion $newversion }
elseif($clean){ Clean }
else{
    $cmds = @('-build','-clean')
    'No command specified, please pass in one of the following [{0}]' -f ($cmds -join ' ') | Write-Error
}


<#
.SYNOPSIS
    This module aimes to help similify consuming NuGet packages from PowerShell.
#>

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$global:NuGetPowerShellSettings = New-Object PSObject -Property @{
    toolsDir = "$env:LOCALAPPDATA\LigerShark\nuget-ps\tools\"
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
        $toolsDir = $global:NuGetPowerShellSettings.toolsDir,
        $nugetDownloadUrl = $global:NuGetPowerShellSettings.nugetDownloadUrl
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

<#
.SYNOPSIS
Updates nuget.exe to the latest and then returns the path to nuget.exe.
#>
function Update-NuGet{
    [cmdletbinding()]
    param()
    process{
        $cmdArgs = @('update','-self')

        $command = '"{0}" {1}' -f (Get-NuGet),($cmdArgs -join ' ')
        Execute-CommandString -command $command | Write-Verbose

        # return the path to nuget.exe
        Get-NuGet
    }
}

function Execute-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [string[]]$command,

        [switch]
        $ignoreExitCode
    )
    process{
        foreach($cmdToExec in $command){
            'Executing command [{0}]' -f $cmdToExec | Write-Verbose
            cmd.exe /D /C $cmdToExec

            if(-not $ignoreExitCode -and ($LASTEXITCODE -ne 0)){
                $msg = ('The command [{0}] exited with code [{1}]' -f $cmdToExec, $LASTEXITCODE)
                throw $msg
            }
        }
    }
}

<#
.SYNOPSIS
    This will return the path to where the given NuGet package is installed.
#>
function Get-NuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        [switch]$prerelease,
        [Parameter(Position=3)]
        $toolsDir = $global:NuGetPowerShellSettings.toolsDir,

        [Parameter(Position=4)]
        [string]$nugetUrl = $null
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null 
        }
        $toolsDir = (Get-Item $toolsDir).FullName.TrimEnd('\')
        # if it's already installed just return the path
        [string]$installPath = $null


        if($version){
            $installPath = (InternalGet-NuGetPackageExpectedPath -name $name -version $version -toolsDir $toolsDir)
        }

        if(!$installPath -or !(test-path $installPath)){
            # install the nuget package and then return the path
            $outdir = (get-item (Resolve-Path $toolsDir)).FullName.TrimEnd("\") # nuget.exe doesn't work well with trailing slash

            # set working directory to avoid needing to specify OutputDirectory, having issues with spaces
            Push-Location | Out-Null
            try{
                Set-Location $outdir | Out-Null
                $cmdArgs = @('install',$name)

                if($version){
                    $cmdArgs += '-Version'
                    $cmdArgs += "$version"

                    $prerelease = $true
                }

                if($prerelease){
                    $cmdArgs += '-prerelease'
                }

                if($nugetUrl -and !([string]::IsNullOrWhiteSpace($nugetUrl))){
                    $cmdArgs += "-source"
                    $cmdArgs += $nugetUrl
                }

                $nugetCommand = ('"{0}" {1}' -f (Get-Nuget -toolsDir $outdir), ($cmdArgs -join ' ' ))
                'Calling nuget to install a package with the following args. [{0}]' -f $nugetCommand | Write-Verbose
                [string[]]$nugetResult = (Execute-CommandString -command $nugetCommand)
                $nugetResult | Write-Verbose

                if(!$installPath){
                    $pkgDirName = InternalGet-PackagePathFromNuGetOutput -nugetOutput ($nugetResult[0])
                    $pkgpath = (Join-Path $toolsDir $pkgDirName)
                    $installPath = ((Get-Item $pkgpath).FullName)
                }
            }
            finally{
                Pop-Location | Out-Null
            }
        }

        # it should be set by now so throw if not
        if(!$installPath){
            throw ('Unable to restore nuget package. [name={0},version={1},toolsDir={2}]' -f $name, $version, $toolsDir)
        }

        $installPath
    }
}

<#
.SYNOPSIS
Returns the name (including version number) of the nuget package installed from the
nuget.exe results when calling nuget.exe install.
#>
function InternalGet-PackagePathFromNuGetOutput{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$nugetOutput
    )
    process{
        if(!([string]::IsNullOrWhiteSpace($nugetOutput))){
            ([regex]"'.*'").match($nugetOutput).groups[0].value.TrimStart("'").TrimEnd("'").Replace(' ','.')
        }
        else{
            throw 'nugetOutput parameter is null or empty'
        }
    }
}

function Load-ModuleFromNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,

        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:NuGetPowerShellSettings.toolsDir,

        [Parameter(Position=3)]
        $nugetUrl = $null
    )
    process{
        $installDir = Get-NuGetPackage -name $name -version $version -nugetUrl $nugetUrl

        $modules = (Get-ChildItem ("$installDir\tools") '*.psm1')
        foreach($module in $modules){
            $moduleFile = $module.FullName
            $moduleName = $module.BaseName

            if(Get-Module $moduleName){
                Remove-Module $moduleName | out-null
            }
            'Loading module from [{0}]' -f $moduleFile | Write-Verbose
            Import-Module $moduleFile -DisableNameChecking -Global -Force
        }
    }
}

function InternalGet-NuGetPackageExpectedPath{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:NuGetPowerShellSettings.toolsDir
    )
    process{
        $pathToFoundPkgFolder = $null
        $toolsDir=(get-item $toolsDir).FullName
		$expectedNuGetPkgFolder = ((Get-Item -Path (join-path $toolsDir (('{0}.{1}' -f $name, $version))) -ErrorAction SilentlyContinue))

        if($expectedNuGetPkgFolder){
            $pathToFoundPkgFolder = $expectedNuGetPkgFolder.FullName
        }

        $pathToFoundPkgFolder
    }
}

if(!$env:IsDeveloperMachine){
    Export-ModuleMember -function Get-*,Set-*,Invoke-*,Save-*,Test-*,Find-*,Add-*,Remove-*,Test-*,Open-*,New-*,Execute-*,Update-*
}
else{
    # you can set the env var to expose all functions to importer. easy for development.
    # this is required for pester testing
    Export-ModuleMember -function *
}
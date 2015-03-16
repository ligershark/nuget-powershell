<#
.SYNOPSIS
    This module aimes to help similify consuming NuGet packages from PowerShell. To find the commands
    made available you can use.

    Get-Command -module nuget-powershell
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

<#
.SYNOPSIS
    Used to execute a command line tool (i.e. nuget.exe) using cmd.exe. This is needed in
    some cases due to hanlding of special characters.

.EXAMPLE
    Execute-CommandString -command ('"{0}" {1}' -f (Get-NuGet),(@('install','psbuild') -join ' '))
    Calls nuget.exe install psbuild using cmd.exe

.EXAMPLE
    '"{0}" {1}' -f (Get-NuGet),(@('install','psbuild') -join ' ') | Execute-CommandString
    Calls nuget.exe install psbuild using cmd.exe

.EXAMPLE
    @('psbuild','packageweb') | % { """$(Get-NuGet)"" install $_ -prerelease"|Execute-CommandString}
    Calls 
        nuget.exe install psbuild -prerelease
        nuget.exe install packageweb -prerelease
#>
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
    This will return the path to where the given NuGet package is installed. If the package
    is not in the local cache then it will automatically be downloaded. All interaction with
    nuget servers go through nuget.exe.

.PARAMETER name
    Name of the NuGet package to be installed. This is a mandatory argument.

.PARAMETER version
    Version of NuGet package to get. If this is not passed the latst version will be
    returned. That will result in a call to nuget.org (or other nugetUrl as specified).

.PARAMETER prerelease
    Pass this to get the prerelease version of the NuGet package.

.PARAMETER toolsDir
    The directory where the package will be downloaded to. This is mostly an internal
    parameter but it can be used to redirect the location of the tools directory. 
    To override this globally you can use $global:NuGetPowerShellSettings.toolsDir.

.PARAMETER nugetUrl
    You can use this to download the package from a different nuget feed.

.PARAMETER force
    Used to re-download the package from the remote nuget feed.

.EXAMPLE
    Get-NuGetPackage -name psbuild
    Gets the latest version of the psbuild nuget package wich is not a prerelease package

.EXAMPLE
    Get-NuGetPackage -name psbuild -prerelease
    Gets the latest version (including prerelase) of the psbuild nuget package.

.EXAMPLE
    Get-NuGetPackage psbuild -version 0.0.5
    Gets psbuild version 0.0.5

.EXAMPLE
    Get-NuGetPackage psbuild -version 0.0.6-beta5
    Gets psbuild version 0.0.6-beta5. When passing a value for version you don't need
    to pass -prerelease, it will be used by default on all calls when version is present.

.EXAMPLE
    Get-NuGetPackage psbuild -version 0.0.6-beta5 -nugetUrl https://staging.nuget.org
    Downloads psbuild version 0.0.6-beta5 fro staging.nuget.org
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
        [string]$nugetUrl = $null,

        [Parameter(Position=5)]
        [switch]$force
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

        if($force -and $installPath -and (Test-Path $installPath)){
            'Deleting package directory at [{0}] because of -force' -f $installPath | Write-Verbose
            Remove-Item $installPath -Recurse -Force | Write-Verbose
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

                    # if the version is not passed with -force then the item may be downloaded twice
                    if($force -and !($version)){
                        'Deleting package directory at [{0}] because of -force' -f $installPath | Write-Verbose
                        Remove-Item $installPath -Recurse -Force | Write-Verbose
                    }

                    [string[]]$nugetResult = (Execute-CommandString -command $nugetCommand)
                    $nugetResult | Write-Verbose
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

<#
.SYNOPSIS
    When this method is called all files in the given nuget package maching *.psm1 in the tools
    folder will automatically be imported using Import-Module.

.EXAMPLE
    Load-ModuleFromNuGetPackage -name psbuild
    Loads the psbuild module from the latest psbuild nuget package (non-prerelease).

.EXAMPLE
    Load-ModuleFromNuGetPackage -name psbuild -prerelease
    Loads the psbuild module from the latest psbuild nuget package (including prerelease).

.EXAMPLE
    Load-ModuleFromNuGetPackage -name psbuild -prerelease -force
    Loads the psbuild module from the latest psbuild nuget package (including prerelease), and the package
    will be re-dowloaded instead of the cached version.
#>
function Load-ModuleFromNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $name,

        [Parameter(Position=1)]
        $version,

        [Parameter(Position=2)]
        [switch]$prerelease,

        [Parameter(Position=3)]
        $toolsDir = $global:NuGetPowerShellSettings.toolsDir,

        [Parameter(Position=4)]
        $nugetUrl = $null,

        [Parameter(Position=5)]
        [switch]$force
    )
    process{
        $pkgDir = Get-NuGetPackage -name $name -version $version -prerelease:$prerelease -nugetUrl $nugetUrl -force:$force

        $modules = (Get-ChildItem ("$pkgDir\tools") '*.psm1' -ErrorAction SilentlyContinue)
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
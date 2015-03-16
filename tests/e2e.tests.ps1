[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'nuget-powershell'
$modulePath = (Join-Path $scriptDir ('..\{0}.psm1' -f $moduleName))

$env:IsDeveloperMachine = $true

if(Test-Path $modulePath){
    'Importing module from [{0}]' -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){ Remove-Module $moduleName -Force }
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
}
else{
    throw ('Unable to find module at [{0}]' -f $modulePath )
}

Describe 'get-nuget tests' {   
    It 'Returns path' {
        $nugetPath = (Get-Nuget)
        $nugetPath | Should exist        
    }
     
    It 'Can use specified url' {
        $nugetPath = (Get-Nuget)
        Remove-Item $nugetPath | out-null
        $nugetPath = (Get-Nuget -nugetDownloadUrl http://staging.nuget.org/nuget.exe)
        $nugetPath | Should Exist
    }

    It 'Can use custom tools folder' {
        $newToolsDir = (join-path $TestDrive 'get-nuget\custom-tools\')
        $nugetPath = (Get-Nuget -toolsDir $newToolsDir)
        $nugetPath | Should Exist
    }
}

Describe 'update-nuget tests'{
    It 'Returns path' {
        $nugetPath = (Update-NuGet)
        $nugetPath | Should Exist
    }
}

Describe 'Load-ModuleFromNuGetPackage tests'{
    It 'Can load module1' {
        if(Get-Module publish-module){
            Remove-Module publish-module -force
        }
        Load-ModuleFromNuGetPackage -name publish-module -prerelease
        $result = (Get-Module publish-module)
        [string]::IsNullOrWhiteSpace($result) | Should Be $false

        if(Get-Module publish-module){
            Remove-Module publish-module -force
        }
    }
}
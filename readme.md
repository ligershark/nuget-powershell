This project aims to simplify consuming NuGet packages in PowerShell. More info coming soon...

### Build status
[![Build status](https://ci.appveyor.com/api/projects/status/yv76i6yybh5pv3kd?svg=true)](https://ci.appveyor.com/project/sayedihashimi/nuget-powershell)

### Getting started
<code style="background-color:grey">(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex</code>

### Examples

#### How to read a .json file with comments

```powershell
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex

$jsonnetpath = (Get-NuGetPackage Newtonsoft.Json -prerelease)
Add-Type -Path (Join-Path $jsonnetpath 'lib\net45\Newtonsoft.Json.dll')
# now we can call apis from json.net
$jsonString = @"
{
    /* Click to learn more about project.json  http://go.microsoft.com/fwlink/?LinkID=517074 */
    "webroot": "wwwroot",
    "version": "1.0.0-*",
    "dependencies": {
        "EntityFramework.SqlServer": "7.0.0-beta3",
        "Microsoft.VisualStudio.Web.BrowserLink.Loader": "14.0.0-beta3"
    },
    "commands": {
        /* Change the port number when you are self hosting this application */
        "web": "Microsoft.AspNet.Hosting --server Microsoft.AspNet.Server.WebListener --server.urls http://localhost:5000",
        "gen": "Microsoft.Framework.CodeGeneration"
    }
}
"@

'webroot: "{0}"' -f [Newtonsoft.Json.JsonConvert]::DeserializeObject($jsonString)['webroot'].value
```

#### How to optimize images in a folder

```powershell
$imgOptExe = (Join-Path (Get-NuGetPackage AzureImageOptimizer -prerelease) 'tools\ImageCompressor.Job.exe')
&$imgOptExe /d c:\temp\images\to-optimize
```

#### How to load a nuget-powershell module

```powershell
Load-ModuleFromNuGetPackage psbuild -prerelease
```






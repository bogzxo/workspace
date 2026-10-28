<#
Gets the workspace going on a new machine. Checks there's Git and a .NET 11 SDK, then clones the engine (with HIDL
inside of it), Hex and the game next to this file, all on development, which is pull-all.ps1 doing it the first time.
After it, Horizon.Workspace.sln opens the lot.

  .\setup.ps1
#>

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

function Say([string]$Text, [string]$Colour = 'Gray') { Write-Host $Text -ForegroundColor $Colour }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Say "Git isn't installed, get it from https://git-scm.com and run this again" 'Red'
    exit 1
}

# The SDK global.json asks for, or a newer one, which it rolls forward to
$wanted = (Get-Content (Join-Path $root 'global.json') -Raw | ConvertFrom-Json).sdk.version
$floor = [version]($wanted -split '-')[0]
$sdks = @()
if (Get-Command dotnet -ErrorAction SilentlyContinue) { $sdks = @(& dotnet --list-sdks 2>$null) }
$found = $sdks | Where-Object { $_ -match '^(\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge $floor }
if (-not $found) {
    Say ".NET SDK $wanted or newer isn't installed, the build wants it. Get the .NET 11 SDK from" 'DarkYellow'
    Say "https://dotnet.microsoft.com/download/dotnet/11.0 (a preview or release candidate is fine), the clone goes on" 'DarkYellow'
    Say "without it`n" 'DarkYellow'
}

& (Join-Path $root 'pull-all.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Say "`nOpen Horizon.Workspace.sln, or build the game with dotnet build Fighter2D" 'Cyan'

#Requires -Version 7.0
<#
.SYNOPSIS
Renders a package icon's SVG to the 128 by 128 PNG that the package packs.

.DESCRIPTION
Each repository keeps its icon as docs/images/icon.svg, the source, and docs/images/icon.png, which the project file
packs with PackageIcon. This script renders the PNG from the SVG with a Chromium-based browser in headless mode, so the
PNG always matches its source. It looks for Microsoft Edge, then Google Chrome; pass -Browser for another one.

.PARAMETER Svg
The SVG files to render. Each PNG is written beside its SVG, with the same name.

.PARAMETER Size
The width and height of the PNG in pixels. nuget.org shows icons at up to 128 by 128.

.PARAMETER Browser
The path of a Chromium-based browser.

.EXAMPLE
pwsh ../AurorisNet.Build/icons/Render-Icon.ps1 docs/images/icon.svg
#>
param(
    [Parameter(Mandatory, Position = 0)][string[]] $Svg,
    [int] $Size = 128,
    [string] $Browser
)

$ErrorActionPreference = 'Stop'
if (-not $Browser) {
    $Browser = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
        '/usr/bin/chromium'
        '/usr/bin/google-chrome'
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $Browser) { throw 'No Chromium-based browser was found. Pass its path with -Browser.' }
}

foreach ($path in $Svg) {
    $source = (Resolve-Path -LiteralPath $path).Path
    $target = [IO.Path]::ChangeExtension($source, '.png')
    # A page that shows the SVG alone, with no margin and no background, so the corners of the PNG stay transparent.
    $page = Join-Path ([IO.Path]::GetTempPath()) "icon-$([guid]::NewGuid().ToString('N')).html"
    $profile = Join-Path ([IO.Path]::GetTempPath()) "icon-profile-$([guid]::NewGuid().ToString('N'))"
    Set-Content -LiteralPath $page -Encoding utf8 -Value (
        "<!doctype html><html><body style=""margin:0;background:transparent"">" +
        "<img src=""$([Uri]::new($source).AbsoluteUri)"" width=""$Size"" height=""$Size"" style=""display:block""></body></html>")
    try {
        & $Browser --headless --disable-gpu --hide-scrollbars --no-first-run "--user-data-dir=$profile" `
            --default-background-color=00000000 "--window-size=$Size,$Size" "--screenshot=$target" ([Uri]::new($page).AbsoluteUri) 2>&1 | Out-Null
        # The browser returns before it has always flushed the file.
        for ($i = 0; $i -lt 50 -and -not (Test-Path -LiteralPath $target); $i++) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path -LiteralPath $target)) { throw "The browser did not write $target." }
        Write-Host "Rendered $target"
    }
    finally {
        Remove-Item -LiteralPath $page -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    }
}

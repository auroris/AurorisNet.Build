#Requires -Version 7.0
<#
.SYNOPSIS
Writes a README badge as an SVG file, in the flat style of the badges in this folder.

.DESCRIPTION
The READMEs show static badges from this folder, so a README renders the same on GitHub and nuget.org and asks no
badge service for an image. The text widths are estimates for 11px Verdana; textLength makes each browser fit the text
to them.

.PARAMETER Label
The text on the left, grey half, such as Umbraco.

.PARAMETER Value
The text on the right, coloured half, such as 17 | 18.

.PARAMETER Color
The colour of the right half. Defaults to the blue of the license and .NET badges.

.PARAMETER Path
The file to write.

.EXAMPLE
./New-Badge.ps1 -Label Umbraco -Value '17 | 18' -Color '#3544b1' -Path umbraco-17-18.svg
#>
param(
    [Parameter(Mandatory)][string] $Label,
    [Parameter(Mandatory)][string] $Value,
    [string] $Color = '#007ec6',
    [Parameter(Mandatory)][string] $Path
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Returns the estimated width of <text> in tenths of a pixel, set in 11px Verdana.
#>
function Get-TextWidth([string] $text) {
    $width = 0
    foreach ($character in $text.ToCharArray()) {
        $width += switch -CaseSensitive -Regex ([string] $character) {
            '[ijl.,:;|!'']' { 35; break }
            '[ ]' { 39; break }
            '[ftrI]' { 45; break }
            '[mw]' { 100; break }
            '[MW]' { 105; break }
            '[A-Z]' { 75; break }
            '[0-9]' { 70; break }
            default { 66; break }
        }
    }
    $width
}

$encode = { param($text) [Security.SecurityElement]::Escape($text) }
$labelText = Get-TextWidth $Label
$valueText = Get-TextWidth $Value
$labelWidth = [Math]::Round($labelText / 10) + 10
$valueWidth = [Math]::Round($valueText / 10) + 10
$total = $labelWidth + $valueWidth
$labelX = $labelWidth * 5
$valueX = $labelWidth * 10 + $valueWidth * 5
$title = & $encode "$($Label): $Value"

<#
.SYNOPSIS
Returns the SVG of one half's text with its shadow, centred on <x>.
#>
function Format-Text([string] $text, [int] $x, [int] $length) {
    $escaped = & $encode $text
    "<g transform=""scale(.1)""><g aria-hidden=""true"" fill=""#010101""><text x=""$x"" y=""150"" fill-opacity="".3"" textLength=""$length"">$escaped</text></g>" +
    "<text x=""$x"" y=""140"" textLength=""$length"">$escaped</text></g>"
}

$svg = "<svg xmlns=""http://www.w3.org/2000/svg"" width=""$total"" height=""20"" role=""img"" aria-label=""$title""><title>$title</title>" +
    "<linearGradient id=""s"" x2=""0"" y2=""100%""><stop offset=""0"" stop-color=""#bbb"" stop-opacity="".1""/><stop offset=""1"" stop-opacity="".1""/></linearGradient>" +
    "<clipPath id=""r""><rect width=""$total"" height=""20"" rx=""3""/></clipPath>" +
    "<g clip-path=""url(#r)""><rect width=""$labelWidth"" height=""20"" fill=""#555""/><rect x=""$labelWidth"" width=""$valueWidth"" height=""20"" fill=""$Color""/><rect width=""$total"" height=""20"" fill=""url(#s)""/></g>" +
    "<g fill=""#fff"" text-anchor=""middle"" font-family=""Verdana,Geneva,DejaVu Sans,sans-serif"" text-rendering=""geometricPrecision"" font-size=""110"">" +
    (Format-Text $Label $labelX $labelText) + (Format-Text $Value $valueX $valueText) + "</g></svg>"
Set-Content -LiteralPath $Path -Value $svg -Encoding utf8 -NoNewline

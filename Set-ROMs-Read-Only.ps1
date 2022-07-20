<#
.SYNOPSIS

Sets the read-only flag of ROM files.

.DESCRIPTION

For each file in the folder, sets the read-only flag to true.

.PARAMETER romPath
Specifies the path to the folder containing ROMs.

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

None. This script does not generate any output.

.EXAMPLE

C:\PS> .\Set-ROMs-Read-Only.ps1 -romPath C:\RetroArch\roms

#>

param(
    [Parameter(Mandatory=$True)]
    [string] $romPath
)

[int] $totalProtected = 0

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}

$romItems = Get-ChildItem -Path $romPath -File

foreach ($romFile in $romItems){
    Set-ItemProperty -Path $romFile.FullName -Name IsReadOnly -Value $true
    $totalProtected++
}

Write-Host
Write-Host "Total ROMs Protected: $totalProtected"

Write-Host


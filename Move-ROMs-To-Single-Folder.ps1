<#
.SYNOPSIS

Relocates ROM files from subfolders within a given folder back to the top-level folder.

.DESCRIPTION

For each file in the subfolder of a folder, moves that file to the top-level folder.

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

[int] $totalMoved = 0

[string] $romPathAbsolute = (Resolve-Path $romPath).Path

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}

$romItems = Get-ChildItem -Path $romPath -File -Recurse

foreach ($romFile in $romItems){
    $fileName = $romFile.Name
    $targetPath = $romPathAbsolute
    $pathExpected = $targetPath + '\' + $romFile.Name
    $pathActual = $romFile.FullName
    if (!($pathExpected -eq $pathActual)) {        
        Write-Host "Moving $fileName..."
        Move-Item -Path $pathActual -Destination $targetPath
        $totalMoved++
    }
}

$directoryItems = Get-ChildItem -Path $romPath -Directory

foreach ($dir in $directoryItems){
    if ((Get-ChildItem -Path $dir.FullName).Count -eq 0){
        Write-Host "Removing $dir"
        Remove-Item -Path $dir.FullName
    }
}

Write-Host
Write-Host "Total ROMs Moved: $totalMoved"

Write-Host
<#
.SYNOPSIS

Relocates ROM files to subfolders within a given folder.

.DESCRIPTION

For each file in the folder, moves it to a folder with the same name as the first letter of the file.

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


if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}

for ($i = 65; $i -le 90; $i++) {
    $romSubPath = $romPath + '\' + [char]$i
    
}

$romItems = Get-ChildItem -Path $romPath -File -Recurse

foreach ($romFile in $romItems){
    $firstChar = $romFile.Name.Substring(0,1)
    $targetPath = $romPath + '\' + $firstChar
    $pathExpected = $targetPath + '\' + $romFile.Name
    $pathActual = $romFile.FullName
    if (!($pathExpected -eq $pathActual)) {
        if (!(Test-Path $targetPath)) {
            New-Item -Path $targetPath -ItemType Directory | Out-Null
        }
        Move-Item -Path $pathActual -Destination $targetPath
        $totalMoved++
    }
}

Write-Host
Write-Host "Total ROMs Moved: $totalMoved"

Write-Host
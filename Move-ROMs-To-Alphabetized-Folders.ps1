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
$folderMap = @{}

$folderMap.Add("0","0-9")
$folderMap.Add("1","0-9")
$folderMap.Add("2","0-9")
$folderMap.Add("3","0-9")
$folderMap.Add("4","0-9")
$folderMap.Add("5","0-9")
$folderMap.Add("6","0-9")
$folderMap.Add("7","0-9")
$folderMap.Add("8","0-9")
$folderMap.Add("9","0-9")
$folderMap.Add("A","A-C")
$folderMap.Add("B","A-C")
$folderMap.Add("C","A-C")
$folderMap.Add("D","D-F")
$folderMap.Add("E","D-F")
$folderMap.Add("F","D-F")
$folderMap.Add("G","G-I")
$folderMap.Add("H","G-I")
$folderMap.Add("I","G-I")
$folderMap.Add("J","J-L")
$folderMap.Add("K","K-L")
$folderMap.Add("L","K-L")
$folderMap.Add("M","M-O")
$folderMap.Add("N","M-O")
$folderMap.Add("O","M-O")
$folderMap.Add("P","P-S")
$folderMap.Add("Q","P-S")
$folderMap.Add("R","P-S")
$folderMap.Add("S","P-S")
$folderMap.Add("T","T-V")
$folderMap.Add("U","T-V")
$folderMap.Add("V","T-V")
$folderMap.Add("W","W-Z")
$folderMap.Add("X","W-Z")
$folderMap.Add("Y","W-Z")
$folderMap.Add("Z","W-Z")

[string] $romPathAbsolute = (Resolve-Path $romPath).Path

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}

$romItems = Get-ChildItem -Path $romPath -File -Recurse

foreach ($romFile in $romItems){
    $fileName = $romFile.Name
    $firstChar = $fileName.Substring(0,1)
    $targetPath = $romPathAbsolute
    if ($folderMap.ContainsKey($firstChar)) {
        $targetPath = $targetPath + '\' + $folderMap[$firstChar]
    } else {
        Write-Host "Skipping $fileName"
        continue
    }
    $pathExpected = $targetPath + '\' + $romFile.Name
    $pathActual = $romFile.FullName
    if (!($pathExpected -eq $pathActual)) {
        if (!(Test-Path $targetPath)) {
            New-Item -Path $targetPath -ItemType Directory | Out-Null
        }
        Write-Host "Moving $fileName..."
        Move-Item -Path $pathActual -Destination $targetPath
        $totalMoved++
    }
}

Write-Host
Write-Host "Total ROMs Moved: $totalMoved"

Write-Host

<#
.SYNOPSIS

Compares ROMs to a No-Intro database.

.DESCRIPTION

The Validate-ROMs.ps1 script loads the most recent DAT file in the specified
folder, loads each ROM file in the specified folder, SHA1 hashes the binary 
content of the file, then compares the hash to the No-Intro database.  If a 
match is found, the ROM file is renamed to the name found in the associated 
DAT entry.

.PARAMETER romPath
Specifies the path to the folder containing ROMs.

.PARAMETER datPath
Specifies the to the folder containing No-Intro DAT files.

.PARAMETER datName
Specifies the No-Intro System name (matches the DAT file name).

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

None. This script does not generate any output.

.EXAMPLE

C:\PS> .\Validate-ROMs.ps1 -romPath C:\RetroArch\roms -datPath C:\No-Intro\dats -datName "Nintendo - Super Nintendo Entertainment System"

#>

param(
    [Parameter(Mandatory=$True)]
    [string] $romPath,
    [Parameter(Mandatory=$True)]
    [string] $datPath,    
    [Parameter(Mandatory=$True)]
    [string] $datName
)

[int] $totalExamined = 0
[int] $totalIdentified = 0
[int] $totalRenamed = 0
[int] $totalUnidentified = 0

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}
if (!(Test-Path $datPath)) {
    Write-Host "Unable to locate DAT directory.  Exiting..."
    exit
}

[string] $datPattern = "^${datName} ([d-]*)"

$datMostRecentFile = Get-ChildItem -Path $datPath -Filter "*.dat" | Where-Object { $_.Name -match $datPattern } | Select-Object -First 1

[xml]$dat = Get-Content -Path $datMostRecentFile.FullName

if (!$dat) {    
    Write-Host "Unable to read DAT file.  Exiting..."
    exit
}
else {
    $datNameQuery = Select-Xml -Xml $dat -XPath "/datafile/header/name[1]"
    $datVersionQuery = Select-Xml -Xml $dat -XPath "/datafile/header/version[1]"
    $datName = $datNameQuery.Node.InnerText
    $datVersion = $datVersionQuery.Node.InnerText
    Write-Host "Loaded DAT file: $datName, version: $datVersion" 
}

$romItems = Get-ChildItem -Path $romPath -File

foreach ($romFile in $romItems){
    $sha1 = Get-FileHash -Path $romFile.FullName -Algorithm SHA1
    $sha1Lower = $sha1.Hash.ToLower()
    $sha1Upper = $sha1.Hash.ToUpper()
    $xPath = "(/datafile/game/rom[@sha1='$sha1Lower']|/datafile/game/rom[@sha1='$sha1Upper'])[1]" 
    $datQuery = Select-Xml -Xml $dat -XPath $xPath
    $totalExamined++

    if ($datQuery) {
        $gameName = $datQuery.Node.ParentNode.Attributes["name"].Value
        $romName = $datQuery.Node.Attributes["name"].Value
        $totalIdentified++

        if (!$romFile.Name.Equals($romName)) {
            Write-Host "Renaming $gameName..."
            Rename-Item -Path $romFile.FullName -NewName $romName
            $totalRenamed++
        }
    } else {
        Write-Host "Unable to identify $romFile"
        $totalUnidentified++
    }
}

Write-Host
Write-Host "Total ROMs: $totalExamined"
Write-Host "Total ROMs Identified: $totalIdentified"
Write-Host "Total ROMs Renamed: $totalRenamed"
Write-Host "Total ROMs Unidentified: $totalUnidentified"
Write-Host
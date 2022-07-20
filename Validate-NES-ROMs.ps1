<#
.SYNOPSIS

Compares NES ROMs to a No-Intro database.

.DESCRIPTION

The Validate-NES-ROMs.ps1 script loads the most recent DAT file in the specified
folder, loads each ROM file in the specified folder, SHA1 hashes all but the 
first 16 bytes, then compares the hash to the No-Intro database.  If a match is 
found, the ROM file is renamed to the name found in the associated DAT entry.

.PARAMETER romPath
Specifies the path to the folder containing NES ROMs.

.PARAMETER datPath
Specifies the to the folder containing No-Intro DAT files.

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

None. This script does not generate any output.

.EXAMPLE

C:\PS> .\Validate-NES-ROMs.ps1 -romPath C:\RetroArch\roms -datPath C:\No-Intro\dats

#>

param(
    [Parameter(Mandatory=$True)]
    [string] $romPath,
    [Parameter(Mandatory=$True)]
    [string] $datPath
)

[int] $totalExamined = 0
[int] $totalIdentified = 0
[int] $totalRenamed = 0
[int] $totalUnidentified = 0
[int] $nesHeaderLength = 16
[string] $datName = "Nintendo - Nintendo Entertainment System"

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
} else {
    $datNameQuery = Select-Xml -Xml $dat -XPath "/datafile/header/name[1]"
    $datVersionQuery = Select-Xml -Xml $dat -XPath "/datafile/header/version[1]"
    $datName = $datNameQuery.Node.InnerText
    $datVersion = $datVersionQuery.Node.InnerText
    Write-Host "Loaded DAT file: $datName, version: $datVersion" 
}

$romItems = Get-ChildItem -Path $romPath -File

$hashProvider = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider

foreach ($romFile in $romItems){
    $fileContent = [System.IO.File]::ReadAllBytes($romFile.FullName)
    if (($fileContent[0] = 0x4e ) -and ($fileContent[1] = 0x45 ) -and ($fileContent[2] = 0x53 ) -and ($fileContent[3] = 0x1a )) {
        $fileContentMinusHeader = [System.Byte[]]::new($fileContent.Length-$nesHeaderLength)
        for($i=$nesHeaderLength;$i -lt $fileContent.Length; $i++){
            $fileContentMinusHeader[$i-$nesHeaderLength] = $fileContent[$i]
        }
        $hash = $hashProvider.ComputeHash($fileContentMinusHeader)
        $sha1 = [System.BitConverter]::ToString($hash) -replace  "-"
        $sha1Lower = $sha1.ToLower()
        $sha1Upper = $sha1.ToUpper()
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
            Write-Host "Unable to identify $romFile; hash not found"
            $totalUnidentified++
        }
    } else {
        Write-Host "Unable to identify $romFile; not in iNES format"
            $totalUnidentified++
    }
}

Write-Host
Write-Host "Total ROMs: $totalExamined"
Write-Host "Total ROMs Identified: $totalIdentified"
Write-Host "Total ROMs Renamed: $totalRenamed"
Write-Host "Total ROMs Unidentified: $totalUnidentified"
Write-Host
<#
.SYNOPSIS

Fixes NES ROM headers based on the Nestopia database

.DESCRIPTION

The Fix-NES-ROM-Headers.ps1 script loads the most recent XML file in the specified
folder, loads each ROM file in the specified folder, SHA1 hashes all but the 
first 16 bytes, then compares the hash to the Nestopa database.  If a match is 
found, the appropriate iNES header is constructed from the Nestopia database, and
compared to the existing iNES header.  If different, the existing header is 
overwritten with the new header.

.PARAMETER romPath
Specifies the path to the folder containing NES ROMs.

.PARAMETER datPath
Specifies the to the folder containing No-Intro DAT files.

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

None. This script does not generate any output.

.EXAMPLE

C:\PS> .\Fix-NES-ROM-Headers.ps1 -romPath C:\RetroArch\roms -nestopiaPath C:\Nestopia\NstDatabase.xml

#>

param(
    [Parameter(Mandatory=$True)]
    [string] $romPath,
    [Parameter(Mandatory=$True)]
    [string] $nestopiaPath
)

[int] $totalExamined = 0
[int] $totalIdentified = 0
[int] $totalRenamed = 0
[int] $totalUnidentified = 0
[int] $nesHeaderLength = 16

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}
if (!(Test-Path $nestopiaPath)) {
    Write-Host "Unable to locate Nestopia directory.  Exiting..."
    exit
}

[xml]$nestopia = Get-Content -Path $nestopiaPath

if (!$nestopia) {    
    Write-Host "Unable to read Nestopia file.  Exiting..."
    exit
} else {
    Write-Host "Loaded Nestopia file"
}

$romItems = Get-ChildItem -Path $romPath -File

$hashProvider = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider

foreach ($romFile in $romItems){
    $fileContent = [System.IO.File]::ReadAllBytes($romFile.FullName)
    if (($fileContent[0] = 0x4e ) -and ($fileContent[1] = 0x45 ) -and ($fileContent[2] = 0x53 ) -and ($fileContent[3] = 0x1a )) {
        $fileHeader = [System.Byte[]]::new($nesHeaderLength)
        for($i=0;$i -lt $nesHeaderLength; $i++){
            $fileHeader[$i] = $fileContent[$i]
        }
        $fileContentMinusHeader = [System.Byte[]]::new($fileContent.Length-$nesHeaderLength)
        for($i=$nesHeaderLength;$i -lt $fileContent.Length; $i++){
            $fileContentMinusHeader[$i-$nesHeaderLength] = $fileContent[$i]
        }
        $hash = $hashProvider.ComputeHash($fileContentMinusHeader)
        $sha1 = [System.BitConverter]::ToString($hash) -replace  "-"
        $xPath = "/database/game/cartridge[@sha1='$sha1'][1]"    
        $nestopiaQuery = Select-Xml -Xml $nestopia -XPath $xPath
        $totalExamined++

        if ($nestopiaQuery) {
            Write-Host("Game: $romFile")
            Write-Host("SHA-1: $sha1")
            [int] $mapper = $nestopiaQuery.Node.SelectSingleNode("board/@mapper").Value
            [int] $mapperLowNibble = $mapper -band 0x0f
            [int] $mapperHighNibble = $mapper -band 0xf0
            Write-Host("Mapper: $mapper ($mapperHighNibble, $mapperLowNibble)")

            [int] $programSize = $nestopiaQuery.Node.SelectSingleNode("board/prg/@size").Value -replace "k"
            [int] $programPages = $programSize * 1024 / 16384
            [int] $characterSize = $nestopiaQuery.Node.SelectSingleNode("board/chr/@size").Value -replace "k"
            [int] $characterPages = $characterSize * 1024 / 8192
            Write-Host("PRG: $programPages pages, CHR: $characterPages pages")

            [int] $mirrorVertical = $nestopiaQuery.Node.SelectSingleNode("board/pad/@h").Value
            [int] $mirror4Screen = 0;

            <# Four-screen mirroring is only used on a handful of titles.
                Gauntlet (multiple versions)
                Rad Racer II    
            Their SHAs are below. #>
            if ($sha1 -eq "97C351AA8201661C11CE32204F18DD4A6A1D5C28" -or
                $sha1 -eq "3BD76AF54A9A2760E5AF975BEEA877057F08E871" -or
                $sha1 -eq "7434AFE89BCAE2A5B73397CF5B7DB0B59D2953E0"){
                $mirror4Screen = 1
                $mirrorVertical = 0
            }

            if ($mirror4Screen) {
                Write-Host("Mirroring: 4-Screen")
            } elseif ($mirrorVertical) {
                Write-Host("Mirroring: Vertical")
            }

            [int] $battery = $nestopiaQuery.Node.SelectSingleNode("board/*[@battery=1]/@battery").Value
            Write-Host("Battery: $battery")          
            
            [int] $expectedSize = ($programSize + $characterSize) * 1024
            if ($expectedSize -ne $fileContentMinusHeader.Length) {                
                Write-Host("Size check failed: expected $expectedSize, got $fileContentMinusHeader.Length") -ForegroundColor DarkRed
            }            

            $totalIdentified++

            $fileHeaderNew = [System.Byte[]]::new($nesHeaderLength)
            $fileHeaderNew[0] = $fileHeader[0]
            $fileHeaderNew[1] = $fileHeader[1]
            $fileHeaderNew[2] = $fileHeader[2]
            $fileHeaderNew[3] = $fileHeader[3]
            $fileHeaderNew[4] = $programPages
            $fileHeaderNew[5] = $characterPages
            $fileHeaderNew[6] = ($mapperLowNibble -shl 4) + ($mirror4Screen -shl 3) + ($battery -shl 1) + ($mirrorVertical)
            $fileHeaderNew[7] = $mapperHighNibble         
            
            [bool] $headersAreDifferent = $false
            for($i=0;$i -lt $nesHeaderLength; $i++){
                if ($fileHeader[$i] -ne $fileHeaderNew[$i]) {
                    $headersAreDifferent = $true
                }
            }

            if ($headersAreDifferent) {
                Write-Host ("Old Header: ") -NoNewline
                for($i=0;$i -lt $nesHeaderLength; $i++){
                    if ($fileHeader[$i] -ne $fileHeaderNew[$i]) {
                        Write-Host($fileHeader[$i].ToString('X2')) -ForegroundColor DarkRed -NoNewline
                    } else {
                        Write-Host($fileHeader[$i].ToString('X2')) -NoNewline
                    }
                    Write-Host(' ') -NoNewline
                }
                Write-Host("")

                Write-Host ("New Header: ") -NoNewline
                for($i=0;$i -lt $nesHeaderLength; $i++){
                    if ($fileHeader[$i] -ne $fileHeaderNew[$i]) {
                        Write-Host($fileHeaderNew[$i].ToString('X2')) -ForegroundColor DarkGreen -NoNewline
                    } else {
                        Write-Host($fileHeaderNew[$i].ToString('X2')) -NoNewline
                    }
                    Write-Host(' ') -NoNewline
                }
                Write-Host("")  

                $fileContentNew = [System.Byte[]]::new($fileContent.Length);
                for ($i=0;$i -lt $nesHeaderLength; $i++){
                    $fileContentNew[$i] = $fileHeaderNew[$i]
                }
                for($i=$nesHeaderLength;$i -lt $fileContent.Length; $i++){
                    $fileContentNew[$i] = $fileContent[$i]
                }

                [System.IO.File]::WriteAllBytes($romFile.FullName, $fileContentNew)
                Write-Host("Header fixed")


                $totalFixed++
            } else {
                Write-Host("Headers are good; no changes made")
            }
            Write-Host("")

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
Write-Host "Total ROMs Fixes: $totalFixed"
Write-Host "Total ROMs Unidentified: $totalUnidentified"
Write-Host
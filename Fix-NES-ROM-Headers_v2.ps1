<#
.SYNOPSIS

Fixes NES ROM headers based on the NES 2.0 database

.DESCRIPTION

The Fix-NES-ROM-Headers.ps1 script loads the most recent XML file in the specified
folder, loads each ROM file in the specified folder, SHA1 hashes all but the 
first 16 bytes, then compares the hash to the database.  If a match is 
found, the appropriate NES 2.0 header is constructed from the NES 2.0 database, and
compared to the existing NES 2.0 header.  If different, the existing header is 
overwritten with the new header.

.PARAMETER romPath
Specifies the path to the folder containing NES ROMs.

.PARAMETER nesXmlPath
Specifies the to the NES 2.0 Database XML file.

.INPUTS

None. You cannot pipe objects to this script.

.OUTPUTS

None. This script does not generate any output.

.EXAMPLE

C:\PS> .\Fix-NES-ROM-Headers.ps1 -romPath C:\emulator\roms -nesXmlPath C:\NES\nes20db.xml

#>

param(
    [Parameter(Mandatory=$True)]
    [string] $romPath,
    [Parameter(Mandatory=$True)]
    [string] $nesXmlPath
)

[int] $totalExamined = 0
[int] $totalIdentified = 0
[int] $totalRenamed = 0
[int] $totalUnidentified = 0
[int] $nesHeaderLength = 16
[int] $programRomPageSize = 16384
[int] $characterRomPageSize = 8192
[int] $ramShiftSize = 64

if (!(Test-Path $romPath)) {
    Write-Host "Unable to locate ROM directory.  Exiting..."
    exit
}
if (!(Test-Path $nesXmlPath)) {
    Write-Host "Unable to locate NES 2.0 Database file.  Exiting..."
    exit
}

[xml]$nesDb = Get-Content -Path $nesXmlPath

if (!$nesDb) {    
    Write-Host "Unable to read NES 2.0 Database file.  Exiting..."
    exit
} else {
    Write-Host "Loaded NES 2.0 Database file"
}

$romItems = Get-ChildItem -Path $romPath -File -Recurse

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
        $sha1 = $sha1.ToUpper()
        $xPath = "/nes20db/game[rom[@sha1='$sha1']][1]"    
        $nesQuery = Select-Xml -Xml $nesDb -XPath $xPath
        $totalExamined++

        if ($nesQuery) {
            Write-Host("Game: $romFile")

            [bool] $programRomHashMatched = $false
            [bool] $characterRomHashMatched = $false
            [bool] $hasCharacterRom = $false          

            [int] $trainer = 0
            [int] $trainerSize = 0     
            $trainerNode = $nesQuery.Node.SelectSingleNode("trainer/@size")
            if ($trainerNode) {
                $trainer = 1
                $trainerSize = $trainerNode.Value
                Write-Host("Trainer: $trainer")
            } 
            
            [int] $mapperLowNibble = 0
            [int] $mapperHighNibble = 0
            [int] $mapperHigherNibble = 0
            [int] $submapperLowNibble = 0
            $mapperNode = $nesQuery.Node.SelectSingleNode("pcb/@mapper")
            if ($mapperNode) {
                [int] $mapper = $mapperNode.Value
                $mapperLowNibble = $mapper -band 0x0f
                $mapperHighNibble = $mapper -shr 4 -band 0x0f
                $mapperHigherNibble = $mapper -shr 8 -band 0x0f
                $submapper = $nesQuery.Node.SelectSingleNode("pcb/@submapper").Value
                $submapperLowNibble = $submapper -band 0x0f
                Write-Host("Mapper: $mapper ($mapperHigherNibble, $mapperHighNibble, $mapperLowNibble), Submapper: $submapper ($submapperLowNibble)")
            }

            [int] $programRomPages = 0 
            [int] $programRomSize = 0           
            $prgromNode = $nesQuery.Node.SelectSingleNode("prgrom/@size")
            if ($prgromNode) {
                $programRomSize = $prgromNode.Value
                $programRomPages = $programRomSize / $programRomPageSize                
                Write-Host("PRG ROM: $programRomSize bytes ($programRomPages pages)")
            }

            $prgromHashNode = $nesQuery.Node.SelectSingleNode("prgrom/@sha1")
            if ($prgromHashNode) {
                $targetProgramRomSha1 = $prgromHashNode.Value 
                [int] $programRomOffset = $nesHeaderLength + $trainerSize
                $programRomContent = [System.Byte[]]::new($programRomSize)
                for($i=0;$i -lt $programRomSize; $i++){
                    $programRomContent[$i] = $fileContent[$i + $programRomOffset]
                }                
                $programRomHash = $hashProvider.ComputeHash($programRomContent)
                $programRomSha1 = [System.BitConverter]::ToString($programRomHash) -replace  "-"
                $programRomSha1 = $programRomSha1.ToUpper()
                if ($programRomSha1.Equals($targetProgramRomSha1)) {
                    $programRomHashMatched = $true
                    Write-Host("PRG ROM hash passed")
                } else {
                    Write-Host("PRG ROM hash failed")
                }                
            }

            [int] $characterRomPages = 0
            [int] $characterRomSize = 0
            $chrromNode= $nesQuery.Node.SelectSingleNode("chrrom/@size")
            if ($chrromNode) {
                $characterRomSize = $chrromNode.Value
                $characterRomPages = $characterRomSize / $characterRomPageSize                         
                Write-Host("CHR ROM: $characterRomSize bytes ($characterRomPages pages)")    
            }

            $chrromHashNode = $nesQuery.Node.SelectSingleNode("chrrom/@sha1")
            if ($chrromHashNode) {
                $targetCharacterRomSha1 = $chrromHashNode.Value
                [int] $characterRomOffset = $nesHeaderLength + $trainerSize + $programRomSize
                $characterRomContent = [System.Byte[]]::new($characterRomSize)
                for($i=0;$i -lt $characterRomSize; $i++){
                    $characterRomContent[$i] = $fileContent[$i + $characterRomOffset]
                }
                $characterRomHash = $hashProvider.ComputeHash($characterRomContent)
                $characterRomSha1 = [System.BitConverter]::ToString($characterRomHash) -replace  "-"
                $characterRomSha1 = $characterRomSha1.ToUpper()
                if ($characterRomSha1.Equals($targetCharacterRomSha1)) {
                    $characterRomHashMatched = $true
                    Write-Host("CHR ROM hash passed")
                } else {
                    Write-Host("CHR ROM hash failed")
                }                                
            } else {
                $hasCharacterRom = $false
            }

            [int] $mirrorVertical = 0
            [int] $mirror4Screen = 0
            $mirrorNode = $nesQuery.Node.SelectSingleNode("pcb/@mirroring")
            if ($mirrorNode) {
                $mirrorVertical = If ($mirrorNode.Value.Equals("V")) { 1 } Else { 0 }
                $mirror4Screen = If ($mirrorNode.Value.Equals("4")) { 1 } Else { 0 }
                if ($mirror4Screen) {
                    Write-Host("Mirroring: 4-Screen")
                } elseif ($mirrorVertical) {
                    Write-Host("Mirroring: Vertical")
                } else {
                    Write-Host("Mirroring: Horizontal")
                }
            }

            [int] $battery = 0
            $batteryNode = $nesQuery.Node.SelectSingleNode("pcb/@battery")
            if ($batteryNode) {
                $battery = $batteryNode.Value
                Write-Host("Battery: $battery")
            }

            [int] $consoleType = 0
            $consoleTypeNode = $nesQuery.Node.SelectSingleNode("console/@type")
            if ($consoleTypeNode) {
                $consoleType = $consoleTypeNode.Value
                Write-Host("Console Type: $consoleType")
            }

            [int] $consoleRegion = 0
            $consoleRegionNode = $nesQuery.Node.SelectSingleNode("console/@region")
            if ($consoleRegionNode) {
                $consoleRegion = $consoleRegionNode.Value
                Write-Host("Console Region: $consoleRegion")
            }

            [int] $programRamShiftCount = 0
            $prgramNode = $nesQuery.Node.SelectSingleNode("prgram/@size")
            if ($prgramNode) {
                [int] $programRamSize = $prgramNode.Value
                while (($ramShiftSize -shl $programRamShiftCount) -lt $programRamSize) { $programRamShiftCount++ }
                Write-Host("PRG RAM: $programRamSize bytes ($programRamShiftCount)")
            }
            [int] $programNvRamShiftCount = 0
            $prgnvramNode = $nesQuery.Node.SelectSingleNode("prgnvram/@size")
            if ($prgnvramNode) {
                [int] $programNvRamSize = $prgnvramNode.Value
                while (($ramShiftSize -shl $programNvRamShiftCount) -lt $programNvRamSize) { $programNvRamShiftCount++ }
                Write-Host("PRG NVRAM: $programNvRamMemorySize bytes ($programNvRamShiftCount)")
            }
            [int] $characterRamShiftCount = 0
            $chrramNode = $nesQuery.Node.SelectSingleNode("chrram/@size")
            if ($chrramNode) {
                [int] $characterRamSize = $chrramNode.Value
                while (($ramShiftSize -shl $characterRamShiftCount) -lt $characterRamSize) { $characterRamShiftCount++ }
                Write-Host("CHR RAM: $characterRamSize bytes ($characterRamShiftCount)")
            } 
            [int] $characterNvRamShiftCount = 0
            $chrnvramNode = $nesQuery.Node.SelectSingleNode("chrnvram/@size")
            if ($chrnvramNode) {
                [int] $characterNvRamSize = $chrnvramNode.Value
                while (($ramShiftSize -shl $characterNvRamShiftCount) -lt $characterNvRamSize) { $characterNvRamShiftCount++ }
                Write-Host("CHR NVRAM: $characterNvRamSize bytes ($characterNvRamShiftCount)")
            }

            [int] $expansionType = 0
            $expansionNode = $nesQuery.Node.SelectSingleNode("expansion/@type")
            if ($expansionNode) {
                $expansionType = $expansionNode.Value
                Write-Host("Expansion Type: $expansionType")
            }     
            
            [int] $miscellaneousRomCount = 0
            $miscRomNode = $nesQuery.Node.SelectSingleNode("miscrom/@number")
            if ($miscRomNode) {
                $miscellaneousRomCount = $miscRomNode.Value
                Write-Host("Miscellaneous ROMs: $miscellaneousRomCount")
            }     
            
            $totalIdentified++

            $fileHeaderNew = [System.Byte[]]::new($nesHeaderLength)
            $fileHeaderNew[0] = $fileHeader[0]
            $fileHeaderNew[1] = $fileHeader[1]
            $fileHeaderNew[2] = $fileHeader[2]
            $fileHeaderNew[3] = $fileHeader[3]
            $fileHeaderNew[4] = $programRomPages
            $fileHeaderNew[5] = $characterRomPages
            $fileHeaderNew[6] = ($mapperLowNibble -shl 4) + ($mirror4Screen -shl 3) + ($trainer -shl 2) + ($battery -shl 1) + ($mirrorVertical)
            $fileHeaderNew[7] = (($mapperHighNibble -shl 4) + $consoleType) -bor 0x8 <#0x8 is the NES 2.0 identification bit#>
            $fileHeaderNew[8] = ($submapperLowNibble -shl 4) + $mapperHigherNibble
            $fileHeaderNew[9] = 0 <#TODO: implement PRG/CHR exponent-multiplier notation #>  
            $fileHeaderNew[10] = ($programNvRamShiftCount -shl 4) + ($programRamShiftCount)
            $fileHeaderNew[11] = ($characterNvRamShiftCount -shl 4) + ($characterRamShiftCount)
            $fileHeaderNew[12] = $consoleRegion
            $fileHeaderNew[13] = 0
            $fileHeaderNew[14] = $miscellaneousRomCount 
            $fileHeaderNew[15] = $expansionType

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
        Write-Host "Unable to identify $romFile; not in iNES or NES 2.0 format"
            $totalUnidentified++
    }
}

Write-Host
Write-Host "Total ROMs: $totalExamined"
Write-Host "Total ROMs Identified: $totalIdentified"
Write-Host "Total ROMs Fixes: $totalFixed"
Write-Host "Total ROMs Unidentified: $totalUnidentified"
Write-Host

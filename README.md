# Game ROM PowerShell Scripts
A collection of PowerShell scripts for validating and renaming ROM files from No-Intro format metadata files.

## Fix NES ROM Headers v2
Updates NES ROM Headers to use [NES 2.0](https://www.nesdev.org/wiki/NES_2.0) format headers.  Requires a copy of the NES 2.0 database in XML format (available at the [NESDev forums](https://forums.nesdev.org/viewtopic.php?t=19940).)

## Validate ROMs
Checks SHA1 hashes against the corresponding [No-Intro .DAT](https://datomatic.no-intro.org) file.  Requires a .DAT file (recommend downloading the daily pack from No-Intro).

## Validate NES ROMs
Checks SHA1 hashes against the corresponding [No-Intro .DAT](https://datomatic.no-intro.org) file, discarding the first 16 bytes (the iNES/NES 2.0 header).  Requires the "Nintendo - Nintendo Entertainment System (Headerless)" .DAT file and ROMS with iNES or NES 2.0 headers.

## Set ROMs Read-Only
Sets the read-only attribute on all files in the folder.  Only tested on Windows thus far.

# Usage
## Fix NES ROM Headers
> ./fix-nes-rom-headers_v2.ps1 -rompath "..\ROMs\Nintendo - Nintendo Entertainment System" -nesxmlpath "..\NES 2.0\nes20db.xml"

## Validate ROMs
> ./validate-ROMs.ps1 -rompath "..\ROMs\Nintendo - Super Nintendo Entertainment System" -datpath "..\DATs" -datname "Nintendo - Super Nintendo Entertainment System"

## Validate NES ROMs
> ./validate-nes-ROMs.ps1 -rompath "..\ROMs\Nintendo - Nintendo Entertainment System" -datpath "..\DATs"

#Notes
These scripts are offered without any warranty.  **Please back up your files before using them.**  These scripts were tested on Windows 10 and 11 only.  These scripts were tested against the author's collection only, not the complete No-Intro sets.

#Known Issues
## Fix NES Rom Headers v2
- PRG-ROM exponent-multiplier notation is not implemented.

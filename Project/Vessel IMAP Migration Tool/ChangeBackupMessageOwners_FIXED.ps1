# ==============================================================================================
# Dualog IMAP Mail Store Backup / Change Folder and Message Ownership / Version 2.0.1
# PowerShell Version - Fixed to match original batch behavior
# ==============================================================================================

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Attempting to restart with elevated privileges..." -ForegroundColor Cyan
    Write-Host ""

    # Re-launch the script with administrator privileges
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

# Clear screen and display header
Clear-Host
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host "Dualog IMAP Mail Store Backup / Change Folder and Message Ownership / Version 2.0.1" -ForegroundColor Cyan
Write-Host "PowerShell Version - Running as Administrator" -ForegroundColor Green
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration Variables
$backupFolder = "$PSScriptRoot\Dualog IMAP Backup\"
$backupFileMask = "imapmailstore.dualogbackup*"
$scriptFolder = $PSScriptRoot + "\"
$tempFolder = $env:TEMP
$archivePassword = "G4VESSEL"

# Display paths
Write-Host "This Folder (Script) : $scriptFolder"
Write-Host "Dualog Backup Folder : $backupFolder"
Write-Host "User's 'Temp' Folder : $tempFolder"
Write-Host ""

# Verify required files exist
$requiredFiles = @(
    @{Name = "7z.exe"; Path = "$scriptFolder\7z.exe"},
    @{Name = "7z.dll"; Path = "$scriptFolder\7z.dll"},
    @{Name = "DualogUserMap.exe"; Path = "$scriptFolder\DualogUserMap.exe"},
    @{Name = "DualogUserMap.ini"; Path = "$scriptFolder\DualogUserMap.ini"}
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file.Path)) {
        Write-Host ""
        Write-Host "=====" -ForegroundColor Red
        Write-Host "ERROR" -ForegroundColor Red
        Write-Host "=====" -ForegroundColor Red
        Write-Host ""
        Write-Host "File $($file.Name) not detected" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please ensure that file $($file.Name) is in the same folder as this script"
        Write-Host ""
        pause
        exit 1
    }
}

# Create backup folder if it doesn't exist
if (-not (Test-Path $backupFolder)) {
    Write-Host "Creating backup folder: $backupFolder" -ForegroundColor Yellow
    New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    Write-Host "Backup folder created successfully." -ForegroundColor Green
    Write-Host ""
}

# Check for backup files
$backupFiles = Get-ChildItem -Path $backupFolder -Filter $backupFileMask -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne "imapmailstore.dualogbackup.archive" }

if ($backupFiles.Count -eq 0) {
    Write-Host ""
    Write-Host "=====" -ForegroundColor Red
    Write-Host "ERROR" -ForegroundColor Red
    Write-Host "=====" -ForegroundColor Red
    Write-Host ""
    Write-Host "No Dualog IMAP mail store backup files were detected using this mask:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "$backupFolder$backupFileMask"
    Write-Host ""
    Write-Host "Please place your backup files in the 'Dualog IMAP Backup' folder." -ForegroundColor Cyan
    Write-Host ""
    pause
    exit 1
}

# Display detected backup files
Write-Host "List of Detected Dualog IMAP Mail Store Backup Files..." -ForegroundColor Green
Write-Host ""
foreach ($file in $backupFiles) {
    Write-Host $file.Name
}
Write-Host ""

# Main processing function
function ProcessBackupFile {
    param([System.IO.FileInfo]$BackupFile)

    Write-Host ""
    Write-Host "Processing File : $($BackupFile.Name)" -ForegroundColor Yellow

    # Clean up any existing folders file in temp
    $foldersFileUpper = "$tempFolder\FOLDERS"
    $foldersFileLower = "$tempFolder\folders"

    if (Test-Path $foldersFileUpper) {
        Remove-Item $foldersFileUpper -Force
    }
    if (Test-Path $foldersFileLower) {
        Remove-Item $foldersFileLower -Force
    }

    # Extract FOLDERS file from archive
    $extractArgs = "e -aoa -bb0 -bd -p$archivePassword `"-o$tempFolder`" `"$($BackupFile.FullName)`" FOLDERS"
    $process = Start-Process -FilePath "$scriptFolder\7z.exe" -ArgumentList $extractArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$tempFolder\7z_extract.log"

    # Check which case was extracted (FOLDERS or folders)
    $foldersFile = $null
    if (Test-Path $foldersFileUpper) {
        $foldersFile = $foldersFileUpper
        # Rename to lowercase for DualogUserMap.exe
        Rename-Item -Path $foldersFileUpper -NewName "folders" -Force
        $foldersFile = $foldersFileLower
    } elseif (Test-Path $foldersFileLower) {
        $foldersFile = $foldersFileLower
    }

    if (-not $foldersFile -or -not (Test-Path $foldersFile)) {
        Write-Host "Failed to Extract File Named 'FOLDERS' From Archive!" -ForegroundColor Red
        return
    }

    # Backup original folders file
    $originalBackupName = "Original-Folders-File-From-$($BackupFile.Name)"
    Copy-Item -Path $foldersFile -Destination "$backupFolder\$originalBackupName" -Force
    Copy-Item -Path $foldersFile -Destination "$tempFolder\$originalBackupName" -Force

    Write-Host ""

    # Run DualogUserMap.exe from script folder (it will look for files in Windows TEMP)
    Write-Host "Running DualogUserMap.exe to remap user IDs..." -ForegroundColor Cyan
    Write-Host "  Script Folder: $scriptFolder" -ForegroundColor Gray
    Write-Host "  Config File: $($scriptFolder)DualogUserMap.ini" -ForegroundColor Gray
    Write-Host "  Processing File: $tempFolder\folders" -ForegroundColor Gray
    $userMapProcess = Start-Process -FilePath "$scriptFolder\DualogUserMap.exe" -WorkingDirectory $scriptFolder -Wait -NoNewWindow -PassThru

    if ($userMapProcess.ExitCode -ne 0 -and $userMapProcess.ExitCode -ne $null) {
        Write-Host "Warning: DualogUserMap.exe exited with code $($userMapProcess.ExitCode)" -ForegroundColor Yellow
    }

    # Display log if it exists
    $logFile = "$tempFolder\dualogusermap.log"
    if (Test-Path $logFile) {
        Write-Host "DualogUserMap.exe Log Output:" -ForegroundColor Cyan
        Write-Host ""
        Get-Content $logFile
        Write-Host ""
        Remove-Item $logFile -Force
    } else {
        Write-Host "No log file generated by DualogUserMap.exe" -ForegroundColor Yellow
    }

    # Verify if the file was modified and analyze changes
    $originalSize = (Get-Item "$backupFolder\$originalBackupName").Length
    $modifiedSize = (Get-Item $foldersFile).Length
    $originalHash = (Get-FileHash "$backupFolder\$originalBackupName" -Algorithm MD5).Hash
    $modifiedHash = (Get-FileHash $foldersFile -Algorithm MD5).Hash

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       USER ID REMAPPING SUMMARY        " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($originalHash -ne $modifiedHash) {
        Write-Host "SUCCESS: User IDs were remapped!" -ForegroundColor Green
        Write-Host ""
        Write-Host "File Statistics:" -ForegroundColor Yellow
        Write-Host "  Original size: $originalSize bytes" -ForegroundColor Gray
        Write-Host "  Modified size: $modifiedSize bytes" -ForegroundColor Gray
        Write-Host "  Size difference: $($modifiedSize - $originalSize) bytes" -ForegroundColor Gray
        Write-Host ""

        # Count occurrences of each user ID in both files
        Write-Host "Analyzing user ID changes..." -ForegroundColor Yellow

        # Read mapping file
        $mappings = @{}
        Get-Content "$scriptFolder\DualogUserMap.ini" | ForEach-Object {
            if ($_ -match '^\s*(\d+)\s+(\d+)\s*$') {
                $oldId = $matches[1]
                $newId = $matches[2]
                $mappings[$oldId] = $newId
            }
        }

        # Read original and modified files as text
        $originalContent = Get-Content "$backupFolder\$originalBackupName" -Raw
        $modifiedContent = Get-Content $foldersFile -Raw

        # Count changes
        $totalChanges = 0
        $changedIds = @()

        foreach ($oldId in $mappings.Keys) {
            $newId = $mappings[$oldId]

            # Count occurrences in original file (using word boundary to avoid partial matches)
            $originalMatches = ([regex]::Matches($originalContent, "\b$oldId\b")).Count
            $modifiedMatches = ([regex]::Matches($modifiedContent, "\b$oldId\b")).Count
            $newIdMatches = ([regex]::Matches($modifiedContent, "\b$newId\b")).Count

            if ($originalMatches -gt $modifiedMatches) {
                $replacements = $originalMatches - $modifiedMatches
                $totalChanges += $replacements
                $changedIds += [PSCustomObject]@{
                    OldID = $oldId
                    NewID = $newId
                    Count = $replacements
                }
            }
        }

        if ($totalChanges -gt 0) {
            Write-Host ""
            Write-Host "Total Replacements: $totalChanges occurrences" -ForegroundColor Green
            Write-Host ""
            Write-Host "Detailed Changes:" -ForegroundColor Yellow
            Write-Host ("{0,-15} {1,-15} {2,-10}" -f "Old User ID", "New User ID", "Count") -ForegroundColor Cyan
            Write-Host ("{0,-15} {1,-15} {2,-10}" -f "-----------", "-----------", "-----") -ForegroundColor Cyan

            foreach ($change in ($changedIds | Sort-Object -Property Count -Descending)) {
                Write-Host ("{0,-15} {1,-15} {2,-10}" -f $change.OldID, $change.NewID, $change.Count) -ForegroundColor White
            }
        } else {
            Write-Host "Note: File was modified but no specific user ID patterns were found." -ForegroundColor Yellow
            Write-Host "This may be normal if changes were made to other parts of the file." -ForegroundColor Gray
        }

    } else {
        Write-Host "WARNING: File was NOT modified (no changes detected)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible reasons:" -ForegroundColor Yellow
        Write-Host "  - DualogUserMap.exe did not run properly" -ForegroundColor Gray
        Write-Host "  - No matching user IDs were found in the file" -ForegroundColor Gray
        Write-Host "  - DualogUserMap.ini has no valid mappings" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ""
    Write-Host "Replacing Modified File in Archive (This Will Take Some Time - Please Wait)..." -ForegroundColor Cyan

    # Delete old FOLDERS file from archive
    $deleteArgs = "d -p$archivePassword `"$($BackupFile.FullName)`" FOLDERS"
    Start-Process -FilePath "$scriptFolder\7z.exe" -ArgumentList $deleteArgs -Wait -NoNewWindow -RedirectStandardOutput "$tempFolder\7z_delete.log"

    # Add modified FOLDERS file to archive
    $addArgs = "a -p$archivePassword `"$($BackupFile.FullName)`" `"$foldersFile`""
    Start-Process -FilePath "$scriptFolder\7z.exe" -ArgumentList $addArgs -Wait -NoNewWindow -RedirectStandardOutput "$tempFolder\7z_add.log"

    # Clean up temp folders file
    if (Test-Path $foldersFile) {
        Remove-Item $foldersFile -Force
    }

    Write-Host ""
    Write-Host "Processing of File Completed ($($BackupFile.Name))" -ForegroundColor Green
}

# Process each backup file
Write-Host "Starting Main Process..." -ForegroundColor Cyan
foreach ($backupFile in $backupFiles) {
    ProcessBackupFile -BackupFile $backupFile
}

Write-Host ""
Write-Host "=================" -ForegroundColor Green
Write-Host "Process Completed" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host ""

pause

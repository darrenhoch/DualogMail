# ==============================================================================================
# Dualog IMAP Mail Store Backup / Change Folder and Message Ownership / Version 2.0.0
# PowerShell Version - Converted from Batch Script
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
Write-Host "Dualog IMAP Mail Store Backup / Change Folder and Message Ownership / Version 2.0.0" -ForegroundColor Cyan
Write-Host "PowerShell Version - Running as Administrator" -ForegroundColor Green
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration Variables
$backupFolder = "$PSScriptRoot\Dualog IMAP Backup\"
$backupFileMask = "imapmailstore.dualogbackup*"
$scriptFolder = $PSScriptRoot + "\"
$tempFolder = $PSScriptRoot
$archivePassword = "G4VESSEL"

# Display paths
Write-Host "This Folder (Script) : $scriptFolder"
Write-Host "Dualog Backup Folder : $backupFolder"
Write-Host "Temp/Working Folder  : $tempFolder"
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
    $foldersFile = "$tempFolder\folders"
    if (Test-Path $foldersFile) {
        Remove-Item $foldersFile -Force
    }

    # Extract FOLDERS file from archive
    $extractArgs = "e -aoa -bb0 -bd -p$archivePassword -o$tempFolder `"$($BackupFile.FullName)`" FOLDERS"
    $process = Start-Process -FilePath "$scriptFolder\7z.exe" -ArgumentList $extractArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$tempFolder\7z_extract.log"

    if (-not (Test-Path $foldersFile)) {
        Write-Host "Failed to Extract File Named 'FOLDERS' From Archive!" -ForegroundColor Red
        return
    }

    # Backup original folders file
    $originalBackupName = "Original-Folders-File-From-$($BackupFile.Name)"
    Copy-Item -Path $foldersFile -Destination "$backupFolder\$originalBackupName" -Force
    Copy-Item -Path $foldersFile -Destination "$tempFolder\$originalBackupName" -Force

    Write-Host ""

    # Run DualogUserMap.exe
    $userMapProcess = Start-Process -FilePath "$scriptFolder\DualogUserMap.exe" -Wait -NoNewWindow -PassThru

    # Display log if it exists
    $logFile = "$tempFolder\dualogusermap.log"
    if (Test-Path $logFile) {
        Get-Content $logFile
        Remove-Item $logFile -Force
    }

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

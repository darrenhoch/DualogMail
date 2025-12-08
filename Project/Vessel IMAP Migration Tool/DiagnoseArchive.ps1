# Diagnostic Script for IMAP Migration Tool
# This script checks the archive contents to identify the issue

Write-Host "=== Diagnostic Script for IMAP Backup Archive ===" -ForegroundColor Cyan
Write-Host ""

# Set the path to your tool folder
$toolFolder = $PSScriptRoot
$backupFolder = "$toolFolder\Dualog IMAP Backup"
$password = "G4VESSEL"

Write-Host "Tool Folder: $toolFolder" -ForegroundColor Yellow
Write-Host "Backup Folder: $backupFolder" -ForegroundColor Yellow
Write-Host ""

# Check if 7z.exe exists
if (-not (Test-Path "$toolFolder\7z.exe")) {
    Write-Host "ERROR: 7z.exe not found!" -ForegroundColor Red
    exit
}

# Find backup files
$backupFiles = Get-ChildItem -Path $backupFolder -Filter "*.DUALOGBACKUP*" -ErrorAction SilentlyContinue

if ($backupFiles.Count -eq 0) {
    Write-Host "ERROR: No backup files found!" -ForegroundColor Red
    exit
}

Write-Host "Found $($backupFiles.Count) backup file(s):" -ForegroundColor Green
foreach ($file in $backupFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor White
}
Write-Host ""

# Check the first backup file
$firstBackup = $backupFiles[0]
Write-Host "Analyzing: $($firstBackup.Name)" -ForegroundColor Cyan
Write-Host ""

# List archive contents
Write-Host "Archive Contents:" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
& "$toolFolder\7z.exe" l -p"$password" "$($firstBackup.FullName)"

Write-Host ""
Write-Host "Looking for FOLDERS file (case variations)..." -ForegroundColor Cyan
Write-Host ""

# Test different case variations
$variations = @("FOLDERS", "folders", "Folders", "IMAP/FOLDERS", "imap/folders", "Imap/Folders")

foreach ($variant in $variations) {
    Write-Host "Testing: $variant" -ForegroundColor Yellow
    $testResult = & "$toolFolder\7z.exe" l -p"$password" "$($firstBackup.FullName)" "$variant" 2>&1

    if ($testResult -match "Archive:.*\n.*\n.*\d+ file") {
        Write-Host "  ✓ FOUND: $variant" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Not found: $variant" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""
pause

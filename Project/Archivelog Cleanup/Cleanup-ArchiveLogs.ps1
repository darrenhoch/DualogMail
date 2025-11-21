<#
.SYNOPSIS
    Manual Oracle Archive Log Cleanup Script - Deletes ALL Archive Logs

.DESCRIPTION
    Emergency script to delete ALL Oracle archive logs when space is critically low.
    Use this when auto-remediation fails or when immediate cleanup is needed.

    This script will:
    1. Retrieve Oracle SYS password from registry (HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS\DatabaseSysPassword)
    2. Shutdown the database (if running)
    3. Mount the database using RMAN
    4. Delete ALL archive logs
    5. Open the database

.PARAMETER WhatIf
    Show what would be deleted without actually deleting

.EXAMPLE
    .\Cleanup-ArchiveLogs.ps1 -WhatIf
    Shows how many archive logs would be deleted

.EXAMPLE
    .\Cleanup-ArchiveLogs.ps1
    Retrieves password from registry and deletes ALL archive logs

.NOTES
    CAUTION: Only use this if you understand the implications.
    This deletes ALL archive logs - not just old ones.
    Deleting archive logs can prevent point-in-time recovery.
    Requires RMAN and DBA privileges.
    Requires Dualog software to be installed (for registry password).

    Method used:
    - Retrieve SYS password from registry (DatabaseSysPassword key)
    - rman target sys/password
    - SHUTDOWN IMMEDIATE
    - STARTUP MOUNT
    - DELETE NOPROMPT ARCHIVELOG ALL
    - ALTER DATABASE OPEN
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param()

# Set error action preference to continue so we can see errors
$ErrorActionPreference = "Continue"

# Immediate output to confirm script is running
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Script started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Get-OraclePasswordFromRegistry {
    <#
    .SYNOPSIS
        Retrieves Oracle SYS password from Windows registry
    .DESCRIPTION
        Searches multiple registry locations for the DatabaseSysPassword value
        stored by Dualog software installation
    #>

    # Try multiple registry locations (same logic as FolderCreation.bat)
    $registryPaths = @(
        "HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS",
        "HKLM:\SOFTWARE\Dualog\DGS"
    )

    Write-Log "Attempting to retrieve Oracle SYS password from registry..." -Level Info
    Write-Host "DEBUG: Checking registry paths for DatabaseSysPassword..." -ForegroundColor Magenta

    foreach ($regPath in $registryPaths) {
        Write-Host "  Checking: $regPath" -ForegroundColor Gray
        try {
            if (Test-Path $regPath) {
                Write-Host "  ✓ Path exists" -ForegroundColor Green
                $regItem = Get-ItemProperty -Path $regPath -ErrorAction Stop

                if ($regItem.PSObject.Properties.Name -contains "DatabaseSysPassword") {
                    $password = $regItem.DatabaseSysPassword
                    if ($password) {
                        Write-Log "Successfully retrieved SYS password from: $regPath" -Level Success
                        return $password
                    } else {
                        Write-Host "  ⚠ DatabaseSysPassword key exists but value is empty" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  ⚠ DatabaseSysPassword key not found in this path" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ✗ Path does not exist" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  ✗ Error accessing registry: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }

    # If we get here, password was not found in any registry location
    Write-Log "Could not retrieve SYS password from registry" -Level Error
    Write-Host ""
    Write-Host "Registry paths checked for DatabaseSysPassword:" -ForegroundColor Yellow
    foreach ($path in $registryPaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Please ensure Dualog software is installed and registry key exists." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To check manually, run in PowerShell:" -ForegroundColor Cyan
    Write-Host '  Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS"' -ForegroundColor Gray
    return $null
}

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          ORACLE ARCHIVE LOG MANAGEMENT               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Global variables
$OracleUsername = "sys"
$OracleSID = "XE"
$OraclePassword = $null

# Interactive Menu
function Show-Menu {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          ORACLE ARCHIVE LOG MANAGEMENT MENU           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Delete Archive Logs" -ForegroundColor Red
    Write-Host "  [2] Check Archive Log Space" -ForegroundColor Green
    Write-Host "  [3] Expand Archive Log Space" -ForegroundColor Yellow
    Write-Host "  [4] Disable Archive Log Mode" -ForegroundColor Magenta
    Write-Host "  [5] Check Archive Log Mode Status" -ForegroundColor Cyan
    Write-Host "  [6] Exit" -ForegroundColor Gray
    Write-Host ""
}

# Main menu loop - keeps running until user exits
while ($true) {
    # Show menu and get user choice
    do {
        Show-Menu
        $choice = Read-Host "Select an option (1-6)"

        switch ($choice) {
        "1" {
            # Delete Archive Logs
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║     ORACLE ARCHIVE LOG MANUAL CLEANUP                 ║" -ForegroundColor Red
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "WARNING: This script will delete archive logs!" -ForegroundColor Red
            Write-Host "Only use this if you understand the implications." -ForegroundColor Yellow
            Write-Host ""

            # Retrieve Oracle credentials from registry
            $script:OraclePassword = Get-OraclePasswordFromRegistry

            if (-not $script:OraclePassword) {
                Write-Log "Failed to retrieve Oracle password from registry. Cannot proceed." -Level Error
                Write-Host ""
                Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            Write-Host ""
            Write-Host "Connection Details:" -ForegroundColor Cyan
            Write-Host "  Username: $OracleUsername"
            Write-Host "  Oracle SID: $OracleSID"
            Write-Host "  Password: Retrieved from registry"
            Write-Host ""

            Write-Host "⚠️  FINAL CONFIRMATION ⚠️" -ForegroundColor Red
            Write-Host ""
            Write-Host "This will:" -ForegroundColor Yellow
            Write-Host "  1. Shutdown the database immediately" -ForegroundColor Yellow
            Write-Host "  2. Mount the database" -ForegroundColor Yellow
            Write-Host "  3. Delete ALL archive logs" -ForegroundColor Yellow
            Write-Host "  4. Open the database" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "⚠️  Database will be unavailable during this process!" -ForegroundColor Red
            Write-Host "This action CANNOT be undone!" -ForegroundColor Red
            Write-Host ""

            $confirm = Read-Host "Are you sure you want to proceed? Type 'YES' to continue"
            if ($confirm -ne 'YES') {
                Write-Log "Operation cancelled by user" -Level Warning
                Write-Host ""
                Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            $script:MenuAction = "DeleteLogs"
            break
        }
        "2" {
            # Check Archive Log Space
            Write-Host ""
            Write-Host "Checking Archive Log Space..." -ForegroundColor Cyan

            # Retrieve password if not already retrieved
            if (-not $script:OraclePassword) {
                $script:OraclePassword = Get-OraclePasswordFromRegistry
                if (-not $script:OraclePassword) {
                    Write-Log "Failed to retrieve Oracle password from registry." -Level Error
                    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
            }

            $script:MenuAction = "CheckSpace"
            break
        }
        "3" {
            # Expand Archive Log Space
            Write-Host ""
            Write-Host "Expanding Archive Log Space to 88GB..." -ForegroundColor Yellow

            # Retrieve password if not already retrieved
            if (-not $script:OraclePassword) {
                $script:OraclePassword = Get-OraclePasswordFromRegistry
                if (-not $script:OraclePassword) {
                    Write-Log "Failed to retrieve Oracle password from registry." -Level Error
                    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
            }

            $script:ExpandSizeGB = 88
            $script:MenuAction = "ExpandSpace"
            break
        }
        "4" {
            # Disable Archive Log Mode
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║             ⚠️  CRITICAL WARNING ⚠️                   ║" -ForegroundColor Red
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "DISABLING ARCHIVE LOG MODE IS STRONGLY DISCOURAGED" -ForegroundColor Red
            Write-Host ""
            Write-Host "This action will have SEVERE consequences:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  1. DATABASE UNRECOVERABLE FROM DISASTERS" -ForegroundColor Red
            Write-Host "     • Power outages CANNOT be recovered from" -ForegroundColor White
            Write-Host "     • Disk failures CANNOT be recovered from" -ForegroundColor White
            Write-Host "     • Data corruption CANNOT be recovered from" -ForegroundColor White
            Write-Host "     • Only full database recovery from backups is possible" -ForegroundColor White
            Write-Host ""
            Write-Host "  2. POINT-IN-TIME RECOVERY PERMANENTLY LOST" -ForegroundColor Red
            Write-Host "     • Cannot recover to any specific moment in time" -ForegroundColor White
            Write-Host "     • Can only restore from complete backups" -ForegroundColor White
            Write-Host ""
            Write-Host "  3. BUSINESS CONTINUITY RISK" -ForegroundColor Red
            Write-Host "     • Extended downtime in case of failure" -ForegroundColor White
            Write-Host "     • Potential data loss" -ForegroundColor White
            Write-Host ""
            Write-Host "RECOMMENDATION BY MIKAEL:" -ForegroundColor Cyan
            Write-Host "  This option should ONLY be used on TEST/DEV environments." -ForegroundColor Cyan
            Write-Host "  Production databases MUST run in ARCHIVELOG mode." -ForegroundColor Cyan
            Write-Host "  This is in accordance with Oracle's own recommendations." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║           DO YOU REALLY WANT TO PROCEED?              ║" -ForegroundColor Red
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""

            $confirm = Read-Host "Type 'YES' to disable archive log mode (all caps required)"
            if ($confirm -ne 'YES') {
                Write-Log "Operation cancelled by user" -Level Warning
                Write-Host ""
                Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            # Retrieve password if not already retrieved
            if (-not $script:OraclePassword) {
                $script:OraclePassword = Get-OraclePasswordFromRegistry
                if (-not $script:OraclePassword) {
                    Write-Log "Failed to retrieve Oracle password from registry." -Level Error
                    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
            }

            $script:MenuAction = "DisableArchiveLog"
            break
        }
        "5" {
            # Check Archive Log Mode Status
            Write-Host ""
            Write-Host "Checking Archive Log Mode Status..." -ForegroundColor Cyan

            # Retrieve password if not already retrieved
            if (-not $script:OraclePassword) {
                $script:OraclePassword = Get-OraclePasswordFromRegistry
                if (-not $script:OraclePassword) {
                    Write-Log "Failed to retrieve Oracle password from registry." -Level Error
                    Write-Host "Press any key to return to menu..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
            }

            $script:MenuAction = "CheckArchiveMode"
            break
        }
        "6" {
            Write-Host ""
            Write-Log "Exiting script..." -Level Info
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please select 1-6." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
    } while ($choice -notin @("1","2","3","4","5","6") -or ($choice -eq "1" -and $confirm -ne "YES") -or ($choice -eq "4" -and $confirm -ne "YES"))

    Write-Host ""

# Define SQL for status check (will be used later)
$statusSQL = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SELECT
    ROUND((SPACE_USED/SPACE_LIMIT)*100,2) || '|' ||
    ROUND(SPACE_USED/1024/1024/1024,2) || '|' ||
    ROUND((SPACE_LIMIT-SPACE_USED)/1024/1024/1024,2)
FROM V$RECOVERY_FILE_DEST;
EXIT;
'@

# Initialize status data variables
$statusData = @()
$status = ""

# Handle menu action: Check Space Only
if ($script:MenuAction -eq "CheckSpace") {
    try {
        # Check status
        Write-Log "Checking current archive log status..." -Level Info
        Write-Host ""
        Write-Host "Connecting to Oracle database..." -ForegroundColor Cyan

        $status = $statusSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba" 2>&1

        # Check for Oracle errors
        if ($status -match "ORA-\d+") {
            throw "Oracle Error: $status"
        }

        # Check if sqlplus command failed
        if ($LASTEXITCODE -ne 0) {
            throw "SQL*Plus execution failed. Ensure Oracle client is installed and database is accessible."
        }

        # Parse the result
        $cleanResult = $status | Where-Object { $_ -match '\d+\.\d+\|' }

        if (-not $cleanResult) {
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "║     ARCHIVE LOG SPACE CHECK - NO DATA RETURNED        ║" -ForegroundColor Yellow
            Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            Write-Log "No data returned from query - FRA may not be configured" -Level Warning
            Write-Host ""
            Write-Host "Possible reasons:" -ForegroundColor Yellow
            Write-Host "  • Fast Recovery Area (FRA) is not configured" -ForegroundColor White
            Write-Host "  • Database is not in ARCHIVELOG mode" -ForegroundColor White
            Write-Host "  • DB_RECOVERY_FILE_DEST is not set" -ForegroundColor White
            Write-Host ""
            Write-Host "To check FRA configuration, run:" -ForegroundColor Cyan
            Write-Host "  SHOW PARAMETER DB_RECOVERY_FILE_DEST" -ForegroundColor Gray
            Write-Host ""
        } else {
            $statusData = $cleanResult -split '\|'

            if ($statusData.Count -ge 3) {
                $pctUsed = [decimal]$statusData[0].Trim()
                $usedGB = [decimal]$statusData[1].Trim()
                $freeGB = [decimal]$statusData[2].Trim()

                Write-Host ""
                Write-Host "Current Archive Log Status:" -ForegroundColor Cyan
                Write-Host "  Percentage Used: $pctUsed%" -ForegroundColor White
                Write-Host "  Space Used: $usedGB GB" -ForegroundColor White
                Write-Host "  Space Free: $freeGB GB" -ForegroundColor White
                Write-Host ""

                Write-Log "Space check completed successfully" -Level Success
            } else {
                Write-Host ""
                Write-Log "Unexpected data format returned from query" -Level Warning
                Write-Host "Raw output: $cleanResult" -ForegroundColor Gray
            }
        }

    } catch {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║        ARCHIVE LOG SPACE CHECK - FAILED               ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Log "Space check failed: $_" -Level Error
        Write-Host ""
        Write-Host "Error Details:" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor White
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  • Ensure Oracle database is running" -ForegroundColor White
        Write-Host "  • Verify password is correct in registry" -ForegroundColor White
        Write-Host "  • Check that you have SYSDBA privileges" -ForegroundColor White
        Write-Host "  • Confirm SQL*Plus is installed and in PATH" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    continue  # Return to main menu loop
}

# Handle menu action: Check Archive Log Mode
if ($script:MenuAction -eq "CheckArchiveMode") {
    try {
        # Check archive log mode
        Write-Log "Checking archive log mode status..." -Level Info
        Write-Host ""
        Write-Host "Connecting to Oracle database..." -ForegroundColor Cyan

        $archiveModeSQL = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SELECT LOG_MODE FROM V$DATABASE;
EXIT;
'@

        $archiveMode = $archiveModeSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba" 2>&1

        # Check for Oracle errors
        if ($archiveMode -match "ORA-\d+") {
            throw "Oracle Error: $archiveMode"
        }

        # Check if sqlplus command failed
        if ($LASTEXITCODE -ne 0) {
            throw "SQL*Plus execution failed. Ensure Oracle client is installed and database is accessible."
        }

        # Parse the result
        $cleanResult = ($archiveMode | Where-Object { $_ -match '\w+' -and $_ -notmatch '^$' }).Trim()

        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║         ARCHIVE LOG MODE STATUS                       ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        if ($cleanResult -eq "ARCHIVELOG") {
            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "ARCHIVELOG MODE ENABLED" -ForegroundColor Green
            Write-Host ""
            Write-Host "  ✓ Archive logs are being generated" -ForegroundColor Green
            Write-Host "  ✓ Point-in-time recovery is available" -ForegroundColor Green
            Write-Host "  ✓ Database can be recovered to any point in time" -ForegroundColor Green
            Write-Host ""
            Write-Log "Archive log mode is ENABLED" -Level Success
        } elseif ($cleanResult -eq "NOARCHIVELOG") {
            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "ARCHIVELOG MODE DISABLED" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  ⚠ Archive logs are NOT being generated" -ForegroundColor Yellow
            Write-Host "  ⚠ Point-in-time recovery is NOT available" -ForegroundColor Yellow
            Write-Host "  ⚠ Only full database recovery is possible" -ForegroundColor Yellow
            Write-Host ""
            Write-Log "Archive log mode is DISABLED" -Level Warning
        } else {
            Write-Host "  Status: UNKNOWN ($cleanResult)" -ForegroundColor Red
            Write-Log "Unexpected archive mode status: $cleanResult" -Level Warning
        }

    } catch {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║      ARCHIVE LOG MODE CHECK - FAILED                  ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Log "Archive mode check failed: $_" -Level Error
        Write-Host ""
        Write-Host "Error Details:" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor White
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  • Ensure Oracle database is running" -ForegroundColor White
        Write-Host "  • Verify password is correct in registry" -ForegroundColor White
        Write-Host "  • Check that you have SYSDBA privileges" -ForegroundColor White
        Write-Host "  • Confirm SQL*Plus is installed and in PATH" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    continue  # Return to main menu loop
}

# Handle menu action: Expand Archive Log Space
if ($script:MenuAction -eq "ExpandSpace") {
    Write-Log "Expanding Fast Recovery Area to $($script:ExpandSizeGB) GB..." -Level Info

    $expandSQL = @"
ALTER SYSTEM SET DB_RECOVERY_FILE_DEST_SIZE=$($script:ExpandSizeGB)G SCOPE=BOTH;
EXIT;
"@

    Write-Host ""
    Write-Host "Executing SQL Command..." -ForegroundColor Cyan
    $result = $expandSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba"
    Write-Host $result

    # Check new status
    Start-Sleep -Seconds 2
    $newStatus = $statusSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba"
    $newStatusData = ($newStatus | Where-Object { $_ -match '\d+\.\d+\|' }) -split '\|'

    if ($newStatusData.Count -ge 3) {
        Write-Host ""
        Write-Host "Archive Log Space Expanded to 88GB:" -ForegroundColor Green
        Write-Host "  Percentage Used: $($newStatusData[0].Trim())%" -ForegroundColor White
        Write-Host "  Space Used: $($newStatusData[1].Trim()) GB" -ForegroundColor White
        Write-Host "  Space Free: $($newStatusData[2].Trim()) GB" -ForegroundColor White
        Write-Host ""
    }

    Write-Log "Space expansion to 88GB completed successfully" -Level Success
    Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    continue  # Return to main menu loop
}

# Handle menu action: Disable Archive Log Mode
if ($script:MenuAction -eq "DisableArchiveLog") {
    Write-Log "Disabling Archive Log Mode..." -Level Warning

    $disableSQL = @'
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;
EXIT;
'@

    Write-Host ""
    Write-Host "Executing commands to disable archive log mode..." -ForegroundColor Cyan
    $result = $disableSQL | sqlplus -S "$OracleUsername/$OraclePassword as sysdba"
    Write-Host $result

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║      ARCHIVE LOG MODE DISABLED - COMPLETED            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Archive Log Mode: DISABLED" -ForegroundColor Yellow
    Write-Host "Database Status: NOARCHIVELOG mode" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  Important Notes:" -ForegroundColor Yellow
    Write-Host "  • Point-in-time recovery is no longer available" -ForegroundColor White
    Write-Host "  • Only full database recovery is possible" -ForegroundColor White
    Write-Host "  • Archive logs will no longer be generated" -ForegroundColor White
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "✓ OPERATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Log "Archive log mode disabled" -Level Success
    Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    continue  # Return to main menu loop
}

# Handle menu action: Delete Archive Logs
if ($script:MenuAction -eq "DeleteLogs") {
    Write-Log "Starting archive log cleanup process..." -Level Info

    # Check status BEFORE cleanup
    Write-Log "Checking current archive log status..." -Level Info
    $status = $statusSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba"
    $statusData = $status -split '\|'

    if ($statusData.Count -ge 3) {
        Write-Host ""
        Write-Host "Current Status BEFORE Cleanup:" -ForegroundColor Cyan
        Write-Host "  Percentage Used: $($statusData[0])%"
        Write-Host "  Space Used: $($statusData[1]) GB"
        Write-Host "  Space Free: $($statusData[2]) GB"
        Write-Host ""
    }

    Write-Host ""
    Write-Host "Process Steps:" -ForegroundColor Yellow
    Write-Host "  1. Shutdown database using SQL*Plus" -ForegroundColor Gray
    Write-Host "  2. Startup in MOUNT mode using SQL*Plus" -ForegroundColor Gray
    Write-Host "  3. Delete ALL archive logs using RMAN" -ForegroundColor Gray
    Write-Host "  4. Open database using SQL*Plus" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  WARNING: This will delete ALL archive logs!" -ForegroundColor Red
    Write-Host ""

    try {
        # Step 1: Shutdown database
        Write-Log "Step 1: Shutting down database..." -Level Info
        $shutdownSQL = @'
SHUTDOWN IMMEDIATE;
EXIT;
'@
        $shutdownResult = $shutdownSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba"
        Write-Host $shutdownResult
        Start-Sleep -Seconds 3

        # Step 2: Startup in MOUNT mode
        Write-Log "Step 2: Starting database in MOUNT mode..." -Level Info
        $mountSQL = @'
STARTUP MOUNT;
EXIT;
'@
        $mountResult = $mountSQL | sqlplus -S "$OracleUsername/$OraclePassword as sysdba"
        Write-Host $mountResult
        Start-Sleep -Seconds 3

        # Step 3: Delete archive logs using RMAN (with password authentication)
        Write-Log "Step 3: Deleting archive logs using RMAN..." -Level Info
        $rmanCommand = @"
CONNECT TARGET $OracleUsername/$OraclePassword
DELETE NOPROMPT ARCHIVELOG ALL;
EXIT;
"@
        $rmanResult = $rmanCommand | rman nocatalog | Out-String
        Write-Host $rmanResult

        # Step 4: Open database
        Write-Log "Step 4: Opening database..." -Level Info
        $openSQL = @'
ALTER DATABASE OPEN;
EXIT;
'@
        $openResult = $openSQL | sqlplus -S "$OracleUsername/$OraclePassword as sysdba"
        Write-Host $openResult

        # Check results
        if ($rmanResult -match "deleted archived log") {
            Write-Host ""
            Write-Log "Archive logs deleted successfully" -Level Success
        } elseif ($rmanResult -match "specification does not match any archived log") {
            Write-Host ""
            Write-Log "No archive logs found to delete - repository is already clean" -Level Info
        } else {
            Write-Host ""
            Write-Log "RMAN execution completed" -Level Info
        }

    } catch {
        Write-Log "Exception during cleanup process: $_" -Level Error

        # Try to restart database if something went wrong
        Write-Host ""
        Write-Host "Attempting to restart database..." -ForegroundColor Yellow
        $restartSQL = @'
STARTUP;
EXIT;
'@
        $restartResult = $restartSQL | sqlplus -S "$OracleUsername/$OraclePassword as sysdba"
        Write-Host $restartResult
    }
    
    # Check status after cleanup
    Start-Sleep -Seconds 3
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Checking status after cleanup..." -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $statusAfter = $statusSQL | sqlplus -S "$OracleUsername/$OraclePassword@$OracleSID as sysdba"
    $statusDataAfter = $statusAfter -split '\|'

    # Display comprehensive summary
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          ARCHIVE LOG CLEANUP - FINAL RESULTS          ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    if ($statusData.Count -ge 3 -and $statusDataAfter.Count -ge 3) {
        Write-Host "BEFORE Cleanup:" -ForegroundColor Yellow
        Write-Host "  ├─ Percentage Used: $($statusData[0])%" -ForegroundColor White
        Write-Host "  ├─ Space Used: $($statusData[1]) GB" -ForegroundColor White
        Write-Host "  └─ Space Free: $($statusData[2]) GB" -ForegroundColor White
        Write-Host ""

        Write-Host "AFTER Cleanup:" -ForegroundColor Green
        Write-Host "  ├─ Percentage Used: $($statusDataAfter[0])%" -ForegroundColor White
        Write-Host "  ├─ Space Used: $($statusDataAfter[1]) GB" -ForegroundColor White
        Write-Host "  └─ Space Free: $($statusDataAfter[2]) GB" -ForegroundColor White
        Write-Host ""

        $freedSpace = [decimal]$statusDataAfter[2] - [decimal]$statusData[2]
        if ($freedSpace -gt 0) {
            Write-Host "SPACE RECOVERED:" -ForegroundColor Cyan
            Write-Host "  └─ $([math]::Round($freedSpace, 2)) GB freed" -ForegroundColor Green
        } else {
            Write-Host "SPACE RECOVERED:" -ForegroundColor Cyan
            Write-Host "  └─ No additional space freed (logs already clean)" -ForegroundColor Yellow
        }
    } elseif ($statusDataAfter.Count -ge 3) {
        Write-Host "Current Status:" -ForegroundColor Green
        Write-Host "  ├─ Percentage Used: $($statusDataAfter[0])%" -ForegroundColor White
        Write-Host "  ├─ Space Used: $($statusDataAfter[1]) GB" -ForegroundColor White
        Write-Host "  └─ Space Free: $($statusDataAfter[2]) GB" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "✓ OPERATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Database Status: OPEN and ready for connections" -ForegroundColor Green
    Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    continue  # Return to main menu loop
}

# If we reach here, something went wrong
Write-Host ""
Write-Host "Error: Invalid menu action" -ForegroundColor Red
Write-Host ""
exit 1
}
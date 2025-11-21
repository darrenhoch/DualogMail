<#
.SYNOPSIS
    Oracle Archive Log Status Checker with Auto-Cleanup

.DESCRIPTION
    Checks Oracle archive log status and automatically cleans up archive logs
    when usage exceeds the specified threshold.
    Connects as: sys as sysdba
    Automatically sends results via email.
    Default retention: 3 days

.PARAMETER OracleSID
    Oracle System Identifier (default: XE)

.PARAMETER ShowDetails
    Show detailed information including recent logs

.PARAMETER ExportToCsv
    Export status to CSV file

.PARAMETER CleanupThreshold
    Percentage threshold to trigger cleanup (default: 5%)

.PARAMETER RetentionDays
    Number of days to retain archive logs during cleanup (default: 3 days)

.EXAMPLE
    .\QuickCheck-ArchiveLogs.ps1

.EXAMPLE
    .\QuickCheck-ArchiveLogs.ps1 -ShowDetails

.EXAMPLE
    .\QuickCheck-ArchiveLogs.ps1 -CleanupThreshold 10 -RetentionDays 2
#>

[CmdletBinding()]
param(
    [string]$OracleSID = "XE",
    [switch]$ShowDetails,
    [switch]$ExportToCsv,
    [string]$Path = ".\archive_log_status.csv",
    [int]$CleanupThreshold = 5,
    [int]$RetentionDays = 3
)

# Hardcoded credentials
$Username = "sys"
$Password = "oracle"

# Email configuration
$SmtpServer = "127.0.0.1"
$SmtpPort = 25
$EmailFrom = "master.andrea@darren.dualog.net"
$EmailPassword = "12345678"
$EmailTo = "darren.ho@dualog.com"
$EmailSubject = "Archive log Report"

# Build connection string - always connect as sysdba
$connectionString = "$Username/$Password@$OracleSID as sysdba"

Write-Host "Connecting as: sys as sysdba to $OracleSID" -ForegroundColor Cyan

# First, check if FRA is configured
$fraCheckQuery = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 300
SELECT COUNT(*) FROM V$RECOVERY_FILE_DEST;
EXIT;
'@

try {
    Write-Host "Checking database configuration..." -ForegroundColor Cyan
    
    $fraCheck = $fraCheckQuery | sqlplus -S $connectionString 2>&1
    $fraConfigured = $false
    
    if ($fraCheck -match "^\s*1\s*$") {
        $fraConfigured = $true
    }
    
    # Initialize variables for email
    $emailBody = ""
    $statusText = "UNKNOWN"
    $pctUsed = 0
    $limitGB = 0
    $usedGB = 0
    $freeGB = 0
    $location = ""
    $cleanupPerformed = $false
    $cleanupDetails = ""
    
    if ($fraConfigured) {
        Write-Host "Fast Recovery Area detected. Checking FRA status..." -ForegroundColor Green
        
        # FRA Query
        $sqlQuery = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 300
SELECT 
    ROUND((SPACE_USED/SPACE_LIMIT)*100,2) || '|' ||
    ROUND(SPACE_LIMIT/1024/1024/1024,2) || '|' ||
    ROUND(SPACE_USED/1024/1024/1024,2) || '|' ||
    ROUND((SPACE_LIMIT-SPACE_USED)/1024/1024/1024,2) || '|' ||
    NAME
FROM V$RECOVERY_FILE_DEST;
EXIT;
'@
        
        $result = $sqlQuery | sqlplus -S $connectionString 2>&1
        
        if ($result -match "ORA-\d+") {
            throw "FRA Query Error: $result"
        }
        
        $cleanResult = $result | Where-Object { $_ -match '\d+\.\d+\|' }
        
        if ($cleanResult) {
            $data = $cleanResult -split '\|'
            
            $pctUsed = [decimal]$data[0].Trim()
            $limitGB = [decimal]$data[1].Trim()
            $usedGB = [decimal]$data[2].Trim()
            $freeGB = [decimal]$data[3].Trim()
            $location = $data[4].Trim()
            
            # Determine status color
            $statusColor = if ($pctUsed -gt 90) { 'Red' } elseif ($pctUsed -gt 80) { 'Yellow' } else { 'Green' }
            $statusText = if ($pctUsed -gt 90) { 'CRITICAL' } elseif ($pctUsed -gt 80) { 'WARNING' } else { 'OK' }
            
            # Display results
            Write-Host ""
            Write-Host "Oracle Archive Log Status (FRA)" -ForegroundColor Cyan
            Write-Host "================================" -ForegroundColor Cyan
            Write-Host "Status:        " -NoNewline
            Write-Host "$statusText" -ForegroundColor $statusColor
            Write-Host "Oracle SID:    $OracleSID"
            Write-Host "Connected as:  sys as sysdba"
            Write-Host "Used:          $pctUsed% ($usedGB GB / $limitGB GB)"
            Write-Host "Free:          $freeGB GB"
            Write-Host "Location:      $location"
            Write-Host "Checked:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Host ""
            
            # Progress bar
            $barLength = 50
            $filledLength = [math]::Floor($pctUsed / 100 * $barLength)
            $bar = ('#' * $filledLength).PadRight($barLength, '-')
            Write-Host "[$bar] $pctUsed%" -ForegroundColor $statusColor
            Write-Host ""
            
            # Check if cleanup is needed
            if ($pctUsed -gt $CleanupThreshold) {
                Write-Host "⚠ Archive log usage ($pctUsed%) exceeds threshold ($CleanupThreshold%)" -ForegroundColor Yellow
                Write-Host "Initiating automatic cleanup..." -ForegroundColor Cyan
                Write-Host ""
                
                # Count archive logs before cleanup
                $countBeforeQuery = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 100
SELECT COUNT(*) FROM V$ARCHIVED_LOG WHERE DELETED='NO' AND NAME IS NOT NULL;
EXIT;
'@
                
                try {
                    $countBeforeResult = $countBeforeQuery | sqlplus -S $connectionString 2>&1
                    $countBeforeLines = $countBeforeResult -split "`n" | Where-Object { $_.Trim() -ne "" }
                    $countBeforeMatch = $countBeforeLines | Where-Object { $_ -match '^\s*\d+\s*$' }
                    
                    if ($countBeforeMatch) {
                        $countBefore = $countBeforeMatch.Trim()
                        Write-Host "Archive logs before cleanup: $countBefore" -ForegroundColor Gray
                    } else {
                        $countBefore = "Unknown"
                        Write-Host "Could not determine archive log count before cleanup" -ForegroundColor Yellow
                    }
                    
                    # Perform RMAN cleanup - RMAN connection string doesn't include "as sysdba"
                    $rmanConnectionString = "$Username/$Password@$OracleSID"
                    $rmanScript = @"
CONNECT TARGET $rmanConnectionString
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-$RetentionDays';
EXIT;
"@
                    
                    Write-Host "Running RMAN cleanup (retaining last $RetentionDays days)..." -ForegroundColor Cyan
                    
                    $rmanResult = $rmanScript | rman nocatalog 2>&1
                    
                    # Check if RMAN connected successfully
                    if ($rmanResult -match "connected to target database") {
                        Write-Host "✓ RMAN connected successfully" -ForegroundColor Green
                    }
                    
                    # Check if any logs were deleted
                    $logsDeletedByRMAN = 0
                    if ($rmanResult -match "deleted archived log") {
                        $deleteLines = $rmanResult | Select-String "deleted archived log"
                        $logsDeletedByRMAN = $deleteLines.Count
                        Write-Host "✓ RMAN deleted $logsDeletedByRMAN archived log(s)" -ForegroundColor Green
                    } elseif ($rmanResult -match "specification does not match any archived log") {
                        Write-Host "ℹ No archived logs older than $RetentionDays days found" -ForegroundColor Cyan
                        Write-Host "  All logs are within the retention period" -ForegroundColor Cyan
                    }
                    
                    # Display relevant RMAN output
                    Write-Host ""
                    Write-Host "RMAN Summary:" -ForegroundColor Gray
                    $rmanResult | Select-String -Pattern "Crosschecked|deleted archived log|specification does not match" | ForEach-Object {
                        Write-Host "  $_" -ForegroundColor Gray
                    }
                    Write-Host ""
                    
                    # Check for RMAN errors
                    if ($rmanResult -match "RMAN-\d+.*error" -or $rmanResult -match "ORA-\d+") {
                        Write-Host "⚠ RMAN reported errors during cleanup" -ForegroundColor Yellow
                        $rmanResult | Select-String "RMAN-|ORA-" | ForEach-Object {
                            Write-Host "  $_" -ForegroundColor Yellow
                        }
                    }
                    
                    # Wait for cleanup to complete
                    Start-Sleep -Seconds 3
                    
                    # Count archive logs after cleanup
                    $countAfterResult = $countBeforeQuery | sqlplus -S $connectionString 2>&1
                    $countAfterLines = $countAfterResult -split "`n" | Where-Object { $_.Trim() -ne "" }
                    $countAfterMatch = $countAfterLines | Where-Object { $_ -match '^\s*\d+\s*$' }
                    
                    if ($countAfterMatch) {
                        $countAfter = $countAfterMatch.Trim()
                        Write-Host "Archive logs after cleanup: $countAfter" -ForegroundColor Gray
                    } else {
                        $countAfter = "Unknown"
                        Write-Host "Could not determine archive log count after cleanup" -ForegroundColor Yellow
                    }
                    
                    # Calculate logs deleted
                    if ($countBefore -ne "Unknown" -and $countAfter -ne "Unknown") {
                        $logsDeleted = [int]$countBefore - [int]$countAfter
                    } else {
                        $logsDeleted = $logsDeletedByRMAN
                    }
                    
                    # Get new space usage
                    $newResult = $sqlQuery | sqlplus -S $connectionString 2>&1
                    $newCleanResult = $newResult | Where-Object { $_ -match '\d+\.\d+\|' }
                    
                    if ($newCleanResult) {
                        $newData = $newCleanResult -split '\|'
                        $newPctUsed = [decimal]$newData[0].Trim()
                        $newUsedGB = [decimal]$newData[2].Trim()
                        $newFreeGB = [decimal]$newData[3].Trim()
                        
                        $spaceFreed = $usedGB - $newUsedGB
                        
                        Write-Host ""
                        Write-Host "✓ Cleanup completed!" -ForegroundColor Green
                        Write-Host "  Archive logs deleted: $logsDeleted" -ForegroundColor Green
                        Write-Host "  Space freed: $([math]::Round($spaceFreed, 2)) GB" -ForegroundColor Green
                        Write-Host "  Usage before: $pctUsed%" -ForegroundColor Yellow
                        Write-Host "  Usage after:  $newPctUsed%" -ForegroundColor Green
                        Write-Host ""
                        
                        $cleanupPerformed = $true
                        
                        if ($logsDeleted -gt 0) {
                            $cleanupDetails = @"
<div style="background-color: #FFF3CD; padding: 15px; margin: 20px 0; border-left: 5px solid #FFA500; border-radius: 5px;">
    <h3 style="color: #856404; margin-top: 0;">🧹 Automatic Cleanup Performed</h3>
    <table style="border-collapse: collapse; width: 100%;">
        <tr><td style="padding: 5px; font-weight: bold;">Threshold Exceeded:</td><td style="padding: 5px;">$pctUsed% > $CleanupThreshold%</td></tr>
        <tr><td style="padding: 5px; font-weight: bold;">Archive Logs Deleted:</td><td style="padding: 5px;">$logsDeleted logs</td></tr>
        <tr><td style="padding: 5px; font-weight: bold;">Space Freed:</td><td style="padding: 5px;">$([math]::Round($spaceFreed, 2)) GB</td></tr>
        <tr><td style="padding: 5px; font-weight: bold;">Retention Policy:</td><td style="padding: 5px;">Kept last $RetentionDays days</td></tr>
        <tr><td style="padding: 5px; font-weight: bold;">Usage Before:</td><td style="padding: 5px;">$pctUsed%</td></tr>
        <tr><td style="padding: 5px; font-weight: bold;">Usage After:</td><td style="padding: 5px;">$newPctUsed%</td></tr>
    </table>
</div>
"@
                        } else {
                            $cleanupDetails = @"
<div style="background-color: #D1ECF1; padding: 15px; margin: 20px 0; border-left: 5px solid #0C5460; border-radius: 5px;">
    <h3 style="color: #0C5460; margin-top: 0;">ℹ Cleanup Executed - No Old Logs Found</h3>
    <p>Archive log usage exceeded threshold ($pctUsed% > $CleanupThreshold%), but no logs older than $RetentionDays days were found.</p>
    <p><strong>All archive logs are within the retention period.</strong></p>
    <p><em>Suggestion: Consider reducing retention days to 1-2 days if more space is needed.</em></p>
</div>
"@
                        }
                        
                        # Update values for reporting
                        $pctUsed = $newPctUsed
                        $usedGB = $newUsedGB
                        $freeGB = $newFreeGB
                    } else {
                        Write-Host "⚠ Could not retrieve space usage after cleanup" -ForegroundColor Yellow
                        $cleanupPerformed = $true
                        $cleanupDetails = @"
<div style="background-color: #FFF3CD; padding: 15px; margin: 20px 0; border-left: 5px solid #FFA500; border-radius: 5px;">
    <h3 style="color: #856404; margin-top: 0;">🧹 Cleanup Attempted</h3>
    <p>RMAN cleanup was executed but final status could not be verified.</p>
    <p><strong>Archive Logs Deleted:</strong> $logsDeleted logs</p>
    <p><strong>Retention Policy:</strong> Kept last $RetentionDays days</p>
</div>
"@
                    }
                    
                } catch {
                    Write-Host "✗ Cleanup failed: $_" -ForegroundColor Red
                    $cleanupDetails = @"
<div style="background-color: #FFEEEE; padding: 15px; margin: 20px 0; border-left: 5px solid #FF0000; border-radius: 5px;">
    <h3 style="color: #842029; margin-top: 0;">⚠ Cleanup Failed</h3>
    <p><strong>Error:</strong> $_</p>
</div>
"@
                }
                
            } else {
                Write-Host "✓ Archive log usage is within acceptable limits ($pctUsed% <= $CleanupThreshold%)" -ForegroundColor Green
                Write-Host "No cleanup needed." -ForegroundColor Green
                Write-Host ""
            }
        }
        
    } else {
        Write-Host "Fast Recovery Area not configured. Checking archive destinations..." -ForegroundColor Yellow
        
        # Alternative: Check archive destinations
        $archiveDestQuery = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 300
SELECT 
    DESTINATION || '|' || STATUS || '|' || ARCHIVER
FROM V$ARCHIVE_DEST 
WHERE DEST_ID = 1;
EXIT;
'@
        
        $result = $archiveDestQuery | sqlplus -S $connectionString 2>&1
        
        if ($result -match "ORA-\d+") {
            throw "Archive Dest Query Error: $result"
        }
        
        $cleanResult = $result | Where-Object { $_ -match '\|' }
        
        if ($cleanResult) {
            $data = $cleanResult -split '\|'
            $destination = $data[0].Trim()
            $status = $data[1].Trim()
            $archiver = $data[2].Trim()
            
            # Check archivelog mode
            $archiveMode = @'
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SELECT LOG_MODE FROM V$DATABASE;
EXIT;
'@
            
            $modeResult = $archiveMode | sqlplus -S $connectionString 2>&1
            $logMode = ($modeResult | Where-Object { $_ -match 'ARCHIVELOG|NOARCHIVELOG' }).Trim()
            
            $statusColor = if ($status -eq 'VALID' -and $logMode -eq 'ARCHIVELOG') { 'Green' } else { 'Yellow' }
            $statusText = if ($status -eq 'VALID' -and $logMode -eq 'ARCHIVELOG') { 'OK' } else { 'WARNING' }
            
            Write-Host ""
            Write-Host "Oracle Archive Log Status" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "Status:        " -NoNewline
            Write-Host "$statusText" -ForegroundColor $statusColor
            Write-Host "Oracle SID:    $OracleSID"
            Write-Host "Connected as:  sys as sysdba"
            Write-Host "Archive Mode:  $logMode"
            Write-Host "Dest Status:   $status"
            Write-Host "Archiver:      $archiver"
            Write-Host "Destination:   $destination"
            Write-Host "Checked:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Host ""
            
            $pctUsed = 0
            $limitGB = 0
            $usedGB = 0
            $freeGB = 0
            $location = $destination
        }
    }
    
    # Show details if requested
    $detailsHtml = ""
    if ($ShowDetails) {
        Write-Host "Recent Archive Logs (Last 24 Hours)" -ForegroundColor Cyan
        Write-Host "====================================" -ForegroundColor Cyan
        
        $detailSQL = @'
SET PAGESIZE 20
SET FEEDBACK OFF
SET HEADING ON
SET LINESIZE 150
COLUMN SEQUENCE# FORMAT 999999
COLUMN SIZE_MB FORMAT 999,999.99
COLUMN FIRST_TIME FORMAT A20
COLUMN NAME FORMAT A60

SELECT 
    SEQUENCE#,
    BLOCKS*BLOCK_SIZE/1024/1024 AS SIZE_MB,
    TO_CHAR(FIRST_TIME, 'YYYY-MM-DD HH24:MI:SS') AS FIRST_TIME,
    NAME
FROM V$ARCHIVED_LOG
WHERE FIRST_TIME > SYSDATE - 1
  AND NAME IS NOT NULL
ORDER BY FIRST_TIME DESC
FETCH FIRST 10 ROWS ONLY;
EXIT;
'@
        
        $details = $detailSQL | sqlplus -S $connectionString
        Write-Host $details
        Write-Host ""
        
        # Format details for email
        $detailsHtml = "<h3>Recent Archive Logs (Last 24 Hours)</h3><pre>$details</pre>"
    }
    
    # Export to CSV if requested
    if ($ExportToCsv) {
        $csvData = [PSCustomObject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            OracleSID = $OracleSID
            Username = "sys as sysdba"
            Status = $statusText
            PercentUsed = $pctUsed
            LimitGB = $limitGB
            UsedGB = $usedGB
            FreeGB = $freeGB
            Location = $location
            Server = $env:COMPUTERNAME
            FRAConfigured = $fraConfigured
            CleanupPerformed = $cleanupPerformed
            CleanupThreshold = $CleanupThreshold
        }
        
        $csvData | Export-Csv -Path $Path -Append -NoTypeInformation
        Write-Host "Status exported to: $Path" -ForegroundColor Green
    }
    
    # ALWAYS send email
    Write-Host ""
    Write-Host "Preparing to send email report..." -ForegroundColor Cyan
    Write-Host "SMTP Server: $SmtpServer`:$SmtpPort" -ForegroundColor Gray
    Write-Host "From: $EmailFrom" -ForegroundColor Gray
    Write-Host "To: $EmailTo" -ForegroundColor Gray
    
    # Determine status color for HTML
    $statusColorHtml = switch ($statusText) {
        "CRITICAL" { "#FF0000" }
        "WARNING" { "#FFA500" }
        "OK" { "#00FF00" }
        default { "#808080" }
    }
    
    # Build HTML email body
    $emailBody = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078D4; color: white; padding: 15px; border-radius: 5px; }
        .status { font-size: 24px; font-weight: bold; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .info-table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        .info-table td { padding: 10px; border: 1px solid #ddd; }
        .info-table td:first-child { font-weight: bold; background-color: #f5f5f5; width: 200px; }
        .progress-bar { width: 100%; height: 30px; background-color: #f0f0f0; border-radius: 5px; overflow: hidden; }
        .progress-fill { height: 100%; background-color: $statusColorHtml; text-align: center; line-height: 30px; color: white; font-weight: bold; }
        .footer { margin-top: 20px; padding: 10px; background-color: #f5f5f5; border-radius: 5px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Oracle Archive Log Status Report</h1>
    </div>
    
    <div class="status" style="background-color: $statusColorHtml; color: white;">
        Status: $statusText
    </div>
    
    $cleanupDetails
    
    <table class="info-table">
        <tr><td>Oracle SID</td><td>$OracleSID</td></tr>
        <tr><td>Server</td><td>$env:COMPUTERNAME</td></tr>
        <tr><td>Connected As</td><td>sys as sysdba</td></tr>
        <tr><td>Used Space</td><td>$pctUsed% ($usedGB GB / $limitGB GB)</td></tr>
        <tr><td>Free Space</td><td>$freeGB GB</td></tr>
        <tr><td>Location</td><td>$location</td></tr>
        <tr><td>FRA Configured</td><td>$fraConfigured</td></tr>
        <tr><td>Cleanup Threshold</td><td>$CleanupThreshold%</td></tr>
        <tr><td>Retention Policy</td><td>$RetentionDays days</td></tr>
        <tr><td>Checked At</td><td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td></tr>
    </table>
    
    <div class="progress-bar">
        <div class="progress-fill" style="width: $pctUsed%; background-color: $statusColorHtml;">
            $pctUsed%
        </div>
    </div>
    
    $detailsHtml
    
    <div class="footer">
        <p>This is an automated report from the Oracle Archive Log Status Checker with Auto-Cleanup.</p>
        <p>Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
</body>
</html>
"@
    
    # Create credentials for SMTP authentication
    try {
        $securePassword = ConvertTo-SecureString $EmailPassword -AsPlainText -Force
        $emailCredential = New-Object System.Management.Automation.PSCredential($EmailFrom, $securePassword)
        
        Write-Host "Attempting to send email..." -ForegroundColor Cyan
        
        # Send email
        Send-MailMessage -From $EmailFrom `
            -To $EmailTo `
            -Subject $EmailSubject `
            -Body $emailBody `
            -BodyAsHtml `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -Credential $emailCredential `
            -ErrorAction Stop
        
        Write-Host "✓ Email sent successfully to $EmailTo" -ForegroundColor Green
        Write-Host ""
        
    } catch {
        Write-Host "✗ Failed to send email!" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "  1. Check if SMTP server is running on 127.0.0.1:25" -ForegroundColor Yellow
        Write-Host "  2. Verify email credentials are correct" -ForegroundColor Yellow
        Write-Host "  3. Check firewall settings for port 25" -ForegroundColor Yellow
        Write-Host "  4. Ensure SMTP service allows authentication" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Return exit code based on status
    if ($pctUsed -gt 90) { exit 2 }
    elseif ($pctUsed -gt 80) { exit 1 }
    else { exit 0 }
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "  - Oracle SID: $OracleSID" -ForegroundColor Yellow
    Write-Host "  - Connecting as: sys as sysdba" -ForegroundColor Yellow
    Write-Host "  - Password: oracle" -ForegroundColor Yellow
    Write-Host "  - Oracle service is running" -ForegroundColor Yellow
    Write-Host "  - SYSDBA privileges are available" -ForegroundColor Yellow
    
    # Send error email
    Write-Host ""
    Write-Host "Attempting to send error notification email..." -ForegroundColor Cyan
    
    $errorEmailBody = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #FF0000; color: white; padding: 15px; border-radius: 5px; }
        .error { background-color: #FFEEEE; padding: 15px; margin: 20px 0; border-left: 5px solid #FF0000; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Oracle Archive Log Status Report - ERROR</h1>
    </div>
    
    <div class="error">
        <h2>Error Occurred</h2>
        <p><strong>Error Message:</strong> $_</p>
        <p><strong>Oracle SID:</strong> $OracleSID</p>
        <p><strong>Server:</strong> $env:COMPUTERNAME</p>
        <p><strong>Time:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
    
    <p>Please check the Oracle database connection and try again.</p>
</body>
</html>
"@
    
    try {
        $securePassword = ConvertTo-SecureString $EmailPassword -AsPlainText -Force
        $emailCredential = New-Object System.Management.Automation.PSCredential($EmailFrom, $securePassword)
        
        Send-MailMessage -From $EmailFrom `
            -To $EmailTo `
            -Subject "Archive log Report - ERROR" `
            -Body $errorEmailBody `
            -BodyAsHtml `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -Credential $emailCredential `
            -ErrorAction Stop
        
        Write-Host "✓ Error notification email sent to $EmailTo" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to send error notification email: $_" -ForegroundColor Red
    }
    
    exit 1
}
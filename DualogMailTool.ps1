# Dualog Webmail Super Script ver 1.0
# PowerShell Script to Fix Common Webmail Database Issues
# Handles database integrity issues in webmail systems

# Script Configuration
$script:logFolder = "C:\WebmailLogs"
$script:timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:logFile = "$script:logFolder\WebmailFix_$script:timestamp.log"

# Function to write to log file
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $script:logFile -Value $logMessage

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message -ForegroundColor White }
    }
}

# Function to initialize logging
function Initialize-Logging {
    if (!(Test-Path -Path $script:logFolder)) {
        try {
            New-Item -ItemType Directory -Path $script:logFolder -Force | Out-Null
            Write-Host "Created log directory: $script:logFolder" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not create log directory. Continuing without logging." -ForegroundColor Yellow
            return $false
        }
    }
    return $true
}

# Function to check if running as Administrator
function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to elevate to Administrator
function Request-AdminElevation {
    param(
        [string]$OptionNumber = ""
    )

    if (-not (Test-AdminPrivileges)) {
        Write-Host ""
        Write-Host "This operation requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Attempting to restart with elevated privileges..." -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 2

        # Build the command to re-run the script with the option parameter
        $scriptPath = $PSCommandPath
        if ($OptionNumber) {
            # Create a relaunch script that will auto-select the option
            $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {. '$scriptPath' | Out-Null; `$global:autoSelectOption='$OptionNumber'}`""
        } else {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        }

        try {
            Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -Wait
            exit
        } catch {
            Write-Host "Failed to elevate privileges. Please run PowerShell as Administrator manually." -ForegroundColor Red
            $null = Read-Host "Press Enter to return to menu"
            return $false
        }
    }
    return $true
}

# Function to get database password from registry
function Get-DatabasePasswordFromRegistry {
    Write-Host "Retrieving database password from registry..." -ForegroundColor Yellow

    $password = $null

    # Try Wow6432Node path first (32-bit app on 64-bit Windows)
    try {
        $regPath = "HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS"
        if (Test-Path $regPath) {
            $password = (Get-ItemProperty -Path $regPath -Name "DatabasePassword" -ErrorAction SilentlyContinue).DatabasePassword
        }
    } catch {
        # Continue to next attempt
    }

    # If not found, try standard path
    if ([string]::IsNullOrEmpty($password)) {
        try {
            $regPath = "HKLM:\SOFTWARE\Dualog\DGS"
            if (Test-Path $regPath) {
                $password = (Get-ItemProperty -Path $regPath -Name "DatabasePassword" -ErrorAction SilentlyContinue).DatabasePassword
            }
        } catch {
            # Continue
        }
    }

    # Check if password was found
    if ([string]::IsNullOrEmpty($password)) {
        Write-Log "ERROR: Could not retrieve database password from registry!" "ERROR"
        Write-Host ""
        Write-Host "Expected registry locations:" -ForegroundColor Yellow
        Write-Host "  HKLM\SOFTWARE\Wow6432Node\Dualog\DGS\DatabasePassword" -ForegroundColor Gray
        Write-Host "  HKLM\SOFTWARE\Dualog\DGS\DatabasePassword" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Please ensure Dualog DGS is installed and configured." -ForegroundColor Yellow
        return $null
    }

    Write-Log "Database password retrieved from registry" "SUCCESS"
    Write-Host "Database password retrieved from registry" -ForegroundColor Green
    return $password
}

# Function to test database connection (Oracle)
function Test-DatabaseConnection {
    param(
        [string]$Username,
        [string]$Password
    )

    try {
        Write-Log "Testing Oracle database connection..." "INFO"

        # Check if SQL*Plus is available
        $sqlplusCheck = Get-Command sqlplus -ErrorAction SilentlyContinue

        if (-not $sqlplusCheck) {
            Write-Log "ERROR: SQL*Plus not found!" "ERROR"
            Write-Host "ERROR: SQL*Plus not found!" -ForegroundColor Red
            Write-Host "Please ensure Oracle Client is installed and sqlplus is in your PATH." -ForegroundColor Yellow
            return $false
        }

        # Test connection with a simple query
        $testQuery = "SELECT 1 FROM DUAL;"
        $testFile = Join-Path $env:TEMP "test_connection.sql"
        "SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF`n$testQuery`nEXIT;" | Out-File $testFile -Encoding ASCII

        $output = & sqlplus -S "$Username/$Password" "@$testFile" 2>&1 | Out-String

        Remove-Item $testFile -Force -ErrorAction SilentlyContinue

        if ($output -match "ORA-" -or $output -match "ERROR") {
            Write-Log "Database connection failed: $output" "ERROR"
            return $false
        }

        Write-Log "Database connection successful!" "SUCCESS"
        Write-Host "Database connection successful!" -ForegroundColor Green
        return $true

    } catch {
        Write-Log "Database connection failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to test TCP port connectivity
function Test-TcpPort {
    param(
        [string]$IpAddress,
        [int]$Port,
        [string]$ServiceName,
        [int]$TimeoutMs = 5000
    )

    Write-Host "`nTesting $ServiceName connection to ${IpAddress}:${Port}..." -ForegroundColor Cyan
    Write-Log "Testing $ServiceName connection: ${IpAddress}:${Port}" "INFO"

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($IpAddress, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($wait) {
            try {
                $tcpClient.EndConnect($connect)
                $tcpClient.Close()
                Write-Host "  [SUCCESS] Connection to ${IpAddress}:${Port} successful!" -ForegroundColor Green
                Write-Log "$ServiceName connection successful: ${IpAddress}:${Port}" "SUCCESS"
                return [PSCustomObject]@{
                    Service = $ServiceName
                    IpAddress = $IpAddress
                    Port = $Port
                    Status = "SUCCESS"
                    Message = "Connection successful"
                }
            } catch {
                Write-Host "  [FAILED] Connection refused" -ForegroundColor Red
                Write-Log "$ServiceName connection refused: ${IpAddress}:${Port}" "ERROR"
                return [PSCustomObject]@{
                    Service = $ServiceName
                    IpAddress = $IpAddress
                    Port = $Port
                    Status = "FAILED"
                    Message = "Connection refused"
                }
            }
        } else {
            $tcpClient.Close()
            Write-Host "  [TIMEOUT] Connection timed out after ${TimeoutMs}ms" -ForegroundColor Yellow
            Write-Log "$ServiceName connection timeout: ${IpAddress}:${Port}" "WARNING"
            return [PSCustomObject]@{
                Service = $ServiceName
                IpAddress = $IpAddress
                Port = $Port
                Status = "TIMEOUT"
                Message = "Connection timed out after ${TimeoutMs}ms"
            }
        }
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "$ServiceName connection error: $($_.Exception.Message)" "ERROR"
        return [PSCustomObject]@{
            Service = $ServiceName
            IpAddress = $IpAddress
            Port = $Port
            Status = "ERROR"
            Message = $_.Exception.Message
        }
    }
}

# Function to Telnet to Dualog Shore USRUSE Server
function Start-TelnetToShoreServer {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Telnet to Dualog Shore USRUSE Server                " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Telnet to Dualog Shore USRUSE Server" "INFO"

    # Prompt for destination IP address
    Write-Host "`n=== Server Connection Information ===" -ForegroundColor Yellow
    Write-Host ""
    $ipAddress = Read-Host "Enter destination IP address of the IMAP/SMTP server"

    if ([string]::IsNullOrWhiteSpace($ipAddress)) {
        Write-Host "Error: IP address cannot be empty!" -ForegroundColor Red
        Write-Log "Server connectivity test cancelled - no IP address provided" "WARNING"
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    # Validate IP address format (basic validation)
    $ipPattern = "^(\d{1,3}\.){3}\d{1,3}$|^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"
    if ($ipAddress -notmatch $ipPattern) {
        Write-Host "Warning: IP address format may be invalid" -ForegroundColor Yellow
    }

    Write-Log "Target server: $ipAddress" "INFO"

    # Prompt for IMAP port
    Write-Host ""
    $imapPortInput = Read-Host "Enter IMAP port (press Enter for default: 143)"
    if ([string]::IsNullOrWhiteSpace($imapPortInput)) {
        $imapPort = 143
        Write-Host "Using default IMAP port: 143" -ForegroundColor Gray
    } else {
        $imapPort = [int]$imapPortInput
    }

    # Prompt for SMTP port
    Write-Host ""
    $smtpPortInput = Read-Host "Enter SMTP port (press Enter for default: 25)"
    if ([string]::IsNullOrWhiteSpace($smtpPortInput)) {
        $smtpPort = 25
        Write-Host "Using default SMTP port: 25" -ForegroundColor Gray
    } else {
        $smtpPort = [int]$smtpPortInput
    }

    # Display configuration summary
    Write-Host "`n=== Connection Test Configuration ===" -ForegroundColor Cyan
    Write-Host "  Server Address : $ipAddress" -ForegroundColor White
    Write-Host "  IMAP Port      : $imapPort" -ForegroundColor White
    Write-Host "  SMTP Port      : $smtpPort" -ForegroundColor White
    Write-Host ""

    $null = Read-Host "Press Enter to start connectivity tests"

    # Store test results
    $testResults = @()

    # Test IMAP connectivity
    Write-Host "`n=== Testing IMAP Connectivity ===" -ForegroundColor Cyan
    $imapResult = Test-TcpPort -IpAddress $ipAddress -Port $imapPort -ServiceName "IMAP" -TimeoutMs 5000
    $testResults += $imapResult

    # Test SMTP connectivity
    Write-Host "`n=== Testing SMTP Connectivity ===" -ForegroundColor Cyan
    $smtpResult = Test-TcpPort -IpAddress $ipAddress -Port $smtpPort -ServiceName "SMTP" -TimeoutMs 5000
    $testResults += $smtpResult

    # Display summary results
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "              CONNECTIVITY TEST SUMMARY                    " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Server: $ipAddress" -ForegroundColor White
    Write-Host ""

    foreach ($result in $testResults) {
        $statusColor = switch ($result.Status) {
            "SUCCESS" { "Green" }
            "FAILED" { "Red" }
            "TIMEOUT" { "Yellow" }
            default { "Red" }
        }

        Write-Host "  $($result.Service) (Port $($result.Port)):" -ForegroundColor White -NoNewline
        Write-Host " [$($result.Status)]" -ForegroundColor $statusColor
        Write-Host "    $($result.Message)" -ForegroundColor Gray
    }

    # Overall status
    Write-Host ""
    $successCount = ($testResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
    $totalTests = $testResults.Count

    if ($successCount -eq $totalTests) {
        Write-Host "Overall Result: ALL TESTS PASSED ($successCount/$totalTests)" -ForegroundColor Green
        Write-Log "All connectivity tests passed" "SUCCESS"
    } elseif ($successCount -gt 0) {
        Write-Host "Overall Result: PARTIAL SUCCESS ($successCount/$totalTests)" -ForegroundColor Yellow
        Write-Log "Partial connectivity success: $successCount/$totalTests" "WARNING"
    } else {
        Write-Host "Overall Result: ALL TESTS FAILED (0/$totalTests)" -ForegroundColor Red
        Write-Log "All connectivity tests failed" "ERROR"
    }

    Write-Host ""
    Write-Host "Log file saved to: $script:logFile" -ForegroundColor Cyan
    $null = Read-Host "Press Enter to return to main menu"
}

# OPTION 1 OLD: Fix Multiple Body Parts Pointing to Single Mail
function Fix-MultipleBodyPartsIssue {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  Fix Multiple Body Parts Point to Single Mail  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Multiple Body Parts Fix process" "INFO"

    # Show introduction
    Write-Host "`n=== About This Issue ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The error happens because of a single (or several) buggy emails." -ForegroundColor White
    Write-Host ""
    Write-Host "To identify the problematic email(s):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Enable loglevel 7 on IMAP" -ForegroundColor White
    Write-Host "     Guide: https://www.notion.so/dualog/Raising-loglevels-for-Dualog-Service-Ports-d5988276858f4377966086ac62ecb6bd" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Identify which mail has the error in the log lines:" -ForegroundColor White
    Write-Host ""
    Write-Host "     20250520,064827.911 DEBUG: 13776: GetBlobFileName(130223)..." -ForegroundColor DarkGray
    Write-Host "     20250520,064827.912 DEBUG2: 13776: DbExecute done: 0.001 sec." -ForegroundColor DarkGray
    Write-Host "     20250520,064827.912 ERROR: 13776: ImapServer::Run():" -ForegroundColor Red
    Write-Host "                          Exception: Multiple body parts pointing to a single mail." -ForegroundColor Red
    Write-Host ""
    Write-Host "  3. Check if there are multiple body parts defined for this mail" -ForegroundColor White
    Write-Host "     (Use CTRL+F and search for 'body part' in the logs)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "This script will scan the database and fix all instances of this issue." -ForegroundColor Green
    Write-Host ""
    $null = Read-Host "Press Enter to continue"

    # Get database connection details from registry
    Write-Host "`n=== Database Connection ===" -ForegroundColor Yellow
    Write-Host "Connecting to database to scan for multiple body parts issues...`n"

    $username = "g4vessel"
    $password = Get-DatabasePasswordFromRegistry

    if ($null -eq $password) {
        Write-Log "Cannot proceed without database password" "ERROR"
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    # Test connection
    Write-Host ""
    $connectionTest = Test-DatabaseConnection -Username $username -Password $password

    if (-not $connectionTest) {
        Write-Log "Cannot proceed without a valid database connection" "ERROR"
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    # Scan for issues
    Write-Host "`n=== Scanning for Multiple Body Parts Issues ===" -ForegroundColor Cyan
    Write-Log "Scanning database for multiple body parts pointing to single mail..." "INFO"

    try {
        # Create SQL query to find IMAP messages with multiple body parts (Oracle syntax)
        $sqlQuery = @"
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF COLSEP '|'
SET LINESIZE 32767
SELECT
    IMM_IMAPMESSAGEID || '|' ||
    COUNT(*) AS NUMMAIN
FROM DV_IMAPBODYPART
WHERE IMB_PARENTID IS NULL
GROUP BY IMM_IMAPMESSAGEID
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
EXIT;
"@

        $sqlFile = Join-Path $env:TEMP "scan_body_parts.sql"
        $sqlQuery | Out-File $sqlFile -Encoding ASCII

        Write-Host "Executing query..." -ForegroundColor Cyan
        $output = & sqlplus -S "$username/$password" "@$sqlFile" 2>&1

        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue

        # Check for errors
        if ($output -match "ORA-" -or $output -match "ERROR") {
            Write-Log "Query failed: $output" "ERROR"
            throw "Database query failed: $output"
        }

        # Parse results into objects
        $issuesFound = @()
        foreach ($line in $output) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $fields = $line -split '\|'
                if ($fields.Count -ge 2) {
                    $issuesFound += [PSCustomObject]@{
                        ImapMessageID = $fields[0].Trim()
                        BodyPartCount = $fields[1].Trim()
                    }
                }
            }
        }

        if ($issuesFound.Count -eq 0) {
            Write-Log "No issues found! Database is healthy." "SUCCESS"
            Write-Host "`nNo mails with multiple body parts were detected." -ForegroundColor Green
        } else {
            Write-Log "Found $($issuesFound.Count) IMAP messages with multiple parent-less body parts" "WARNING"
            Write-Host "`nFound $($issuesFound.Count) IMAP messages with multiple parent-less body parts:`n" -ForegroundColor Yellow

            # Display first 20 issues
            $displayCount = [Math]::Min(20, $issuesFound.Count)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $row = $issuesFound[$i]
                Write-Host "  IMAP Message ID: $($row.ImapMessageID) | Body Part Count: $($row.BodyPartCount)" -ForegroundColor White
            }

            if ($issuesFound.Count -gt 20) {
                Write-Host "`n  ... and $($issuesFound.Count - 20) more" -ForegroundColor Gray
            }

            # Calculate total body parts that will be deleted
            $totalBodyParts = ($issuesFound | ForEach-Object { [int]$_.BodyPartCount } | Measure-Object -Sum).Sum
            Write-Host "`nTotal affected body parts: $totalBodyParts" -ForegroundColor Yellow

            # Ask user what to do
            Write-Host "`n=== Fix Options ===" -ForegroundColor Cyan
            Write-Host "1. Fix issues by deleting duplicate parent-less body parts"
            Write-Host "2. Export issue report only (no fixes)"
            Write-Host "3. Cancel and return to menu"

            $fixChoice = Read-Host "`nChoose an option [1-3]"

            switch ($fixChoice) {
                "1" {
                    Write-Log "User chose to fix issues by deleting duplicates" "INFO"
                    Fix-DuplicateBodyParts -Username $username -Password $password -Issues $issuesFound
                }
                "2" {
                    Write-Log "User chose to export report only" "INFO"
                    Export-IssueReport -Issues $issuesFound
                }
                "3" {
                    Write-Log "User cancelled operation" "INFO"
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                }
                default {
                    Write-Log "Invalid choice" "WARNING"
                    Write-Host "Invalid choice. Returning to menu." -ForegroundColor Red
                }
            }
        }

    } catch {
        Write-Log "Error during scan: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError Details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception:" -ForegroundColor Red
            Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
        }
    }

    Write-Host "`nLog file saved to: $script:logFile" -ForegroundColor Cyan
    $null = Read-Host "Press Enter to return to main menu"
}

# Function to fix duplicate body parts
function Fix-DuplicateBodyParts {
    param(
        [string]$Username,
        [string]$Password,
        [array]$Issues
    )

    Write-Host "`n=== Fixing Duplicate Body Parts Issues ===" -ForegroundColor Yellow
    Write-Host "WARNING: This will DELETE all parent-less body parts for messages with duplicates!" -ForegroundColor Red
    Write-Host "Total IMAP messages affected: $($Issues.Count)" -ForegroundColor Yellow

    # Calculate total body parts to be deleted
    $totalBodyParts = ($Issues | ForEach-Object { [int]$_.BodyPartCount } | Measure-Object -Sum).Sum
    Write-Host "Total body parts to be deleted: $totalBodyParts`n" -ForegroundColor Yellow

    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-Log "User did not confirm fix operation" "WARNING"
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    Write-Log "Starting fix operation - deleting duplicate parent-less body parts" "INFO"

    try {
        # Execute the DELETE statement as provided
        $sqlQuery = @"
SET PAGESIZE 0 FEEDBACK ON VERIFY OFF HEADING OFF ECHO OFF
DELETE FROM DV_IMAPBODYPART
WHERE IMM_IMAPMESSAGEID IN (
    SELECT IMM_IMAPMESSAGEID
    FROM (
        SELECT IMM_IMAPMESSAGEID, count(*) nummain
        FROM DV_IMAPBODYPART
        WHERE IMB_PARENTID IS NULL
        GROUP BY IMM_IMAPMESSAGEID
    )
    WHERE NUMMAIN > 1
);
COMMIT;
EXIT;
"@

        $sqlFile = Join-Path $env:TEMP "fix_duplicate_body_parts.sql"
        $sqlQuery | Out-File $sqlFile -Encoding ASCII

        Write-Host "`nExecuting fix..." -ForegroundColor Cyan
        $output = & sqlplus -S "$Username/$Password" "@$sqlFile" 2>&1 | Out-String

        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue

        # Check for errors
        if ($output -match "ORA-" -or $output -match "ERROR") {
            Write-Log "Error during fix operation: $output" "ERROR"
            throw "Database error: $output"
        }

        # Parse rows affected from output
        if ($output -match "(\d+) row[s]? deleted") {
            $rowsDeleted = [int]$matches[1]
            Write-Log "Fix completed successfully! Deleted $rowsDeleted duplicate body parts" "SUCCESS"
            Write-Host "`nSuccess! Deleted $rowsDeleted duplicate body parts." -ForegroundColor Green
        } else {
            Write-Log "Fix operation completed but could not determine rows affected" "WARNING"
            Write-Host "`nFix operation completed." -ForegroundColor Green
            Write-Host "Please verify the results manually." -ForegroundColor Yellow
        }

    } catch {
        Write-Log "Error during fix operation: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError occurred during fix operation." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Function to export issue report
function Export-IssueReport {
    param(
        [array]$Issues
    )

    try {
        $reportPath = "$script:logFolder\ImapBodyPartsIssues_$script:timestamp.csv"
        $Issues | Export-Csv -Path $reportPath -NoTypeInformation

        Write-Log "Issue report exported to: $reportPath" "SUCCESS"
        Write-Host "`nReport exported successfully to:" -ForegroundColor Green
        Write-Host $reportPath -ForegroundColor White

        # Also create a summary report
        $summaryPath = "$script:logFolder\ImapBodyPartsIssues_Summary_$script:timestamp.txt"

        # Calculate statistics
        $bodyPartCounts = $Issues | ForEach-Object { [int]$_.BodyPartCount }
        $totalBodyParts = ($bodyPartCounts | Measure-Object -Sum).Sum
        $avgBodyParts = [Math]::Round(($bodyPartCounts | Measure-Object -Average).Average, 2)
        $maxBodyParts = ($bodyPartCounts | Measure-Object -Maximum).Maximum

        $summary = "Webmail IMAP Body Parts Issue Report`n"
        $summary += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
        $summary += "Issue: Multiple parent-less body parts (IMB_PARENTID IS NULL) per IMAP message`n`n"
        $summary += "Summary Statistics:`n"
        $summary += "-------------------`n"
        $summary += "Total affected IMAP messages: $($Issues.Count)`n"
        $summary += "Total duplicate body parts: $totalBodyParts`n"
        $summary += "Average body parts per message: $avgBodyParts`n"
        $summary += "Maximum body parts for one message: $maxBodyParts`n`n"
        $summary += "Detailed data has been exported to: $reportPath`n"

        $summary | Out-File -FilePath $summaryPath
        Write-Log "Summary report created: $summaryPath" "SUCCESS"
        Write-Host "Summary report created: $summaryPath" -ForegroundColor Green

    } catch {
        Write-Log "Error exporting report: $($_.Exception.Message)" "ERROR"
        Write-Host "Error creating report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# OPTION 2: Force-Subscribe for GREYED OUT Folder
function Force-SubscribeGreyedOutFolders {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  Force-Subscribe for GREYED OUT Folder                     " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Force-Subscribe for GREYED OUT Folder process" "INFO"

    # Show introduction
    Write-Host "`n=== About This Issue ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Greyed out folders in IMAP are folders marked as non-selectable." -ForegroundColor White
    Write-Host "This script will allow you to force-subscribe (enable) these folders." -ForegroundColor White
    Write-Host ""
    Write-Host "The script will:" -ForegroundColor Cyan
    Write-Host "  1. Connect to the database" -ForegroundColor White
    Write-Host "  2. Prompt for the user email address" -ForegroundColor White
    Write-Host "  3. Find all greyed out folders for that user" -ForegroundColor White
    Write-Host "  4. Allow you to select which folders to enable" -ForegroundColor White
    Write-Host ""
    $null = Read-Host "Press Enter to continue"

    # Get database connection details from registry
    Write-Host "`n=== Database Connection ===" -ForegroundColor Yellow
    Write-Host "Connecting to database...`n"

    $username = "g4vessel"
    $password = Get-DatabasePasswordFromRegistry

    if ($null -eq $password) {
        Write-Log "Cannot proceed without database password" "ERROR"
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    # Test connection
    Write-Host ""
    $connectionTest = Test-DatabaseConnection -Username $username -Password $password

    if (-not $connectionTest) {
        Write-Log "Cannot proceed without a valid database connection" "ERROR"
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    # Prompt for user email address
    Write-Host "`n=== User Email Address ===" -ForegroundColor Yellow
    Write-Host ""
    $userEmail = Read-Host "Enter the user email address"

    if ([string]::IsNullOrWhiteSpace($userEmail)) {
        Write-Log "No email address provided" "WARNING"
        Write-Host "Email address cannot be empty!" -ForegroundColor Red
        $null = Read-Host "Press Enter to return to main menu"
        return
    }

    Write-Log "Searching for greyed out folders for user: $userEmail" "INFO"

    # Scan for greyed out folders
    Write-Host "`n=== Scanning for Greyed Out Folders ===" -ForegroundColor Cyan
    Write-Log "Scanning database for greyed out folders..." "INFO"

    try {
        # Create SQL query to find greyed out folders
        $sqlQuery = @"
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF COLSEP '|'
SET LINESIZE 32767
SELECT
    imf.IMF_IMAPFOLDERID || '|' ||
    imf.IMF_FOLDERNAME
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
WHERE usr.USR_EMAIL = '$userEmail'
AND imf.IMF_NOSELECT IS NOT NULL
ORDER BY imf.IMF_FOLDERNAME;
EXIT;
"@

        $sqlFile = Join-Path $env:TEMP "scan_greyed_folders.sql"
        $sqlQuery | Out-File $sqlFile -Encoding ASCII

        Write-Host "Executing query..." -ForegroundColor Cyan
        $output = & sqlplus -S "$username/$password" "@$sqlFile" 2>&1

        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue

        # Check for errors
        if ($output -match "ORA-" -or $output -match "ERROR") {
            Write-Log "Query failed: $output" "ERROR"
            throw "Database query failed: $output"
        }

        # Parse results into objects
        $greyedFolders = @()
        foreach ($line in $output) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $fields = $line -split '\|'
                if ($fields.Count -ge 2) {
                    $greyedFolders += [PSCustomObject]@{
                        FolderID = $fields[0].Trim()
                        FolderName = $fields[1].Trim()
                        Selected = $false
                    }
                }
            }
        }

        if ($greyedFolders.Count -eq 0) {
            Write-Log "No greyed out folders found for user: $userEmail" "SUCCESS"
            Write-Host "`nNo greyed out folders found for user: $userEmail" -ForegroundColor Green
        } else {
            Write-Log "Found $($greyedFolders.Count) greyed out folders" "WARNING"
            Write-Host "`nFound $($greyedFolders.Count) greyed out folder(s):`n" -ForegroundColor Yellow

            # Display all greyed out folders with numbering
            for ($i = 0; $i -lt $greyedFolders.Count; $i++) {
                $folder = $greyedFolders[$i]
                Write-Host "  $($i + 1). Folder ID: $($folder.FolderID) | Name: $($folder.FolderName)" -ForegroundColor White
            }

            Write-Host ""
            Write-Host "=== Selection Options ===" -ForegroundColor Cyan
            Write-Host "1. Force-subscribe ALL greyed out folders"
            Write-Host "2. Select individual folders to force-subscribe"
            Write-Host "3. Cancel and return to menu"

            $selectionChoice = Read-Host "`nChoose an option [1-3]"

            switch ($selectionChoice) {
                "1" {
                    Write-Log "User chose to force-subscribe ALL folders" "INFO"
                    Force-SubscribeFolders -Username $username -Password $password -Folders $greyedFolders -Email $userEmail
                }
                "2" {
                    Write-Log "User chose to select individual folders" "INFO"
                    $selectedFolders = Select-FoldersForSubscribe -Folders $greyedFolders
                    if ($selectedFolders.Count -gt 0) {
                        Force-SubscribeFolders -Username $username -Password $password -Folders $selectedFolders -Email $userEmail
                    } else {
                        Write-Log "No folders selected" "WARNING"
                        Write-Host "No folders selected." -ForegroundColor Yellow
                    }
                }
                "3" {
                    Write-Log "User cancelled operation" "INFO"
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                }
                default {
                    Write-Log "Invalid choice" "WARNING"
                    Write-Host "Invalid choice. Returning to menu." -ForegroundColor Red
                }
            }
        }

    } catch {
        Write-Log "Error during scan: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError Details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception:" -ForegroundColor Red
            Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
        }
    }

    Write-Host "`nLog file saved to: $script:logFile" -ForegroundColor Cyan
    $null = Read-Host "Press Enter to return to main menu"
}

# Function to select individual folders for subscription
function Select-FoldersForSubscribe {
    param(
        [array]$Folders
    )

    Write-Host "`n=== Select Folders ===" -ForegroundColor Cyan
    Write-Host "Enter folder numbers separated by commas (e.g., 1,3,5)" -ForegroundColor Yellow
    Write-Host "Or type 'ALL' to select all folders" -ForegroundColor Yellow
    Write-Host ""

    $selection = Read-Host "Enter your selection"

    $selectedFolders = @()

    if ($selection.ToUpper() -eq "ALL") {
        $selectedFolders = $Folders
    } else {
        $selections = $selection -split ',' | ForEach-Object { $_.Trim() }
        foreach ($sel in $selections) {
            if ([int]::TryParse($sel, [ref]$index)) {
                $index = $index - 1
                if ($index -ge 0 -and $index -lt $Folders.Count) {
                    $selectedFolders += $Folders[$index]
                }
            }
        }
    }

    Write-Host "`nSelected $($selectedFolders.Count) folder(s)" -ForegroundColor Green
    foreach ($folder in $selectedFolders) {
        Write-Host "  - $($folder.FolderName)" -ForegroundColor White
    }

    return $selectedFolders
}

# Function to force-subscribe folders
function Force-SubscribeFolders {
    param(
        [string]$Username,
        [string]$Password,
        [array]$Folders,
        [string]$Email
    )

    Write-Host "`n=== Force-Subscribe Folders ===" -ForegroundColor Yellow
    Write-Host "Total folders to enable: $($Folders.Count)" -ForegroundColor Yellow

    foreach ($folder in $Folders) {
        Write-Host "  - $($folder.FolderName)" -ForegroundColor White
    }

    Write-Host ""
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-Log "User did not confirm force-subscribe operation" "WARNING"
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    Write-Log "Starting force-subscribe operation for user: $Email" "INFO"

    $successCount = 0
    $failCount = 0

    foreach ($folder in $Folders) {
        try {
            $folderID = $folder.FolderID
            $folderName = $folder.FolderName

            # Execute the UPDATE statement
            $sqlQuery = @"
SET PAGESIZE 0 FEEDBACK ON VERIFY OFF HEADING OFF ECHO OFF
UPDATE DV_IMAPFOLDER
SET IMF_NOSELECT = NULL
WHERE IMF_IMAPFOLDERID = $folderID;
COMMIT;
EXIT;
"@

            $sqlFile = Join-Path $env:TEMP "subscribe_folder_$folderID.sql"
            $sqlQuery | Out-File $sqlFile -Encoding ASCII

            Write-Host "`nUpdating folder: $folderName..." -ForegroundColor Cyan
            $output = & sqlplus -S "$Username/$Password" "@$sqlFile" 2>&1 | Out-String

            Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue

            # Check for errors
            if ($output -match "ORA-" -or $output -match "ERROR") {
                Write-Log "Error updating folder $folderID ($folderName): $output" "ERROR"
                Write-Host "  [FAILED] $folderName - Error during update" -ForegroundColor Red
                $failCount++
            } else {
                Write-Log "Successfully force-subscribed folder: $folderName ($folderID)" "SUCCESS"
                Write-Host "  [SUCCESS] $folderName - Now enabled" -ForegroundColor Green
                $successCount++
            }

        } catch {
            Write-Log "Error updating folder: $($_.Exception.Message)" "ERROR"
            Write-Host "  [FAILED] $($folder.FolderName) - $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }

    # Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Force-Subscribe Summary:" -ForegroundColor Cyan
    Write-Host "  Successfully enabled: $successCount folder(s)" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "  Failed: $failCount folder(s)" -ForegroundColor Red
    }
    Write-Log "Force-subscribe complete: $successCount successful, $failCount failed" "INFO"
}

# IMAP Repair Menu
function Show-ImapRepairMenu {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              Dualog IMAP Repair Script                    " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Fix Multiple Body Parts Point to Single Mail" -ForegroundColor White
    Write-Host "  2. Force-Subscribe for GREYED OUT Folder" -ForegroundColor White
    Write-Host "  3. [Reserved for future IMAP option]" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  B. Back to Main Menu" -ForegroundColor Yellow
    Write-Host ""
}

# IMAP Repair Script Handler
function Start-ImapRepairScript {
    $loggingEnabled = Test-Path $script:logFile -ErrorAction SilentlyContinue

    do {
        Show-ImapRepairMenu
        $choice = Read-Host "Enter your choice"

        switch ($choice.ToUpper()) {
            "1" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Option 1: Fix Multiple Body Parts" "INFO"
                }
                Fix-MultipleBodyPartsIssue
            }
            "2" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Option 2: Force-Subscribe for GREYED OUT Folder" "INFO"
                }
                Force-SubscribeGreyedOutFolders
            }
            "3" {
                Write-Host "`nThis option is not yet implemented." -ForegroundColor Yellow
                $null = Read-Host "Press Enter to continue"
            }
            "B" {
                Write-Host "`nReturning to Main Menu..." -ForegroundColor Cyan
                break
            }
            default {
                Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice.ToUpper() -ne "B")
}

# Function to Telnet to Dualog local Imap Server
function Start-TelnetToImapServer {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Telnet to Dualog local Imap Server                  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Telnet to Dualog local Imap Server" "INFO"

    Write-Host "`n=== IMAP Server Connection ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will open a telnet connection to the Dualog IMAP Server." -ForegroundColor White
    Write-Host ""

    # Prompt for server details
    $server = Read-Host "Enter IMAP server address (default: localhost)"
    if ([string]::IsNullOrWhiteSpace($server)) {
        $server = "localhost"
    }

    $port = Read-Host "Enter IMAP port (default: 143)"
    if ([string]::IsNullOrWhiteSpace($port)) {
        $port = "143"
    }

    Write-Host "`nConnecting to $server on port $port..." -ForegroundColor Cyan
    Write-Log "Attempting to connect to IMAP server: $server`:$port" "INFO"

    try {
        # Test if telnet command exists by trying to get the command
        $telnetCmd = Get-Command telnet -ErrorAction SilentlyContinue

        if (-not $telnetCmd) {
            Write-Host "`nTelnet client is not available on this system." -ForegroundColor Red
            Write-Host "You can enable it via:" -ForegroundColor Yellow
            Write-Host "  - Control Panel -> Programs -> Turn Windows features on or off" -ForegroundColor Yellow
            Write-Host "  - Or use Option 3 from the main menu to enable it" -ForegroundColor Yellow
            Write-Host ""
            Write-Log "Telnet client not available" "ERROR"
            $null = Read-Host "Press Enter to return to menu"
            return
        }

        # Test IMAP connection by reading server greeting
        Write-Host ""
        Write-Host "Testing IMAP connection..." -ForegroundColor Cyan

        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectAsync = $tcpClient.BeginConnect($server, $port, $null, $null)
        $wait = $connectAsync.AsyncWaitHandle.WaitOne(5000, $false)

        if (-not $wait) {
            $tcpClient.Close()
            Write-Host "`nfailure to connect to Dualog local IMAP Server" -ForegroundColor Red
            Write-Log "failure to connect to Dualog local IMAP Server - Connection timeout" "ERROR"
        } else {
            try {
                $tcpClient.EndConnect($connectAsync)

                # Get server greeting
                $stream = $tcpClient.GetStream()
                $reader = New-Object System.IO.StreamReader($stream)

                # Set read timeout
                $stream.ReadTimeout = 5000

                # Read server greeting
                $serverGreeting = $reader.ReadLine()

                Write-Host ""
                Write-Host "Server Response: $serverGreeting" -ForegroundColor Cyan

                # Check if response contains IMAP OK greeting
                if ($serverGreeting -match "\* OK.*IMAP") {
                    Write-Host ""
                    Write-Host "Telnet to Dualog local IMAP Server is successful" -ForegroundColor Green
                    Write-Log "Telnet to Dualog local IMAP Server is successful - Server: $serverGreeting" "SUCCESS"

                    # Close the test connection
                    $reader.Close()
                    $stream.Close()
                    $tcpClient.Close()
                } else {
                    Write-Host ""
                    Write-Host "failure to connect to Dualog local IMAP Server" -ForegroundColor Red
                    Write-Host "Server did not return valid IMAP greeting" -ForegroundColor Yellow
                    Write-Log "failure to connect to Dualog local IMAP Server - Invalid IMAP greeting: $serverGreeting" "ERROR"

                    # Close connection
                    $reader.Close()
                    $stream.Close()
                    $tcpClient.Close()
                }

            } catch {
                Write-Host "`nfailure to connect to Dualog local IMAP Server" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Log "failure to connect to Dualog local IMAP Server - $($_.Exception.Message)" "ERROR"
                $tcpClient.Close()
            }
        }

    } catch {
        Write-Host "`nfailure to connect to Dualog local IMAP Server" -ForegroundColor Red
        Write-Log "Error starting telnet: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    $null = Read-Host "Press any key to return to main menu"
}

# Function to Change Dualog IMAP Log Level
function Set-ImapLogLevel {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Change Dualog IMAP Log Level                        " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Change IMAP Log Level" "INFO"

    Write-Host "`n=== IMAP Log Level Configuration ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will change the log level for the Dualog IMAP service." -ForegroundColor White
    Write-Host ""
    Write-Host "Available log levels:" -ForegroundColor Cyan
    Write-Host "  0 - No logging" -ForegroundColor Gray
    Write-Host "  1 - Errors only" -ForegroundColor Gray
    Write-Host "  2 - Errors and warnings" -ForegroundColor Gray
    Write-Host "  3 - Errors, warnings, and info" -ForegroundColor Gray
    Write-Host "  4 - Standard logging" -ForegroundColor Gray
    Write-Host "  5 - Verbose logging" -ForegroundColor Gray
    Write-Host "  6 - Debug logging" -ForegroundColor Gray
    Write-Host "  7 - Detailed debug logging (recommended for troubleshooting)" -ForegroundColor Yellow
    Write-Host ""

    $newLevel = Read-Host "Enter new log level (0-7)"

    # Validate input
    if ($newLevel -notmatch '^\d$' -or [int]$newLevel -lt 0 -or [int]$newLevel -gt 7) {
        Write-Host "`nInvalid log level. Please enter a number between 0 and 7." -ForegroundColor Red
        Write-Log "Invalid log level entered: $newLevel" "ERROR"
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    # Connect to IMAP server via telnet
    Write-Host "`nConnecting to IMAP server at 127.0.0.1:4535..." -ForegroundColor Cyan
    Write-Log "Connecting to 127.0.0.1:4535 to set log level" "INFO"

    try {
        # Create TCP client connection
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", 4535)

        if (-not $tcpClient.Connected) {
            throw "Failed to connect to IMAP server"
        }

        Write-Host "Connected successfully!" -ForegroundColor Green

        # Get network stream for reading/writing
        $stream = $tcpClient.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        # Read initial greeting/response
        Start-Sleep -Milliseconds 500
        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Gray
            }
        }

        # Send setloglevel command
        $command = "setloglevel $newLevel"
        Write-Host "`nSending command: $command" -ForegroundColor Cyan
        Write-Log "Sending command: $command" "INFO"
        $writer.WriteLine($command)

        # Wait for response
        Start-Sleep -Milliseconds 500

        # Read and display response
        Write-Host "`n--- Server Response ---" -ForegroundColor Yellow
        $responseReceived = $false

        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Green
                Write-Log "Server response: $line" "INFO"
                $responseReceived = $true
            }
        }

        if (-not $responseReceived) {
            Write-Host "No response received from server" -ForegroundColor Yellow
        }

        Write-Host "--- End Response ---" -ForegroundColor Yellow

        # Wait for user
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"

        # Cleanup
        $writer.Close()
        $reader.Close()
        $stream.Close()
        $tcpClient.Close()

        Write-Log "Connection closed successfully" "INFO"

    } catch {
        Write-Log "Error communicating with IMAP server: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError connecting to IMAP server:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  - The IMAP server is running" -ForegroundColor White
        Write-Host "  - Port 4535 is accessible on 127.0.0.1" -ForegroundColor White
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"
    }
}

# Function to Trigger Dualog IMAP Backup
function Start-ImapBackup {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Trigger Dualog IMAP Backup                          " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting IMAP Backup trigger" "INFO"

    Write-Host "`n=== IMAP Backup ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will trigger a backup of the Dualog IMAP database." -ForegroundColor White
    Write-Host ""
    Write-Host "The script will:" -ForegroundColor Cyan
    Write-Host "  1. Connect to the IMAP server at 127.0.0.1:4535" -ForegroundColor White
    Write-Host "  2. Send the backup command: backup 0" -ForegroundColor White
    Write-Host "  3. Log all activity to C:\WebmailLogs" -ForegroundColor White
    Write-Host ""

    $null = Read-Host "Press Enter to proceed with backup"

    Write-Host "`nConnecting to IMAP server at 127.0.0.1:4535..." -ForegroundColor Cyan
    Write-Log "Connecting to 127.0.0.1:4535 to trigger backup" "INFO"

    try {
        # Create TCP client connection
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", 4535)

        if (-not $tcpClient.Connected) {
            throw "Failed to connect to IMAP server"
        }

        Write-Host "Connected successfully!" -ForegroundColor Green
        Write-Log "Successfully connected to 127.0.0.1:4535" "SUCCESS"

        # Get network stream for reading/writing
        $stream = $tcpClient.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        # Read initial greeting/response
        Start-Sleep -Milliseconds 500
        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Gray
                Write-Log "Server greeting: $line" "INFO"
            }
        }

        # Send backup command
        $command = "backup 0"
        Write-Host "`nSending command: $command" -ForegroundColor Cyan
        Write-Log "Sending command: $command" "INFO"
        $writer.WriteLine($command)

        # Wait for response
        Start-Sleep -Milliseconds 500

        # Read and display response
        Write-Host "`n--- Server Response ---" -ForegroundColor Yellow
        $responseReceived = $false

        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Green
                Write-Log "Server response: $line" "INFO"
                $responseReceived = $true
            }
        }

        if (-not $responseReceived) {
            Write-Host "No response received from server" -ForegroundColor Yellow
            Write-Log "No response received from server" "WARNING"
        }

        Write-Host "--- End Response ---" -ForegroundColor Yellow
        Write-Log "Backup command completed" "SUCCESS"

        # Wait for user
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"

        # Cleanup
        $writer.Close()
        $reader.Close()
        $stream.Close()
        $tcpClient.Close()

        Write-Log "Connection closed successfully" "INFO"

    } catch {
        Write-Log "Error communicating with IMAP server: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError connecting to IMAP server:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  - The IMAP server is running" -ForegroundColor White
        Write-Host "  - Port 4535 is accessible on 127.0.0.1" -ForegroundColor White
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"
    }
}

# Function to Trigger Dualog IMAP Restore
function Start-ImapRestore {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Trigger Dualog IMAP Restore                         " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting IMAP Restore trigger" "INFO"

    Write-Host "`n=== IMAP Restore ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "WARNING: This will restore the IMAP database from a backup!" -ForegroundColor Red
    Write-Host "All current IMAP data will be replaced with the backup data." -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to continue? Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-Log "User cancelled restore operation" "INFO"
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    # Prompt user for backup file location
    Write-Host "`n=== Backup File Location ===" -ForegroundColor Yellow
    Write-Host ""
    $backupFilePath = Read-Host "Enter the full IMAP location path of the Dualog backup file"

    if ([string]::IsNullOrWhiteSpace($backupFilePath)) {
        Write-Log "No backup file path provided" "WARNING"
        Write-Host "Backup file path cannot be empty!" -ForegroundColor Red
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    # Validate that the file exists
    if (-not (Test-Path $backupFilePath)) {
        Write-Log "Backup file not found: $backupFilePath" "ERROR"
        Write-Host "Error: Backup file not found at the specified location!" -ForegroundColor Red
        Write-Host "Path: $backupFilePath" -ForegroundColor Yellow
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    Write-Host "`nSelected backup file: $backupFilePath" -ForegroundColor Green
    Write-Log "User selected backup file: $backupFilePath" "INFO"

    Write-Host "`nConnecting to IMAP server at 127.0.0.1:4535..." -ForegroundColor Cyan
    Write-Log "Connecting to 127.0.0.1:4535 to trigger restore" "INFO"

    try {
        # Create TCP client connection
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", 4535)

        if (-not $tcpClient.Connected) {
            throw "Failed to connect to IMAP server"
        }

        Write-Host "Connected successfully!" -ForegroundColor Green
        Write-Log "Successfully connected to 127.0.0.1:4535" "SUCCESS"

        # Get network stream for reading/writing
        $stream = $tcpClient.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        # Read initial greeting/response
        Start-Sleep -Milliseconds 500
        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Gray
                Write-Log "Server greeting: $line" "INFO"
            }
        }

        # Send import command with backup file location
        $command = "import 0 $backupFilePath"
        Write-Host "`nSending command: $command" -ForegroundColor Cyan
        Write-Log "Sending command: $command" "INFO"
        $writer.WriteLine($command)

        # Wait for response
        Start-Sleep -Milliseconds 500

        # Read and display response
        Write-Host "`n--- Server Response ---" -ForegroundColor Yellow
        $responseReceived = $false

        while ($stream.DataAvailable) {
            $line = $reader.ReadLine()
            if ($line) {
                Write-Host $line -ForegroundColor Green
                Write-Log "Server response: $line" "INFO"
                $responseReceived = $true
            }
        }

        if (-not $responseReceived) {
            Write-Host "No response received from server" -ForegroundColor Yellow
            Write-Log "No response received from server" "WARNING"
        }

        Write-Host "--- End Response ---" -ForegroundColor Yellow
        Write-Log "Restore command completed" "SUCCESS"

        # Wait for user
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"

        # Cleanup
        $writer.Close()
        $reader.Close()
        $stream.Close()
        $tcpClient.Close()

        Write-Log "Connection closed successfully" "INFO"

    } catch {
        Write-Log "Error communicating with IMAP server: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError connecting to IMAP server:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  - The IMAP server is running" -ForegroundColor White
        Write-Host "  - Port 4535 is accessible on 127.0.0.1" -ForegroundColor White
        Write-Host ""
        $null = Read-Host "Press Enter to return to menu"
    }
}

# Function to test Dualog Shore Gateway connectivity
function Start-TelnetToShoreGateway {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Telnet to Dualog Shore Gateway                        " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Telnet to Dualog Shore Gateway" "INFO"

    $targets = @(
        @{ Server = "93.188.232.240"; Port = 4550 },
        @{ Server = "93.188.232.39";  Port = 109  },
        @{ Server = "93.188.232.40";  Port = 110  },
        @{ Server = "93.188.232.38";  Port = 80   },
        @{ Server = "93.188.232.45";  Port = 50100 }
    )

    $maxWaitSeconds = 20
    $jobs = @()

    Write-Host "`n=====================================" -ForegroundColor Cyan
    Write-Host "STARTING CONNECTION TESTS" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Testing connections to the following servers:" -ForegroundColor Yellow
    foreach ($target in $targets) {
        Write-Host "  - $($target.Server):$($target.Port)" -ForegroundColor White
    }
    Write-Host ""
    Write-Log "Testing Dualog Shore Gateway connections" "INFO"

    # Start a job for each host
    foreach ($target in $targets) {
        Write-Host "[→] Initiating test for $($target.Server):$($target.Port)..." -ForegroundColor Cyan
        $jobs += Start-Job -ArgumentList $target, $maxWaitSeconds -ScriptBlock {
            param($target, $maxWaitSeconds)

            $server = $target.Server
            $port = $target.Port
            $status = "FAIL"
            $responseText = ""

            Write-Host "`nTesting ${server}:${port} ..."

            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $async = $client.BeginConnect($server, $port, $null, $null)

                if (-not $async.AsyncWaitHandle.WaitOne($maxWaitSeconds * 1000)) {
                    Write-Host "Connection timeout: ${server}:${port}" -ForegroundColor Red
                    return [PSCustomObject]@{ Server=$server; Port=$port; Result="FAIL - Timeout" }
                }

                $client.EndConnect($async)
                $stream = $client.GetStream()
                $stream.ReadTimeout = 1000

                $buffer = New-Object byte[] 1024
                $responseBuilder = New-Object System.Text.StringBuilder
                $foundUSR = $false

                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                while ($stopwatch.Elapsed.TotalSeconds -lt $maxWaitSeconds) {
                    if ($stream.DataAvailable) {
                        try {
                            $read = $stream.Read($buffer, 0, $buffer.Length)
                            if ($read -le 0) { break }
                            $chunk = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
                            $responseBuilder.Append($chunk) | Out-Null
                            if ($chunk -match "(?i)USR") {
                                $foundUSR = $true
                                break
                            }
                        } catch { break }
                    }
                    Start-Sleep -Milliseconds 200
                }

                $responseText = $responseBuilder.ToString().Trim()

                if ($foundUSR -or ($responseText -match "(?i)USR")) {
                    Write-Host "PASS - Connection to ${server}:${port} successful" -ForegroundColor Green
                    $status = "PASS"
                } else {
                    Write-Host "FAIL - Connection to ${server}:${port} failed" -ForegroundColor Red
                }

                return [PSCustomObject]@{ Server=$server; Port=$port; Result=$status }

            } catch {
                Write-Host "ERROR - ${server}:${port} - $($_.Exception.Message)" -ForegroundColor Yellow
                return [PSCustomObject]@{ Server=$server; Port=$port; Result="FAIL - Error" }
            } finally {
                if ($client -and $client.Connected) { $client.Close() }
            }
        }
    }

    # ==========================================
    # Progress Monitoring Section
    # ==========================================
    Write-Host "`nMonitoring connection tests..." -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    $results = @()
    $completed = 0
    $total = $jobs.Count
    $processedJobOutput = @{}

    while ($jobs.Count -gt 0) {
        $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
        $completed = $total - $runningJobs.Count

        # Update progress bar
        $percentComplete = [math]::Round(($completed / $total) * 100)
        Write-Progress -Activity "Testing TCP Connections" `
                       -Status "$completed of $total completed - $($runningJobs.Count) in progress" `
                       -PercentComplete $percentComplete

        # Check for completed jobs
        $finishedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
        foreach ($job in $finishedJobs) {
            $result = Receive-Job -Job $job
            if ($result) {
                $results += $result
                # Show result immediately
                if ($result.Result -match "PASS") {
                    Write-Host ("[PASS] {0}:{1} - PASS" -f $result.Server, $result.Port) -ForegroundColor Green
                } else {
                    Write-Host ("[FAIL] {0}:{1} - FAIL" -f $result.Server, $result.Port) -ForegroundColor Red
                }
            }
            Remove-Job -Job $job
            $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
        }

        Start-Sleep -Milliseconds 500
    }

    Write-Progress -Activity "Testing TCP Connections" -Completed

    # ==========================================
    # Summary Section
    # ==========================================
    Write-Host "`n=====================================" -ForegroundColor Cyan
    Write-Host "SUMMARY OF CONNECTION TESTS"
    Write-Host "=====================================" -ForegroundColor Cyan

    foreach ($r in $results) {
        if ($r.Result -match "PASS") {
            Write-Host ("{0}:{1} - PASS" -f $r.Server, $r.Port) -ForegroundColor Green
            Write-Log "Gateway connection PASS: $($r.Server):$($r.Port)" "SUCCESS"
        } else {
            Write-Host ("{0}:{1} - FAIL" -f $r.Server, $r.Port) -ForegroundColor Red
            Write-Log "Gateway connection FAIL: $($r.Server):$($r.Port)" "WARNING"
        }
    }

    $total = $results.Count
    $pass = ($results | Where-Object { $_.Result -match "PASS" }).Count
    $fail = $total - $pass

    Write-Host "`nTotal Hosts Tested : $total"
    Write-Host "Passed              : $pass" -ForegroundColor Green
    Write-Host "Failed              : $fail" -ForegroundColor Red
    Write-Host "=====================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Log "Dualog Shore Gateway test completed - $pass passed, $fail failed" "INFO"
    $null = Read-Host "Press Enter to return to menu"
}

# IMAP Server Tool Menu
function Enable-ImapProtocol {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "             Enable IMAP Protocol                            " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Enable IMAP Protocol" "INFO"

    # Check if running as Administrator, if not, request elevation
    if (-not (Test-AdminPrivileges)) {
        Request-AdminElevation -OptionNumber "7"
        return
    }

    Write-Host "`n=== IMAP Protocol Configuration ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will enable the IMAP Protocol logging by:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Registry Location:" -ForegroundColor Cyan
    Write-Host "   Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\DUALOG\ImapServer" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Action:" -ForegroundColor Cyan
    Write-Host "   Create a string called 'LogProtocol' (if it doesn't exist)" -ForegroundColor Gray
    Write-Host "   Set the value to 'true'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Service Restart:" -ForegroundColor Cyan
    Write-Host "   The 'Dualogimap' service will be restarted" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Do you want to continue? (yes/no)"

    if ($confirm.ToLower() -ne "yes") {
        Write-Host "`nOperation cancelled." -ForegroundColor Yellow
        Write-Log "Enable IMAP Protocol operation cancelled by user" "INFO"
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    Write-Host ""
    Write-Host "Proceeding with IMAP Protocol enablement..." -ForegroundColor Cyan
    Write-Log "Proceeding with Enable IMAP Protocol" "INFO"

    try {
        # Define registry path and values
        $regPath = "HKLM:\SOFTWARE\WOW6432Node\DUALOG\ImapServer"
        $regProperty = "LogProtocol"
        $regValue = "true"

        Write-Host ""
        Write-Host "Opening registry location..." -ForegroundColor Cyan
        Write-Log "Accessing registry path: $regPath" "INFO"

        # Check if registry path exists
        if (-not (Test-Path $regPath)) {
            Write-Host "Registry path not found. Creating path: $regPath" -ForegroundColor Yellow
            Write-Log "Creating registry path: $regPath" "INFO"
            New-Item -Path $regPath -Force | Out-Null
        }

        # Check if property exists
        $existingProperty = Get-ItemProperty -Path $regPath -Name $regProperty -ErrorAction SilentlyContinue

        if ($existingProperty) {
            Write-Host "Found existing 'LogProtocol' property. Current value: $($existingProperty.LogProtocol)" -ForegroundColor Gray
            Write-Log "Existing LogProtocol property found with value: $($existingProperty.LogProtocol)" "INFO"
        } else {
            Write-Host "Property 'LogProtocol' does not exist. Creating it..." -ForegroundColor Cyan
            Write-Log "Creating new LogProtocol property" "INFO"
        }

        # Set the registry value
        Set-ItemProperty -Path $regPath -Name $regProperty -Value $regValue -Type String -Force
        Write-Host "Successfully set 'LogProtocol' to 'true'" -ForegroundColor Green
        Write-Log "Successfully set LogProtocol to true" "INFO"

        Write-Host ""
        Write-Host "Restarting Dualogimap service..." -ForegroundColor Cyan
        Write-Log "Attempting to restart Dualogimap service" "INFO"

        # Restart the Dualogimap service
        $service = Get-Service -Name "Dualogimap" -ErrorAction SilentlyContinue

        if ($service) {
            Write-Host "Service found. Current status: $($service.Status)" -ForegroundColor Gray

            # Stop the service
            if ($service.Status -eq "Running") {
                Write-Host "Stopping service..." -ForegroundColor Cyan
                Stop-Service -Name "Dualogimap" -Force
                Write-Log "Dualogimap service stopped" "INFO"

                # Wait for service to stop
                Start-Sleep -Seconds 2
            }

            # Start the service
            Write-Host "Starting service..." -ForegroundColor Cyan
            Start-Service -Name "Dualogimap"
            Write-Log "Dualogimap service started" "INFO"

            # Verify service status
            Start-Sleep -Seconds 2
            $updatedService = Get-Service -Name "Dualogimap"

            if ($updatedService.Status -eq "Running") {
                Write-Host "Service restarted successfully. Current status: $($updatedService.Status)" -ForegroundColor Green
                Write-Log "Dualogimap service restarted successfully" "INFO"
            } else {
                Write-Host "Service status: $($updatedService.Status)" -ForegroundColor Yellow
                Write-Log "Dualogimap service status after restart: $($updatedService.Status)" "WARNING"
            }
        } else {
            Write-Host "Warning: Dualogimap service not found." -ForegroundColor Yellow
            Write-Log "Dualogimap service not found" "WARNING"
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "IMAP Protocol enablement completed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Log "Enable IMAP Protocol operation completed successfully" "INFO"

    } catch {
        Write-Log "Error enabling IMAP Protocol: $($_.Exception.Message)" "ERROR"
        Write-Host ""
        Write-Host "Error occurred during IMAP Protocol enablement:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure you have Administrator privileges." -ForegroundColor Yellow
        Write-Log "Enable IMAP Protocol operation failed" "ERROR"
    }

    $null = Read-Host "Press Enter to return to menu"
}

function Disable-ImapProtocol {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "             Disable IMAP Protocol                           " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Disable IMAP Protocol" "INFO"

    # Check if running as Administrator, if not, request elevation
    if (-not (Test-AdminPrivileges)) {
        Request-AdminElevation -OptionNumber "8"
        return
    }

    Write-Host "`n=== IMAP Protocol Configuration ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will disable the IMAP Protocol logging by:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Registry Location:" -ForegroundColor Cyan
    Write-Host "   Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\DUALOG\ImapServer" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Action:" -ForegroundColor Cyan
    Write-Host "   Set 'LogProtocol' value to 'false'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Service Restart:" -ForegroundColor Cyan
    Write-Host "   The 'Dualogimap' service will be restarted" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Do you want to continue? (yes/no)"

    if ($confirm.ToLower() -ne "yes") {
        Write-Host "`nOperation cancelled." -ForegroundColor Yellow
        Write-Log "Disable IMAP Protocol operation cancelled by user" "INFO"
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    Write-Host ""
    Write-Host "Proceeding with IMAP Protocol disablement..." -ForegroundColor Cyan
    Write-Log "Proceeding with Disable IMAP Protocol" "INFO"

    try {
        # Define registry path and values
        $regPath = "HKLM:\SOFTWARE\WOW6432Node\DUALOG\ImapServer"
        $regProperty = "LogProtocol"
        $regValue = "false"

        Write-Host ""
        Write-Host "Opening registry location..." -ForegroundColor Cyan
        Write-Log "Accessing registry path: $regPath" "INFO"

        # Check if registry path exists
        if (-not (Test-Path $regPath)) {
            Write-Host "Registry path not found. Creating path: $regPath" -ForegroundColor Yellow
            Write-Log "Creating registry path: $regPath" "INFO"
            New-Item -Path $regPath -Force | Out-Null
        }

        # Check if property exists
        $existingProperty = Get-ItemProperty -Path $regPath -Name $regProperty -ErrorAction SilentlyContinue

        if ($existingProperty) {
            Write-Host "Found existing 'LogProtocol' property. Current value: $($existingProperty.LogProtocol)" -ForegroundColor Gray
            Write-Log "Existing LogProtocol property found with value: $($existingProperty.LogProtocol)" "INFO"
        } else {
            Write-Host "Property 'LogProtocol' does not exist. Creating it..." -ForegroundColor Cyan
            Write-Log "Creating new LogProtocol property" "INFO"
        }

        # Set the registry value
        Set-ItemProperty -Path $regPath -Name $regProperty -Value $regValue -Type String -Force
        Write-Host "Successfully set 'LogProtocol' to 'false'" -ForegroundColor Green
        Write-Log "Successfully set LogProtocol to false" "INFO"

        Write-Host ""
        Write-Host "Restarting Dualogimap service..." -ForegroundColor Cyan
        Write-Log "Attempting to restart Dualogimap service" "INFO"

        # Restart the Dualogimap service
        $service = Get-Service -Name "Dualogimap" -ErrorAction SilentlyContinue

        if ($service) {
            Write-Host "Service found. Current status: $($service.Status)" -ForegroundColor Gray

            # Stop the service
            if ($service.Status -eq "Running") {
                Write-Host "Stopping service..." -ForegroundColor Cyan
                Stop-Service -Name "Dualogimap" -Force
                Write-Log "Dualogimap service stopped" "INFO"

                # Wait for service to stop
                Start-Sleep -Seconds 2
            }

            # Start the service
            Write-Host "Starting service..." -ForegroundColor Cyan
            Start-Service -Name "Dualogimap"
            Write-Log "Dualogimap service started" "INFO"

            # Verify service status
            Start-Sleep -Seconds 2
            $updatedService = Get-Service -Name "Dualogimap"

            if ($updatedService.Status -eq "Running") {
                Write-Host "Service restarted successfully. Current status: $($updatedService.Status)" -ForegroundColor Green
                Write-Log "Dualogimap service restarted successfully" "INFO"
            } else {
                Write-Host "Service status: $($updatedService.Status)" -ForegroundColor Yellow
                Write-Log "Dualogimap service status after restart: $($updatedService.Status)" "WARNING"
            }
        } else {
            Write-Host "Warning: Dualogimap service not found." -ForegroundColor Yellow
            Write-Log "Dualogimap service not found" "WARNING"
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "IMAP Protocol disablement completed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Log "Disable IMAP Protocol operation completed successfully" "INFO"

    } catch {
        Write-Log "Error disabling IMAP Protocol: $($_.Exception.Message)" "ERROR"
        Write-Host ""
        Write-Host "Error occurred during IMAP Protocol disablement:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure you have Administrator privileges." -ForegroundColor Yellow
        Write-Log "Disable IMAP Protocol operation failed" "ERROR"
    }

    $null = Read-Host "Press Enter to return to menu"
}

function Show-ImapServerToolMenu {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             Dualog IMAP Server Tool                       " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Telnet to Dualog local IMAP/SMTP Server" -ForegroundColor White
    Write-Host "  2. Telnet to Dualog Shore Gateway" -ForegroundColor White
    Write-Host "  3. Change Dualog IMAP log level" -ForegroundColor White
    Write-Host "  4. Trigger Dualog IMAP Backup" -ForegroundColor White
    Write-Host "  5. Trigger Dualog IMAP Restore" -ForegroundColor White
    Write-Host "  6. Large Files `& Attachments Finder" -ForegroundColor White
    Write-Host "  7. Enable IMAP Protocol" -ForegroundColor White
    Write-Host "  8. Disable IMAP Protocol" -ForegroundColor White
    Write-Host ""
    Write-Host "  B. Back to Main Menu" -ForegroundColor Yellow
    Write-Host ""
}

# IMAP Server Tool Handler
function Start-ImapServerTool {
    $loggingEnabled = Test-Path $script:logFile -ErrorAction SilentlyContinue

    do {
        Show-ImapServerToolMenu
        $choice = Read-Host "Enter your choice"

        switch ($choice.ToUpper()) {
            "1" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 1: Telnet to Dualog local IMAP/SMTP Server" "INFO"
                }
                Start-TelnetToShoreServer
            }
            "2" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 2: Telnet to Dualog Shore Gateway" "INFO"
                }
                Start-TelnetToShoreGateway
            }
            "3" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 3: Change IMAP log level" "INFO"
                }
                Set-ImapLogLevel
            }
            "4" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 4: Trigger IMAP Backup" "INFO"
                }
                Start-ImapBackup
            }
            "5" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 5: Trigger IMAP Restore" "INFO"
                }
                Start-ImapRestore
            }
            "6" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 6: Large Files `& Attachments Finder" "INFO"
                }
                Start-LargeFileFinder
            }
            "7" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 7: Enable IMAP Protocol" "INFO"
                }
                Enable-ImapProtocol
            }
            "8" {
                if ($loggingEnabled) {
                    Write-Log "User selected IMAP Server Tool Option 8: Disable IMAP Protocol" "INFO"
                }
                Disable-ImapProtocol
            }
            "B" {
                Write-Host "`nReturning to Main Menu..." -ForegroundColor Cyan
                break
            }
            default {
                Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice.ToUpper() -ne "B")
}

# Function to search file system for large files
function Search-FileSystem {
    # Prompt user for directory location
    $directory = Read-Host "Enter the directory path to search"

    # Check if directory exists
    if (-Not (Test-Path -Path $directory)) {
        Write-Host "Error: The specified directory does not exist." -ForegroundColor Red
        Write-Log "File system search cancelled - directory not found: $directory" "ERROR"
        Read-Host "Press Enter to continue"
        return
    }

    # Prompt user for file size threshold
    Write-Host ""
    $sizeInput = Read-Host "Enter minimum file size in MB (press Enter for default: 50 MB)"

    $sizeThresholdMB = 0

    if ([string]::IsNullOrWhiteSpace($sizeInput)) {
        $sizeThresholdMB = 50
        Write-Host "Using default size: 50 MB" -ForegroundColor Gray
    } else {
        if (-not [int]::TryParse($sizeInput, [ref]$sizeThresholdMB)) {
            Write-Host "Error: Invalid input. Please enter a valid number." -ForegroundColor Red
            Write-Log "File system search cancelled - invalid size input: $sizeInput" "ERROR"
            Read-Host "Press Enter to continue"
            return
        }
    }

    $sizeThresholdBytes = $sizeThresholdMB * 1024 * 1024

    Write-Host ""
    Write-Host ('Searching for files larger than {0} MB in: {1}' -f $sizeThresholdMB, $directory) -ForegroundColor Cyan
    Write-Host "Please wait...`n" -ForegroundColor Yellow
    Write-Log "Searching for files larger than $sizeThresholdMB MB in: $directory" "INFO"

    # Find files larger than 30 MB
    $largeFiles = Get-ChildItem -Path $directory -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt $sizeThresholdBytes } |
        Select-Object FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime |
        Sort-Object SizeMB -Descending

    # Display results
    if ($largeFiles.Count -eq 0) {
        Write-Host "No files larger than $sizeThresholdMB MB were found." -ForegroundColor Green
        Write-Log "No large files found" "INFO"
    } else {
        Write-Host "Found $($largeFiles.Count) file(s) larger than $sizeThresholdMB MB:`n" -ForegroundColor Green
        $largeFiles | Format-Table -AutoSize
        Write-Log "Found $($largeFiles.Count) file(s) larger than $sizeThresholdMB MB" "INFO"

        # Calculate total size
        $totalSizeMB = ($largeFiles | Measure-Object -Property SizeMB -Sum).Sum
        Write-Host "`nTotal size of large files: $([math]::Round($totalSizeMB, 2)) MB" -ForegroundColor Cyan
    }

    Write-Host ""
    $null = Read-Host "Press Enter to return to menu"
}

# Function to search Outlook for large attachments
function Search-Outlook {
    # Ask user what type of search to perform
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "What would you like to search for?" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Individual attachment size (finds specific large attachments)" -ForegroundColor White
    Write-Host "2. Total message size (email body + all attachments combined)" -ForegroundColor White
    Write-Host ""
    $searchMode = Read-Host "Enter your choice (1 or 2)"

    if ($searchMode -ne "1" -and $searchMode -ne "2") {
        Write-Host "Invalid choice. Defaulting to Total Message Size." -ForegroundColor Yellow
        $searchMode = "2"
    }

    $searchByMessageSize = ($searchMode -eq "2")

    # Prompt user for size threshold
    Write-Host ""
    if ($searchByMessageSize) {
        Write-Host "Searching by TOTAL MESSAGE SIZE (body + attachments)" -ForegroundColor Yellow
        $sizeInput = Read-Host "Enter minimum message size in MB (press Enter for default: 50 MB)"
    } else {
        Write-Host "Searching by INDIVIDUAL ATTACHMENT SIZE" -ForegroundColor Yellow
        $sizeInput = Read-Host "Enter minimum attachment size in MB (press Enter for default: 50 MB)"
    }

    $sizeThresholdMB = 0

    if ([string]::IsNullOrWhiteSpace($sizeInput)) {
        $sizeThresholdMB = 50
        Write-Host "Using default size: 50 MB" -ForegroundColor Gray
    } else {
        if (-not [int]::TryParse($sizeInput, [ref]$sizeThresholdMB)) {
            Write-Host "Error: Invalid input. Please enter a valid number." -ForegroundColor Red
            Write-Log "Outlook search cancelled - invalid size input: $sizeInput" "ERROR"
            Read-Host "Press Enter to continue"
            return
        }
    }

    $sizeThresholdBytes = $sizeThresholdMB * 1024 * 1024

    Write-Host ""
    if ($searchByMessageSize) {
        Write-Host ('Searching Outlook for emails larger than {0} MB (total size)...' -f $sizeThresholdMB) -ForegroundColor Cyan
    } else {
        Write-Host ('Searching Outlook for emails with attachments larger than {0} MB...' -f $sizeThresholdMB) -ForegroundColor Cyan
    }
    Write-Host "Size threshold in bytes: $sizeThresholdBytes" -ForegroundColor Gray
    Write-Host "Please wait (this may take a while)...`n" -ForegroundColor Yellow
    Write-Log ('Starting Outlook search - Mode: {0}, Threshold: {1} MB' -f $(if($searchByMessageSize){"Total Message Size"}else{"Attachment Size"}), $sizeThresholdMB) "INFO"

    try {
        # Create Outlook COM object
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNamespace("MAPI")

        # Use script scope for results array to ensure it's accessible in nested function
        $script:results = @()
        $script:totalEmails = 0
        $script:totalItemsScanned = 0
        $script:largeAttachmentsFound = 0
        $script:totalAttachmentsChecked = 0

        # Function to search folder recursively
        function Search-Folder {
            param($folder, $sizeThreshold, $searchByMsg)

            try {
                Write-Host "`n[Scanning] Folder: $($folder.Name)" -ForegroundColor Cyan

                $items = $folder.Items
                $folderItemCount = $items.Count
                Write-Host "  Total items in folder: $folderItemCount" -ForegroundColor Gray

                $emailsInFolder = 0
                $attachmentsInFolder = 0

                foreach ($item in $items) {
                    $script:totalItemsScanned++

                    try {
                        # Try to access MessageClass property to determine item type
                        $messageClass = $null
                        try {
                            $messageClass = $item.MessageClass
                        } catch {
                            # Item doesn't have MessageClass, skip it
                            continue
                        }

                        # Check if it's an email (IPM.Note) or related message types
                        if ($messageClass -notmatch "^IPM\.Note") {
                            # Not an email - skip (could be appointment, task, etc.)
                            continue
                        }

                        $emailsInFolder++
                        $script:totalEmails++

                        # Get subject safely
                        $subject = "Unknown Subject"
                        try {
                            if ($item.Subject) {
                                $subject = $item.Subject
                            }
                        } catch {}

                        # MODE 1: Search by TOTAL MESSAGE SIZE
                        if ($searchByMsg) {
                            # Get total message size
                            $messageSize = 0
                            try {
                                $messageSize = $item.Size
                            } catch {
                                continue
                            }

                            # Check if message size exceeds threshold
                            if ($messageSize -gt $sizeThreshold) {
                                $script:largeAttachmentsFound++
                                $sizeMB = [math]::Round($messageSize / 1048576, 2)

                                Write-Host "    [FOUND] Large email: $subject ($sizeMB MB total size)" -ForegroundColor Green
                                Write-Host "            Folder: $($folder.FolderPath)" -ForegroundColor Green

                                # Get sender safely
                                $senderName = "Unknown"
                                try {
                                    if ($item.SenderName) {
                                        $senderName = $item.SenderName
                                    }
                                } catch {}

                                # Get received time safely
                                $receivedTime = Get-Date
                                try {
                                    if ($item.ReceivedTime) {
                                        $receivedTime = $item.ReceivedTime
                                    }
                                } catch {}

                                # Get attachment count
                                $attachmentCount = 0
                                try {
                                    $attachmentCount = $item.Attachments.Count
                                } catch {}

                                $script:results += [PSCustomObject]@{
                                    Subject = $subject
                                    From = $senderName
                                    Received = $receivedTime
                                    AttachmentName = "Total Message ($attachmentCount attachment(s))"
                                    SizeMB = $sizeMB
                                    FolderPath = $folder.FolderPath
                                    Item = $item
                                    Attachment = $null
                                }

                                Write-Log "Found large email: $subject ($sizeMB MB) with $attachmentCount attachments" "INFO"
                            }
                        }
                        # MODE 2: Search by INDIVIDUAL ATTACHMENT SIZE
                        else {
                            # Check for attachments
                            $attachmentCount = 0
                            try {
                                $attachmentCount = $item.Attachments.Count
                            } catch {
                                # Can't access attachments on this item
                                continue
                            }

                            if ($attachmentCount -gt 0) {
                                for ($i = 1; $i -le $attachmentCount; $i++) {
                                    try {
                                        $attachment = $item.Attachments.Item($i)
                                        $script:totalAttachmentsChecked++
                                        $attachmentsInFolder++

                                        # Get attachment properties safely
                                        $attachmentName = "Unknown"
                                        $attachmentSize = 0

                                        try {
                                            if ($attachment.FileName) {
                                                $attachmentName = $attachment.FileName
                                            }
                                        } catch {}

                                        try {
                                            $attachmentSize = $attachment.Size
                                        } catch {
                                            continue
                                        }

                                        # Check if size exceeds threshold
                                        if ($attachmentSize -gt $sizeThreshold) {
                                            $script:largeAttachmentsFound++
                                            $sizeMB = [math]::Round($attachmentSize / 1048576, 2)

                                            Write-Host "    [FOUND] Large attachment: $attachmentName ($sizeMB MB)" -ForegroundColor Green
                                            Write-Host "            In email: $subject" -ForegroundColor Green
                                            Write-Host "            Folder: $($folder.FolderPath)" -ForegroundColor Green

                                            # Get sender safely
                                            $senderName = "Unknown"
                                            try {
                                                if ($item.SenderName) {
                                                    $senderName = $item.SenderName
                                                }
                                            } catch {}

                                            # Get received time safely
                                            $receivedTime = Get-Date
                                            try {
                                                if ($item.ReceivedTime) {
                                                    $receivedTime = $item.ReceivedTime
                                                }
                                            } catch {}

                                            $script:results += [PSCustomObject]@{
                                                Subject = $subject
                                                From = $senderName
                                                Received = $receivedTime
                                                AttachmentName = $attachmentName
                                                SizeMB = $sizeMB
                                                FolderPath = $folder.FolderPath
                                                Item = $item
                                                Attachment = $attachment
                                            }

                                            Write-Log "Found large attachment: $attachmentName ($sizeMB MB) in $subject" "INFO"
                                        }
                                    }
                                    catch {
                                        Write-Host "      [WARNING] Error checking attachment: $($_.Exception.Message)" -ForegroundColor DarkYellow
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        # Error processing this item - skip it
                    }
                }

                Write-Host "  [COMPLETE] Scanned $emailsInFolder emails with $attachmentsInFolder attachments" -ForegroundColor DarkGreen

                # Search subfolders recursively
                foreach ($subfolder in $folder.Folders) {
                    Search-Folder -folder $subfolder -sizeThreshold $sizeThreshold -searchByMsg $searchByMsg
                }
            }
            catch {
                Write-Host "  [ERROR] Could not access folder '$($folder.Name)': $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Could not access folder: $($folder.Name) - $($_.Exception.Message)" "ERROR"
            }
        }

        # List all available mailboxes
        Write-Host "`nAvailable Mailboxes:" -ForegroundColor Cyan
        Write-Host "===================="  -ForegroundColor Cyan
        $stores = @($namespace.Stores)

        for ($i = 0; $i -lt $stores.Count; $i++) {
            Write-Host "$($i + 1). $($stores[$i].DisplayName)" -ForegroundColor White
        }
        Write-Host "$($stores.Count + 1). Search All Mailboxes" -ForegroundColor Yellow
        Write-Host ""

        # Get user selection
        $selection = Read-Host "Select a mailbox to search (1-$($stores.Count + 1))"

        try {
            $selectionNum = [int]$selection

            if ($selectionNum -lt 1 -or $selectionNum -gt ($stores.Count + 1)) {
                Write-Host "Invalid selection. Exiting." -ForegroundColor Red
                Write-Log "Invalid mailbox selection" "WARNING"
                return
            }

            # Search selected mailbox or all
            if ($selectionNum -eq ($stores.Count + 1)) {
                # Search all mailboxes
                Write-Host "`n============================================================" -ForegroundColor Cyan
                Write-Host ('  Searching ALL Mailboxes for Attachments > ' + $sizeThresholdMB + ' MB') -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Log "Searching all mailboxes" "INFO"
                foreach ($store in $stores) {
                    Write-Host ('>>> Searching store: ' + $store.DisplayName + ' <<<') -ForegroundColor Magenta
                    $rootFolder = $store.GetRootFolder()
                    Search-Folder -folder $rootFolder -sizeThreshold $sizeThresholdBytes -searchByMsg $searchByMessageSize
                }
            } else {
                # Search selected mailbox only
                $selectedStore = $stores[$selectionNum - 1]
                Write-Host "`n============================================================" -ForegroundColor Cyan
                Write-Host "  Searching Mailbox: $($selectedStore.DisplayName)" -ForegroundColor Cyan
                if ($searchByMessageSize) {
                    Write-Host ('  Looking for Messages > ' + $sizeThresholdMB + ' MB (total size)') -ForegroundColor Cyan
                } else {
                    Write-Host ('  Looking for Attachments > ' + $sizeThresholdMB + ' MB') -ForegroundColor Cyan
                }
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Log "Searching mailbox: $($selectedStore.DisplayName)" "INFO"
                $rootFolder = $selectedStore.GetRootFolder()
                Search-Folder -folder $rootFolder -sizeThreshold $sizeThresholdBytes -searchByMsg $searchByMessageSize
            }
        }
        catch {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            Write-Log "Invalid input for mailbox selection" "ERROR"
            return
        }

        # Display summary statistics
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "SEARCH SUMMARY" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Total items scanned: $script:totalItemsScanned" -ForegroundColor White
        Write-Host "Total emails found: $script:totalEmails" -ForegroundColor White
        Write-Host "Total attachments checked: $script:totalAttachmentsChecked" -ForegroundColor White
        Write-Host "Large attachments found: $script:largeAttachmentsFound" -ForegroundColor Yellow
        Write-Host ""

        # Display detailed results table
        if ($script:results.Count -gt 0) {
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "DETAILED MATCH RESULTS" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""

            # Prepare data for table display
            $tableData = $script:results | Sort-Object SizeMB -Descending | ForEach-Object {
                [PSCustomObject]@{
                    'Subject' = if ($_.Subject.Length -gt 40) { $_.Subject.Substring(0, 37) + "..." } else { $_.Subject }
                    'From' = if ($_.From.Length -gt 25) { $_.From.Substring(0, 22) + "..." } else { $_.From }
                    'Attachment/Message' = if ($_.AttachmentName.Length -gt 30) { $_.AttachmentName.Substring(0, 27) + "..." } else { $_.AttachmentName }
                    'Size (MB)' = $_.SizeMB
                    'Received' = $_.Received.ToString("yyyy-MM-dd HH:mm")
                    'Folder' = if ($_.FolderPath.Length -gt 35) { "..." + $_.FolderPath.Substring($_.FolderPath.Length - 32) } else { $_.FolderPath }
                }
            }

            # Display as formatted table
            $tableData | Format-Table -AutoSize

            Write-Host ""
        }

        # Display results
        Write-Host "`n========================================" -ForegroundColor Cyan
        if ($script:results.Count -eq 0) {
            Write-Host "No emails with attachments larger than $sizeThresholdMB MB were found." -ForegroundColor Yellow
            Write-Log "No large attachments found" "INFO"
        } else {
            Write-Host ('Found {0} attachment(s) larger than {1} MB:' -f $script:results.Count, $sizeThresholdMB) -ForegroundColor Green
            Write-Log ('Found {0} large attachments' -f $script:results.Count) "INFO"

            # Display results with numbering
            $sortedResults = $script:results | Sort-Object SizeMB -Descending
            Write-Host ""
            for ($i = 0; $i -lt $sortedResults.Count; $i++) {
                $result = $sortedResults[$i]
                Write-Host ("{0}. Subject: {1}" -f ($i + 1), $result.Subject) -ForegroundColor White
                Write-Host ("   File: {0} ({1} MB)" -f $result.AttachmentName, $result.SizeMB) -ForegroundColor Gray
                Write-Host ("   From: {0}" -f $result.From) -ForegroundColor Gray
                Write-Host ("   Folder: {0}" -f $result.FolderPath) -ForegroundColor Gray
                Write-Host ""
            }

            # Calculate total size
            $totalSizeMB = ($script:results | Measure-Object -Property SizeMB -Sum).Sum
            Write-Host ('Total size of large attachments: {0} MB' -f [math]::Round($totalSizeMB, 2)) -ForegroundColor Cyan
            Write-Host ('Total emails scanned: {0}' -f $script:totalEmails) -ForegroundColor Cyan
            Write-Host ('Total attachments checked: {0}' -f $script:totalAttachmentsChecked) -ForegroundColor Cyan

            # Ask if user wants to delete messages
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "WARNING: This will permanently delete the entire messages." -ForegroundColor Yellow
            Write-Host "A backup .pst file will be created before deletion." -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Cyan
            $deleteChoice = Read-Host "Do you want to delete these messages and backup as .pst? (Y/N)"

            if ($deleteChoice -eq "Y" -or $deleteChoice -eq "y") {
                # Prompt for backup directory
                $defaultBackupPath = "C:\Dualog\deleteditems"
                Write-Host "`nDefault backup location: $defaultBackupPath" -ForegroundColor Yellow
                $backupPath = Read-Host "Enter backup directory path (press Enter for default)"

                if ([string]::IsNullOrWhiteSpace($backupPath)) {
                    $backupPath = $defaultBackupPath
                }

                # Create backup directory if it doesn't exist
                if (-Not (Test-Path -Path $backupPath)) {
                    try {
                        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
                        Write-Host "Created backup directory: $backupPath" -ForegroundColor Green
                        Write-Log "Created backup directory: $backupPath" "INFO"
                    }
                    catch {
                        Write-Host "Error creating backup directory: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Log "Error creating backup directory: $($_.Exception.Message)" "ERROR"
                        return
                    }
                }

                # Process each message - delete and backup as .pst
                $successCount = 0
                $failCount = 0

                Write-Host "`nProcessing messages..." -ForegroundColor Cyan
                Write-Log "Starting deletion of $($sortedResults.Count) messages and backup as .pst" "INFO"

                # Create a single PST file for all messages
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $pstFileName = "DeletedMessages_${timestamp}.pst"
                $pstFilePath = Join-Path -Path $backupPath -ChildPath $pstFileName

                Write-Host "`n[CREATING PST] Creating backup archive: $pstFileName" -ForegroundColor Cyan
                Write-Log "Creating PST archive: $pstFilePath" "INFO"

                try {
                    # Create PST file using AddStore method
                    $namespace.AddStore($pstFilePath)

                    # Wait for PST to be added
                    Start-Sleep -Milliseconds 1000

                    # Find the newly added PST store by path
                    $pstStore = $null
                    foreach ($store in $namespace.Stores) {
                        if ($store.FilePath -eq $pstFilePath) {
                            $pstStore = $store
                            break
                        }
                    }

                    if ($null -eq $pstStore) {
                        throw "Failed to locate newly created PST store"
                    }

                    # Get the root folder of the new PST
                    $pstRootFolder = $pstStore.GetRootFolder()

                    # Create an "Archived Messages" folder in the PST
                    $archivedFolder = $pstRootFolder.Folders.Add("Archived Messages")

                    Write-Host "[PST CREATED] Archive ready: $($pstStore.DisplayName)" -ForegroundColor Green
                    Write-Host "[PST ATTACHED] Archive is now attached to Outlook" -ForegroundColor Green
                    Write-Host ""

                    # Close any open inspector windows to prevent conflicts
                    Write-Host "[PREPARING] Closing any open message windows..." -ForegroundColor Cyan
                    try {
                        $inspectors = $outlook.Inspectors
                        $inspectorCount = $inspectors.Count
                        if ($inspectorCount -gt 0) {
                            Write-Host "  Found $inspectorCount open window(s), closing..." -ForegroundColor Yellow
                            for ($i = $inspectorCount; $i -ge 1; $i--) {
                                try {
                                    $inspectors.Item($i).Close(0)  # 0 = olDiscard (don't save changes)
                                } catch {
                                    # Ignore errors closing individual inspectors
                                }
                            }
                            Start-Sleep -Milliseconds 500
                            Write-Host "  [OK] Closed open windows" -ForegroundColor Green
                        } else {
                            Write-Host "  [OK] No open windows found" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "  [WARNING] Could not check for open windows: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    Write-Host ""

                    # Array to track failed messages for final report
                    $script:failedMessages = @()

                    # Now move all messages to this single PST with retry logic
                    foreach ($result in $sortedResults) {
                        $item = $result.Item
                        $subject = $result.Subject
                        $maxRetries = 3
                        $retryCount = 0
                        $moveSuccessful = $false

                        Write-Host "  [MOVING] $subject" -ForegroundColor Cyan

                        while ($retryCount -lt $maxRetries -and -not $moveSuccessful) {
                            try {
                                # Refresh the item to get latest version
                                try {
                                    $item = $namespace.GetItemFromID($item.EntryID)
                                } catch {
                                    # If refresh fails, use original item
                                }

                                # Move the message to the archived folder in PST
                                $movedItem = $item.Move($archivedFolder)

                                Write-Host "  [OK] Moved to archive: $subject" -ForegroundColor Green
                                Write-Log "Moved message to PST: $subject" "SUCCESS"
                                $successCount++
                                $moveSuccessful = $true
                            }
                            catch {
                                $retryCount++

                                if ($retryCount -lt $maxRetries) {
                                    Write-Host "  [RETRY] Attempt $retryCount failed, retrying... ($($_.Exception.Message))" -ForegroundColor Yellow
                                    Start-Sleep -Milliseconds (500 * $retryCount)  # Incremental delay: 500ms, 1000ms, 1500ms
                                } else {
                                    Write-Host "  [FAIL] Could not move message after $maxRetries attempts: $subject" -ForegroundColor Red
                                    Write-Host "         Error: $($_.Exception.Message)" -ForegroundColor Red
                                    Write-Log "Failed to move message after $maxRetries attempts: $subject - $($_.Exception.Message)" "ERROR"
                                    $failCount++

                                    # Add to failed messages list for report
                                    $script:failedMessages += [PSCustomObject]@{
                                        Subject = $subject
                                        From = $result.From
                                        SizeMB = $result.SizeMB
                                        Folder = $result.FolderPath
                                        Error = $_.Exception.Message
                                    }
                                }
                            }
                        }
                    }

                    Write-Host ""
                    Write-Host "[COMPLETE] All messages moved to archive PST" -ForegroundColor Green
                    Write-Host "[PST LOCATION] $pstFilePath" -ForegroundColor Yellow
                    Write-Host "[PST STATUS] Archive remains attached to Outlook for easy access" -ForegroundColor Yellow
                    Write-Log "PST archive created and attached: $pstFilePath" "SUCCESS"
                }
                catch {
                    Write-Host "`n[ERROR] Failed to create PST archive: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log "Failed to create PST archive: $($_.Exception.Message)" "ERROR"

                    # Try to clean up partially created PST
                    try {
                        foreach ($store in $namespace.Stores) {
                            if ($store.FilePath -eq $pstFilePath) {
                                $namespace.RemoveStore($store.GetRootFolder())
                                Start-Sleep -Milliseconds 500
                                break
                            }
                        }
                    }
                    catch {
                        # Ignore cleanup errors
                    }
                }

                # Summary
                Write-Host "`n========================================" -ForegroundColor Cyan
                Write-Host "Deletion Summary:" -ForegroundColor Cyan
                Write-Host "  Successfully deleted: $successCount message(s)" -ForegroundColor Green
                if ($failCount -gt 0) {
                    Write-Host "  Failed: $failCount message(s)" -ForegroundColor Red
                }
                Write-Host "  Backup location: $backupPath" -ForegroundColor Yellow
                Write-Log "Deletion complete: $successCount successful, $failCount failed" "INFO"

                # Export failed messages report if there are any
                if ($script:failedMessages.Count -gt 0) {
                    Write-Host "`n========================================" -ForegroundColor Cyan
                    Write-Host "FAILED MESSAGES REPORT" -ForegroundColor Red
                    Write-Host "========================================" -ForegroundColor Cyan
                    Write-Host ""

                    # Display failed messages table
                    $script:failedMessages | Format-Table -AutoSize

                    # Export to CSV file
                    try {
                        $failedReportPath = Join-Path -Path $backupPath -ChildPath "FailedMessages_${timestamp}.csv"
                        $script:failedMessages | Export-Csv -Path $failedReportPath -NoTypeInformation
                        Write-Host "[REPORT EXPORTED] Failed messages saved to:" -ForegroundColor Yellow
                        Write-Host "  $failedReportPath" -ForegroundColor White
                        Write-Log "Failed messages report exported: $failedReportPath" "INFO"
                    } catch {
                        Write-Host "[WARNING] Could not export failed messages report: $($_.Exception.Message)" -ForegroundColor Yellow
                    }

                    Write-Host "`nYou can manually move these messages or investigate the errors." -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "No messages were deleted." -ForegroundColor Yellow
                Write-Log "User chose not to delete messages" "INFO"
            }
        }

        # Cleanup
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    catch {
        Write-Host "`nError accessing Outlook: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Make sure Outlook is installed and you have access to it." -ForegroundColor Yellow
        Write-Log "Error accessing Outlook: $($_.Exception.Message)" "ERROR"
    }

    Write-Host ""
    $null = Read-Host "Press Enter to return to menu"
}

# Main function for Large Files & Attachments Finder
function Start-LargeFileFinder {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  Large Files `& Attachments Finder" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log "Started Large Files `& Attachments Finder" "INFO"

    Write-Host "What would you like to search?" -ForegroundColor Yellow
    Write-Host "1. File System (files > 30 MB)" -ForegroundColor White
    Write-Host "2. Outlook Emails (attachments > 30 MB)" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Enter your choice '1' or '2'"

    switch ($choice) {
        "1" {
            Write-Log "User selected File System search" "INFO"
            Search-FileSystem
        }
        "2" {
            Write-Log "User selected Outlook search" "INFO"
            Search-Outlook
        }
        default {
            Write-Host "Invalid choice. Please run the option again and select 1 or 2." -ForegroundColor Red
            Write-Log "Invalid choice in Large Files Finder" "WARNING"
            Start-Sleep -Seconds 2
        }
    }
}

# Function to Enable Telnet Client
function Enable-TelnetClient {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "       Enable Telnet Client                                " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Log "Starting Enable Telnet Client" "INFO"

    Write-Host "`n=== Windows Telnet Client ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool will enable the Telnet Client feature on Windows." -ForegroundColor White
    Write-Host ""

    # Check for Administrator privileges
    if (-not (Test-AdminPrivileges)) {
        Write-Host "`nThis operation requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Attempting to restart with elevated privileges..." -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 2

        $scriptPath = $PSCommandPath
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        try {
            Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -Wait
            exit
        } catch {
            Write-Host "Failed to elevate privileges. Please run PowerShell as Administrator manually." -ForegroundColor Red
            $null = Read-Host "Press Enter to return to menu"
            return
        }
    }

    # Check current status
    try {
        Write-Host "Checking current Telnet Client status..." -ForegroundColor Cyan
        $telnetStatus = Get-WindowsOptionalFeature -Online -FeatureName TelnetClient -ErrorAction Stop

        if ($telnetStatus.State -eq "Enabled") {
            Write-Host "`nTelnet Client is already enabled!" -ForegroundColor Green
            Write-Log "Telnet Client already enabled" "INFO"
            $null = Read-Host "Press Enter to return to menu"
            return
        } elseif ($telnetStatus.State -eq "Disabled") {
            Write-Host "`nTelnet Client is currently disabled." -ForegroundColor Yellow
        } else {
            Write-Host "`nTelnet Client status: $($telnetStatus.State)" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "`nCould not check Telnet Client status." -ForegroundColor Yellow
        Write-Log "Error checking Telnet status: $($_.Exception.Message)" "WARNING"
    }

    Write-Host ""
    Write-Host "Enabling Telnet Client requires administrator privileges." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Do you want to enable Telnet Client now? (Y/N)"

    if ($confirm.ToUpper() -ne "Y") {
        Write-Log "User cancelled Telnet Client enable" "INFO"
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        $null = Read-Host "Press Enter to return to menu"
        return
    }

    # Enable Telnet Client
    try {
        Write-Host "`nEnabling Telnet Client..." -ForegroundColor Cyan
        Write-Host "This may take a few moments..." -ForegroundColor Yellow
        Write-Host ""

        Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient -NoRestart -ErrorAction Stop | Out-Null

        Write-Log "Telnet Client enabled successfully" "SUCCESS"
        Write-Host "Success! Telnet Client has been enabled." -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use telnet from the command line." -ForegroundColor Green

    } catch {
        Write-Log "Error enabling Telnet Client: $($_.Exception.Message)" "ERROR"
        Write-Host "`nError enabling Telnet Client:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternative method:" -ForegroundColor Yellow
        Write-Host "1. Open Control Panel" -ForegroundColor White
        Write-Host "2. Go to Programs, then Programs and Features" -ForegroundColor White
        Write-Host "3. Click `"Turn Windows features on or off`"" -ForegroundColor White
        Write-Host "4. Check `"Telnet Client`" and click OK" -ForegroundColor White
        Write-Host ""
        Write-Host "Or run this command as Administrator:" -ForegroundColor Yellow
        Write-Host "dism /online /Enable-Feature /FeatureName:TelnetClient" -ForegroundColor Gray
    }

    Write-Host ""
    $null = Read-Host "Press Enter to return to menu"
}

# Main Menu
function Show-MainMenu {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "         Dualog Webmail Super Script v1.0                  " -ForegroundColor Cyan
    Write-Host "         Database Integrity and Maintenance Tool           " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Dualog IMAP Repair script" -ForegroundColor White
    Write-Host "  2. Dualog IMAP Server Tool" -ForegroundColor White
    Write-Host "  3. Enable Telnet Client" -ForegroundColor White
    Write-Host "  4. [Reserved for future option]" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor Yellow
    Write-Host ""
}

# Main Script Execution
function Start-WebmailSuperScript {
    # Initialize logging
    $loggingEnabled = Initialize-Logging

    if ($loggingEnabled) {
        Write-Log "========================================" "INFO"
        Write-Log "Webmail Super Script Started" "INFO"
        Write-Log "========================================" "INFO"
    }

    do {
        Show-MainMenu
        $choice = Read-Host "Enter your choice"

        switch ($choice.ToUpper()) {
            "1" {
                if ($loggingEnabled) {
                    Write-Log "User selected Option 1: Dualog IMAP Repair script" "INFO"
                }
                Start-ImapRepairScript
            }
            "2" {
                if ($loggingEnabled) {
                    Write-Log "User selected Option 2: Dualog IMAP Server Tool" "INFO"
                }
                Start-ImapServerTool
            }
            "3" {
                if ($loggingEnabled) {
                    Write-Log "User selected Option 3: Enable Telnet Client" "INFO"
                }
                Enable-TelnetClient
            }
            "4" {
                Write-Host "`nThis option is not yet implemented." -ForegroundColor Yellow
                $null = Read-Host "Press Enter to continue"
            }
            "Q" {
                Write-Host "`nExiting Webmail Super Script..." -ForegroundColor Cyan
                if ($loggingEnabled) {
                    Write-Log "User exited script" "INFO"
                    Write-Log "========================================" "INFO"
                }
                break
            }
            default {
                Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice.ToUpper() -ne "Q")
}

# Start the script
Start-WebmailSuperScript

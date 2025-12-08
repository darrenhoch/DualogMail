<#
.SYNOPSIS
    Automated installer for Dualog Connection Suite Ship software for AESM vessels.

.DESCRIPTION
    This script installs and configures the Dualog Connection Suite Ship software,
    including port conflict checks, Oracle database configuration, email folder creation,
    and automatic Windows Firewall configuration for Apache HTTP Server.

.NOTES
    Script Version: 1.6
    Script Date: 2024-10-16
    Company: Anglo Eastern Ship Management Ltd
    Converted to PowerShell from batch script
    Added: Automatic firewall configuration for Apache HTTP Server
#>

# ============================================================================
# ADMINISTRATOR PRIVILEGE CHECK AND AUTO-ELEVATION
# ============================================================================

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    param(
        [string]$ScriptPath,
        [string]$WorkingDirectory
    )
    
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                    🔒 ADMINISTRATOR PRIVILEGES REQUIRED 🔒                     ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  This installer needs Administrator privileges to:" -ForegroundColor White
    Write-Host ""
    Write-Host "    ✓ Install Dualog Connection Suite Ship software" -ForegroundColor Cyan
    Write-Host "    ✓ Configure Windows services" -ForegroundColor Cyan
    Write-Host "    ✓ Modify system registry" -ForegroundColor Cyan
    Write-Host "    ✓ Configure Oracle database" -ForegroundColor Cyan
    Write-Host "    ✓ Set up network ports" -ForegroundColor Cyan
    Write-Host "    ✓ Configure Windows Firewall" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The script will now request elevation..." -ForegroundColor Green
    Write-Host ""
    Write-Host "  📌 What will happen next:" -ForegroundColor Cyan
    Write-Host "     1. Windows UAC (User Account Control) prompt will appear" -ForegroundColor White
    Write-Host "     2. Click 'Yes' to grant administrator privileges" -ForegroundColor White
    Write-Host "     3. The installer will restart with elevated privileges" -ForegroundColor White
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to continue and show the UAC prompt..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    Write-Host ""
    Write-Host "Requesting administrator privileges..." -ForegroundColor Cyan
    
    try {
        # Prepare arguments to pass to elevated process
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        
        # Start elevated process
        Start-Process -FilePath "powershell.exe" `
                      -ArgumentList $arguments `
                      -Verb RunAs `
                      -WorkingDirectory $WorkingDirectory
        
        # Exit current non-elevated instance
        Write-Host "Elevation request sent. Current window will close..." -ForegroundColor Green
        Start-Sleep -Seconds 2
        exit
    }
    catch {
        Clear-Host
        Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                          ❌ ELEVATION FAILED ❌                                 ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Administrator privileges could not be obtained." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Possible reasons:" -ForegroundColor Yellow
        Write-Host "    • You clicked 'No' on the UAC prompt" -ForegroundColor White
        Write-Host "    • UAC is disabled on this system" -ForegroundColor White
        Write-Host "    • Your account does not have administrator rights" -ForegroundColor White
        Write-Host "    • Group Policy restrictions prevent elevation" -ForegroundColor White
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Host "  💡 Solutions:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Option 1: Try again and click 'Yes' on the UAC prompt" -ForegroundColor Green
        Write-Host "  Option 2: Right-click this script and select 'Run as administrator'" -ForegroundColor Green
        Write-Host "  Option 3: Contact your IT administrator for assistance" -ForegroundColor Green
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Error details: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $workingDir = Split-Path -Parent $scriptPath
    Request-AdminElevation -ScriptPath $scriptPath -WorkingDirectory $workingDir
}

# If we reach here, we have admin privileges
Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green
Start-Sleep -Milliseconds 500

# Set error action preference to continue so script doesn't exit on errors
$ErrorActionPreference = "Continue"

# Display startup information
Write-Host ""
Write-Host "Initializing installer..." -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Script Path: $($MyInvocation.MyCommand.Path)" -ForegroundColor Gray

# Wrap entire script in try-catch to prevent disappearing

# ============================================================================
# CLEANUP / UNINSTALL FUNCTION - DEFINED IN MAIN SCOPE
# ============================================================================

# ============================================================================
# ENVIRONMENT PATH CLEANUP FUNCTION
# ============================================================================

function Remove-EnvironmentPath {
    param(
        [string[]]$PathsToRemove,
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'Machine'
    )
    
    $target = if ($Scope -eq 'Machine') { 
        [EnvironmentVariableTarget]::Machine 
    } else { 
        [EnvironmentVariableTarget]::User 
    }
    
    # Get current PATH
    $currentPath = [Environment]::GetEnvironmentVariable('Path', $target)
    Write-Host ""
    Write-Host "📋 Current PATH environment variable:" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host $currentPath -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    
    $pathArray = $currentPath -split ';'
    $removedCount = 0
    $newPathArray = @()
    
    Write-Host "🔍 Processing PATH entries:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($path in $pathArray) {
        $pathToCheck = $path.Trim()
        
        if ([string]::IsNullOrEmpty($pathToCheck)) {
            continue
        }
        
        $isRemoved = $false
        foreach ($removePattern in $PathsToRemove) {
            if ($pathToCheck -eq $removePattern -or $pathToCheck -like $removePattern) {
                Write-Host "  ❌ REMOVED: $pathToCheck" -ForegroundColor Red
                $isRemoved = $true
                $removedCount++
                if ($PSBoundParameters.ContainsKey('Log')) {
                    Write-Log "Removed PATH entry: $pathToCheck"
                }
                break
            }
        }
        
        if (-not $isRemoved) {
            $newPathArray += $pathToCheck
            Write-Host "  ✓ KEPT: $pathToCheck" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "📊 Summary: $removedCount PATH entry(ies) removed" -ForegroundColor Cyan
    Write-Host ""
    
    if ($removedCount -gt 0) {
        try {
            $newPath = $newPathArray -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, $target)
            
            # Refresh current process environment
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            
            Write-Host "✅ Updated PATH environment variable in registry" -ForegroundColor Green
            Write-Host ""
            Write-Host "📋 New PATH environment variable:" -ForegroundColor Cyan
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Gray
            Write-Host $newPath -ForegroundColor White
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Gray
            Write-Host ""
            Write-Host "📌 Note: The current PowerShell session displays updated paths above." -ForegroundColor Yellow
            Write-Host "   New processes started after this point will use the updated PATH." -ForegroundColor Yellow
            Write-Host ""
            
            return $true
        }
        catch {
            Write-Host "❌ Error updating PATH: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "ℹ️  No matching PATH entries found to remove" -ForegroundColor Yellow
        Write-Host ""
        return $true
    }
}



function Invoke-DualogCleanup {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    🧹 STARTING CLEANUP / UNINSTALL 🧹                         " -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Starting Dualog and Oracle cleanup and removal process"
    
    # PRE-CLEANUP: RESTART CONFIRMATION
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                    ⚠️  IMPORTANT - RESTART REQUIRED ⚠️                         ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Before proceeding with cleanup, it is HIGHLY RECOMMENDED to restart the" -ForegroundColor White
    Write-Host "  computer first. This ensures all Dualog processes and services are" -ForegroundColor White
    Write-Host "  fully terminated and file locks are released." -ForegroundColor White
    Write-Host ""
    Write-Host "  Benefits of restarting before cleanup:" -ForegroundColor Cyan
    Write-Host "    ✓ Guarantees all services are stopped" -ForegroundColor White
    Write-Host "    ✓ Releases all file locks on Dualog folders" -ForegroundColor White
    Write-Host "    ✓ Prevents 'folder locked' errors during cleanup" -ForegroundColor White
    Write-Host "    ✓ Ensures complete and clean removal" -ForegroundColor White
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    $RestartConfirmed = $false
    $ValidRestartResponse = $false
    
    while (-not $ValidRestartResponse) {
        Write-Host "Has the computer been restarted at least once since installing Dualog?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [Y] Yes  - Computer has been restarted, proceed with cleanup" -ForegroundColor Green
        Write-Host "  [N] No   - Restart the computer now, then run cleanup again" -ForegroundColor Yellow
        Write-Host ""
        $RestartConfirmation = Read-Host "Enter your choice (Y/N)"
        
        if ($RestartConfirmation -eq 'Y' -or $RestartConfirmation -eq 'y') {
            Write-Host ""
            Write-Host "✅ Confirmed: Computer has been restarted" -ForegroundColor Green
            Write-Log "User confirmed computer has been restarted. Proceeding with cleanup."
            $ValidRestartResponse = $true
            $RestartConfirmed = $true
        }
        elseif ($RestartConfirmation -eq 'N' -or $RestartConfirmation -eq 'n') {
            Write-Host ""
            Write-Host "⚠️  Please restart the computer now and then run this script again." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  To restart your computer:" -ForegroundColor White
            Write-Host "    • Press Ctrl+Alt+Del → Select Restart" -ForegroundColor White
            Write-Host "    • Or go to Start Menu → Power → Restart" -ForegroundColor White
            Write-Host "    • Or run: shutdown -r -t 30" -ForegroundColor White
            Write-Host ""
            Write-Host "  After restart, run this script again and select Cleanup." -ForegroundColor White
            Write-Host ""
            Write-Log "User chose not to restart. Exiting cleanup."
            Write-Host "Press any key to return to main menu..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        else {
            Write-Host ""
            Write-Host "Invalid input. Please enter Y (Yes) or N (No)." -ForegroundColor Red
            Write-Host ""
        }
    }
    
    # STEP 1: STOP AND REMOVE DUALOG SERVICES
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                   STEP 1: Removing Dualog Services                            ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $dualogServices = @(
        "DualogServiceManager", "DualogFileTransfer", "DualogLiveLinkClient", "DualogUpgradeServer",
        "DualogPortMapper", "DualogConfigBeacon", "DualogConnectionSuiteWebServer", "DualogLDAP",
        "DualogIMAP", "DualogApache", "DuaCorePro", "DualogAntivirusServer", "DualogDHCPServer",
        "DualogWeb4Sea", "DualogWebService", "DualogScheduler", "DualogCSApi", "DualogConnectionSuiteShipAPI",
        "DualogAccessClient", "DualogAccessWorker", "DualogConnectionSuiteApi", "DualogConnectionSuiteWorker",
        "DualogConnectionSuiteSmtp", "DualogTransmissionClient", "DualogCelestialClient"
    )
    
    Write-Host "Stopping and removing Dualog services..." -ForegroundColor Cyan
    foreach ($service in $dualogServices) {
        Stop-Service -Name $service -ErrorAction SilentlyContinue -Force
        & sc.exe delete $service 2>$null
    }
    
    # Kill all Dualog-related processes
    Write-Host "Terminating Dualog processes..." -ForegroundColor Cyan
    $dualogProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*dualog*" -or $_.Name -like "*oracle*" }
    
    if ($dualogProcesses) {
        foreach ($proc in $dualogProcesses) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                Write-Host "  ✓ Terminated process: $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Green
            }
            catch {
                Write-Host "  ⚠️  Could not terminate: $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Yellow
            }
        }
    }
    
    # Additional cleanup: kill any remaining handles using taskkill as fallback
    Write-Host "Running additional process cleanup..." -ForegroundColor Cyan
    & taskkill.exe /F /IM dualog*.exe 2>$null | Out-Null
    & taskkill.exe /F /IM oracle*.exe 2>$null | Out-Null
    & taskkill.exe /F /IM httpd.exe 2>$null | Out-Null
    
    Write-Host "OK - Dualog services and processes removed" -ForegroundColor Green
    Write-Host ""
    
    # STEP 2: REMOVE DUALOG FILES
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                  STEP 2: Removing Dualog Files and Folders                    ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $pathsToRemove = @(
        "C:\Dualog\ConnectionSuite",
        "C:\Dualog\OracleXE",
        "C:\Program Files\Dualog",
        "C:\Dualog\Mail Store"
    )
    
    Write-Host "Removing Dualog files and directories..." -ForegroundColor Cyan
    foreach ($path in $pathsToRemove) {
        if (Test-Path $path) {
            try {
                Write-Host "  Attempting to remove: $path" -ForegroundColor White
                Remove-Item -Path $path -Recurse -Force -Confirm:$false -ErrorAction Stop
                Write-Host "  ✓ Removed: $path" -ForegroundColor Green
            }
            catch {
                Write-Host "  ❌ ERROR - Folder locked or inaccessible: $path" -ForegroundColor Red
                Write-Host "     Reason: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host ""
                Write-Log "FAILED to remove $path - $($_.Exception.Message)" -Level Error
                
                # Try to identify which processes are locking the folder
                Write-Host "     Attempting to identify locked processes..." -ForegroundColor Cyan
                
                try {
                    $lockedProcesses = @()
                    $allProcesses = Get-Process -ErrorAction SilentlyContinue
                    
                    foreach ($process in $allProcesses) {
                        try {
                            # Use try-catch for accessing modules (compatible with older PowerShell)
                            $modules = @()
                            $modules = $process.Modules
                            
                            foreach ($module in $modules) {
                                if ($module.FileName -like "$path*") {
                                    $lockedProcesses += $process
                                    break
                                }
                            }
                        }
                        catch {
                            # Skip if we can't access process modules
                        }
                    }
                    
                    if ($lockedProcesses.Count -gt 0) {
                        Write-Host "     🔒 Processes locking this folder:" -ForegroundColor Yellow
                        foreach ($proc in $lockedProcesses | Sort-Object -Unique -Property Name) {
                            Write-Host "        • $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Yellow
                            Write-Log "Process locking folder: $($proc.Name) (PID: $($proc.Id))"
                        }
                        Write-Host ""
                        Write-Host "     ⚠️  SOLUTION: Please try one of the following:" -ForegroundColor Yellow
                        Write-Host "        1. Close all Dualog-related applications and try again" -ForegroundColor White
                        Write-Host "        2. Restart the computer to release all file handles" -ForegroundColor White
                        Write-Host "        3. Disable antivirus scanning temporarily and retry" -ForegroundColor White
                    }
                    else {
                        Write-Host "     Could not identify specific processes" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "     Could not identify which processes are locking the folder" -ForegroundColor Yellow
                }
                
                Write-Host ""
            }
        }
    }
    
    $desktopShortcut = "C:\Users\Public\Desktop\Dualog Connection Suite.URL"
    if (Test-Path $desktopShortcut) {
        Remove-Item -Path $desktopShortcut -Force -ErrorAction SilentlyContinue
    }
    Write-Host "OK - Dualog files removed" -ForegroundColor Green
    Write-Host ""
    
    # STEP 3: REMOVE DUALOG FROM ADD/REMOVE PROGRAMS (UNINSTALL REGISTRY)
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║           STEP 3: Removing Dualog from Add/Remove Programs                    ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    # Search for Dualog Connection Suite in Add/Remove Programs registry
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    Write-Host "Searching for Dualog Connection Suite entries in Add/Remove Programs..." -ForegroundColor Cyan
    $dualogFound = $false
    
    foreach ($uninstallPath in $uninstallPaths) {
        if (Test-Path $uninstallPath) {
            $subkeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $displayName = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName
                
                # Check if this is Dualog Connection Suite (any version including 5.11.000)
                if ($displayName -match "Dualog.*Connection.*Suite|Connection.*Suite.*Dualog") {
                    Write-Host "  Found: $displayName" -ForegroundColor Yellow
                    $dualogFound = $true
                    
                    # Remove the registry key
                    try {
                        Remove-Item -Path $subkey.PSPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
                        Write-Host "  ✓ Removed registry entry: $($subkey.PSChildName)" -ForegroundColor Green
                        Write-Log "Removed Dualog uninstall entry from registry: $displayName"
                    }
                    catch {
                        Write-Host "  ⚠️  Could not remove registry entry: $_" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    
    if (-not $dualogFound) {
        Write-Host "  ℹ️  Dualog Connection Suite not found in Add/Remove Programs" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✓ Dualog uninstall entry removed from Add/Remove Programs" -ForegroundColor Green
    }
    
    Write-Host "OK - Dualog Add/Remove Programs entries processed" -ForegroundColor Green
    Write-Host ""
    
    # STEP 4: REMOVE DUALOG REGISTRY ENTRIES
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                  STEP 4: Removing Dualog Registry Entries                     ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\Wow6432Node\Dualog",
        "HKLM:\SOFTWARE\Dualog",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Dualog",
        "HKLM:\SYSTEM\CurrentControlSet\Services\DUALOGREDIR"
    )
    
    Write-Host "Removing Dualog registry entries..." -ForegroundColor Cyan
    foreach ($regPath in $registryPaths) {
        Remove-Item -Path $regPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host "OK - Dualog registry entries removed" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "                   ✅ DUALOG REMOVAL COMPLETED ✅                            " -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Log "Dualog removal completed successfully"
    
    # STEP 5: REMOVE ORACLE
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                   STEP 5: Removing Oracle Database XE                        ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $oracleServices = @("OracleJobSchedulerXE", "OracleMTSRecoveryService", "OracleServiceXE", "OracleXEClrAgent", "OracleXETNSListener")
    
    Write-Host "Stopping and removing Oracle services..." -ForegroundColor Cyan
    foreach ($service in $oracleServices) {
        Stop-Service -Name $service -ErrorAction SilentlyContinue -Force
        & sc.exe delete $service 2>$null
    }
    
    Get-Process -Name oracle* -ErrorAction SilentlyContinue | Stop-Process -Force | Out-Null
    Get-Process -Name Oracle* -ErrorAction SilentlyContinue | Stop-Process -Force | Out-Null
    
    Write-Host "OK - Oracle services stopped" -ForegroundColor Green
    Write-Host ""
    
    # Remove Oracle from Add/Remove Programs
    Write-Host "Removing Oracle from Add/Remove Programs..." -ForegroundColor Cyan
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    $oracleFound = $false
    foreach ($uninstallPath in $uninstallPaths) {
        if (Test-Path $uninstallPath) {
            $subkeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $displayName = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName
                
                # Check if this is Oracle Database 11g Express Edition
                if ($displayName -match "Oracle.*11g|Oracle.*Database.*Express|Express.*Edition.*Oracle") {
                    Write-Host "  Found: $displayName" -ForegroundColor Yellow
                    $oracleFound = $true
                    
                    # Remove the registry key
                    try {
                        Remove-Item -Path $subkey.PSPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
                        Write-Host "  ✓ Removed registry entry: $($subkey.PSChildName)" -ForegroundColor Green
                        Write-Log "Removed Oracle uninstall entry from registry: $displayName"
                    }
                    catch {
                        Write-Host "  ⚠️  Could not remove registry entry: $_" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    
    if (-not $oracleFound) {
        Write-Host "  ℹ️  Oracle Database 11g Express Edition not found in Add/Remove Programs" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✓ Oracle uninstall entry removed from Add/Remove Programs" -ForegroundColor Green
    }
    Write-Host "OK - Oracle Add/Remove Programs entries processed" -ForegroundColor Green
    Write-Host ""
    
    
    foreach ($path in $oraclePathsToRemove) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed: $path" -ForegroundColor Green
        }
    }
    
    $oracleRegistryPaths = @("HKLM:\SOFTWARE\ORACLE", "HKLM:\SOFTWARE\WOW6432Node\Oracle")
    foreach ($regPath in $oracleRegistryPaths) {
        Remove-Item -Path $regPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    $envVars = @("NLS_LANG", "ORACLE_HOME", "ORACLE_SID")
    foreach ($var in $envVars) {
        Remove-ItemProperty -Path "HKCU:\Environment" -Name $var -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name $var -ErrorAction SilentlyContinue
    }
    
    Write-Host "OK - Oracle removed" -ForegroundColor Green
    Write-Host ""
    
    # STEP 6: REMOVE ENVIRONMENT PATHS
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                 STEP 6: Removing Oracle & Dualog Environment Paths            ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $pathsToRemoveFromEnv = @(
        "C:\Dualog\OracleXE\app\oracle\product\11.2.0\server\bin",
        "C:\Dualog\ConnectionSuite\ociclient"
    )
    
    Write-Host "Removing environment PATH entries..." -ForegroundColor Cyan
    Write-Log "Starting environment PATH cleanup"
    
    $result = Remove-EnvironmentPath -PathsToRemove $pathsToRemoveFromEnv -Scope Machine
    
    if ($result) {
        Write-Host "✓ Environment PATH cleanup completed successfully" -ForegroundColor Green
        Write-Log "Environment PATH entries removed successfully"
    }
    else {
        Write-Host "⚠️  Warning: Environment PATH cleanup encountered issues" -ForegroundColor Yellow
        Write-Log "Environment PATH cleanup encountered issues"
    }
    Write-Host ""
    
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "        ✅ ALL DUALOG AND ORACLE COMPONENTS REMOVED SUCCESSFULLY ✅           " -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Log "Dualog and Oracle cleanup process completed successfully"
}

try {

# Script configuration
$ScriptVersion = "1.6"
$ScriptDate = "2024-10-16"
$CSInstallerFile = "setup_x64_5.11.000_UA.exe"
$CSStartPackFile = "startpack.dsp"
$CSUASettingsFile = "ua_settings.ini"
$CSFolderCreatorFile = "foldercreation.bat"
$OraclePortChangerFile = "oraclesethttp.bat"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OracleSQLPlusPath = "C:\dualog\oraclexe\app\oracle\product\11.2.0\server\bin\"
$LogFile = "$env:TEMP\Dualog_AESM_Installer.log"
$FolderCreationFailed = $false
$OraclePortConfigFailed = $false
$ApacheFirewallConfigFailed = $false

# Function to configure firewall ONLY for Apache HTTP Server
function Add-ApacheFirewallRule {
    Write-Host ""
    Write-Host "Verifying Apache HTTP Server firewall configuration..." -ForegroundColor Cyan
    Write-Log "Verifying and updating Apache firewall rules"

    try {
        # Possible Apache installation paths - INCLUDING THE ACTUAL PATH!
        $ApachePaths = @(
            "C:\dualog\connectionsuite\web\apache\bin\httpd.exe",
            "C:\dualog\oraclexe\app\oracle\product\11.2.0\server\Apache\Apache\bin\httpd.exe",
            "C:\dualog\Apache\Apache\bin\httpd.exe",
            "C:\Program Files\Apache*\bin\httpd.exe"
        )

        $ApacheFound = $false
        $ApacheExePath = $null

        # Quick check for Apache
        foreach ($Path in $ApachePaths) {
            # Check if path contains wildcard
            if ($Path -like "*``**") {
                $ParentPath = Split-Path $Path -Parent
                $FileName = Split-Path $Path -Leaf
                if (Test-Path $ParentPath) {
                    $ResolvedPaths = Get-ChildItem -Path $ParentPath -Filter $FileName -ErrorAction SilentlyContinue
                    foreach ($ResolvedPath in $ResolvedPaths) {
                        if (Test-Path $ResolvedPath.FullName) {
                            $ApacheExePath = $ResolvedPath.FullName
                            $ApacheFound = $true
                            break
                        }
                    }
                }
            }
            elseif (Test-Path $Path) {
                $ApacheExePath = $Path
                $ApacheFound = $true
                break
            }

            if ($ApacheFound) { break }
        }

        if ($ApacheFound) {
            Write-Host "✓ Apache HTTP Server found at: $ApacheExePath" -ForegroundColor Green
            Write-Log "Apache HTTP Server found at: $ApacheExePath"

            # Create specific program-based rule for the actual executable
            New-NetFirewallRule -DisplayName "Apache HTTP Server - Exact Path (Dualog)" `
                                -Description "Allow Apache HTTP Server at $ApacheExePath for Dualog Connection Suite" `
                                -Direction Inbound `
                                -Program $ApacheExePath `
                                -Action Allow `
                                -Profile Any `
                                -Enabled True `
                                -ErrorAction SilentlyContinue | Out-Null

            Write-Host "✓ Program-based firewall rule added for Apache executable" -ForegroundColor Green
            Write-Log "Created program-based firewall rule for Apache at: $ApacheExePath"
            return $true
        }
        else {
            Write-Host "⚠ Apache not found yet - will configure after restart" -ForegroundColor Yellow
            Write-Log "Apache executable not found - will configure firewall after restart" -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Error updating Apache firewall rule: $_" -Level Error
        Write-Host "⚠ Apache firewall configuration will retry after restart" -ForegroundColor Yellow
        return $false
    }
}

# Function to create post-reboot Apache firewall configuration script
function Create-ApacheFirewallScript {
    $FirewallScriptPath = Join-Path $ScriptDir "configure_apache_firewall.ps1"
    
    $FirewallScriptContent = @'
# Apache HTTP Server Firewall Configuration
# Runs once after reboot
# ONLY configures Apache - NO OTHER SERVICES

$LogFile = "$env:TEMP\Apache_Firewall_Config.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
}

# ============================================================================
# CLEANUP / UNINSTALL FUNCTION
# ============================================================================



Write-Log "Starting Apache firewall configuration after reboot"
Write-Log "IMPORTANT: Only configuring Apache HTTP Server - no other services"

# Wait for services to start
Start-Sleep -Seconds 10

# Apache paths only - INCLUDING THE ACTUAL PATH!
$ApachePaths = @(
    "C:\dualog\connectionsuite\web\apache\bin\httpd.exe",
    "C:\dualog\oraclexe\app\oracle\product\11.2.0\server\Apache\Apache\bin\httpd.exe",
    "C:\dualog\Apache\Apache\bin\httpd.exe"
)

$ApacheFound = $false

foreach ($Path in $ApachePaths) {
    if (Test-Path $Path) {
        Write-Log "Found Apache at: $Path"
        
        # Create firewall rule for Apache only
        New-NetFirewallRule -DisplayName "Apache HTTP Server - Exact Path (Dualog)" `
                            -Description "Allow Apache HTTP Server at $Path for Dualog Connection Suite" `
                            -Direction Inbound `
                            -Program $Path `
                            -Action Allow `
                            -Profile Any `
                            -Enabled True `
                            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Log "Created firewall rule for Apache only - no other services configured"
        $ApacheFound = $true
        break
    }
}

if (-not $ApacheFound) {
    Write-Log "Apache not found after reboot - port-based rules should still work"
}

Write-Log "Apache firewall configuration completed (Apache only)"
'@
    
    Set-Content -Path $FirewallScriptPath -Value $FirewallScriptContent -Force
    Write-Log "Created Apache firewall configuration script (Apache only): $FirewallScriptPath"
    
    return $FirewallScriptPath
}

# Initialize log file
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Level) {
        'Warning' { Write-Host $Message -ForegroundColor Yellow }
        'Error' { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message }
    }
}

# Clear console and start logging
Clear-Host
Write-Log "AESM custom installer started"

# Function to check disk space
function Get-DiskFreeSpace {
    param([string]$DriveLetter = "C")
    
    try {
        $Drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
        return $FreeSpaceGB
    }
    catch {
        Write-Log "Error checking disk space: $_" -Level Error
        return 0
    }
}

# Function to check if port is in use
function Test-PortInUse {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port,
        
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    
    Write-Log "Checking port $Port ($Description)"
    
    try {
        $Connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        
        if ($Connections) {
            $ProcessId = $Connections[0].OwningProcess
            $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            $ProcessName = if ($Process) { $Process.ProcessName } else { "Unknown" }
            
            Write-Log "Warning - IP port $Port ($Description) is in use by process $ProcessName (PID: $ProcessId)" -Level Warning
            return $true
        }
        else {
            Write-Log "NetStat did not report IP port $Port ($Description) as being currently in use"
            return $false
        }
    }
    catch {
        Write-Log "Error checking port $Port : $_" -Level Error
        return $false
    }
}

# Function to create firewall rules BEFORE installation (port-based rules)
# Function to disable Windows Firewall notifications during installation
# Display header
Write-Host "======================================================================================="
Write-Host "Anglo Eastern Ship Management Ltd - Dualog Connection Suite Ship Automated Installation"
Write-Host "======================================================================================="
Write-Host ""

# Display system information
$FreeSpaceGB = Get-DiskFreeSpace -DriveLetter "C"
$OracleDrive = $OracleSQLPlusPath.Substring(0, 2)

Write-Host "Script version   : $ScriptVersion ($ScriptDate)"
Write-Host "Host name        : $env:COMPUTERNAME"
Write-Host "Current user     : $env:USERNAME"
Write-Host "Installer folder : $ScriptDir"
Write-Host "Free space C:    : $FreeSpaceGB GB"
Write-Host "SQLPlus drive    : $OracleDrive"
Write-Host "SQLPlus path     : $OracleSQLPlusPath"

Write-Log "Script version = $ScriptVersion ($ScriptDate)"
Write-Log "Host name = $env:COMPUTERNAME"
Write-Log "Current user = $env:USERNAME"
Write-Log "Installer folder = $ScriptDir"
Write-Log "Free space C: = $FreeSpaceGB GB"
Write-Log "SQLPlus drive = $OracleDrive"
Write-Log "SQLPlus path = $OracleSQLPlusPath"

# Critical Warning - New Installation Only
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                              ⚠️  IMPORTANT WARNING ⚠️                           ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "  This installer will perform a FRESH INSTALLATION of:" -ForegroundColor White
Write-Host ""
Write-Host "  📦 Dualog Connection Suite Ship - Version 5.11.000" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ⛔ DO NOT USE THIS INSTALLER IF:" -ForegroundColor Red
Write-Host "     • You are trying to PATCH an existing Dualog Connection Suite installation" -ForegroundColor Red
Write-Host "     • You are trying to UPGRADE an existing installation" -ForegroundColor Red
Write-Host "     • Dualog Connection Suite is already installed on this system" -ForegroundColor Red
Write-Host ""
Write-Host "  ✅ USE THIS INSTALLER ONLY FOR:" -ForegroundColor Green
Write-Host "     • New installations on systems without Dualog Connection Suite" -ForegroundColor Green
Write-Host "     • Complete reinstallation after full uninstallation" -ForegroundColor Green
Write-Host ""
Write-Host "  ⚠️  Running this on an existing installation may cause:" -ForegroundColor Yellow
Write-Host "     • Loss of configuration settings" -ForegroundColor Yellow
Write-Host "     • Database conflicts" -ForegroundColor Yellow
Write-Host "     • Service disruption" -ForegroundColor Yellow
Write-Host "     • Data loss" -ForegroundColor Yellow
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

# Prompt user for confirmation
$Confirmation = $null
$ValidResponse = $false

while (-not $ValidResponse) {
    Write-Host "Do you want to proceed with a NEW installation of Dualog Connection Suite 5.11?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [Y] Yes - Proceed with NEW installation" -ForegroundColor Green
    Write-Host "  [N] No  - Exit the installer" -ForegroundColor Red
    Write-Host ""
    $Confirmation = Read-Host "Enter your choice (Y/N)"
    
    if ($Confirmation -eq 'Y' -or $Confirmation -eq 'y') {
        Write-Host ""
        Write-Host "✅ User confirmed: Proceeding with NEW installation" -ForegroundColor Green
        Write-Log "User confirmed to proceed with NEW installation of Dualog Connection Suite 5.11"
        $ValidResponse = $true
    }
    elseif ($Confirmation -eq 'N' -or $Confirmation -eq 'n') {
        Write-Host ""
        Write-Host "❌ Installation cancelled by user" -ForegroundColor Red
        Write-Log "User cancelled installation at initial warning prompt"
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }
    else {
        Write-Host ""
        Write-Host "Invalid input. Please enter Y (Yes) or N (No)." -ForegroundColor Yellow
        Write-Host ""
    }
}


# ============================================================================
# MAIN INSTALLATION MENU - FIRST MENU
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                   🚀 INSTALLATION MODE SELECTION 🚀                            ║" -ForegroundColor Green
Write-Host "║                                                                                ║" -ForegroundColor Green
Write-Host "║         Dualog Connection Suite Ship - Version 5.11.000                       ║" -ForegroundColor Green
Write-Host "║         Anglo Eastern Ship Management Ltd                                      ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Please select an installation option:" -ForegroundColor White
Write-Host ""
Write-Host "  ┌────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "  │                                                                            │" -ForegroundColor Gray
Write-Host "  │  [1] AUTOMATIC INSTALLATION                                              │" -ForegroundColor Green
Write-Host "  │      └─ Full automated installation of Dualog Connection Suite           │" -ForegroundColor Gray
Write-Host "  │      └─ Recommended for most users                                       │" -ForegroundColor Gray
Write-Host "  │      └─ Handles all configuration automatically                          │" -ForegroundColor Gray
Write-Host "  │      └─ Minimum user interaction required                                │" -ForegroundColor Gray
Write-Host "  │                                                                            │" -ForegroundColor Gray
Write-Host "  │  [2] MANUAL INSTALLATION                                                 │" -ForegroundColor Green
Write-Host "  │      └─ Step-by-step manual installation process                         │" -ForegroundColor Gray
Write-Host "  │      └─ More control over installation options                           │" -ForegroundColor Gray
Write-Host "  │      └─ For experienced users                                            │" -ForegroundColor Gray
Write-Host "  │      └─ Allows custom configuration at each step                         │" -ForegroundColor Gray
Write-Host "  │                                                                            │" -ForegroundColor Gray
Write-Host "  │  [3] CLEANUP / UNINSTALL                                                 │" -ForegroundColor Yellow
Write-Host "  │      └─ Clean up and remove Dualog Connection Suite                      │" -ForegroundColor Gray
Write-Host "  │      └─ Removes installation files and configurations                    │" -ForegroundColor Gray
Write-Host "  │      └─ Use before fresh installation if needed                          │" -ForegroundColor Gray
Write-Host "  │                                                                            │" -ForegroundColor Gray
Write-Host "  │  [4] EXIT                                                                │" -ForegroundColor Red
Write-Host "  │      └─ Exit the installer without making any changes                    │" -ForegroundColor Gray
Write-Host "  │                                                                            │" -ForegroundColor Gray
Write-Host "  └────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
Write-Host ""
Write-Host "  📌 Which installation mode do you want to use?" -ForegroundColor Cyan
Write-Host ""

# Initialize variable for installation mode selection
$InstallationModeSelection = $null
$ValidInstallationModeResponse = $false
$InstallationMode = "AUTOMATIC"  # Default value

while (-not $ValidInstallationModeResponse) {
    $InstallationModeSelection = Read-Host "  Enter your choice (1, 2, 3, or 4)"
    
    if ($InstallationModeSelection -eq '1') {
        Write-Host ""
        Write-Host "  ✅ Installation mode selected: AUTOMATIC INSTALLATION" -ForegroundColor Green
        Write-Host "     Full automated setup will proceed..." -ForegroundColor Gray
        Write-Log "User selected installation mode = AUTOMATIC (option 1)"
        $ValidInstallationModeResponse = $true
        $InstallationMode = "AUTOMATIC"
    }
    elseif ($InstallationModeSelection -eq '2') {
        Write-Host ""
        Write-Host "  ✅ Installation mode selected: MANUAL INSTALLATION" -ForegroundColor Green
        Write-Host "     Step-by-step manual setup will proceed..." -ForegroundColor Gray
        Write-Log "User selected installation mode = MANUAL (option 2)"
        $ValidInstallationModeResponse = $true
        $InstallationMode = "MANUAL"
    }
    
    # ============================================================================
    # MANUAL INSTALLATION SUBMENU
    # ============================================================================
    
    # If user selected Manual Installation, show the manual installation menu
    if ($InstallationMode -eq "MANUAL") {
        
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║                        ⚠️  IMPORTANT WARNING ⚠️                                 ║" -ForegroundColor Yellow
        Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  🔴 BEFORE PROCEEDING WITH MANUAL INSTALLATION 🔴" -ForegroundColor Red
        Write-Host ""
        Write-Host "  If you have an EXISTING Dualog Connection Suite installation on this system," -ForegroundColor White
        Write-Host "  you MUST use the CLEANUP / UNINSTALL option from the main menu first!" -ForegroundColor White
        Write-Host ""
        Write-Host "  ⛔ IMPORTANT STEPS:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Go back to the main menu (Option 3 below)" -ForegroundColor White
        Write-Host "  2. Select Option 3: CLEANUP / UNINSTALL" -ForegroundColor White
        Write-Host "  3. Complete the cleanup procedure" -ForegroundColor White
        Write-Host "  4. Restart the computer when prompted" -ForegroundColor White
        Write-Host "  5. Re-run this installer and select Manual Installation again" -ForegroundColor White
        Write-Host ""
        Write-Host "  ❌ Skipping cleanup may cause:" -ForegroundColor Red
        Write-Host "     • Installation conflicts" -ForegroundColor Red
        Write-Host "     • File corruption" -ForegroundColor Red
        Write-Host "     • Service failures" -ForegroundColor Red
        Write-Host "     • Database issues" -ForegroundColor Red
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Host "┌────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│            📦 MANUAL INSTALLATION MODE - FILE OPTIONS 📦                   │" -ForegroundColor Cyan
        Write-Host "└────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Choose how you want to proceed with manual installation:" -ForegroundColor White
        Write-Host ""
        Write-Host "  ┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
        Write-Host "  │                                                                        │" -ForegroundColor Gray
        Write-Host "  │  [1] DOWNLOAD DUALOG CONNECTION SUITE 5.11                            │" -ForegroundColor Green
        Write-Host "  │      └─ Download latest installation files                            │" -ForegroundColor Gray
        Write-Host "  │      └─ Files will be saved to installation folder                    │" -ForegroundColor Gray
        Write-Host "  │      └─ Use this if you don't have the files yet                      │" -ForegroundColor Gray
        Write-Host "  │                                                                        │" -ForegroundColor Gray
        Write-Host "  │  [2] OPEN FULL INSTALLATION FILES                                     │" -ForegroundColor Green
        Write-Host "  │      └─ Open existing files at C:\Dualog\Installer\                   │" -ForegroundColor Gray
        Write-Host "  │      └─ Launch manual installation procedure                          │" -ForegroundColor Gray
        Write-Host "  │      └─ Use this if you already have installation files               │" -ForegroundColor Gray
        Write-Host "  │                                                                        │" -ForegroundColor Gray
        Write-Host "  │  [3] RETURN TO MAIN MENU                                              │" -ForegroundColor Yellow
        Write-Host "  │      └─ Go back to the main installation mode selection                │" -ForegroundColor Gray
        Write-Host "  │      └─ Choose a different installation option                        │" -ForegroundColor Gray
        Write-Host "  │                                                                        │" -ForegroundColor Gray
        Write-Host "  └────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  📌 Which manual installation option do you want?" -ForegroundColor Cyan
        Write-Host ""
        
        # Initialize variable for manual installation menu selection
        $ManualInstallationSelection = $null
        $ValidManualResponse = $false
        
        while (-not $ValidManualResponse) {
            $ManualInstallationSelection = Read-Host "  Enter your choice (1, 2, or 3)"
            
            if ($ManualInstallationSelection -eq '1') {
                Write-Host ""
                Write-Host "  ✅ Option selected: DOWNLOAD DUALOG CONNECTION SUITE 5.11" -ForegroundColor Green
                Write-Host "     Initializing download process..." -ForegroundColor Gray
                Write-Log "User selected manual installation option = DOWNLOAD (option 1)"
                $ValidManualResponse = $true
                $ManualInstallationOption = "DOWNLOAD"
                
                # ============================================================================
                # DOWNLOAD DUALOG CONNECTION SUITE WITH PROGRESS BAR
                # ============================================================================
                
                Write-Host ""
                Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                         📥 DOWNLOADING FILES 📥                                " -ForegroundColor Cyan
                Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                
                # Configuration
                $downloadUrl = "https://cdn.download.dualog.com/ConnectionSuite/5.11/5.11.000/Setup_x64_5.11.000.exe"
                $downloadFileName = "Setup_x64_5.11.000.exe"
                $installationFolder = "C:\Dualog\Installer"
                $downloadPath = Join-Path -Path $installationFolder -ChildPath $downloadFileName
                
                Write-Host "  📍 Source URL:" -ForegroundColor Cyan
                Write-Host "     $downloadUrl" -ForegroundColor White
                Write-Host ""
                Write-Host "  💾 Destination:" -ForegroundColor Cyan
                Write-Host "     $downloadPath" -ForegroundColor White
                Write-Host ""
                
                # Create installation folder if it doesn't exist
                if (-not (Test-Path $installationFolder)) {
                    Write-Host "  📁 Creating installation folder: $installationFolder" -ForegroundColor Cyan
                    try {
                        New-Item -ItemType Directory -Path $installationFolder -Force | Out-Null
                        Write-Log "Created installation folder: $installationFolder"
                        Write-Host "  ✓ Folder created successfully" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  ❌ Failed to create folder: $_" -ForegroundColor Red
                        Write-Log "Failed to create folder: $_" -Level Error
                        Write-Host ""
                        Write-Host "Press any key to return to menu..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        continue
                    }
                }
                else {
                    Write-Host "  ✓ Installation folder exists: $installationFolder" -ForegroundColor Green
                }
                
                Write-Host ""
                Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                
                # Check if file already exists
                if (Test-Path $downloadPath) {
                    Write-Host "  ⚠️  FILE ALREADY EXISTS" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  The file already exists at:" -ForegroundColor White
                    Write-Host "  $downloadPath" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "  Options:" -ForegroundColor White
                    Write-Host "  [R] Redownload (overwrite existing file)" -ForegroundColor Yellow
                    Write-Host "  [K] Keep existing file" -ForegroundColor Green
                    Write-Host "  [C] Cancel and return to menu" -ForegroundColor Red
                    Write-Host ""
                    
                    $fileExistResponse = Read-Host "  Enter your choice (R, K, or C)"
                    
                    if ($fileExistResponse -eq 'C' -or $fileExistResponse -eq 'c') {
                        Write-Host ""
                        Write-Host "  Download cancelled. Returning to menu..." -ForegroundColor Yellow
                        Write-Log "User cancelled download - file already exists"
                        Write-Host ""
                        continue
                    }
                    elseif ($fileExistResponse -eq 'K' -or $fileExistResponse -eq 'k') {
                        Write-Host ""
                        Write-Host "  ✓ Keeping existing file" -ForegroundColor Green
                        Write-Log "User chose to keep existing file"
                        Write-Host ""
                        Write-Host "Press any key to continue..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        Write-Host ""
                        Write-Host "Opening installation folder: $installationFolder" -ForegroundColor Cyan
                        Start-Process -FilePath explorer.exe -ArgumentList $installationFolder
                        Write-Host ""
                        Write-Host "Windows Explorer is opening the installation folder." -ForegroundColor White
                        Write-Host "Please navigate to the setup file and run the installation manually." -ForegroundColor White
                        Write-Host ""
                        Write-Log "Opened installation folder in Windows Explorer"
                        continue
                    }
                    elseif ($fileExistResponse -eq 'R' -or $fileExistResponse -eq 'r') {
                        Write-Host ""
                        Write-Host "  ⚠️  Removing existing file..." -ForegroundColor Yellow
                        try {
                            Remove-Item -Path $downloadPath -Force
                            Write-Host "  ✓ Existing file removed" -ForegroundColor Green
                            Write-Log "Removed existing download file"
                        }
                        catch {
                            Write-Host "  ❌ Failed to remove existing file: $_" -ForegroundColor Red
                            Write-Log "Failed to remove existing file: $_" -Level Error
                            Write-Host ""
                            Write-Host "Press any key to return to menu..."
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            continue
                        }
                    }
                    else {
                        Write-Host "  ❌ Invalid choice. Please enter R, K, or C" -ForegroundColor Red
                        continue
                    }
                }
                
                Write-Host ""
                Write-Host "  ⏳ Starting download..." -ForegroundColor Cyan
                Write-Host "     This may take several minutes depending on your internet connection" -ForegroundColor Gray
                Write-Host ""
                
                
                # Download method with simple percentage display
                try {
                    Write-Host ""
                    Write-Host "  ⏳ Downloading file..." -ForegroundColor Yellow
                    Write-Host "  Please wait, this may take several minutes..." -ForegroundColor Gray
                    Write-Host ""
                    
                    $downloadStartTime = Get-Date
                    
                    Write-Log "Starting download from: $downloadUrl"
                    Write-Log "Destination: $downloadPath"
                    
                    # Disable default PowerShell progress bar
                    $ProgressPreference = 'SilentlyContinue'
                    
                    # Get file size first
                    try {
                        $response = Invoke-WebRequest -Uri $downloadUrl -Method Head -UseBasicParsing
                        $totalBytes = [long]$response.Headers.'Content-Length'
                        $totalMB = [math]::Round($totalBytes / 1MB, 2)
                        Write-Host "  📦 File size: $totalMB MB" -ForegroundColor Cyan
                        Write-Host ""
                    }
                    catch {
                        $totalBytes = 0
                        Write-Host "  📦 Downloading... (size unknown)" -ForegroundColor Cyan
                        Write-Host ""
                    }
                    
                    # Download file in chunks to show progress
                    $webClient = New-Object System.Net.WebClient
                    $buffer = New-Object byte[] 8192
                    $downloadedBytes = 0
                    $lastPercentage = -1
                    
                    try {
                        $responseStream = $webClient.OpenRead($downloadUrl)
                        $fileStream = [System.IO.File]::Create($downloadPath)
                        
                        Write-Host "  " -NoNewline
                        
                        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $fileStream.Write($buffer, 0, $bytesRead)
                            $downloadedBytes += $bytesRead
                            
                            if ($totalBytes -gt 0) {
                                $percentage = [math]::Round(($downloadedBytes / $totalBytes) * 100, 0)
                                
                                # Update display when percentage changes
                                if ($percentage -ne $lastPercentage) {
                                    Write-Host "`r  📥 Downloading: $percentage% complete" -NoNewline -ForegroundColor Green
                                    $lastPercentage = $percentage
                                }
                            }
                            else {
                                # Show MB downloaded when total size unknown
                                $downloadedMB = [math]::Round($downloadedBytes / 1MB, 2)
                                Write-Host "`r  📥 Downloaded: $downloadedMB MB" -NoNewline -ForegroundColor Green
                            }
                        }
                        
                        Write-Host ""  # New line after progress
                        Write-Host ""
                        Write-Host "  ✓ Download completed!" -ForegroundColor Green
                        Write-Log "Download completed successfully"
                    }
                    catch {
                        Write-Host ""
                        Write-Host "  ❌ Download failed: $_" -ForegroundColor Red
                        Write-Log "Download failed: $_" -Level Error
                        throw $_
                    }
                    finally {
                        # Clean up resources
                        if ($fileStream) { $fileStream.Close(); $fileStream.Dispose() }
                        if ($responseStream) { $responseStream.Close(); $responseStream.Dispose() }
                        if ($webClient) { $webClient.Dispose() }
                    }
                    
                    $downloadEndTime = Get-Date
                    
                    $downloadEndTime = Get-Date
                    $totalDownloadTime = $downloadEndTime - $downloadStartTime
                    
                    # Final verification
                    Write-Host ""
                    Write-Host ""
                    Write-Host "  ✓ Verifying downloaded file..." -ForegroundColor Cyan
                    Write-Host ""
                    
                    Start-Sleep -Milliseconds 500
                    
                    if (Test-Path $downloadPath) {
                        $fileSize = (Get-Item $downloadPath).Length
                        
                        if ($fileSize -gt 1MB) {
                            $fileSizeStr = "{0:N2} MB" -f ($fileSize / 1MB)
                        }
                        else {
                            $fileSizeStr = "{0:N2} KB" -f ($fileSize / 1KB)
                        }
                        
                        $downloadEndTime = Get-Date
                        $totalDownloadTime = $downloadEndTime - $downloadStartTime
                        
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host "                     ✅ DOWNLOAD COMPLETED SUCCESSFULLY ✅                      " -ForegroundColor Green
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "  📊 Download Statistics:" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "    File Name:        $downloadFileName" -ForegroundColor White
                        Write-Host "    File Size:        $fileSizeStr" -ForegroundColor White
                        Write-Host "    Download Time:    $($totalDownloadTime.ToString('hh\:mm\:ss'))" -ForegroundColor White
                        Write-Host "    Save Location:    $downloadPath" -ForegroundColor White
                        Write-Host ""
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host ""
                        Write-Log "Successfully downloaded file: $downloadFileName ($fileSizeStr) to $downloadPath in $($totalDownloadTime.ToString('hh\:mm\:ss'))"
                        
                        Write-Host "Press any key to continue..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        
                        Write-Host ""
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "  🚀 Launching setup and installation guide..." -ForegroundColor Cyan
                        Write-Host ""
                        
                        # Launch the setup executable
                        Write-Host "  1️⃣  Opening Setup_x64_5.11.000.exe" -ForegroundColor Green
                        Write-Log "Launching Setup_x64_5.11.000.exe from $downloadPath"
                        Start-Process -FilePath $downloadPath
                        
                        # Give it a moment to start
                        Start-Sleep -Seconds 2
                        
                        # Launch the PDF guide
                        $pdfPath = Join-Path -Path $installationFolder -ChildPath "Dualog-AESM full intallation guide.pdf"
                        
                        if (Test-Path $pdfPath) {
                            Write-Host "  2️⃣  Opening Dualog-AESM full intallation guide.pdf" -ForegroundColor Green
                            Write-Log "Launching PDF guide from $pdfPath"
                            Start-Process -FilePath $pdfPath
                            Start-Sleep -Seconds 1
                        }
                        else {
                            Write-Host "  ⚠️  PDF guide not found at: $pdfPath" -ForegroundColor Yellow
                            Write-Log "PDF guide not found at $pdfPath"
                        }
                        
                        Write-Host ""
                        Write-Host "  ✅ Setup and installation guide are now launching..." -ForegroundColor Green
                        Write-Host ""
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "  The installer script will now exit. Follow the setup wizard to complete" -ForegroundColor White
                        Write-Host "  the Dualog Connection Suite installation." -ForegroundColor White
                        Write-Host ""
                        Write-Log "Download complete. Setup and PDF guide launched. Exiting installer script."
                        
                        Start-Sleep -Seconds 2
                        exit 0
                    }
                    else {
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                        Write-Host "                       ❌ DOWNLOAD FAILED ❌                                    " -ForegroundColor Red
                        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                        Write-Host ""
                        Write-Host "  The downloaded file was not found at the expected location:" -ForegroundColor Red
                        Write-Host "  $downloadPath" -ForegroundColor White
                        Write-Host ""
                        Write-Host "  Possible reasons:" -ForegroundColor Yellow
                        Write-Host "    • Download was interrupted" -ForegroundColor Gray
                        Write-Host "    • Permission denied to save file" -ForegroundColor Gray
                        Write-Host "    • Insufficient disk space" -ForegroundColor Gray
                        Write-Host "    • Network connectivity issue" -ForegroundColor Gray
                        Write-Host ""
                        Write-Log "Download verification failed - file not found at $downloadPath" -Level Error
                    }
                }
                catch {
                    Write-Host ""
                    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                    Write-Host "                   ❌ DOWNLOAD ERROR OCCURRED ❌                                " -ForegroundColor Red
                    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "  Error Details:" -ForegroundColor Red
                    Write-Host "  $($_.Exception.Message)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
                    Write-Host "    • Check your internet connection" -ForegroundColor Gray
                    Write-Host "    • Verify the URL is correct: $downloadUrl" -ForegroundColor Gray
                    Write-Host "    • Check that C:\Dualog\ folder has write permissions" -ForegroundColor Gray
                    Write-Host "    • Try again later if the server is temporarily unavailable" -ForegroundColor Gray
                    Write-Host ""
                    Write-Log "Download error: $($_.Exception.Message)" -Level Error
                }
                
                Write-Host ""
                Write-Host "Press any key to return to manual installation menu..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                # Reset flag to show manual installation menu again
                $ValidManualResponse = $false
            }
            elseif ($ManualInstallationSelection -eq '2') {
                Write-Host ""
                Write-Host "  ✅ Option selected: OPEN FULL INSTALLATION FILES" -ForegroundColor Green
                Write-Log "User selected manual installation option = OPEN FILES (option 2)"
                $ValidManualResponse = $true
                $ManualInstallationOption = "OPEN_FILES"
                
                # Open the installation folder and close the script
                $InstallationFolderPath = "C:\Dualog\Installer"
                
                Write-Host ""
                Write-Host "  Opening installation folder at: $InstallationFolderPath" -ForegroundColor Cyan
                Write-Log "Opening installation folder at: $InstallationFolderPath"
                
                try {
                    # Open the folder in Windows Explorer
                    Start-Process -FilePath explorer.exe -ArgumentList $InstallationFolderPath
                    
                    Write-Host "  ✓ File Explorer opened successfully" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  Closing installer..." -ForegroundColor Cyan
                    Write-Log "Opened installation folder in Windows Explorer and closing installer"
                    
                    Start-Sleep -Seconds 1
                    exit 0
                }
                catch {
                    Write-Host ""
                    Write-Host "  ❌ Error opening file explorer: $_" -ForegroundColor Red
                    Write-Log "Error opening file explorer: $_" -Level Error
                    Write-Host ""
                    Write-Host "  Press any key to return to menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    # Reset flag to show menu again
                    $ValidManualResponse = $false
                }
            }
            elseif ($ManualInstallationSelection -eq '3') {
                Write-Host ""
                Write-Host "  ↩️  Returning to main installation menu..." -ForegroundColor Yellow
                Write-Log "User selected to return to main menu from manual installation"
                Write-Host ""
                # This will exit the manual installation block and restart the main menu
                $ValidManualResponse = $true
                $ManualInstallationOption = "RETURN_TO_MAIN"
                break
            }
            else {
                Write-Host ""
                Write-Host "  ❌ Invalid input. Please enter 1, 2, or 3." -ForegroundColor Red
                Write-Host ""
            }
        }
        
        # Handle return to main menu
        if ($ManualInstallationOption -eq "RETURN_TO_MAIN") {
            Write-Host "Restarting main menu..." -ForegroundColor Cyan
            Start-Sleep -Seconds 1
            # The script will continue and reach the email configuration menu
            # To actually return to main menu, we would need to restructure with functions
        }
    }
    elseif ($InstallationModeSelection -eq '3') {
        Write-Host ""
        Write-Host "  ✅ Installation mode selected: CLEANUP / UNINSTALL" -ForegroundColor Yellow
        Write-Host "     Cleanup process will proceed..." -ForegroundColor Gray
        Write-Log "User selected installation mode = CLEANUP (option 3)"
        $ValidInstallationModeResponse = $true
        $InstallationMode = "CLEANUP"
        
        # ============================================================================
        # CLEANUP / UNINSTALL CONFIRMATION
        # ============================================================================
        
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                    ⚠️  CLEANUP / UNINSTALL WARNING ⚠️                          ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  This process will PERMANENTLY REMOVE:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  ❌ Dualog Connection Suite software" -ForegroundColor Red
        Write-Host "  ❌ All Dualog services" -ForegroundColor Red
        Write-Host "  ❌ Oracle Database XE installation" -ForegroundColor Red
        Write-Host "  ❌ All configuration files" -ForegroundColor Red
        Write-Host "  ❌ Registry entries" -ForegroundColor Red
        Write-Host "  ❌ Environment variables" -ForegroundColor Red
        Write-Host ""
        Write-Host "  ⚠️  WARNING: This action CANNOT be undone!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        
        $CleanupConfirmation = $null
        $ValidCleanupResponse = $false
        
        while (-not $ValidCleanupResponse) {
            Write-Host "Do you want to proceed with CLEANUP / UNINSTALL?" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  [Y] Yes - Proceed with complete removal (THIS CANNOT BE UNDONE)" -ForegroundColor Red
            Write-Host "  [N] No  - Cancel and return to main menu" -ForegroundColor Yellow
            Write-Host ""
            $CleanupConfirmation = Read-Host "Enter your choice (Y/N)"
            
            if ($CleanupConfirmation -eq 'Y' -or $CleanupConfirmation -eq 'y') {
                Write-Host ""
                Write-Host "✅ User confirmed: Proceeding with CLEANUP / UNINSTALL" -ForegroundColor Green
                Write-Log "User confirmed cleanup and uninstall process"
                $ValidCleanupResponse = $true
            }
            elseif ($CleanupConfirmation -eq 'N' -or $CleanupConfirmation -eq 'n') {
                Write-Host ""
                Write-Host "❌ Cleanup cancelled by user" -ForegroundColor Yellow
                Write-Log "User cancelled cleanup and uninstall process"
                Write-Host ""
                Write-Host "Returning to main menu..." -ForegroundColor Cyan
                Start-Sleep -Seconds 2
                exit 0
            }
            else {
                Write-Host ""
                Write-Host "Invalid input. Please enter Y (Yes) or N (No)." -ForegroundColor Red
                Write-Host ""
            }
        }
    }
    elseif ($InstallationModeSelection -eq '4') {
        Write-Host ""
        Write-Host "  ⚠️  Exit selected by user" -ForegroundColor Yellow
        Write-Log "User selected to exit installer (option 4)"
        Write-Host ""
        Write-Host "  The installer will now exit without making any changes." -ForegroundColor White
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }
    else {
        Write-Host ""
        Write-Host "  ❌ Invalid input. Please enter 1, 2, 3, or 4." -ForegroundColor Red
        Write-Host ""
    }
}

# ============================================================================
# CHECK IF CLEANUP MODE - IF YES, EXECUTE CLEANUP AND EXIT
# ============================================================================

if ($InstallationMode -eq "CLEANUP") {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    Starting Cleanup Process..." -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Call the cleanup function
    Invoke-DualogCleanup
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "                   ✅ CLEANUP COMPLETED SUCCESSFULLY ✅" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "The system has been cleaned. Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else {
    # Only show email configuration for installation modes (not cleanup)
    
# ============================================================================
# EMAIL FORMAT SELECTION - ONLY RUNS FOR INSTALLATION MODES
# ============================================================================

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ============================================================================

# ============================================================================
# EMAIL FORMAT SELECTION PROMPT - SECOND MENU
# ============================================================================

# EMAIL FORMAT SELECTION PROMPT - INSERTED SECTION
# ============================================================================

Write-Host ""
Write-Host "┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│                   📧 EMAIL FOLDER CONFIGURATION 📧                          │" -ForegroundColor Cyan
Write-Host "│                                                                             │" -ForegroundColor Cyan
Write-Host "│  The system needs to know which email naming format to use for creating    │" -ForegroundColor Cyan
Write-Host "│  folder structures. Please select one:                                     │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ℹ️  EMAIL FORMAT SELECTION" -ForegroundColor White
Write-Host ""
Write-Host "  What format is your vessel's email address in?" -ForegroundColor White
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "  │                                                                         │" -ForegroundColor Gray
Write-Host "  │  [1] IMO NUMBER FORMAT                                                 │" -ForegroundColor Green
Write-Host "  │      └─ Example: imo@vessel.example.com                                │" -ForegroundColor Gray
Write-Host "  │      └─ Folder structure: IMO_1234567                                  │" -ForegroundColor Gray
Write-Host "  │      └─ Use this if email username is the vessel's IMO number         │" -ForegroundColor Gray
Write-Host "  │                                                                         │" -ForegroundColor Gray
Write-Host "  │  [2] VESSEL NAME FORMAT                                                │" -ForegroundColor Green
Write-Host "  │      └─ Example: msc-gulsun@vessel.example.com                        │" -ForegroundColor Gray
Write-Host "  │      └─ Folder structure: VESSEL_NAME                                 │" -ForegroundColor Gray
Write-Host "  │      └─ Use this if email username is the vessel's name               │" -ForegroundColor Gray
Write-Host "  │                                                                         │" -ForegroundColor Gray
Write-Host "  └─────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
Write-Host ""
Write-Host "  📌 Which format should be used for email folders?" -ForegroundColor Cyan
Write-Host ""

# Initialize variable for email format selection
$EmailFormatSelection = $null
$ValidEmailFormatResponse = $false
$EmailFormat = "IMO"  # Default value

while (-not $ValidEmailFormatResponse) {
    $EmailFormatSelection = Read-Host "  Enter your choice (1 or 2)"
    
    if ($EmailFormatSelection -eq '1') {
        Write-Host ""
        Write-Host "  ✅ Email format selected: IMO NUMBER FORMAT" -ForegroundColor Green
        Write-Host "  Folder structures will use IMO number format (e.g., imo_1234567)" -ForegroundColor Gray
        Write-Log "User selected email format = IMO (option 1)"
        $ValidEmailFormatResponse = $true
        $EmailFormat = "IMO"
    }
    elseif ($EmailFormatSelection -eq '2') {
        Write-Host ""
        Write-Host "  ✅ Email format selected: VESSEL NAME FORMAT" -ForegroundColor Green
        Write-Host "  Folder structures will use vessel name format (e.g., msc_gulsun)" -ForegroundColor Gray
        Write-Log "User selected email format = Vessel Name (option 2)"
        
        Write-Host ""
        Write-Host "  📋 VESSEL NAME INPUT REQUIRED" -ForegroundColor Cyan
        Write-Host "  Please enter the vessel name to use for folder creation:" -ForegroundColor White
        Write-Host ""
        
        $VesselName = $null
        $ValidVesselNameResponse = $false
        
        while (-not $ValidVesselNameResponse) {
            $VesselName = Read-Host "  Enter vessel name"
            
            if ([string]::IsNullOrWhiteSpace($VesselName)) {
                Write-Host ""
                Write-Host "  ❌ Vessel name cannot be empty. Please try again." -ForegroundColor Red
                Write-Host ""
            }
            else {
                # Sanitize vessel name (remove special characters, replace spaces/dashes with underscores)
                $VesselNameSanitized = $VesselName -replace '[^a-zA-Z0-9_-]', '_'
                
                Write-Host ""
                Write-Host "  ✅ Vessel name entered: $VesselName" -ForegroundColor Green
                Write-Host "  📝 Sanitized name: $VesselNameSanitized" -ForegroundColor Gray
                Write-Host ""
                Write-Log "User entered vessel name = $VesselName (sanitized: $VesselNameSanitized)"
                
                $ValidVesselNameResponse = $true
            }
        }
        
        # ====================================================================
        # INVOKE UpdateFolderCreation.ps1 AUTOMATICALLY
        # ====================================================================
        Write-Host ""
        Write-Host "╔─────────────────────────────────────────────────────────────────────────────╗" -ForegroundColor Cyan
        Write-Host "║              🔄 INVOKING FOLDER CREATION BUILDER 🔄                         ║" -ForegroundColor Cyan
        Write-Host "╚─────────────────────────────────────────────────────────────────────────────╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Preparing to process batch file with vessel name: $VesselNameSanitized" -ForegroundColor Cyan
        Write-Host ""
        
        try {
            $UpdateFolderCreationScript = Join-Path $ScriptDir "UpdateFolderCreation.ps1"
            
            # Check if the script exists
            if (-not (Test-Path $UpdateFolderCreationScript)) {
                throw "UpdateFolderCreation.ps1 not found at: $UpdateFolderCreationScript"
            }
            
            Write-Log "Starting UpdateFolderCreation.ps1 with vessel name: $VesselNameSanitized"
            
            # Create embedded script content with vessel name passed
            $UpdateFolderContent = @"
# FolderCreation-Builder.ps1 - Auto-invoked by main installer

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

# Define paths - using installer directory passed from main script
`$scriptDir = "$ScriptDir"
`$sourceFile = Join-Path `$scriptDir "RAW.bat"
`$destinationFile = Join-Path `$scriptDir "FolderCreation.bat"
`$logFile = Join-Path `$scriptDir "FolderCreation.summary.txt"

# Replacement text (passed from main installer)
`$replacement = "$VesselNameSanitized"

try {
    if (-not (Test-Path `$sourceFile)) {
        throw "Source file not found: `$sourceFile"
    }

    Write-Host ""
    Write-Host "Processing RAW.bat with replacement text: `$replacement" -ForegroundColor Cyan
    Write-Host ""

    # Read full content of the batch file
    `$content = Get-Content -Path `$sourceFile -Raw

    # Count how many "imo" words appear (case-insensitive)
    `$matchCount = ([regex]::Matches(`$content, '\bimo\b', 'IgnoreCase')).Count

    if (`$matchCount -gt 0) {
        # Replace all occurrences of "imo" with replacement text
        `$updated = [regex]::Replace(`$content, '\bimo\b', `$replacement, 'IgnoreCase')

        # Save the modified batch file
        Set-Content -Path `$destinationFile -Value `$updated -Encoding UTF8

        # Display summary
        Write-Host "✅ Batch file processing completed." -ForegroundColor Green
        Write-Host "➡️  `$matchCount occurrences of 'imo' were replaced with '`$replacement'." -ForegroundColor Green
        Write-Host "💾 Output file: `$destinationFile" -ForegroundColor Green
        Write-Host ""

        # Also log it to a text file
        `$summary = @(
            "Folder Creation Processing Summary:"
            "Date: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "Source: `$sourceFile"
            "Destination: `$destinationFile"
            "Occurrences replaced: `$matchCount"
            "Replacement text: `$replacement"
            "Triggered by: Email format selection (Vessel Name)"
        ) -join [Environment]::NewLine

        Set-Content -Path `$logFile -Value `$summary -Encoding UTF8
        Write-Host "📝 Summary saved to: `$logFile" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  No occurrences of 'imo' found in `$sourceFile." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Error processing batch file: `$(`$_.Exception.Message)" -ForegroundColor Red
    throw
}
"@

            # Save the temporary script to a file and execute it
            $TempScriptPath = Join-Path $env:TEMP "UpdateFolderCreation_Temp.ps1"
            Set-Content -Path $TempScriptPath -Value $UpdateFolderContent -Encoding UTF8
            
            Write-Log "Executing UpdateFolderCreation with vessel name: $VesselNameSanitized"
            
            # Execute the script with error handling
            & $TempScriptPath
            
            # Verify the output file was created
            $FolderCreationBatPath = Join-Path $ScriptDir "FolderCreation.bat"
            if (Test-Path $FolderCreationBatPath) {
                Write-Host ""
                Write-Host "✅ FolderCreation.bat successfully created" -ForegroundColor Green
                Write-Log "FolderCreation.bat successfully created with vessel name format"
            }
            else {
                Write-Host ""
                Write-Host "⚠️  Warning: FolderCreation.bat was not created" -ForegroundColor Yellow
                Write-Log "Warning: FolderCreation.bat was not created" -Level Warning
            }
            
            # Clean up temporary script
            Remove-Item -Path $TempScriptPath -Force -ErrorAction SilentlyContinue
            
            Write-Host ""
            Write-Host "╔─────────────────────────────────────────────────────────────────────────────╗" -ForegroundColor Green
            Write-Host "║                    ✅ BATCH FILE PROCESSING COMPLETED ✅                     ║" -ForegroundColor Green
            Write-Host "╚─────────────────────────────────────────────────────────────────────────────╝" -ForegroundColor Green
            Write-Host ""
            Write-Host "Continuing with main installation process..." -ForegroundColor Cyan
            Write-Host ""
            Write-Log "Batch file processing completed - resuming main installation"
            
        }
        catch {
            Write-Host ""
            Write-Host "╔─────────────────────────────────────────────────────────────────────────────╗" -ForegroundColor Red
            Write-Host "║                  ❌ BATCH FILE PROCESSING FAILED ❌                          ║" -ForegroundColor Red
            Write-Host "╚─────────────────────────────────────────────────────────────────────────────╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Error during batch file processing: $($_.Exception.Message)" -Level Error
            Write-Host ""
            Write-Host "The installation will continue, but folder creation may use default IMO format." -ForegroundColor Yellow
            Write-Host ""
            Write-Log "Installation continuing despite batch file processing error"
        }
        
        $ValidEmailFormatResponse = $true
        $EmailFormat = "VesselName"
    }
    else {
        Write-Host ""
        Write-Host "  ❌ Invalid input. Please enter 1 (IMO Format) or 2 (Vessel Name Format)." -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Check if launched via UNC path
if ($ScriptDir -like "\\*") {
    Write-Log "Installation aborted due to launch via UNC path" -Level Error
    Write-Log "Detected UNC path = $ScriptDir" -Level Error
    Write-Host ""
    Write-Host "Error: UNC path detected - this installation script must be run from a local or mapped drive" -ForegroundColor Red
    Write-Host ""
    Write-Host "This process will now end due to being launched via a UNC path"
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Change to script directory
Set-Location $ScriptDir
Write-Log "Current directory = $(Get-Location)"

# Check disk space
if ($FreeSpaceGB -lt 50) {
    Write-Host ""
    Write-Host "WARNING: Free space on drive C: is below 50 GB" -ForegroundColor Yellow
    $Response = Read-Host "Continue installation? (Y/N) [Default: Y, auto-continues in 20 seconds]"
    
    if ($Response -eq 'N' -or $Response -eq 'n') {
        Write-Log "User aborted installation when warned about low free space on drive C:" -Level Warning
        Write-Host "Installation cancelled by user."
        Start-Sleep -Seconds 5
        exit 1
    }
    Write-Log "Continuing after warning about low free space on drive C:"
}

# Check for required files
Write-Host ""
Write-Host "Checking for required files..."

$RequiredFiles = @{
    $CSInstallerFile = "Dualog Connection Suite Ship unattended installer"
    $CSUASettingsFile = "Unattended installer automatic response file"
    $CSStartPackFile = "Vessel-specific configuration file"
    $CSFolderCreatorFile = "E-Mail folder creation script"
    $OraclePortChangerFile = "Oracle HTTP port change script"
}

$MissingFiles = @()

foreach ($File in $RequiredFiles.Keys) {
    $FilePath = Join-Path $ScriptDir $File
    
    if (Test-Path $FilePath) {
        Write-Host "File detected    : $File ($($RequiredFiles[$File]))"
        Write-Log "Required file detected = $File"
    }
    else {
        $MissingFiles += $File
        Write-Host "Missing file     : $File" -ForegroundColor Red
        Write-Log "Missing required file = $File" -Level Error
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "=============================" -ForegroundColor Red
    Write-Host "Error : Required file missing" -ForegroundColor Red
    Write-Host "=============================" -ForegroundColor Red
    Write-Host "Folder       : $ScriptDir"
    Write-Host "Missing files:"
    foreach ($File in $MissingFiles) {
        Write-Host "  - $File" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "This process will now end due to one or more missing files"
    Write-Log "Installation aborted due to missing files: $($MissingFiles -join ', ')" -Level Error
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host "All required files detected - proceeding"
Write-Log "All required files detected - proceeding"

# Check port conflicts
Write-Host ""
Write-Host "Checking local use of required IP ports..."
Write-Host ""

$PortsToCheck = @(
    @{Port = 444; Description = "Dualog HTTP"; Critical = $false},
    @{Port = 465; Description = "Dualog SMTP"; Critical = $false},
    @{Port = 993; Description = "Dualog IMAP"; Critical = $false},
    @{Port = 995; Description = "Dualog POP"; Critical = $false},
    @{Port = 389; Description = "Dualog LDAP"; Critical = $false},
    @{Port = 1521; Description = "Oracle TNS Listener"; Critical = $true},
    @{Port = 8081; Description = "Oracle HTTP Listener"; Critical = $true},
    @{Port = 4444; Description = "Oracle HTTP Listener - Post Installation"; Critical = $true},
    @{Port = 2031; Description = "Oracle Transaction Server"; Critical = $false}
)

$PortConflict = $false
$CriticalPortInUse = $false

foreach ($PortInfo in $PortsToCheck) {
    $InUse = Test-PortInUse -Port $PortInfo.Port -Description $PortInfo.Description
    
    if ($InUse) {
        Write-Host "Warning - possible existing use of IP port $($PortInfo.Port) ($($PortInfo.Description)) detected" -ForegroundColor Yellow
        $PortConflict = $true
        
        if ($PortInfo.Critical) {
            Write-Host "Warning - cannot continue because $($PortInfo.Port) ($($PortInfo.Description)) is critical for installation" -ForegroundColor Red
            $CriticalPortInUse = $true
        }
    }
}

if ($CriticalPortInUse) {
    Write-Host ""
    [System.Console]::Beep(800, 300)
    Write-Host "ERROR: One or more critical IP ports are already in use - the installation cannot continue" -ForegroundColor Red
    Write-Log "ERROR: One or more critical IP ports are already in use - the installation cannot continue" -Level Error
    Write-Host ""
    Write-Host "This script will terminate in 180 seconds - press any key to terminate immediately"
    $timeout = New-TimeSpan -Seconds 180
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($stopwatch.Elapsed -lt $timeout) {
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            break
        }
        Start-Sleep -Milliseconds 100
    }
    exit 1
}

if ($PortConflict) {
    Write-Host ""
    Write-Host "WARNING: One or more potential IP port conflicts were detected" -ForegroundColor Yellow
    $Response = Read-Host "Continue installation? (Y/N) [Default: Y, auto-continues in 20 seconds]"
    
    if ($Response -eq 'N' -or $Response -eq 'n') {
        Write-Log "User aborted installation when warned about potential IP port conflicts" -Level Warning
        Write-Host "Installation cancelled by user."
        Start-Sleep -Seconds 5
        exit 1
    }
    Write-Log "Continuing after warning about potential IP port conflicts"
}
else {
    Write-Host "No IP port conflicts detected"
    Write-Log "No IP port conflicts detected"
}

# Create firewall rules for Apache BEFORE installation
Write-Host ""
Write-Host "Configuring Windows Firewall for Apache HTTP Server..." -ForegroundColor Cyan
Write-Log "Creating pre-emptive firewall rules for Apache HTTP Server only"

try {
    # Create port-based rules for Apache BEFORE it starts
    # This prevents the firewall prompt from appearing
    # ONLY for Apache HTTP Server - no other services
    
    # Remove any existing Apache rules
    Remove-NetFirewallRule -DisplayName "*Apache*" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "*httpd*" -ErrorAction SilentlyContinue
    
    # Allow httpd.exe by program path (all possible paths)
    # This is the CRITICAL part that prevents the firewall prompt!
    $ApachePrograms = @(
        "C:\dualog\connectionsuite\web\apache\bin\httpd.exe",
        "C:\dualog\oraclexe\app\oracle\product\11.2.0\server\Apache\Apache\bin\httpd.exe",
        "C:\dualog\Apache\Apache\bin\httpd.exe"
    )
    
    foreach ($ApachePath in $ApachePrograms) {
        New-NetFirewallRule -DisplayName "Apache HTTP Server - $ApachePath (Dualog)" `
                            -Description "Allow Apache HTTP Server at $ApachePath for Dualog Connection Suite" `
                            -Direction Inbound `
                            -Program $ApachePath `
                            -Action Allow `
                            -Profile Any `
                            -Enabled True `
                            -ErrorAction SilentlyContinue | Out-Null
    }
    
    Write-Host "✓ Firewall rules created for Apache HTTP Server (program-based only)" -ForegroundColor Green
    Write-Log "Created pre-emptive firewall rules for Apache only - NO PORT-BASED RULES, NO OTHER SERVICES"
}
catch {
    Write-Log "Warning creating Apache firewall rules: $_" -Level Warning
    Write-Host "⚠ Could not create firewall rules (Apache may prompt during installation)" -ForegroundColor Yellow
}

# Begin installation
Write-Host ""
Write-Host "Installing the Connection Suite Ship software (this might take up to 30 minutes)..."
Write-Host ""
Write-Host "*** Please do not close or interact with this window ***" -ForegroundColor Yellow

$InstallerPath = Join-Path $ScriptDir $CSInstallerFile
$UASettingsPath = Join-Path $ScriptDir $CSUASettingsFile

Write-Log "Starting Connection Suite Ship installer $CSInstallerFile with arg -uafile=.\$CSUASettingsFile"

try {
    # Start the installer process
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList "-uafile=.\$CSUASettingsFile" -PassThru -NoNewWindow
    
    # Monitor installation progress
    $MaxWaitMinutes = 35  # Maximum expected installation time
    $MaxWaitSeconds = $MaxWaitMinutes * 60
    $ElapsedSeconds = 0
    $CheckInterval = 2  # Check every 2 seconds
    
    Write-Host ""
    Write-Host "Monitoring installation progress..." -ForegroundColor Cyan
    Write-Host ""
    
    while (!$Process.HasExited -and $ElapsedSeconds -lt $MaxWaitSeconds) {
        # Calculate progress percentage
        $PercentComplete = [math]::Min(100, [math]::Round(($ElapsedSeconds / $MaxWaitSeconds) * 100))
        
        # Determine current stage based on elapsed time
        $Stage = ""
        if ($ElapsedSeconds -lt 120) {
            $Stage = "Initializing installation..."
        }
        elseif ($ElapsedSeconds -lt 300) {
            $Stage = "Extracting files..."
        }
        elseif ($ElapsedSeconds -lt 600) {
            $Stage = "Installing core components..."
        }
        elseif ($ElapsedSeconds -lt 900) {
            $Stage = "Configuring database..."
        }
        elseif ($ElapsedSeconds -lt 1200) {
            $Stage = "Installing services..."
        }
        elseif ($ElapsedSeconds -lt 1500) {
            $Stage = "Registering components..."
        }
        else {
            $Stage = "Finalizing installation..."
        }
        
        # Calculate time remaining
        $TimeRemainingSeconds = [math]::Max(0, ($MaxWaitSeconds - $ElapsedSeconds))
        $TimeRemaining = [TimeSpan]::FromSeconds($TimeRemainingSeconds)
        
        # Display progress bar
        Write-Progress -Activity "Installing Dualog Connection Suite Ship" `
                       -Status "$Stage ($([math]::Round($ElapsedSeconds / 60, 1)) of $MaxWaitMinutes minutes)" `
                       -PercentComplete $PercentComplete `
                       -SecondsRemaining $TimeRemainingSeconds
        
        Start-Sleep -Seconds $CheckInterval
        $ElapsedSeconds += $CheckInterval
    }
    
    # Wait for process to complete if still running
    if (!$Process.HasExited) {
        Write-Progress -Activity "Installing Dualog Connection Suite Ship" `
                       -Status "Waiting for installer to complete..." `
                       -PercentComplete 99
        $Process.WaitForExit()
    }
    
    # Complete the progress bar
    Write-Progress -Activity "Installing Dualog Connection Suite Ship" `
                   -Status "Installation completed" `
                   -PercentComplete 100 `
                   -Completed
    
    $ExitCode = $Process.ExitCode
    $ActualTimeMinutes = [math]::Round($ElapsedSeconds / 60, 1)
    
    Write-Host ""
    Write-Host "Installation completed in $ActualTimeMinutes minutes" -ForegroundColor Green
    Write-Log "Connection Suite Ship installer return code (exit code) = $ExitCode"
    Write-Log "Installation took $ActualTimeMinutes minutes"
    
    if ($ExitCode -ne 0) {
        Write-Host "Warning: Installer returned exit code $ExitCode" -ForegroundColor Yellow
        Write-Log "Installer returned non-zero exit code: $ExitCode" -Level Warning
    }
}
catch {
    Write-Progress -Activity "Installing Dualog Connection Suite Ship" -Completed
    Write-Log "Error running installer: $_" -Level Error
    Write-Host "Error running installer: $_" -ForegroundColor Red
}

# Create default folders (AESM) with enhanced logging
Write-Host ""
Write-Host "Creating default folders (AESM) with enhanced logging..."
Write-Progress -Activity "Post-Installation Configuration" -Status "Creating email folders..." -PercentComplete 10

$SQLPlusExe = Join-Path $OracleSQLPlusPath "sqlplus.exe"

if (Test-Path $SQLPlusExe) {
    Write-Log "File sqlplus.exe detected in folder $OracleSQLPlusPath"
    
    # Create the results log directory if it doesn't exist
    $ResultLogPath = "C:\Dualog\installer"
    if (-not (Test-Path $ResultLogPath)) {
        New-Item -ItemType Directory -Path $ResultLogPath -Force | Out-Null
        Write-Log "Created directory for results log: $ResultLogPath"
    }
    
    # Define the result log file
    $ResultLogFile = Join-Path $ResultLogPath "FolderCreation_Result.log"
    
    # Initialize the result log
    $LogHeader = @"
================================================================================
DUALOG EMAIL FOLDER CREATION RESULT LOG
================================================================================
Date/Time Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Vessel/IMO: $VesselNameSanitized
Script Directory: $ScriptDir
Oracle SQL*Plus Path: $OracleSQLPlusPath
================================================================================

"@
    Set-Content -Path $ResultLogFile -Value $LogHeader -Encoding UTF8
    
    # Change to Oracle directory
    Push-Location $OracleSQLPlusPath
    Write-Log "Current folder now changed to $(Get-Location)"
    
    # Run folder creator script with output capture
    $FolderCreatorPath = Join-Path $ScriptDir $CSFolderCreatorFile
    Write-Log "Starting AESM folder creator '$FolderCreatorPath' with detailed logging"
    
    Write-Progress -Activity "Post-Installation Configuration" -Status "Running folder creation script (this may take several minutes)..." -PercentComplete 30
    Write-Host "Creating default email folders with detailed logging..." -ForegroundColor Cyan
    Write-Host "Results will be logged to: $ResultLogFile" -ForegroundColor Yellow
    
    try {
        # Create a more comprehensive process to capture all output
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "cmd.exe"
        $ProcessInfo.Arguments = "/c `"$FolderCreatorPath`" 2>&1"
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $ProcessInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $ProcessInfo.WorkingDirectory = $OracleSQLPlusPath
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        
        # Start the process
        $Process.Start() | Out-Null
        
        # Capture all output
        $OutputBuilder = New-Object System.Text.StringBuilder
        $StderrBuilder = New-Object System.Text.StringBuilder
        
        # Read output streams
        while (!$Process.HasExited) {
            $line = $Process.StandardOutput.ReadLine()
            if ($line -ne $null) {
                $OutputBuilder.AppendLine($line) | Out-Null
            }
        }
        
        # Get remaining output
        $remainingOutput = $Process.StandardOutput.ReadToEnd()
        $remainingError = $Process.StandardError.ReadToEnd()
        
        if ($remainingOutput) {
            $OutputBuilder.Append($remainingOutput) | Out-Null
        }
        if ($remainingError) {
            $StderrBuilder.Append($remainingError) | Out-Null
        }
        
        $ExitCode = $Process.ExitCode
        
        # Parse the output to identify created folders
        $CapturedOutput = $OutputBuilder.ToString()
        $CapturedError = $StderrBuilder.ToString()
        
        # Log the execution details
        Add-Content -Path $ResultLogFile -Value @"

EXECUTION DETAILS:
--------------------------------------------------------------------------------
Script Executed: $FolderCreatorPath
Exit Code: $ExitCode
Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@ -Encoding UTF8
        
        # Analyze the output for folder creation results
        $FolderCreationResults = @{
            Success = @()
            Failed = @()
            Unknown = @()
        }
        
        # Parse SQL output for folder creation indicators
        $FolderList = @(
            "Administrator", "Certificates", "Change of Command", "Circulars",
            "Company", "Finance", "Insurance", "Internal Mails",
            "Management", "Manning", "NoonReport", "Operations",
            "PersonalMails", "Photos", "Plans", "Procurement",
            "QHSE", "Reports", "Store", "Technical", "Training", "Voyage"
        )
        
        # Check for successful folder creation patterns in output
        foreach ($folder in $FolderList) {
            if ($CapturedOutput -match "(?i)$folder.*created|creating.*$folder|insert.*$folder") {
                $FolderCreationResults.Success += $folder
            }
            elseif ($CapturedOutput -match "(?i)$folder.*exists|$folder.*already") {
                $FolderCreationResults.Success += "$folder (already exists)"
            }
            elseif ($CapturedOutput -match "(?i)$folder.*error|failed.*$folder") {
                $FolderCreationResults.Failed += $folder
            }
        }
        
        # Check for Oracle/SQL errors
        $OracleErrors = @()
        if ($CapturedOutput -match "ORA-\d+") {
            $matches = [regex]::Matches($CapturedOutput, "ORA-\d+[^\n]*")
            foreach ($match in $matches) {
                $OracleErrors += $match.Value
            }
        }
        
        # Write detailed results to log
        Add-Content -Path $ResultLogFile -Value @"

FOLDER CREATION RESULTS:
================================================================================

SUCCESSFULLY CREATED/VERIFIED FOLDERS:
----------------------------------------
"@ -Encoding UTF8
        
        if ($FolderCreationResults.Success.Count -gt 0) {
            foreach ($folder in $FolderCreationResults.Success) {
                Add-Content -Path $ResultLogFile -Value "✓ $folder" -Encoding UTF8
            }
        }
        else {
            Add-Content -Path $ResultLogFile -Value "(No folders confirmed as created)" -Encoding UTF8
        }
        
        Add-Content -Path $ResultLogFile -Value @"

FAILED TO CREATE:
----------------------------------------
"@ -Encoding UTF8
        
        if ($FolderCreationResults.Failed.Count -gt 0) {
            foreach ($folder in $FolderCreationResults.Failed) {
                Add-Content -Path $ResultLogFile -Value "✗ $folder" -Encoding UTF8
            }
        }
        else {
            Add-Content -Path $ResultLogFile -Value "(No failures detected)" -Encoding UTF8
        }
        
        # Add Oracle errors if any
        if ($OracleErrors.Count -gt 0) {
            Add-Content -Path $ResultLogFile -Value @"

ORACLE/DATABASE ERRORS:
----------------------------------------
"@ -Encoding UTF8
            foreach ($error in $OracleErrors) {
                Add-Content -Path $ResultLogFile -Value "• $error" -Encoding UTF8
            }
        }
        
        # Add summary
        $SuccessCount = $FolderCreationResults.Success.Count
        $FailureCount = $FolderCreationResults.Failed.Count
        $TotalExpected = $FolderList.Count
        
        Add-Content -Path $ResultLogFile -Value @"

================================================================================
SUMMARY:
================================================================================
Total Folders Expected: $TotalExpected
Successfully Created/Verified: $SuccessCount
Failed: $FailureCount
Exit Code: $ExitCode
Status: $(if ($ExitCode -eq 0) { "COMPLETED" } else { "COMPLETED WITH WARNINGS/ERRORS" })
================================================================================

DETAILED OUTPUT LOG:
--------------------------------------------------------------------------------
$CapturedOutput
--------------------------------------------------------------------------------

"@ -Encoding UTF8
        
        if ($CapturedError) {
            Add-Content -Path $ResultLogFile -Value @"
ERROR OUTPUT:
--------------------------------------------------------------------------------
$CapturedError
--------------------------------------------------------------------------------

"@ -Encoding UTF8
        }
        
        # Add completion timestamp
        Add-Content -Path $ResultLogFile -Value @"
================================================================================
Folder Creation Process Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Log File Location: $ResultLogFile
================================================================================
"@ -Encoding UTF8
        
        # Display summary to console
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "FOLDER CREATION SUMMARY:" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "• Total Folders Expected: $TotalExpected" -ForegroundColor White
        Write-Host "• Successfully Created/Verified: $SuccessCount" -ForegroundColor Green
        Write-Host "• Failed: $FailureCount" -ForegroundColor $(if ($FailureCount -eq 0) { "Green" } else { "Yellow" })
        Write-Host "• Exit Code: $ExitCode" -ForegroundColor $(if ($ExitCode -eq 0) { "Green" } else { "Yellow" })
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📄 Detailed results saved to:" -ForegroundColor Yellow
        Write-Host "   $ResultLogFile" -ForegroundColor Cyan
        Write-Host ""
        
        # Log to main installation log
        Write-Log "Folder creator return code = $ExitCode"
        Write-Log "Folder creation summary: $SuccessCount succeeded, $FailureCount failed out of $TotalExpected expected"
        Write-Log "Detailed results saved to: $ResultLogFile"
        
        if ($ExitCode -ne 0) {
            Write-Log "Folder creator returned non-zero exit code: $ExitCode" -Level Warning
            $FolderCreationFailed = $true
            Write-Host "⚠ Folder creation completed with warnings (Exit Code: $ExitCode)" -ForegroundColor Yellow
        }
        else {
            Write-Host "✓ Folder creation completed successfully" -ForegroundColor Green
        }
        
        Write-Progress -Activity "Post-Installation Configuration" -Status "Folder creation completed" -PercentComplete 50
    }
    catch {
        $ErrorMsg = $_.Exception.Message
        $FolderCreationFailed = $true
        Write-Log "Error running folder creator: $ErrorMsg" -Level Error
        Write-Host "⚠ Error running folder creator: $ErrorMsg" -ForegroundColor Yellow
        
        # Still create an error log
        Add-Content -Path $ResultLogFile -Value @"

================================================================================
CRITICAL ERROR DURING EXECUTION:
================================================================================
Error: $ErrorMsg
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

The folder creation process encountered an unexpected error.
Please check the Oracle database connection and retry after system restart.
================================================================================
"@ -Encoding UTF8
        
        Write-Host "📄 Error details saved to: $ResultLogFile" -ForegroundColor Red
        Write-Progress -Activity "Post-Installation Configuration" -Status "Error in folder creation" -PercentComplete 50
    }
    # Configure Oracle HTTP port
    Write-Host ""
    Write-Host "Configuring Oracle HTTP port..."
    Write-Progress -Activity "Post-Installation Configuration" -Status "Configuring Oracle HTTP port..." -PercentComplete 60
    
    $OraclePortChangerPath = Join-Path $ScriptDir $OraclePortChangerFile
    Write-Log "Starting Oracle HTTP port changer '$OraclePortChangerPath'"
    
    try {
        # Run the batch file with output completely suppressed
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "cmd.exe"
        $ProcessInfo.Arguments = "/c `"$OraclePortChangerPath`" >nul 2>&1"
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $ProcessInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $ProcessInfo.WorkingDirectory = $OracleSQLPlusPath
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null
        
        # Drain output streams to prevent any output from appearing
        $stdout = $Process.StandardOutput.ReadToEndAsync()
        $stderr = $Process.StandardError.ReadToEndAsync()
        
        # Wait for completion with timeout (2 minutes max)
        $Completed = $Process.WaitForExit(120000)  # 120 seconds = 2 minutes
        
        if (-not $Completed) {
            Write-Log "Oracle port changer timed out after 2 minutes" -Level Warning
            Write-Host "⚠ Oracle port configuration timed out - will retry after restart" -ForegroundColor Yellow
            $Process.Kill()
            $ExitCode = -1
            $OraclePortConfigFailed = $true
        }
        else {
            $ExitCode = $Process.ExitCode
            Write-Log "Oracle HTTP port changer return code (exit code) = $ExitCode"
            if ($ExitCode -ne 0) {
                Write-Host "⚠ Oracle HTTP port configuration completed with warnings (Exit Code: $ExitCode)" -ForegroundColor Yellow
                $OraclePortConfigFailed = $true
            }
            else {
                Write-Host "✓ Oracle HTTP port configuration completed" -ForegroundColor Green
            }
        }
        
        Write-Progress -Activity "Post-Installation Configuration" -Status "Oracle configuration completed" -PercentComplete 80
    }
    catch {
        Write-Log "Error running Oracle HTTP port changer: $_" -Level Error
        Write-Host "⚠ Error configuring Oracle port (will retry after restart)" -ForegroundColor Yellow
        $OraclePortConfigFailed = $true
        Write-Progress -Activity "Post-Installation Configuration" -Status "Error in Oracle configuration" -PercentComplete 80
    }
    
    # Return to script directory
    Pop-Location

    # Configure Windows Firewall for Apache HTTP Server only
    $ApacheConfigSuccess = Add-ApacheFirewallRule
    if (-not $ApacheConfigSuccess) {
        $ApacheFirewallConfigFailed = $true
    }
}
else {
    Write-Host "The file sqlplus.exe was not detected in folder $OracleSQLPlusPath" -ForegroundColor Yellow
    Write-Log "The file sqlplus.exe was not detected in folder $OracleSQLPlusPath" -Level Warning
    Write-Progress -Activity "Post-Installation Configuration" -Status "SQLPlus not found - skipping folder creation" -PercentComplete 80

    # Still try to configure Apache firewall
    $ApacheConfigSuccess = Add-ApacheFirewallRule
    if (-not $ApacheConfigSuccess) {
        $ApacheFirewallConfigFailed = $true
    }
}

# Create RunOnce registry entries
Write-Host ""
Write-Host "Creating registry entries for post-reboot tasks..."
Write-Progress -Activity "Post-Installation Configuration" -Status "Creating registry entries..." -PercentComplete 90

$FolderCreatorPath = Join-Path $ScriptDir $CSFolderCreatorFile
$OraclePortChangerPath = Join-Path $ScriptDir $OraclePortChangerFile
$ApacheFirewallScriptPath = Create-ApacheFirewallScript

try {
    # Clean up any old RunOnce entries first
    $RunOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    try {
        Remove-ItemProperty -Path $RunOncePath -Name "CreateAESMFolders" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RunOncePath -Name "ConfigureOracleHTTPPort" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RunOncePath -Name "ConfigureApacheFirewall" -ErrorAction SilentlyContinue
        Write-Log "Cleaned up old RunOnce registry entries"
    }
    catch {
        Write-Log "No old RunOnce entries found to clean up (this is normal)"
    }

    # Only create folder creation RunOnce task if it failed during installation
    if ($FolderCreationFailed) {
        Write-Log "Folder creation failed during installation - Creating 'runonce' registry entry for '$FolderCreatorPath'"
        New-ItemProperty -Path $RunOncePath `
                         -Name "CreateAESMFolders" `
                         -Value "`"$FolderCreatorPath`"" `
                         -PropertyType String `
                         -Force | Out-Null
        Write-Host "  • Folder creation task registered for post-reboot execution" -ForegroundColor Yellow
    }
    else {
        Write-Log "Folder creation succeeded during installation - Skipping RunOnce registry entry"
        Write-Host "  • Folder creation completed successfully during installation" -ForegroundColor Green
    }

    # Only create Oracle port config RunOnce task if it failed during installation
    if ($OraclePortConfigFailed) {
        Write-Log "Oracle port configuration failed during installation - Creating 'runonce' registry entry for '$OraclePortChangerPath'"
        New-ItemProperty -Path $RunOncePath `
                         -Name "ConfigureOracleHTTPPort" `
                         -Value "`"$OraclePortChangerPath`"" `
                         -PropertyType String `
                         -Force | Out-Null
        Write-Host "  • Oracle HTTP port configuration task registered for post-reboot execution" -ForegroundColor Yellow
    }
    else {
        Write-Log "Oracle port configuration succeeded during installation - Skipping RunOnce registry entry"
        Write-Host "  • Oracle HTTP port configuration completed successfully during installation" -ForegroundColor Green
    }

    # Only create Apache firewall RunOnce task if it failed during installation
    if ($ApacheFirewallConfigFailed) {
        Write-Log "Apache firewall configuration failed during installation - Creating 'runonce' registry entry for Apache firewall"
        New-ItemProperty -Path $RunOncePath `
                         -Name "ConfigureApacheFirewall" `
                         -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ApacheFirewallScriptPath`"" `
                         -PropertyType String `
                         -Force | Out-Null
        Write-Host "  • Apache firewall configuration task registered for post-reboot execution" -ForegroundColor Yellow
    }
    else {
        Write-Log "Apache firewall configuration succeeded during installation - Skipping RunOnce registry entry"
        Write-Host "  • Apache firewall configuration completed successfully during installation" -ForegroundColor Green
    }

    Write-Host "Registry entries created successfully" -ForegroundColor Green
    Write-Log "Created RunOnce registry entries"
    Write-Progress -Activity "Post-Installation Configuration" -Status "Registry entries created" -PercentComplete 100 -Completed
}
catch {
    Write-Log "Error creating registry entries: $_" -Level Error
    Write-Host "Error creating registry entries: $_" -ForegroundColor Red
    Write-Progress -Activity "Post-Installation Configuration" -Completed
}

# ============================================================================

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                          ✅ INSTALLATION COMPLETED ✅                            " -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  The Dualog Connection Suite Ship software has been successfully installed!" -ForegroundColor White
Write-Host ""
Write-Host "  📋 Post-installation tasks have been configured to run after restart:" -ForegroundColor Cyan
if (-not $FolderCreationFailed) {
    Write-Host "     ✓ Email folder creation - Completed during installation" -ForegroundColor Green
}
else {
    Write-Host "     • Email folder creation - Will retry after restart" -ForegroundColor Yellow
}
Write-Host "     • Oracle HTTP port configuration" -ForegroundColor White
Write-Host "     • Apache HTTP Server firewall configuration" -ForegroundColor White
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  ⚠️  IMPORTANT FIREWALL NOTIFICATION:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  During the restart or when Apache HTTP Server starts, you MAY see a" -ForegroundColor White
Write-Host "  Windows Defender Firewall notification stating:" -ForegroundColor White
Write-Host ""
Write-Host "  'Windows Defender Firewall has blocked some features of this app'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📌 IF THIS NOTIFICATION APPEARS:" -ForegroundColor White
Write-Host ""
Write-Host "     CLICK 'Allow access' to allow Apache HTTP Server through the firewall" -ForegroundColor Green
Write-Host ""
Write-Host "  ✅ Why this is needed:" -ForegroundColor Cyan
Write-Host "     • Allows the Dualog Connection Suite web interface to function properly" -ForegroundColor White
Write-Host "     • Required for Apache HTTP Server to serve web pages" -ForegroundColor White
Write-Host ""
Write-Host "  ❌ If you click 'Block' or ignore the notification:" -ForegroundColor Red
Write-Host "     • The web interface may become inaccessible" -ForegroundColor Red
Write-Host "     • Users may not be able to connect to the Dualog system" -ForegroundColor Red
Write-Host "     • You will need to manually configure the firewall later" -ForegroundColor Red
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ⚠️  IMPORTANT: A system restart is required to complete the installation" -ForegroundColor Yellow
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green

Write-Log "Operation completed - awaiting user decision on restart"

if ($FolderCreationFailed) {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "                    ⚠️  FOLDER CREATION WARNING ⚠️                             " -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ⚠️  The automatic folder creation encountered errors during installation." -ForegroundColor White
    Write-Host ""
    Write-Host "  📋 ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "     After restarting, you MUST manually run FolderCreation.bat" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📍 Location:" -ForegroundColor Cyan
    Write-Host "     $ScriptDir\FolderCreation.bat" -ForegroundColor White
    Write-Host ""
    Write-Host "  📝 Steps to run manually:" -ForegroundColor Cyan
    Write-Host "     1. Navigate to the installation directory" -ForegroundColor White
    Write-Host "     2. Right-click on 'FolderCreation.bat'" -ForegroundColor White
    Write-Host "     3. Select 'Run as administrator'" -ForegroundColor White
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
}

# Prompt user for restart decision
Write-Host ""
$RestartResponse = $null
$ValidResponse = $false

while (-not $ValidResponse) {
    Write-Host "Do you want to restart the computer now?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [Y] Yes - Restart now (recommended)" -ForegroundColor Green
    Write-Host "  [N] No  - Restart later manually" -ForegroundColor Yellow
    Write-Host ""
    $RestartResponse = Read-Host "Enter your choice (Y/N)"
    
    if ($RestartResponse -eq 'Y' -or $RestartResponse -eq 'y') {
        Write-Host ""
        Write-Host "✅ Restarting computer in 30 seconds..." -ForegroundColor Green
        Write-Host "   Press Ctrl+C to cancel the restart" -ForegroundColor Yellow
        Write-Log "User chose to restart computer immediately"
        
        
        if ($FolderCreationFailed) {
            Write-Host ""
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "                    ⚠️  FOLDER CREATION WARNING ⚠️                             " -ForegroundColor Red
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host ""
            Write-Host "  The automatic folder creation encountered errors during installation." -ForegroundColor White
            Write-Host "  After the computer restarts, please manually run FolderCreation.bat:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Steps to run manually:" -ForegroundColor Cyan
            Write-Host "    1. Navigate to: $ScriptDir" -ForegroundColor White
            Write-Host "    2. Right-click on 'FolderCreation.bat'" -ForegroundColor White
            Write-Host "    3. Select 'Run as administrator'" -ForegroundColor White
            Write-Host ""
            Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
        }
        Start-Sleep -Seconds 5
        
        try {
            Write-Host ""
            Write-Host "Initiating system restart..." -ForegroundColor Cyan
            Start-Sleep -Seconds 25  # Wait to reach 30 seconds total
            Restart-Computer -Force
        }
        catch {
            Write-Log "Error initiating restart: $_" -Level Error
            Write-Host ""
            Write-Host "⚠️  Error initiating automatic restart: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please restart the computer manually to complete the installation." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        $ValidResponse = $true
    }
    elseif ($RestartResponse -eq 'N' -or $RestartResponse -eq 'n') {
        Write-Host ""
        Write-Host "⚠️  Restart postponed" -ForegroundColor Yellow
        Write-Log "User chose to restart computer later manually"
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "                              ⚠️  REMINDER ⚠️                                   " -ForegroundColor Yellow
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Please remember to RESTART the computer manually to complete the installation." -ForegroundColor White
        Write-Host ""
        Write-Host "  Post-installation tasks will run automatically on next restart:" -ForegroundColor Cyan
        Write-Host "     • Email folder creation" -ForegroundColor White
        Write-Host "     • Oracle HTTP port configuration (changing from 8081 to 4444)" -ForegroundColor White
        Write-Host "     • Apache HTTP Server firewall configuration" -ForegroundColor White
        Write-Host ""
        Write-Host "  📌 IMPORTANT - Windows Firewall Notification:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "     When Apache starts, you may see a firewall notification." -ForegroundColor White
        Write-Host "     CLICK 'Allow access' to permit Apache HTTP Server." -ForegroundColor Green
        Write-Host ""
        if ($FolderCreationFailed) {
            Write-Host "  ⚠️  WARNING - Folder Creation Issue Detected:" -ForegroundColor Red
            Write-Host ""
            Write-Host "     The automatic folder creation encountered errors during installation." -ForegroundColor White
            Write-Host "     Please run FolderCreation.bat manually after restarting:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "     1. Navigate to the installation directory" -ForegroundColor White
            Write-Host "     2. Right-click on 'FolderCreation.bat'" -ForegroundColor White
            Write-Host "     3. Select 'Run as administrator'" -ForegroundColor White
            Write-Host ""
            Write-Host "     Location: $ScriptDir\FolderCreation.bat" -ForegroundColor Cyan
            Write-Host ""
        }
        Write-Host ""
        Write-Host "  💡 To restart later, you can:" -ForegroundColor Cyan
        Write-Host "     • Use Start Menu → Power → Restart" -ForegroundColor White
        Write-Host "     • Run: shutdown -r -t 0" -ForegroundColor White
        Write-Host "     • Press Ctrl+Alt+Del → Restart" -ForegroundColor White
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $ValidResponse = $true
    }
    else {
        Write-Host ""
        Write-Host "Invalid input. Please enter Y (Yes) or N (No)." -ForegroundColor Red
        Write-Host ""
    }
}

# End of try block for main script
}
}

catch {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "                              ❌ CRITICAL ERROR ❌                               " -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "  The installer encountered an unexpected error and cannot continue." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Error details:" -ForegroundColor Yellow
    Write-Host "  $($_.Exception.Message)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Error location:" -ForegroundColor Yellow
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor White
    Write-Host "  $($_.InvocationInfo.Line)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" -Level Error
    Write-Log "Error at line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line)" -Level Error
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}



# Final pause to ensure window does not close if something unexpected happens
Write-Host ""
Write-Host "Script execution completed."
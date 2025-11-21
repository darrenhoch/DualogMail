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

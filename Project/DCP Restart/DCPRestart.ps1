# ==============================================================================================
# Dualog Core Pro (DCP) Service Restart Tool
# Version 2.0.0 - PowerShell Edition
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
Write-Host "Dualog Core Pro (DCP) Service Restart Tool - Version 2.0.0" -ForegroundColor Cyan
Write-Host "PowerShell Edition - Running as Administrator" -ForegroundColor Green
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

# Default Configuration
$serviceName = "duacorepro"
$waitTimeSeconds = 500  # Default: 500 seconds (8 minutes, 20 seconds)
$enableLogging = $true
$logFilePath = "$PSScriptRoot\DCPRestart.log"

# Prompt user for wait time
Write-Host ""
Write-Host "==============================================================================================" -ForegroundColor Yellow
Write-Host "Wait Time Configuration" -ForegroundColor Yellow
Write-Host "==============================================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "How long should the service run before stopping?" -ForegroundColor Cyan
Write-Host ""
Write-Host "Common options:" -ForegroundColor Gray
Write-Host "  1 minute   - Quick test" -ForegroundColor Gray
Write-Host "  5 minutes  - Short maintenance" -ForegroundColor Gray
Write-Host "  10 minutes - Standard restart" -ForegroundColor Gray
Write-Host "  15 minutes - Extended warm-up" -ForegroundColor Gray
Write-Host ""

$defaultMinutes = [math]::Round($waitTimeSeconds / 60, 2)
Write-Host "Enter wait time in minutes [Default: $defaultMinutes]: " -ForegroundColor Cyan -NoNewline

$userInput = Read-Host

# Validate and process input
if ([string]::IsNullOrWhiteSpace($userInput)) {
    # User pressed Enter, use default
    $waitMinutes = $defaultMinutes
    Write-Host "Using default: $waitMinutes minutes" -ForegroundColor Green
} else {
    # Try to parse user input
    $parsedMinutes = 0
    if ([double]::TryParse($userInput, [ref]$parsedMinutes)) {
        if ($parsedMinutes -gt 0 -and $parsedMinutes -le 1440) {  # Max 24 hours
            $waitMinutes = $parsedMinutes
            Write-Host "Using: $waitMinutes minutes" -ForegroundColor Green
        } else {
            Write-Host "Invalid input. Must be between 0 and 1440 minutes (24 hours)." -ForegroundColor Red
            Write-Host "Using default: $defaultMinutes minutes" -ForegroundColor Yellow
            $waitMinutes = $defaultMinutes
        }
    } else {
        Write-Host "Invalid input. Please enter a valid number." -ForegroundColor Red
        Write-Host "Using default: $defaultMinutes minutes" -ForegroundColor Yellow
        $waitMinutes = $defaultMinutes
    }
}

# Convert minutes to seconds
$waitTimeSeconds = [int]($waitMinutes * 60)

Write-Host ""

# Function to get service status with color
function Get-ServiceStatusColored {
    param([string]$ServiceName)

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Host "NOT FOUND" -ForegroundColor Red
        return $null
    }

    $status = $service.Status
    switch ($status) {
        "Running" { Write-Host $status -ForegroundColor Green -NoNewline }
        "Stopped" { Write-Host $status -ForegroundColor Red -NoNewline }
        "StartPending" { Write-Host $status -ForegroundColor Yellow -NoNewline }
        "StopPending" { Write-Host $status -ForegroundColor Yellow -NoNewline }
        default { Write-Host $status -ForegroundColor Gray -NoNewline }
    }

    return $service
}

# Function to write log
function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    # Write to console
    Write-Host $logMessage -ForegroundColor Gray

    # Write to log file if logging is enabled
    if ($enableLogging) {
        Add-Content -Path $logFilePath -Value $logMessage
    }
}

# Main Script Start
Write-Host "Service Name: " -NoNewline
Write-Host $serviceName -ForegroundColor Cyan
Write-Host "Wait Time: " -NoNewline
Write-Host "$waitTimeSeconds seconds ($([math]::Round($waitTimeSeconds/60, 2)) minutes)" -ForegroundColor Cyan
Write-Host ""

# Check if service exists
Write-Host "Checking if service exists..." -ForegroundColor Yellow
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($null -eq $service) {
    Write-Host ""
    Write-Host "=====" -ForegroundColor Red
    Write-Host "ERROR" -ForegroundColor Red
    Write-Host "=====" -ForegroundColor Red
    Write-Host ""
    Write-Host "Service '$serviceName' was not found on this system." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "  1. The service name is correct" -ForegroundColor Yellow
    Write-Host "  2. Dualog Core Pro is installed on this machine" -ForegroundColor Yellow
    Write-Host "  3. You are running this on the correct server" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "ERROR: Service '$serviceName' not found"
    pause
    exit 1
}

Write-Host "Service found successfully." -ForegroundColor Green
Write-Host ""

# Display initial service status
Write-Host "Current Service Status: " -NoNewline
Get-ServiceStatusColored -ServiceName $serviceName
Write-Host ""
Write-Host ""

# Step 1: Start the service
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host "STEP 1: Starting Service" -ForegroundColor Cyan
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

$service = Get-Service -Name $serviceName

if ($service.Status -eq "Running") {
    Write-Host "Service is already running. No action needed." -ForegroundColor Yellow
    Write-Log "Service was already running"
} else {
    Write-Host "Starting service '$serviceName'..." -ForegroundColor Yellow
    Write-Log "Attempting to start service '$serviceName'"

    try {
        Start-Service -Name $serviceName -ErrorAction Stop
        Write-Host "Service start command issued successfully." -ForegroundColor Green
        Write-Log "Service start command successful"

        # Wait for service to start
        Start-Sleep -Seconds 3

        $service = Get-Service -Name $serviceName
        Write-Host "Service Status: " -NoNewline
        Get-ServiceStatusColored -ServiceName $serviceName
        Write-Host ""
        Write-Log "Service status after start: $($service.Status)"
    }
    catch {
        Write-Host "Failed to start service: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERROR: Failed to start service - $($_.Exception.Message)"
        Write-Host ""
        pause
        exit 1
    }
}

Write-Host ""

# Step 2: Wait period
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host "STEP 2: Wait Period" -ForegroundColor Cyan
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Waiting for $waitTimeSeconds seconds before stopping the service..." -ForegroundColor Yellow
Write-Host "Start Time: " -NoNewline
Write-Host (Get-Date -Format "HH:mm:ss") -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting wait period of $waitTimeSeconds seconds"

# Progress bar for wait time
$intervalSeconds = 10
$elapsed = 0

while ($elapsed -lt $waitTimeSeconds) {
    $remaining = $waitTimeSeconds - $elapsed
    $percentComplete = [math]::Round(($elapsed / $waitTimeSeconds) * 100)

    Write-Progress -Activity "Waiting before service stop" `
                   -Status "$percentComplete% Complete - $remaining seconds remaining" `
                   -PercentComplete $percentComplete

    Start-Sleep -Seconds $intervalSeconds
    $elapsed += $intervalSeconds

    # Check service status periodically
    if ($elapsed % 60 -eq 0) {
        $service = Get-Service -Name $serviceName
        if ($service.Status -ne "Running") {
            Write-Host ""
            Write-Host "WARNING: Service stopped unexpectedly during wait period!" -ForegroundColor Red
            Write-Host "Service Status: " -NoNewline
            Get-ServiceStatusColored -ServiceName $serviceName
            Write-Host ""
            Write-Log "WARNING: Service stopped unexpectedly at $elapsed seconds"
        }
    }
}

Write-Progress -Activity "Waiting before service stop" -Completed

Write-Host ""
Write-Host "Wait period completed." -ForegroundColor Green
Write-Host "End Time: " -NoNewline
Write-Host (Get-Date -Format "HH:mm:ss") -ForegroundColor Cyan
Write-Host ""
Write-Log "Wait period completed"

# Step 3: Stop the service
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host "STEP 3: Stopping Service" -ForegroundColor Cyan
Write-Host "==============================================================================================" -ForegroundColor Cyan
Write-Host ""

$service = Get-Service -Name $serviceName

if ($service.Status -eq "Stopped") {
    Write-Host "Service is already stopped." -ForegroundColor Yellow
    Write-Log "Service was already stopped"
} else {
    Write-Host "Stopping service '$serviceName'..." -ForegroundColor Yellow
    Write-Log "Attempting to stop service '$serviceName'"

    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        Write-Host "Service stop command issued successfully." -ForegroundColor Green
        Write-Log "Service stop command successful"

        # Wait for service to stop
        Start-Sleep -Seconds 3

        $service = Get-Service -Name $serviceName
        Write-Host "Service Status: " -NoNewline
        Get-ServiceStatusColored -ServiceName $serviceName
        Write-Host ""
        Write-Log "Service status after stop: $($service.Status)"
    }
    catch {
        Write-Host "Failed to stop service: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERROR: Failed to stop service - $($_.Exception.Message)"
        Write-Host ""
        pause
        exit 1
    }
}

Write-Host ""

# Summary
Write-Host "==============================================================================================" -ForegroundColor Green
Write-Host "OPERATION COMPLETED" -ForegroundColor Green
Write-Host "==============================================================================================" -ForegroundColor Green
Write-Host ""

$finalService = Get-Service -Name $serviceName
Write-Host "Final Service Status: " -NoNewline
Get-ServiceStatusColored -ServiceName $serviceName
Write-Host ""
Write-Host ""

if ($enableLogging) {
    Write-Host "Log file saved to: $logFilePath" -ForegroundColor Cyan
    Write-Host ""
}

Write-Log "Script completed successfully"

pause

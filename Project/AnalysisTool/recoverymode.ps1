# Recovery Mode Analysis Script
# Analyzes IMAP recovery logs to identify which folders have been moved to recovery
# and provides a comprehensive summary of what happened

param(
    [string]$LogFile = $null
)

function Get-LogFiles {
    <#
    .SYNOPSIS
    Find all .log files in the script's directory
    #>
    $ScriptDir = $PSScriptRoot
    if (-not $ScriptDir) {
        $ScriptDir = (Get-Item -Path $MyInvocation.PSCommandPath).DirectoryName
    }
    if (-not $ScriptDir) {
        $ScriptDir = Get-Location
    }
    return Get-ChildItem -Path $ScriptDir -Filter "*.log" -File
}

function Analyze-RecoveryLog {
    <#
    .SYNOPSIS
    Parse recovery log entries and extract relevant information
    #>
    param([string]$FilePath)

    $recoveryFolders = @()
    $renamedFolders = @()
    $messagesMoved = 0
    $foldersToRecovery = 0
    $successfulRenames = 0
    $failedOperations = 0
    $operationTimes = @()

    $content = Get-Content -Path $FilePath -ErrorAction SilentlyContinue

    if (-not $content) {
        Write-Host "Warning: Could not read log file or file is empty: $FilePath" -ForegroundColor Yellow
        return $null
    }

    # First pass: collect all message count information
    $messageCountMap = @{}
    foreach ($line in $content) {
        if ($line -match "Moved (\d+) messages from subfolder (.+?) to recovery") {
            $messageCount = [int]$matches[1]
            $folderName = $matches[2].Trim()
            $messageCountMap[$folderName] = $messageCount
            $messagesMoved += $messageCount
        }
    }

    # Second pass: process all other information
    foreach ($line in $content) {
        # Extract timestamp
        if ($line -match "^.*?(\d{8}),(\d{6})") {
            $timestamp = $matches[1] + " " + $matches[2].Substring(0,2) + ":" + $matches[2].Substring(2,2) + ":" + $matches[2].Substring(4,2)
            $operationTimes += $timestamp
        }

        # Track folders moved to recovery
        if ($line -match "Moved subfolder to recovery:\s*(.+?)\s*->\s*recover\.(.+?)$") {
            $originalFolder = $matches[1].Trim()
            $recoveryFolder = "recover." + $matches[2]

            $msgCount = if ($messageCountMap.ContainsKey($originalFolder)) { $messageCountMap[$originalFolder] } else { 0 }

            $recoveryFolders += @{
                OriginalFolder = $originalFolder
                RecoveryFolder = $recoveryFolder
                MessageCount = $msgCount
                Status = "Moved to Recovery"
            }
            $foldersToRecovery++
        }

        # Track successful renames
        if ($line -match "Successfully renamed folder:\s*(.+?)\s*->\s*(.+?)$") {
            $fromFolder = $matches[1].Trim()
            $toFolder = $matches[2].Trim()
            $renamedFolders += @{
                FromFolder = $fromFolder
                ToFolder = $toFolder
            }
            $successfulRenames++
        }

        # Track failures
        if ($line -match "RENAME failed" -or ($line -match "Error" -and $line -match "renaming")) {
            $failedOperations++
        }
    }

    return @{
        FilePath = $FilePath
        FileName = Split-Path -Leaf $FilePath
        TotalFoldersMovedToRecovery = $foldersToRecovery
        TotalMessagesMoved = $messagesMoved
        SuccessfulRenames = $successfulRenames
        FailedOperations = $failedOperations
        RecoveryFolders = $recoveryFolders
        RenamedFolders = $renamedFolders
        StartTime = if ($operationTimes.Count -gt 0) { $operationTimes[0] } else { "Unknown" }
        EndTime = if ($operationTimes.Count -gt 0) { $operationTimes[-1] } else { "Unknown" }
        TotalOperations = $operationTimes.Count
    }
}

function Display-Summary {
    <#
    .SYNOPSIS
    Display comprehensive recovery analysis summary
    #>
    param([hashtable]$Analysis)

    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "RECOVERY MODE ANALYSIS REPORT" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "=" * 80 -ForegroundColor Cyan

    Write-Host "`nLog File: " -ForegroundColor White -NoNewline
    Write-Host "$($Analysis.FileName)" -ForegroundColor Yellow

    Write-Host "`n--- OVERVIEW ---" -ForegroundColor Green
    Write-Host "Total Folders Moved to Recovery: " -NoNewline
    Write-Host "$($Analysis.TotalFoldersMovedToRecovery)" -ForegroundColor Yellow

    Write-Host "Total Messages Moved: " -NoNewline
    Write-Host "$($Analysis.TotalMessagesMoved)" -ForegroundColor Yellow

    Write-Host "Successful Folder Renames: " -NoNewline
    Write-Host "$($Analysis.SuccessfulRenames)" -ForegroundColor Green

    if ($Analysis.FailedOperations -gt 0) {
        Write-Host "Failed Operations: " -NoNewline
        Write-Host "$($Analysis.FailedOperations)" -ForegroundColor Red
    }

    Write-Host "Total Log Entries Processed: " -NoNewline
    Write-Host "$($Analysis.TotalOperations)" -ForegroundColor White

    Write-Host "`nOperation Timeline:" -ForegroundColor Green
    Write-Host "  Start Time: " -NoNewline
    Write-Host "$($Analysis.StartTime)" -ForegroundColor Cyan
    Write-Host "  End Time: " -NoNewline
    Write-Host "$($Analysis.EndTime)" -ForegroundColor Cyan

    Write-Host "`n--- RECOVERED FOLDERS ---" -ForegroundColor Green

    if ($Analysis.RecoveryFolders.Count -gt 0) {
        # Group by parent folder
        $grouped = $Analysis.RecoveryFolders | Group-Object { $_.OriginalFolder.Split('.')[0] }

        foreach ($group in $grouped) {
            Write-Host "`n  [$($group.Name)]" -ForegroundColor Magenta

            foreach ($folder in $group.Group) {
                $msgInfo = if ($folder.MessageCount -gt 0) { " >> $($folder.MessageCount) messages moved" } else { " >> (empty)" }
                Write-Host "    - $($folder.OriginalFolder)$msgInfo" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  No folders moved to recovery" -ForegroundColor Yellow
    }

    Write-Host "`n--- RENAMED FOLDERS ---" -ForegroundColor Green

    if ($Analysis.RenamedFolders.Count -gt 0) {
        foreach ($rename in $Analysis.RenamedFolders) {
            Write-Host "    - $($rename.FromFolder)" -ForegroundColor Yellow -NoNewline
            Write-Host " >> " -ForegroundColor Gray -NoNewline
            Write-Host "$($rename.ToFolder)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  No folders were renamed" -ForegroundColor Yellow
    }

    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "`n"
}

function Main {
    Write-Host "Recovery Mode Log Analyzer" -ForegroundColor Cyan
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) {
        $scriptPath = (Get-Item -Path $MyInvocation.PSCommandPath).DirectoryName
    }
    if (-not $scriptPath) {
        $scriptPath = Get-Location
    }
    Write-Host "Processing logs in: $scriptPath" -ForegroundColor Gray
    Write-Host ""

    if ($LogFile) {
        # Use specified log file
        $filesToProcess = Get-Item -Path $LogFile -ErrorAction SilentlyContinue
        if (-not $filesToProcess) {
            Write-Host "Error: Log file not found: $LogFile" -ForegroundColor Red
            return
        }
    } else {
        # Find all log files in script directory
        $filesToProcess = Get-LogFiles
        if ($filesToProcess.Count -eq 0) {
            Write-Host "No .log files found in script directory" -ForegroundColor Yellow
            return
        }
    }

    # Ensure it's an array even if single result
    if (-not ($filesToProcess -is [array])) {
        $filesToProcess = @($filesToProcess)
    }

    Write-Host "Found $($filesToProcess.Count) log file(s) to analyze`n" -ForegroundColor Green

    # Analyze each log file
    foreach ($file in $filesToProcess) {
        $analysis = Analyze-RecoveryLog -FilePath $file.FullName
        if ($analysis) {
            Display-Summary -Analysis $analysis
        }
    }
}

# Run the analysis
Main

# Keep the window open
Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

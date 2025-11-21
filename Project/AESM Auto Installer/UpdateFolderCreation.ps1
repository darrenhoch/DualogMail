# FolderCreation-Builder.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Define paths relative to where the script is located
$here = Split-Path -Parent $PSCommandPath
$sourceFile = Join-Path $here "RAW.bat"
$destinationFile = Join-Path $here "FolderCreation.bat"
$logFile = Join-Path $here "FolderCreation.summary.txt"

# Prompt for replacement text
$replacement = Read-Host "Enter the text to replace 'imo' with"

try {
    if (-not (Test-Path $sourceFile)) {
        throw "Source file not found: $sourceFile"
    }

    # Check if destination file already exists
    if (Test-Path $destinationFile) {
        Write-Host ""
        Write-Host "⚠️  FolderCreation.bat already exists at: $destinationFile" -ForegroundColor Yellow
        Write-Host ""
        
        # Ask user if they want to overwrite
        $overwriteResponse = $null
        $validOverwriteResponse = $false
        
        while (-not $validOverwriteResponse) {
            Write-Host "Do you want to overwrite the existing file?" -ForegroundColor Cyan
            Write-Host "  [Y] Yes - Overwrite and continue" -ForegroundColor Green
            Write-Host "  [N] No  - Cancel operation" -ForegroundColor Red
            Write-Host ""
            
            $overwriteResponse = Read-Host "Enter your choice (Y/N)"
            
            if ($overwriteResponse -eq 'Y' -or $overwriteResponse -eq 'y') {
                Write-Host ""
                Write-Host "✅ Proceeding with overwrite..." -ForegroundColor Green
                Write-Host ""
                $validOverwriteResponse = $true
            }
            elseif ($overwriteResponse -eq 'N' -or $overwriteResponse -eq 'n') {
                Write-Host ""
                Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
                Write-Host ""
                Write-Host "Press any key to exit..."
                [void][System.Console]::ReadKey($true)
                exit 0
            }
            else {
                Write-Host ""
                Write-Host "Invalid input. Please enter Y (Yes) or N (No)." -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }

    # Read full content of the batch file
    $content = Get-Content -Path $sourceFile -Raw

    # Count how many "imo" words appear (case-insensitive)
    $matchCount = ([regex]::Matches($content, '\bimo\b', 'IgnoreCase')).Count

    if ($matchCount -gt 0) {
        # Replace all occurrences of "imo" with your input
        $updated = [regex]::Replace($content, '\bimo\b', $replacement, 'IgnoreCase')

        # Save the modified batch file (will overwrite if exists)
        Set-Content -Path $destinationFile -Value $updated -Encoding UTF8 -Force

        # Display summary
        Write-Host ""
        Write-Host "✅ Replacement complete."
        Write-Host "➡️  $matchCount occurrences of 'imo' were replaced with '$replacement'."
        
        # Check if file was overwritten or newly created
        if (Test-Path $destinationFile) {
            $fileInfo = Get-Item $destinationFile
            if ($fileInfo.CreationTime -eq $fileInfo.LastWriteTime) {
                Write-Host "💾 New file created: $destinationFile"
            }
            else {
                Write-Host "💾 Existing file overwritten: $destinationFile" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""

        # Also log it to a text file
        $summary = @(
            "Replacement Summary:"
            "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "Source: $sourceFile"
            "Destination: $destinationFile"
            "Occurrences replaced: $matchCount"
            "Replacement text: $replacement"
            "Action: $(if ($overwriteResponse) { 'Overwrite' } else { 'Create' })"
        ) -join [Environment]::NewLine

        Set-Content -Path $logFile -Value $summary -Encoding UTF8 -Force
        Write-Host "📝 Summary saved to: $logFile"
    }
    else {
        Write-Host "No occurrences of 'imo' found in $sourceFile."
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host ""
    Write-Host "Press any key to continue..."
    [void][System.Console]::ReadKey($true)
}
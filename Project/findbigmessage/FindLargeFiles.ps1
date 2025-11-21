# PowerShell script to find large files or Outlook emails with large attachments

# Function to search file system
function Search-FileSystem {
    # Prompt user for directory location
    $directory = Read-Host "Enter the directory path to search"

    # Check if directory exists
    if (-Not (Test-Path -Path $directory)) {
        Write-Host "Error: The specified directory does not exist." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    # Define size threshold (30 MB in bytes)
    $sizeThresholdMB = 30
    $sizeThresholdBytes = $sizeThresholdMB * 1024 * 1024

    Write-Host "`nSearching for files larger than $sizeThresholdMB MB in: $directory" -ForegroundColor Cyan
    Write-Host "Please wait...`n" -ForegroundColor Yellow

    # Find files larger than 20 MB
    $largeFiles = Get-ChildItem -Path $directory -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt $sizeThresholdBytes } |
        Select-Object FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime |
        Sort-Object SizeMB -Descending

    # Display results
    if ($largeFiles.Count -eq 0) {
        Write-Host "No files larger than $sizeThresholdMB MB were found." -ForegroundColor Green
    } else {
        Write-Host "Found $($largeFiles.Count) file(s) larger than $sizeThresholdMB MB:`n" -ForegroundColor Green
        $largeFiles | Format-Table -AutoSize

        # Calculate total size
        $totalSizeMB = ($largeFiles | Measure-Object -Property SizeMB -Sum).Sum
        Write-Host "`nTotal size of large files: $([math]::Round($totalSizeMB, 2)) MB" -ForegroundColor Cyan
    }
}

# Function to search Outlook
function Search-Outlook {
    $sizeThresholdMB = 30
    $sizeThresholdBytes = $sizeThresholdMB * 1024 * 1024

    Write-Host "`nSearching Outlook for emails with attachments larger than $sizeThresholdMB MB..." -ForegroundColor Cyan
    Write-Host "Please wait (this may take a while)...`n" -ForegroundColor Yellow

    try {
        # Create Outlook COM object
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNamespace("MAPI")

        $results = @()
        $script:totalEmails = 0
        $script:largeAttachmentsFound = 0
        $script:currentFolder = ""

        # Function to search folder recursively
        function Search-Folder {
            param($folder)

            try {
                # Update current folder being scanned
                $script:currentFolder = $folder.FolderPath
                Write-Host "`n[Scanning] Folder: $($folder.Name)" -ForegroundColor Cyan

                $items = $folder.Items
                $folderItemCount = $items.Count
                Write-Host "  Items in folder: $folderItemCount" -ForegroundColor Gray

                $itemsProcessed = 0
                foreach ($item in $items) {
                    $script:totalEmails++
                    $itemsProcessed++

                    # Show progress every 50 emails or every 10% of folder items
                    $progressInterval = [Math]::Max(1, [Math]::Min(50, [Math]::Floor($folderItemCount / 10)))
                    if ($itemsProcessed % $progressInterval -eq 0 -or $itemsProcessed -eq $folderItemCount) {
                        $percentComplete = [Math]::Round(($itemsProcessed / $folderItemCount) * 100)
                        Write-Host "  Progress: $itemsProcessed/$folderItemCount ($percentComplete%) | Total scanned: $($script:totalEmails) | Large attachments found: $($script:largeAttachmentsFound)" -ForegroundColor Yellow
                    }

                    if ($item.Attachments.Count -gt 0) {
                        foreach ($attachment in $item.Attachments) {
                            if ($attachment.Size -gt $sizeThresholdBytes) {
                                $script:largeAttachmentsFound++
                                Write-Host "    [FOUND] Large attachment: $($attachment.FileName) ($([math]::Round($attachment.Size / 1MB, 2)) MB) in '$($item.Subject)'" -ForegroundColor Green

                                $results += [PSCustomObject]@{
                                    Subject = $item.Subject
                                    From = $item.SenderName
                                    Received = $item.ReceivedTime
                                    AttachmentName = $attachment.FileName
                                    SizeMB = [math]::Round($attachment.Size / 1MB, 2)
                                    FolderPath = $folder.FolderPath
                                    Item = $item
                                    Attachment = $attachment
                                }
                            }
                        }
                    }
                }

                Write-Host "  [COMPLETE] Folder: $($folder.Name) - Scanned $itemsProcessed items" -ForegroundColor DarkGreen

                # Search subfolders
                foreach ($subfolder in $folder.Folders) {
                    Search-Folder $subfolder
                }
            }
            catch {
                Write-Host "  [WARNING] Could not access folder: '$($folder.Name)'" -ForegroundColor Yellow
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
                return
            }

            # Search selected mailbox or all
            if ($selectionNum -eq ($stores.Count + 1)) {
                # Search all mailboxes
                Write-Host "`n============================================================" -ForegroundColor Cyan
                Write-Host "  Searching ALL Mailboxes for Attachments > $sizeThresholdMB MB" -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                foreach ($store in $stores) {
                    Write-Host "`n>>> Searching store: $($store.DisplayName) <<<" -ForegroundColor Magenta
                    $rootFolder = $store.GetRootFolder()
                    Search-Folder $rootFolder
                }
            } else {
                # Search selected mailbox only
                $selectedStore = $stores[$selectionNum - 1]
                Write-Host "`n============================================================" -ForegroundColor Cyan
                Write-Host "  Searching Mailbox: $($selectedStore.DisplayName)" -ForegroundColor Cyan
                Write-Host "  Looking for Attachments > $sizeThresholdMB MB" -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                $rootFolder = $selectedStore.GetRootFolder()
                Search-Folder $rootFolder
            }
        }
        catch {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            return
        }

        # Display results
        Write-Host "`n========================================" -ForegroundColor Cyan
        if ($results.Count -eq 0) {
            Write-Host "No emails with attachments larger than $sizeThresholdMB MB were found." -ForegroundColor Green
        } else {
            Write-Host "Found $($results.Count) attachment(s) larger than $sizeThresholdMB MB:`n" -ForegroundColor Green

            # Display without Item and Attachment columns
            $sortedResults = $results | Sort-Object SizeMB -Descending
            $displayResults = $sortedResults | Select-Object Subject, From, Received, AttachmentName, SizeMB, FolderPath
            $displayResults | Format-Table -AutoSize -Wrap

            # Calculate total size
            $totalSizeMB = ($results | Measure-Object -Property SizeMB -Sum).Sum
            Write-Host "`nTotal size of large attachments: $([math]::Round($totalSizeMB, 2)) MB" -ForegroundColor Cyan
            Write-Host "Total emails scanned: $($script:totalEmails)" -ForegroundColor Cyan

            # Ask if user wants to delete attachments
            Write-Host "`n========================================" -ForegroundColor Cyan
            $deleteChoice = Read-Host "Do you want to delete these attachments? (Y/N)"

            if ($deleteChoice -eq "Y" -or $deleteChoice -eq "y") {
                # Prompt for backup directory
                $defaultBackupPath = "C:\dualog\bigfilebackup"
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
                    }
                    catch {
                        Write-Host "Error creating backup directory: $($_.Exception.Message)" -ForegroundColor Red
                        return
                    }
                }

                # Process each attachment
                $successCount = 0
                $failCount = 0

                Write-Host "`nProcessing attachments..." -ForegroundColor Cyan

                foreach ($result in $sortedResults) {
                    try {
                        $attachment = $result.Attachment
                        $item = $result.Item
                        $fileName = $attachment.FileName

                        # Create a unique filename with timestamp to avoid conflicts
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $sanitizedSubject = $item.Subject -replace '[\\/:*?"<>|]', '_'
                        $sanitizedSubject = $sanitizedSubject.Substring(0, [Math]::Min(50, $sanitizedSubject.Length))
                        $backupFileName = "${timestamp}_${sanitizedSubject}_${fileName}"
                        $backupFilePath = Join-Path -Path $backupPath -ChildPath $backupFileName

                        # Save attachment to backup location
                        $attachment.SaveAsFile($backupFilePath)

                        # Delete attachment from email
                        $attachment.Delete()
                        $item.Save()

                        Write-Host "  [OK] Deleted: $fileName (from: $($item.Subject))" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Could not delete: $($result.AttachmentName) - $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }

                # Summary
                Write-Host "`n========================================" -ForegroundColor Cyan
                Write-Host "Deletion Summary:" -ForegroundColor Cyan
                Write-Host "  Successfully deleted: $successCount attachment(s)" -ForegroundColor Green
                if ($failCount -gt 0) {
                    Write-Host "  Failed: $failCount attachment(s)" -ForegroundColor Red
                }
                Write-Host "  Backup location: $backupPath" -ForegroundColor Yellow
            }
            else {
                Write-Host "No attachments were deleted." -ForegroundColor Yellow
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
    }
}

# Main menu
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Large Files & Attachments Finder" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "What would you like to search?" -ForegroundColor Yellow
Write-Host "1. File System (files > 30 MB)" -ForegroundColor White
Write-Host "2. Outlook Emails (attachments > 30 MB)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (1 or 2)"

switch ($choice) {
    "1" { Search-FileSystem }
    "2" { Search-Outlook }
    default {
        Write-Host "Invalid choice. Please run the script again and select 1 or 2." -ForegroundColor Red
    }
}

# Pause before exit
Read-Host "`nPress Enter to exit"

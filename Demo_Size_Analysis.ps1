# Demo showing the new size analysis feature

Write-Host ""
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| RESULT #1                                     Size: 45.23 MB" -ForegroundColor White
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| Subject  : Project Files and Documentation Package" -ForegroundColor White
Write-Host "| From     : John Smith <john.smith@company.com>" -ForegroundColor White
Write-Host "| Received : 2024-12-10 14:30:00" -ForegroundColor White
Write-Host "| File     : Total Message (3 attachment(s))" -ForegroundColor White
Write-Host "| Folder   : \\Mailbox - user@company.com\Inbox\Projects" -ForegroundColor Gray
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| SIZE ANALYSIS:" -ForegroundColor Yellow
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| Message Body    : 0.15 MB (0.3%)" -ForegroundColor White
Write-Host "| Attachments     : 3 file(s)" -ForegroundColor White
Write-Host "|   [1] ProjectPresentation.pptx - 25.5 MB (56.4%)" -ForegroundColor Yellow
Write-Host "|   [2] Documentation.pdf - 12.3 MB (27.2%)" -ForegroundColor Yellow
Write-Host "|   [3] Spreadsheet.xlsx - 7.28 MB (16.1%)" -ForegroundColor Yellow
Write-Host "| Total Attachments: 45.08 MB (99.7%)" -ForegroundColor Cyan
Write-Host "| " -ForegroundColor DarkGray
Write-Host "| Recommendation  : Size mainly from attachments" -ForegroundColor Green
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| RESULT #2                                      Size: 8.45 MB" -ForegroundColor White
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| Subject  : Newsletter - December 2024 with Images" -ForegroundColor White
Write-Host "| From     : Marketing Team" -ForegroundColor White
Write-Host "| Received : 2024-12-08 09:00:00" -ForegroundColor White
Write-Host "| File     : Total Message (0 attachment(s))" -ForegroundColor White
Write-Host "| Folder   : \\Mailbox - user@company.com\Inbox\Marketing" -ForegroundColor Gray
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| SIZE ANALYSIS:" -ForegroundColor Yellow
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "| Message Body    : 8.45 MB (100%)" -ForegroundColor White
Write-Host "| Attachments     : None" -ForegroundColor White
Write-Host "| " -ForegroundColor DarkGray
Write-Host "| Recommendation  : Large email body (no attachments)" -ForegroundColor Yellow
Write-Host "+-------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

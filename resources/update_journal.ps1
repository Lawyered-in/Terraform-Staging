# PowerShell Script to Update the Infrastructure Journal
param (
    [Parameter(Mandatory=$true)]
    [string]$TaskName,
    
    [Parameter(Mandatory=$true)]
    [string]$Outcome
)

$Date = Get-Date -Format "MMMM dd, yyyy"
$Entry = @"

### **Task: $TaskName**
- **Date**: $Date
- **Outcome**: $Outcome
"@

Add-Content -Path ".\JOURNAL.md" -Value $Entry
Write-Host "Journal updated successfully!" -ForegroundColor Green

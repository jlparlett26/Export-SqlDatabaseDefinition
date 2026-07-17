# GitSync.ps1
# Pull -> Add -> Commit -> Push

$CommitMessage = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"

Write-Host ""
Write-Host "Git Sync Started"
Write-Host "Message: $CommitMessage"
Write-Host ""

git pull

if ($LASTEXITCODE -ne 0) {
    Write-Host "Pull failed. Resolve conflicts and try again."
    exit 1
}

git add .

git diff --cached --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "No changes detected."
    exit 0
}

git commit -m $CommitMessage

if ($LASTEXITCODE -ne 0) {
    Write-Host "Commit failed."
    exit 1
}

git push

if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed."
    exit 1
}

Write-Host ""
Write-Host "Git Sync Complete"

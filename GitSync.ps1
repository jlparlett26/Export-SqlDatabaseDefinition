# GitSync.ps1
# Pull -> Add -> Commit -> Push

# Get the timestamp that will be used when no custom description is provided.
$Timestamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"

# Prompt for an optional commit description.
$UserDescription = Read-Host "Enter commit description (blank for timestamp only)"

# Trim whitespace and treat blank input as empty.
if ($null -ne $UserDescription) {
    $UserDescription = $UserDescription.Trim()
}

# Construct the final commit message.
if ([string]::IsNullOrWhiteSpace($UserDescription)) {
    $CommitMessage = $Timestamp
}
else {
    $CommitMessage = "$UserDescription - $Timestamp"
}

# Display the final commit message before the existing workflow continues.
Write-Host ""
Write-Host "Git Sync Started"
Write-Host "Commit Message: $CommitMessage"
Write-Host ""

git pull origin main

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

git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed."
    exit 1
}

Write-Host ""
Write-Host "Git Sync Complete"

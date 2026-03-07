# Deploy Leave Tracker frontend from unified NutriLens repository root
param(
    [string]$ProjectId = "leave-tracker-2025",
    [string]$BucketName = "leave-tracker-2025-frontend",
    [string]$ApiUrl = "",
    [switch]$CleanBucket
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Deploying Leave Tracker Frontend from unified repo" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

$frontendPath = "frontend"
if (!(Test-Path $frontendPath)) {
    Write-Host "ERROR: Frontend folder not found: $frontendPath" -ForegroundColor Red
    exit 1
}

if ($ApiUrl -ne "") {
    "VITE_API_URL=$ApiUrl" | Out-File -FilePath "$frontendPath\.env.production" -Encoding utf8
    "VITE_ENABLE_REGISTRATION=true" | Out-File -FilePath "$frontendPath\.env.production" -Append -Encoding utf8
}

Write-Host "Step 1/4: Building frontend..." -ForegroundColor Yellow
Push-Location $frontendPath
npm install
npm run build:prod
Pop-Location
Write-Host "✓ Build successful`n" -ForegroundColor Green

Write-Host "Step 2/4: Optional clean..." -ForegroundColor Yellow
if ($CleanBucket.IsPresent) {
    gcloud storage rm -r gs://$BucketName/* --project=$ProjectId 2>$null
    Write-Host "✓ Bucket cleaned`n" -ForegroundColor Green
} else {
    Write-Host "✓ Skip clean (use -CleanBucket to enable)`n" -ForegroundColor Green
}

Write-Host "Step 3/4: Uploading build output..." -ForegroundColor Yellow
gcloud storage cp "$frontendPath/dist/index.html" "gs://$BucketName/" --project=$ProjectId
gcloud storage cp -r "$frontendPath/dist/assets" "gs://$BucketName/" --project=$ProjectId
if (Test-Path "$frontendPath/dist/public") {
    gcloud storage cp -r "$frontendPath/dist/public" "gs://$BucketName/" --project=$ProjectId
}
Write-Host "✓ Upload successful`n" -ForegroundColor Green

Write-Host "Step 4/4: Setting cache-control for index.html..." -ForegroundColor Yellow
gcloud storage objects update "gs://$BucketName/index.html" `
    --cache-control="no-cache, no-store, must-revalidate" `
    --project=$ProjectId

Write-Host "`n✅ Leave Tracker frontend deployed." -ForegroundColor Green
Write-Host "URL: https://storage.googleapis.com/$BucketName/index.html" -ForegroundColor Cyan

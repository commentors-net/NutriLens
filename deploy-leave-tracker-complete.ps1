# Complete Leave Tracker deployment from unified NutriLens repository root
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [Parameter(Mandatory = $true)]
    [string]$SecretKey,
    [Parameter(Mandatory = $true)]
    [string]$GeminiApiKey,
    [string]$Region = 'us-central1',
    [string]$BucketName = '',
    [switch]$CleanBucket
)

$ErrorActionPreference = 'Stop'

if ($BucketName -eq '') {
    $BucketName = "$ProjectId-frontend"
}

Write-Host "`n🚀 Full Leave Tracker deploy from unified repo" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

& .\deploy-leave-tracker-backend.ps1 `
    -ProjectId $ProjectId `
    -Region $Region `
    -SecretKey $SecretKey `
    -GeminiApiKey $GeminiApiKey

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Backend deployment failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

$backendUrl = gcloud run services describe leave-tracker-api --region=$Region --format='value(status.url)'

& .\deploy-leave-tracker-frontend.ps1 `
    -ProjectId $ProjectId `
    -BucketName $BucketName `
    -ApiUrl $backendUrl `
    -CleanBucket:$CleanBucket

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend deployment failed" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n✅ Full deployment complete" -ForegroundColor Green
Write-Host "Backend : $backendUrl" -ForegroundColor Cyan
Write-Host "Frontend: https://storage.googleapis.com/$BucketName/index.html" -ForegroundColor Cyan

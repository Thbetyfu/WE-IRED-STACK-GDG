# PowerShell Restore & Verification Script for WE-IRED Cloud (Windows / Local Dev)
param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "weired_user",
    [string]$DbName = "weired_db",
    [string]$DbPassword = "weired_secret"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupFile)) {
    Write-Host "[ERROR] Backup file not found: $BackupFile" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Restoring database $DbName from $BackupFile..." -ForegroundColor Cyan

# Check SHA-256 if file exists
$HashFile = "$BackupFile.sha256"
if (Test-Path $HashFile) {
    Write-Host "[INFO] Verifying checksum against $HashFile..." -ForegroundColor Cyan
    $ExpectedHash = ((Get-Content $HashFile).Split(' ')[0]).Trim()
    $ActualHash = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash
    if ($ExpectedHash -ne $ActualHash) {
        Write-Host "[ERROR] SHA256 mismatch! Expected: $ExpectedHash, Got: $ActualHash" -ForegroundColor Red
        exit 1
    }
    Write-Host "[VERIFIED] SHA-256 checksum matched." -ForegroundColor Green
}

$env:PGPASSWORD = $DbPassword
try {
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $BackupFile
    Write-Host "[SUCCESS] Restore command executed successfully." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Restore failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    $env:PGPASSWORD = $null
}

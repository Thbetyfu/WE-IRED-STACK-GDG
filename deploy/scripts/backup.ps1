# PowerShell Backup Script for WE-IRED Cloud (Windows / Local Dev)
param(
    [string]$BackupDir = "./backups",
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "weired_user",
    [string]$DbName = "weired_db",
    [string]$DbPassword = "weired_secret"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "weired_backup_$Timestamp.sql"

Write-Host "[INFO] Starting database backup for $DbName at $(Get-Date)..." -ForegroundColor Cyan

$env:PGPASSWORD = $DbPassword
try {
    & pg_dump -h $DbHost -p $DbPort -U $DbUser -d $DbName --clean --if-exists -f $BackupFile
    if (-not (Test-Path $BackupFile) -or (Get-Item $BackupFile).Length -eq 0) {
        throw "Backup file is empty or missing!"
    }

    $Hash = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash
    Set-Content -Path "$BackupFile.sha256" -Value "$Hash  $BackupFile"

    $SizeKb = [math]::Round((Get-Item $BackupFile).Length / 1KB, 2)
    Write-Host "[SUCCESS] Backup created successfully: $BackupFile ($SizeKb KB)" -ForegroundColor Green
    Write-Host "[SHA256] $Hash" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Backup failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    $env:PGPASSWORD = $null
}

# Claude Credentials Watchdog (Windows)
#
# Monitors $env:USERPROFILE\.claude\.credentials.json for:
#   1. Missing file -> restore from latest backup
#   2. Expired token (delta < ALERT_THRESHOLD_MIN) -> Telegram alert
#   3. Daily backup at first run after 03:00 local time
#
# Schedule via Task Scheduler every 15 min:
#   schtasks /Create /SC MINUTE /MO 15 /TN "ClaudeCredWatchdog" `
#     /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\...\claude-cred-watchdog.ps1'"
#
# Telegram alert: requires CLAUDECLAW_BOT_TOKEN + ALLOWED_CHAT_ID env or .env file.

$ErrorActionPreference = 'Stop'

$CredPath       = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$BackupDir      = 'C:\Users\mjnol\.openclaw\workspace\claudeclaw-live\backups\credentials'
$LogPath        = Join-Path $BackupDir 'watchdog.log'
$EnvFile        = 'C:\Users\mjnol\.openclaw\workspace\claudeclaw-live\.env'
$AlertThresholdMin = 30          # alert if token expires in < 30 min
$BackupRetentionDays = 14
$DailyBackupHour = 3              # backup once per day after 03:00 local

function Write-Log([string]$msg) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = "[$ts] $msg"
  Add-Content -Path $LogPath -Value $line
  Write-Host $line
}

function Send-Telegram([string]$text) {
  try {
    $token = $null; $chatId = $null
    if (Test-Path $EnvFile) {
      foreach ($l in Get-Content $EnvFile) {
        if ($l -match '^\s*CLAUDECLAW_BOT_TOKEN\s*=\s*(.+?)\s*$')   { $token  = $matches[1].Trim('"').Trim("'") }
        if ($l -match '^\s*ALLOWED_CHAT_ID\s*=\s*(.+?)\s*$')        { $chatId = $matches[1].Trim('"').Trim("'") }
      }
    }
    if (-not $token)  { $token  = $env:CLAUDECLAW_BOT_TOKEN }
    if (-not $chatId) { $chatId = $env:ALLOWED_CHAT_ID }
    if (-not $token -or -not $chatId) {
      Write-Log "Cannot send Telegram alert: token or chat_id missing"
      return
    }
    $url  = "https://api.telegram.org/bot$token/sendMessage"
    $body = @{ chat_id = $chatId; text = $text; parse_mode = 'Markdown' } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 15 | Out-Null
    Write-Log "Telegram alert sent"
  } catch {
    Write-Log "Telegram alert failed: $($_.Exception.Message)"
  }
}

function Restore-FromBackup {
  $latest = Get-ChildItem -Path $BackupDir -Filter '*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) {
    Send-Telegram "ALERTA Claude Credentials WIN: ficheiro em falta e SEM backup. Login manual urgente: claude login"
    Write-Log "FATAL: credentials missing and no backups available"
    exit 1
  }
  Copy-Item $latest.FullName $CredPath -Force
  Write-Log "Restored credentials from $($latest.Name)"
  Send-Telegram "Claude Credentials WIN: ficheiro restaurado de backup $($latest.Name)"
}

function Backup-Today {
  $today = (Get-Date).ToString('yyyy-MM-dd')
  $dest  = Join-Path $BackupDir "$today.json"
  if (Test-Path $dest) { return }  # already backed up today
  Copy-Item $CredPath $dest -Force
  Write-Log "Backup created: $today.json"
  # Retention
  Get-ChildItem -Path $BackupDir -Filter '*.json' |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$BackupRetentionDays) } |
    ForEach-Object { Remove-Item $_.FullName -Force; Write-Log "Pruned old backup: $($_.Name)" }
}

# === Main ===
try {
  # 1. Check file exists
  if (-not (Test-Path $CredPath)) {
    Write-Log "Credentials file missing - attempting restore"
    Restore-FromBackup
  }

  # 2. Parse and check expiry
  $cred = Get-Content $CredPath -Raw | ConvertFrom-Json
  $oauth = $cred.claudeAiOauth
  if (-not $oauth -or -not $oauth.expiresAt) {
    Write-Log "Credentials file missing claudeAiOauth.expiresAt"
    Send-Telegram "ALERTA Claude Credentials WIN: ficheiro corrompido (sem expiresAt). Re-login: claude login"
    exit 1
  }

  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $deltaMin = [math]::Round(($oauth.expiresAt - $now) / 60000, 1)

  if ($deltaMin -lt -60) {
    # Expired more than 1h ago and CLI hasn't auto-refreshed
    Write-Log "Token expired ${deltaMin}min ago - alerting"
    Send-Telegram "ALERTA Claude Credentials WIN: token expirou ha $([math]::Abs($deltaMin))min e refresh falhou. Acao: claude logout && claude login"
  } elseif ($deltaMin -lt $AlertThresholdMin) {
    Write-Log "Token expires in ${deltaMin}min (warning threshold)"
    # Soft warning only on first detection per day - skip for now to avoid spam
  } else {
    Write-Log "OK - token valid for ${deltaMin}min"
  }

  # 3. Daily backup
  if ((Get-Date).Hour -ge $DailyBackupHour) {
    Backup-Today
  }

  exit 0
} catch {
  Write-Log "FATAL: $($_.Exception.Message)"
  Send-Telegram "ALERTA Claude Credentials WIN: watchdog crashed - $($_.Exception.Message)"
  exit 1
}

# ---------------------------------------------------------------------------
#  Voicebox one-command installer for Windows — packaged by Ihsan Ops
#  https://ihsanops.ai  ·  "Less admin. More growth."
#
#  Usage (PowerShell):
#    irm https://ihsanops.ai/voicebox.ps1 | iex
#
#  Downloads the latest official, signed Voicebox installer, installs it
#  silently for the current user, and opens it.
#
#  Voicebox is free, open-source (MIT) software by Jamie Pine and contributors:
#  https://github.com/jamiepine/voicebox — this script only installs it.
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster

$Repo = if ($env:VOICEBOX_REPO) { $env:VOICEBOX_REPO } else { 'jamiepine/voicebox' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "!   $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "X   $m" -ForegroundColor Red; throw $m }

Write-Host ''
Write-Host 'Voicebox installer - free local voice cloning, set up by Ihsan Ops' -ForegroundColor White
Write-Host '-----------------------------------------------------------------'

# 1. Checks
if (-not [Environment]::Is64BitOperatingSystem) { Die 'Voicebox needs 64-bit Windows 10 or 11.' }
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { Warn 'Windows on ARM detected - the x64 build will run under emulation (slower).' }
$os = [Environment]::OSVersion.Version
if ($os.Major -lt 10) { Die "Voicebox needs Windows 10 or newer." }
Ok "Windows $($os.Major).$($os.Build)"

$drive = Get-PSDrive -Name ($env:LOCALAPPDATA.Substring(0,1))
$freeGB = [math]::Floor($drive.Free / 1GB)
if ($freeGB -lt 10) { Warn "Only $freeGB GB free. Voice models need roughly 4-8 GB." } else { Ok "$freeGB GB free disk space" }

$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
if ($ramGB -ge 8) { Ok "$ramGB GB RAM" } else { Warn "$ramGB GB RAM - 8 GB+ recommended." }

$nvidia = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
if ($nvidia) { Ok "NVIDIA GPU found ($($nvidia.Name)) - enable CUDA in Voicebox Settings for big speedups" }
else { Warn 'No NVIDIA GPU found - Voicebox will use DirectML/CPU (works, just slower).' }

# 2. Download
$tmp = Join-Path $env:TEMP ("voicebox-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
# Windows installers are versioned (e.g. voicebox_0.5.0_x64-setup.exe), so look up the latest release
Say 'Finding the latest Voicebox release...'
$url = $null
try {
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing -Headers @{ 'User-Agent' = 'voicebox-installer' }
  $url = ($rel.assets | Where-Object { $_.name -match '_x64-setup\.exe$' } | Select-Object -First 1).browser_download_url
  $ver = $rel.tag_name
} catch { }
if (-not $url) {
  # Fallback: read the version from the /releases/latest redirect
  $resp = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" -UseBasicParsing
  $tag = ($resp.BaseResponse.ResponseUri, $resp.BaseResponse.RequestMessage.RequestUri | Where-Object { $_ } | Select-Object -First 1).ToString().Split('/')[-1]
  $ver = $tag
  $url = "https://github.com/$Repo/releases/download/$tag/voicebox_$($tag.TrimStart('v'))_x64-setup.exe"
}
Ok "Latest version: $ver"

$setup = Join-Path $tmp 'voicebox-setup.exe'
Say 'Downloading Voicebox...'
try { Invoke-WebRequest -Uri $url -OutFile $setup -UseBasicParsing }
catch { Die 'Download failed. Check your internet connection and try again.' }

$sig = Get-AuthenticodeSignature $setup
if ($sig.Status -eq 'Valid') { Ok "Signature verified ($($sig.SignerCertificate.Subject.Split(',')[0]))" }
else { Warn 'Installer is not code-signed - Windows SmartScreen may ask you to confirm.' }

# 3. Install
Get-Process -Name 'voicebox*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Say 'Installing (this takes a minute)...'
$p = Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru
if ($p.ExitCode -ne 0) { Die "Installer exited with code $($p.ExitCode)." }
Ok 'Installed'
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

# 4. Launch
$candidates = @(
  "$env:LOCALAPPDATA\Programs\Voicebox\voicebox.exe",
  "$env:LOCALAPPDATA\Voicebox\voicebox.exe",
  "$env:ProgramFiles\Voicebox\voicebox.exe"
)
$exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) {
  $lnk = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter 'Voicebox*.lnk' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($lnk) { $exe = $lnk.FullName }
}
if ($exe) { Say 'Opening Voicebox...'; Start-Process $exe } else { Warn 'Installed - open Voicebox from the Start menu.' }

Write-Host ''
Write-Host 'All done! Next steps:' -ForegroundColor Green
Write-Host '  1. Wait for the status light (bottom-left) to turn green.'
Write-Host '  2. Voices -> New profile: record or upload 10-30 seconds of clear speech.'
Write-Host '  3. Pick Qwen3-TTS 1.7B and generate. First run downloads the model (~3.5 GB).'
Write-Host ''
Write-Host 'Your voice never leaves this PC. Want AI automation for your business?'
Write-Host '  -> https://ihsanops.ai' -ForegroundColor White
Write-Host ''

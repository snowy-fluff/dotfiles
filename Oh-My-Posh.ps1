#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false, HelpMessage = 'Specific Catppuccin flavor: catppuccin, frappe, latte, macchiato, mocha. Defaults to mocha.')]
    [ValidateSet('catppuccin', 'frappe', 'latte', 'macchiato', 'mocha')]
    [string]$Flavor = 'catppuccin',

    [Parameter(HelpMessage = 'Install the JetBrainsMono Nerd Font and set it as the default in Windows Terminal.')]
    [Switch]$InstallFont,

    [Parameter(HelpMessage = 'Revert changes by restoring your PowerShell profile and Windows Terminal settings from backups.')]
    [Switch]$Remove,

    [Parameter(HelpMessage = 'Show this help message.')]
    [Switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "[?] Usage: .\Oh-My-Posh.ps1 [-Flavor <flavor>] [-InstallFont] [-Remove] [-Help]" -ForegroundColor Yellow
    Write-Host "[?]   -Flavor      : catppuccin, frappe, latte, macchiato, or mocha. (Default: catppuccin)" -ForegroundColor Yellow
    Write-Host "[?]   -InstallFont : Downloads and installs the JetBrainsMono Nerd Font, then sets it in Windows Terminal." -ForegroundColor Yellow
    Write-Host "[?]   -Remove      : Restores your PowerShell profile and Windows Terminal settings from .bak files." -ForegroundColor Yellow
    Write-Host "[?]   -Help        : Shows this help message." -ForegroundColor Yellow
    exit
}

$profilePath = $PROFILE
$profileBackupPath = "$profilePath.bak"
$wtPackageNames = @(
    "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe",
    "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe"
)
$wtSettingsPath = $null
foreach ($pkg in $wtPackageNames) {
    $candidate = Join-Path $env:LOCALAPPDATA "$pkg\LocalState\settings.json"
    if (Test-Path $candidate) { $wtSettingsPath = $candidate; break }
}
$wtSettingsBackupPath = if ($wtSettingsPath) { "$wtSettingsPath.bak" } else { $null }
$themesDir = Join-Path $HOME ".poshthemes"

$themeName = if ($Flavor -eq 'catppuccin') { "catppuccin.omp.json" } else { "catppuccin_$Flavor.omp.json" }
$themePath = Join-Path $themesDir $themeName

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        $backup = "$Path.bak"
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Host "[*] Backed up $Path to $backup" -ForegroundColor Yellow
    }
}

if ($Remove) {
    if (Test-Path $profileBackupPath) {
        Copy-Item -Path $profileBackupPath -Destination $profilePath -Force
        Write-Host "[+] Restored PowerShell profile from backup." -ForegroundColor Green
    } else {
        Write-Host "[-] No PowerShell profile backup found at $profileBackupPath." -ForegroundColor Red
    }

    if ($wtSettingsBackupPath -and (Test-Path $wtSettingsBackupPath)) {
        Copy-Item -Path $wtSettingsBackupPath -Destination $wtSettingsPath -Force
        Write-Host "[+] Restored Windows Terminal settings from backup." -ForegroundColor Green
    } elseif ($wtSettingsBackupPath) {
        Write-Host "[-] No Windows Terminal settings backup found at $wtSettingsBackupPath." -ForegroundColor Red
    }
    exit
}

Clear-Host
Write-Host "Starting Terminal Upgrade Process..." -ForegroundColor Magenta -BackgroundColor Black

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

Write-Host "[*] Checking for Oh My Posh..." -ForegroundColor Cyan
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "[*] Installing Oh My Posh via winget..." -ForegroundColor Green
        winget install JanDeDobbeleer.OhMyPosh --source winget --scope user --force
    } else {
        Write-Host "[*] Installing Oh My Posh via online script..." -ForegroundColor Green
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
    }
    $env:Path += ";$($env:LOCALAPPDATA)\Programs\oh-my-posh\bin"
    Write-Host "[+] Oh My Posh installed and added to PATH for current session." -ForegroundColor Green
} else {
    Write-Host "[!] Oh My Posh is already installed." -ForegroundColor Yellow
}

if ($InstallFont) {
    Write-Host "[*] Installing JetBrainsMono Nerd Font..." -ForegroundColor Cyan
    oh-my-posh font install JetBrainsMono
    Write-Host "[+] Font installation command executed." -ForegroundColor Green

    if ($wtSettingsPath) {
        Write-Host "[*] Updating Windows Terminal settings..." -ForegroundColor Cyan
        Backup-File -Path $wtSettingsPath

        $settingsJson = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

        if (-not $settingsJson.profiles) { $settingsJson | Add-Member -MemberType NoteProperty -Name profiles -Value @{} }
        if (-not $settingsJson.profiles.defaults) { $settingsJson.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value @{} }
        if (-not $settingsJson.profiles.defaults.font) { $settingsJson.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value @{} }
        $settingsJson.profiles.defaults.font.face = "JetBrainsMono Nerd Font"

        foreach ($profile in $settingsJson.profiles.list) {
            if (-not $profile.font) { $profile | Add-Member -MemberType NoteProperty -Name font -Value @{} }
            $profile.font.face = "JetBrainsMono Nerd Font"
        }

        $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath -Encoding UTF8
        Write-Host "[+] Windows Terminal font set to JetBrainsMono Nerd Font." -ForegroundColor Green
    } else {
        Write-Host "[-] Windows Terminal settings.json not found." -ForegroundColor Red
    }
}

$baseUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/"
$flavors = @{
    'catppuccin' = "$baseUrl/catppuccin.omp.json"
    'frappe'     = "$baseUrl/catppuccin_frappe.omp.json"
    'latte'      = "$baseUrl/catppuccin_latte.omp.json"
    'macchiato'  = "$baseUrl/catppuccin_macchiato.omp.json"
    'mocha'      = "$baseUrl/catppuccin_mocha.omp.json"
}

if (-not (Test-Path $themesDir)) { New-Item -ItemType Directory -Path $themesDir | Out-Null }

Write-Host "[*] Downloading Catppuccin '$Flavor' theme..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $flavors[$Flavor] -OutFile $themePath -UseBasicParsing
Write-Host "[+] Theme saved to $themePath" -ForegroundColor Green

Backup-File -Path $profilePath
if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -Type File -Force | Out-Null }

$loaderLine = "oh-my-posh init pwsh --config `"$themePath`" | Invoke-Expression"
$rawProfileContent = if (Test-Path $profilePath) { Get-Content $profilePath -ErrorAction SilentlyContinue } else { $null }
$profileContent = $rawProfileContent -join [System.Environment]::NewLine

if ($profileContent -notmatch '(?m)^\s*oh-my-posh\s+init\b') {
    # No existing init line – append (with a preceding newline if the file is non‑empty)
    if ($profileContent.Trim().Length -gt 0) {
        Add-Content -Path $profilePath -Value "`n$loaderLine"
    } else {
        Set-Content -Path $profilePath -Value $loaderLine -Encoding UTF8
    }
    Write-Host "[+] Added Oh My Posh configuration to profile." -ForegroundColor Green
} else {
    # Replace first matching line with the new loader line
    $updatedContent = [regex]::Replace($profileContent, '(?m)^\s*oh-my-posh\s+init\b.*', $loaderLine, 1)
    $updatedContent | Set-Content -Path $profilePath -Encoding UTF8
    Write-Host "[*] Updated existing Oh My Posh configuration in profile." -ForegroundColor Cyan
}

Write-Host "`n[+] Terminal upgrade complete. Restart Windows Terminal or open a new PowerShell session to see the changes." -ForegroundColor Green
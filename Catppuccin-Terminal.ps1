param(
    [Parameter(Mandatory = $false, HelpMessage = 'Specific flavor(s), comma-separated: frappe, latte, macchiato, mocha. If omitted, installs all.')]
    [string]$Flavor,

    [Parameter(HelpMessage = 'Show this help message.')]
    [Switch]$Help,

    [Parameter(HelpMessage = 'Revert changes by restoring settings.json.bak if it exists.')]
    [Switch]$Remove
)

if ($Help) {
    Write-Host "[?] Usage: .\Catppuccin-Terminal.ps1 [-Flavor <flavors>] [-Remove] [-Help]" -ForegroundColor Yellow
    Write-Host "[?]   -Flavor : Comma-separated list (frappe, latte, macchiato, mocha). Default = all." -ForegroundColor Yellow
    Write-Host "[?]   -Remove : Restore settings.json from the .bak file if present." -ForegroundColor Yellow
    Write-Host "[?]   -Help   : Show this message." -ForegroundColor Yellow
    exit
}

# Locate settings.json
$settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$backupPath = "$settingsPath.bak"

if ($Remove) {
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $settingsPath -Force
        Write-Host "[+] Restored settings.json from backup." -ForegroundColor Green
    }
    else {
        Write-Host "[-] No backup file found to restore." -ForegroundColor Red
    }
    exit
}

# Define available flavors and their URLs
$flavors = @{
    'frappe'    = @{ theme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/frappeTheme.json'; scheme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/frappe.json' }
    'latte'     = @{ theme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/latteTheme.json'; scheme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/latte.json' }
    'macchiato' = @{ theme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/macchiatoTheme.json'; scheme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/macchiato.json' }
    'mocha'     = @{ theme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/mochaTheme.json'; scheme = 'https://raw.githubusercontent.com/catppuccin/windows-terminal/refs/heads/main/mocha.json' }
}
$allFlavors = $flavors.Keys

# Choose flavors
if ([string]::IsNullOrEmpty($Flavor)) {
    $selected = $allFlavors
}
else {
    $selected = $Flavor -split '[,;]' | ForEach-Object { $_.Trim().ToLower() }
}

# Validate
$invalid = $selected | Where-Object { -not $flavors.ContainsKey($_) }
if ($invalid) {
    Write-Host "[-] Invalid flavor(s): $($invalid -join ', ')" -ForegroundColor Red
    Write-Host "[*] Valid options: $($allFlavors -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Backup current settings
Copy-Item $settingsPath $backupPath -ErrorAction SilentlyContinue
Write-Host "[*] Backed up settings.json to settings.json.bak" -ForegroundColor Yellow

# Load JSON
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    Write-Host "[*] Loaded settings.json" -ForegroundColor Cyan
}
catch {
    Write-Host "[-] Failed to load settings.json. Aborting." -ForegroundColor Red
    exit 1
}

# Process selected flavors
foreach ($fl in $selected) {
    $info = $flavors[$fl]
    Write-Host "`n[*] Processing flavor: $fl" -ForegroundColor Cyan

    try {
        $theme = Invoke-RestMethod -Uri $info.theme
        Write-Host "[*] Fetched theme JSON" -ForegroundColor Cyan
        $scheme = Invoke-RestMethod -Uri $info.scheme
        Write-Host "[*] Fetched scheme JSON" -ForegroundColor Cyan
    }
    catch {
        Write-Host "[-] Failed to fetch resources for $fl" -ForegroundColor Red
        continue
    }

    if (-not ($settings.themes   | Where-Object { $_.name -eq $theme.name })) {
        $settings.themes += $theme
        Write-Host "[+] Added theme: $($theme.name)"   -ForegroundColor Green
    }
    else {
        Write-Host "[!] Theme already present: $($theme.name)" -ForegroundColor Yellow
    }

    if (-not ($settings.schemes  | Where-Object { $_.name -eq $scheme.name })) {
        $settings.schemes += $scheme
        Write-Host "[+] Added scheme: $($scheme.name)"  -ForegroundColor Green
    }
    else {
        Write-Host "[!] Scheme already present: $($scheme.name)" -ForegroundColor Yellow
    }
}

# Save updated settings
try {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Host "`n[*] Updated settings.json successfully!" -ForegroundColor Green
}
catch {
    Write-Host "[-] Failed to write settings.json." -ForegroundColor Red
    exit 1
}

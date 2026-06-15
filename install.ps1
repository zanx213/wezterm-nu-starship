Set-StrictMode -Version Latest

# Color output helpers
function Write-Step { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Info { param([string]$Message) Write-Host "  -> $Message" -ForegroundColor Yellow }
function Write-Success { param([string]$Message) Write-Host "  -> $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  -> $Message" -ForegroundColor Magenta }
function Write-Err { param([string]$Message) Write-Host "  -> $Message" -ForegroundColor Red }

# Yes/No prompt
function Confirm-Action {
    param([string]$Message)
    while ($true) {
        $input = Read-Host "$Message (Y/N)"
        if ($input -eq 'Y' -or $input -eq 'y') { return $true }
        if ($input -eq 'N' -or $input -eq 'n') { return $false }
        Write-Host "请输入 Y 或 N" -ForegroundColor Red
    }
}

# Check if command exists
function Test-CommandInstalled {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Add directory to User PATH
function Add-ToUserPath {
    param([string]$PathToAdd)
    if (-not (Test-Path $PathToAdd)) { return }
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -split ';' -notcontains $PathToAdd) {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$PathToAdd", "User")
        $env:PATH += ";$PathToAdd"
    }
}

# Elevate to admin if not already
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Write-Warn "需要管理员权限，请在 UAC 对话框中确认提权..."
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -WorkingDirectory (Get-Location)
    Write-Info "如提权被取消，请手动以管理员身份重新运行此脚本"
    exit
}

# Font detection
function Test-FontInstalled {
    param([string]$FontName)
    $fonts = Get-ChildItem "$env:WINDIR\Fonts" -ErrorAction SilentlyContinue
    return $fonts | Where-Object { $_.Name -like "*$FontName*" } | Select-Object -First 1
}

# JetBrainsMono Nerd Font install
function Install-JetBrainsMonoNF {
    Write-Step "JetBrainsMono Nerd Font"

    if (Test-FontInstalled "JetBrainsMonoNerd") {
        Write-Info "已检测到 JetBrainsMono Nerd Font"
        if (-not (Confirm-Action "是否覆盖重装？")) {
            Write-Info "跳过字体安装"
            return
        }
    } elseif (-not (Confirm-Action "是否安装 JetBrainsMono Nerd Font？")) {
        Write-Info "跳过字体安装"
        return
    }

    Write-Info "正在下载 JetBrainsMono Nerd Font..."
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $zipPath = "$env:TEMP\JetBrainsMono.zip"
    $extractPath = "$env:TEMP\JetBrainsMono"

    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Write-Info "下载完成，正在解压..."

        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        Write-Info "正在安装字体到系统..."
        $fontDestination = "$env:WINDIR\Fonts"

        Get-ChildItem "$extractPath\*.ttf", "$extractPath\*.otf" | ForEach-Object {
            $destPath = Join-Path $fontDestination $_.Name
            Copy-Item $_.FullName $destPath -Force

            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $fontRegName = if ($_.Extension -eq '.ttf') {
                "$($_.BaseName) (TrueType)"
            } else {
                "$($_.BaseName) (OpenType)"
            }
            New-ItemProperty -Path $regPath -Name $fontRegName -Value $_.Name -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        }

        Write-Success "JetBrainsMono Nerd Font 安装完成"
    } catch {
        Write-Err "字体安装失败: $_"
    } finally {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# WezTerm Nightly install
function Install-WezTerm {
    Write-Step "WezTerm (Nightly)"

    $installed = Test-CommandInstalled "wezterm"

    if ($installed) {
        Write-Info "已检测到 WezTerm"
        if (-not (Confirm-Action "是否覆盖重装 WezTerm？")) {
            Write-Info "跳过 WezTerm 安装，继续配置"
            Write-WezTermConfig
            return
        }
    } elseif (-not (Confirm-Action "是否安装 WezTerm Nightly？")) {
        Write-Info "跳过 WezTerm 安装"
        return
    }

    Write-Info "正在下载 WezTerm Nightly..."
    try {
        $url = "https://github.com/wez/wezterm/releases/download/nightly/WezTerm-nightly-setup.exe"
        $exePath = "$env:TEMP\WezTerm-nightly-setup.exe"
        Invoke-WebRequest -Uri $url -OutFile $exePath -UseBasicParsing

        Write-Info "正在静默安装..."
        Start-Process -FilePath $exePath -ArgumentList "/S" -Wait
        Remove-Item $exePath -Force -ErrorAction SilentlyContinue
        Write-Success "WezTerm 安装完成"
    } catch {
        Write-Err "WezTerm 安装失败: $_"
        return
    }

    Write-WezTermConfig
}

# WezTerm Configuration
function Write-WezTermConfig {
    Write-Info "生成 WezTerm 配置..."

    $source = Join-Path $PSScriptRoot "config" "wezterm.lua"
    $dest = "$env:USERPROFILE\.wezterm.lua"

    if (-not (Test-Path $source)) {
        Write-Err "配置文件不存在: $source"
        return
    }

    Copy-Item -Path $source -Destination $dest -Force
    Write-Success "WezTerm 配置已生成: $dest"
}

# Nushell install
function Install-Nushell {
    Write-Step "Nushell"

    $installed = Test-CommandInstalled "nu"

    if ($installed) {
        Write-Info "已检测到 Nushell"
        if (-not (Confirm-Action "是否覆盖重装 Nushell？")) {
            Write-Info "跳过 Nushell 安装，继续配置"
            Write-NushellConfig
            return
        }
    } elseif (-not (Confirm-Action "是否安装 Nushell？")) {
        Write-Info "跳过 Nushell 安装"
        return
    }

    # Try winget first
    try {
        Write-Info "正在通过 winget 安装 Nushell..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        $psi.Arguments = "install --id=nushell -e --silent --accept-package-agreements --accept-source-agreements"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) { $proc.WaitForExit() }
        if ($proc -and $proc.HasExited -and $proc.ExitCode -eq 0) {
            Write-Success "Nushell 安装完成"
            Write-NushellConfig
            return
        }
        Write-Warn "winget 安装失败，尝试从 GitHub 下载..."
    } catch {
        Write-Warn "winget 不可用，尝试从 GitHub 下载..."
    }

    # Fallback: GitHub download
    try {
        $apiUrl = "https://api.github.com/repos/nushell/nushell/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" -and $_.name -like "*.zip" } | Select-Object -First 1

        if (-not $asset) {
            Write-Err "未找到 Nushell Windows 安装包"
            return
        }

        $zipPath = "$env:TEMP\nushell.zip"
        $extractPath = "$env:LOCALAPPDATA\nushell"

        Write-Info "正在下载 Nushell $($release.tag_name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        Add-ToUserPath $extractPath

        Write-Success "Nushell 安装完成"
    } catch {
        Write-Err "Nushell 安装失败: $_"
        return
    }

    Write-NushellConfig
}

# Nushell Configuration
function Write-NushellConfig {
    Write-Info "生成 Nushell 配置..."

    $configDir = "$env:APPDATA\nushell"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # env.nu
    $sourceEnv = Join-Path $PSScriptRoot "config" "nushell" "env.nu"
    $destEnv = "$configDir\env.nu"
    if (Test-Path $sourceEnv) {
        Copy-Item -Path $sourceEnv -Destination $destEnv -Force
    } else {
        [System.IO.File]::WriteAllText($destEnv, "# env.nu")
    }

    # ---- Git 自动补全 ----
    Write-Info "正在安装 Git 自动补全脚本..."
    $completionsDir = "$configDir\completions"
    if (-not (Test-Path $completionsDir)) {
        New-Item -ItemType Directory -Path $completionsDir -Force | Out-Null
    }
    $gitCompletionUrl = "https://raw.githubusercontent.com/nushell/nu_scripts/main/custom-completions/git/git-completions.nu"
    $gitCompletionPath = "$completionsDir\git-completions.nu"
    try {
        Invoke-WebRequest -Uri $gitCompletionUrl -OutFile $gitCompletionPath -UseBasicParsing
        Write-Success "Git 自动补全脚本已下载"
    } catch {
        Write-Warn "Git 自动补全下载失败: $_"
    }

    # config.nu
    $sourceConfig = Join-Path $PSScriptRoot "config" "nushell" "config.nu"
    $destConfig = "$configDir\config.nu"
    if (Test-Path $sourceConfig) {
        Copy-Item -Path $sourceConfig -Destination $destConfig -Force
    }

    Write-Success "Nushell 配置已生成: $configDir"
}

# Starship install
function Install-Starship {
    Write-Step "Starship"

    $installed = Test-CommandInstalled "starship"

    if ($installed) {
        Write-Info "已检测到 Starship"
        if (-not (Confirm-Action "是否覆盖重装 Starship？")) {
            Write-Info "跳过 Starship 安装，继续配置"
            Write-StarshipConfig
            return
        }
    } elseif (-not (Confirm-Action "是否安装 Starship？")) {
        Write-Info "跳过 Starship 安装"
        return
    }

    # Try winget first
    try {
        Write-Info "正在通过 winget 安装 Starship..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        $psi.Arguments = "install --id=Starship.Starship -e --silent --accept-package-agreements --accept-source-agreements"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) { $proc.WaitForExit() }
        if ($proc -and $proc.HasExited -and $proc.ExitCode -eq 0) {
            Write-Success "Starship 安装完成"
            Write-StarshipConfig
            return
        }
        Write-Warn "winget 安装失败，尝试直接下载..."
    } catch {
        Write-Warn "winget 不可用，尝试直接下载..."
    }

    # Fallback: download binary directly
    try {
        Write-Info "正在下载 Starship 二进制文件..."
        $starshipUrl = "https://github.com/starship/starship/releases/latest/download/starship-x86_64-pc-windows-msvc.zip"
        $zipPath = "$env:TEMP\starship.zip"
        $extractPath = "$env:LOCALAPPDATA\starship"

        Invoke-WebRequest -Uri $starshipUrl -OutFile $zipPath -UseBasicParsing
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Remove-Item $zipPath -Force

        Add-ToUserPath $extractPath

        Write-Success "Starship 安装完成"
    } catch {
        Write-Err "Starship 安装失败: $_"
        return
    }

    Write-StarshipConfig
}

# Starship Configuration
function Write-StarshipConfig {
    Write-Info "生成 Starship 配置..."

    $configDir = "$env:USERPROFILE\.config"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $source = Join-Path $PSScriptRoot "config" "starship.toml"
    $dest = "$configDir\starship.toml"

    if (-not (Test-Path $source)) {
        Write-Err "配置文件不存在: $source"
        return
    }

    Copy-Item -Path $source -Destination $dest -Force
    Write-Success "Starship 配置已生成: $dest"
}

# Main entry point
function Start-DevEnvSetup {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Windows Dev Environment Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Info "本脚本将安装以下组件："
    Write-Info "  1. JetBrainsMono Nerd Font (终端字体)"
    Write-Info "  2. WezTerm Nightly (终端模拟器)"
    Write-Info "  3. Nushell (Shell)"
    Write-Info "  4. Starship (Prompt 美化)"
    Write-Host ""

    if (-not (Confirm-Action "是否继续？")) {
        Write-Info "已取消"
        exit
    }

    Install-JetBrainsMonoNF
    Install-WezTerm
    Install-Nushell
    Install-Starship

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  安装完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "下一步："
    Write-Info "  1. 重新打开终端使 PATH 生效"
    Write-Info "  2. 打开 WezTerm 即可体验"
    Write-Info "  3. 如遇到 Starship 不显示，执行: starship init nu | save ~/.config/nushell/starship.nu"
    Write-Host ""
    pause
}

# Entry point
Start-DevEnvSetup

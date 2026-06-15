#!/usr/bin/env python3
"""
Windows Dev Environment Setup
一键安装 WezTerm nightly + Nushell + Starship + JetBrainsMono Nerd Font
"""

import ctypes
import os
import shutil
import subprocess
import sys
import tempfile
import winreg
import zipfile
from pathlib import Path

import requests

# ── 脚本自身路径 ──────────────────────────────────────────

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_DIR = SCRIPT_DIR / "config"

# ── 辅助函数 ──────────────────────────────────────────────


def info(msg):
    print(f"  -> {msg}")


def step(msg):
    print(f"\n==> {msg}")


def success(msg):
    print(f"  -> {msg}")


def warn(msg):
    print(f"  -> {msg}")


def confirm(msg) -> bool:
    while True:
        ans = input(f"{msg} (Y/N) ").strip().lower()
        if ans == "y":
            return True
        if ans == "n":
            return False
        print("  -> 请输入 Y 或 N")


def cmd_exists(name: str) -> bool:
    return shutil.which(name) is not None


def add_to_user_path(path: str):
    if not os.path.isdir(path):
        return
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_ALL_ACCESS)
    try:
        current, _ = winreg.QueryValueEx(key, "PATH")
    except FileNotFoundError:
        current = ""
    segments = current.split(";") if current else []
    if path not in segments:
        new_path = f"{current};{path}" if current else path
        winreg.SetValueEx(key, "PATH", 0, winreg.REG_EXPAND_SZ, new_path)
        os.environ["PATH"] += f";{path}"
    winreg.CloseKey(key)


def download(url: str, dest: str):
    info(f"正在下载 {Path(dest).name}...")
    r = requests.get(url, stream=True, timeout=60)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            f.write(chunk)


# ── 管理员提权 ────────────────────────────────────────────


def is_admin() -> bool:
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def elevate():
    if is_admin():
        return
    warn("需要管理员权限，请在 UAC 对话框中确认提权...")
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, " ".join(sys.argv), None, 1
    )
    info("如提权被取消，请手动以管理员身份重新运行此脚本")
    sys.exit(0)


# ── JetBrainsMono Nerd Font ────────────────────────────────


def font_installed(name: str) -> bool:
    fonts_dir = Path(os.environ["WINDIR"]) / "Fonts"
    if not fonts_dir.exists():
        return False
    return any(f.name.lower().startswith(name.lower()) for f in fonts_dir.iterdir())


def install_jetbrains_mono_nf():
    step("JetBrainsMono Nerd Font")

    if font_installed("JetbrainsMonoNerd"):
        info("已检测到 JetBrainsMono Nerd Font")
        if not confirm("是否覆盖重装？"):
            return
    elif not confirm("是否安装 JetBrainsMono Nerd Font？"):
        return

    zip_path = Path(tempfile.gettempdir()) / "JetBrainsMono.zip"
    extract_path = Path(tempfile.gettempdir()) / "JetBrainsMono"
    font_dest = Path(os.environ["WINDIR"]) / "Fonts"

    try:
        download(
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip",
            str(zip_path),
        )
        info("下载完成，正在解压...")

        if extract_path.exists():
            shutil.rmtree(extract_path)
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(extract_path)

        info("正在安装字体到系统...")
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
            0,
            winreg.KEY_ALL_ACCESS,
        )

        for ext in ("*.ttf", "*.otf"):
            for font_file in extract_path.glob(ext):
                dest = font_dest / font_file.name
                shutil.copy2(font_file, dest)

                reg_name = (
                    f"{font_file.stem} (TrueType)"
                    if font_file.suffix == ".ttf"
                    else f"{font_file.stem} (OpenType)"
                )
                try:
                    winreg.SetValueEx(key, reg_name, 0, winreg.REG_SZ, font_file.name)
                except Exception:
                    pass

        winreg.CloseKey(key)
        success("JetBrainsMono Nerd Font 安装完成")
    except Exception as e:
        print(f"  -> 字体安装失败: {e}")
    finally:
        if zip_path.exists():
            zip_path.unlink()
        if extract_path.exists():
            shutil.rmtree(extract_path, ignore_errors=True)


# ── WezTerm ────────────────────────────────────────────────

def install_wezterm():
    step("WezTerm (Nightly)")

    installed = cmd_exists("wezterm")

    if installed:
        info("已检测到 WezTerm")
        if not confirm("是否覆盖重装 WezTerm？"):
            info("跳过 WezTerm 安装，继续配置")
            write_wezterm_config()
            return
    elif not confirm("是否安装 WezTerm Nightly？"):
        return

    info("正在下载 WezTerm Nightly...")
    try:
        url = "https://github.com/wez/wezterm/releases/download/nightly/WezTerm-nightly-setup.exe"
        exe_path = Path(tempfile.gettempdir()) / "WezTerm-nightly-setup.exe"
        download(url, str(exe_path))

        info("正在静默安装...")
        subprocess.run([str(exe_path), "/S"], check=True)
        exe_path.unlink(missing_ok=True)
        success("WezTerm 安装完成")
    except Exception as e:
        print(f"  -> WezTerm 安装失败: {e}")
        return

    write_wezterm_config()


def write_wezterm_config():
    info("生成 WezTerm 配置...")
    source = CONFIG_DIR / "wezterm.lua"
    dest = Path.home() / ".wezterm.lua"
    if not source.exists():
        print(f"  -> 配置文件不存在: {source}")
        return
    shutil.copy2(source, dest)
    success(f"WezTerm 配置已生成: {dest}")


# ── Nushell ────────────────────────────────────────────────

def install_nushell():
    step("Nushell")

    installed = cmd_exists("nu")

    if installed:
        info("已检测到 Nushell")
        if not confirm("是否覆盖重装 Nushell？"):
            info("跳过 Nushell 安装，继续配置")
            write_nushell_config()
            return
    elif not confirm("是否安装 Nushell？"):
        return

    # Try winget first
    try:
        info("正在通过 winget 安装 Nushell...")
        r = subprocess.run(
            [
                "winget",
                "install",
                "--id=nushell",
                "-e",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
            ],
            capture_output=True,
            timeout=120,
        )
        if r.returncode == 0:
            success("Nushell 安装完成")
            write_nushell_config()
            return
        warn("winget 安装失败，尝试从 GitHub 下载...")
    except Exception:
        warn("winget 不可用，尝试从 GitHub 下载...")

    # Fallback: GitHub download
    try:
        api_url = "https://api.github.com/repos/nushell/nushell/releases/latest"
        release = requests.get(api_url, timeout=30).json()
        asset = None
        for a in release.get("assets", []):
            name = a["name"]
            if "x86_64-pc-windows-msvc" in name and name.endswith(".zip"):
                asset = a
                break

        if not asset:
            print("  -> 未找到 Nushell Windows 安装包")
            return

        zip_path = Path(tempfile.gettempdir()) / "nushell.zip"
        extract_path = Path(os.environ["LOCALAPPDATA"]) / "nushell"

        info(f"正在下载 Nushell {release['tag_name']}...")
        download(asset["browser_download_url"], str(zip_path))

        if extract_path.exists():
            shutil.rmtree(extract_path)
        extract_path.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(extract_path)
        zip_path.unlink()

        add_to_user_path(str(extract_path))
        success("Nushell 安装完成")
    except Exception as e:
        print(f"  -> Nushell 安装失败: {e}")
        return

    write_nushell_config()


def write_nushell_config():
    info("生成 Nushell 配置...")
    config_dir = Path(os.environ["APPDATA"]) / "nushell"
    config_dir.mkdir(parents=True, exist_ok=True)

    # Git 自动补全
    info("正在安装 Git 自动补全脚本...")
    completions_dir = config_dir / "completions"
    completions_dir.mkdir(parents=True, exist_ok=True)
    git_completion_url = "https://raw.githubusercontent.com/nushell/nu_scripts/main/custom-completions/git/git-completions.nu"
    git_completion_path = completions_dir / "git-completions.nu"
    try:
        download(git_completion_url, str(git_completion_path))
        success("Git 自动补全脚本已下载")
    except Exception as e:
        warn(f"Git 自动补全下载失败: {e}")

    # 从 config/ 目录复制
    nu_config_dir = CONFIG_DIR / "nushell"
    if nu_config_dir.exists():
        for f in ("env.nu", "config.nu"):
            src = nu_config_dir / f
            if src.exists():
                shutil.copy2(src, config_dir / f)
    success(f"Nushell 配置已生成: {config_dir}")


# ── Starship ───────────────────────────────────────────────

def install_starship():
    step("Starship")

    installed = cmd_exists("starship")

    if installed:
        info("已检测到 Starship")
        if not confirm("是否覆盖重装 Starship？"):
            info("跳过 Starship 安装，继续配置")
            write_starship_config()
            return
    elif not confirm("是否安装 Starship？"):
        return

    # Try winget first
    try:
        info("正在通过 winget 安装 Starship...")
        r = subprocess.run(
            [
                "winget",
                "install",
                "--id=Starship.Starship",
                "-e",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
            ],
            capture_output=True,
            timeout=120,
        )
        if r.returncode == 0:
            success("Starship 安装完成")
            write_starship_config()
            return
        warn("winget 安装失败，尝试直接下载...")
    except Exception:
        warn("winget 不可用，尝试直接下载...")

    # Fallback: download binary
    try:
        info("正在下载 Starship 二进制文件...")
        url = "https://github.com/starship/starship/releases/latest/download/starship-x86_64-pc-windows-msvc.zip"
        zip_path = Path(tempfile.gettempdir()) / "starship.zip"
        extract_path = Path(os.environ["LOCALAPPDATA"]) / "starship"

        download(url, str(zip_path))

        if extract_path.exists():
            shutil.rmtree(extract_path)
        extract_path.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(extract_path)
        zip_path.unlink()

        add_to_user_path(str(extract_path))
        success("Starship 安装完成")
    except Exception as e:
        print(f"  -> Starship 安装失败: {e}")
        return

    write_starship_config()


def write_starship_config():
    info("生成 Starship 配置...")
    config_dir = Path.home() / ".config"
    config_dir.mkdir(parents=True, exist_ok=True)

    source = CONFIG_DIR / "starship.toml"
    dest = config_dir / "starship.toml"
    if not source.exists():
        print(f"  -> 配置文件不存在: {source}")
        return
    shutil.copy2(source, dest)
    success(f"Starship 配置已生成: {dest}")


# ── 主入口 ────────────────────────────────────────────────


def main():
    elevate()

    print("")
    print("=" * 40)
    print("  Windows Dev Environment Setup")
    print("=" * 40)
    print("")

    info("本脚本将安装以下组件：")
    info("  1. JetBrainsMono Nerd Font (终端字体)")
    info("  2. WezTerm Nightly (终端模拟器)")
    info("  3. Nushell (Shell)")
    info("  4. Starship (Prompt 美化)")
    print("")

    if not confirm("是否继续？"):
        info("已取消")
        return

    install_jetbrains_mono_nf()
    install_wezterm()
    install_nushell()
    install_starship()

    print("")
    print("=" * 40)
    print("  安装完成！")
    print("=" * 40)
    print("")
    info("下一步：")
    info("  1. 重新打开终端使 PATH 生效")
    info("  2. 打开 WezTerm 即可体验")
    input("")
    print("")


if __name__ == "__main__":
    main()

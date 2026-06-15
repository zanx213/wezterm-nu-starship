# wezterm-nu-starship

Windows 一键安装 **WezTerm Nightly** + **Nushell** + **Starship** + **JetBrainsMono Nerd Font** + **Git 自动补全**，自动生成开箱即用的终端配置。

## 使用

| 脚本 | 运行方式 |
|------|----------|
| `install.ps1` | 右键"以 PowerShell 运行" |
| `install.py` | `pip install requests && python install.py` |

脚本会自动请求管理员提权，逐项检测、询问、安装并生成配置。

## 组件

| 组件 | 版本 | 安装方式 |
|------|------|----------|
| JetBrainsMono Nerd Font | latest | GitHub Releases → `%WINDIR%\Fonts` |
| WezTerm | nightly | winget / GitHub exe |
| Nushell | latest stable | winget / GitHub zip |
| Starship | latest | winget / GitHub zip |
| Git 自动补全 (Nushell) | latest | 从 nu_scripts 官方仓库下载至 completions 目录 |

## 配置

所有配置统一存放在 `config/` 目录下，脚本执行时直接复制到对应位置：

```
config/
├── wezterm.lua              # WezTerm 配置
├── starship.toml             # Starship 配置
└── nushell/
    ├── config.nu             # Nushell 主配置（含 Git 补全引入）
    └── env.nu                # Nushell 环境变量配置
```

- **WezTerm** (`config/wezterm.lua`) — Tokyo Night 主题，JetBrainsMono NF 13px，Alt 快捷键体系（分屏/切屏/标签），INTEGRATED_BUTTONS 去标题栏
- **Nushell** (`config/nushell/config.nu`) — Starship 缓存 init，`show_banner=false`，Git 自动补全（动态路径 `use completions/git-completions.nu`），内置 alias（ll/la/lt/l/g）
- **Starship** (`config/starship.toml`) — `[>]` 提示符，粗体青色目录，Git 分支图标，Python/Node.js/耗时模块

修改配置只需编辑 `config/` 下的文件，改一处即可。

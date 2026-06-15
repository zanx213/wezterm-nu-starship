# 1. Starship 提示符
if not ($"($nu.home-dir)/.cache/starship/init.nu" | path exists) {
    mkdir ~/.cache/starship
    starship init nu | save ~/.cache/starship/init.nu
}
use ~/.cache/starship/init.nu

# 2. 基础配置
$env.config.show_banner = false
$env.STARSHIP_SHELL = "nu"

# 3. 自定义配置区域
alias ll = ls -l
alias la = ls -a
alias lt = ls -t
alias l = ls
alias g = git

def lsd [] { ls | where type == dir }   # 输入 lsd，只看文件夹
def lsf [] { ls | where type == file }  # 输入 lsf，只看文件

def starship-reload [] {
    starship init nu | save -f ~/.cache/starship/init.nu
}

# Git 自动补全（动态定位至 nushell 配置目录下的 completions）
use ($nu.config-path | path dirname | path join 'completions' 'git-completions.nu') *
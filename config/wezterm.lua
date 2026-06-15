-- .wezterm.lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- 默认拉起 Nushell
config.default_prog = { 'nu' }

-- 自定义快捷键
config.keys = {
  -- 用 Alt + d 左右分屏 (Direction Right)
  { key = 'd', mods = 'ALT', action = wezterm.action.SplitHorizontal{ domain = 'CurrentPaneDomain' } },
  -- 用 Alt + s 上下分屏 (Split Down)
  { key = 's', mods = 'ALT', action = wezterm.action.SplitVertical{ domain = 'CurrentPaneDomain' } },
  -- 用 Alt + w 关闭当前分屏
  { key = 'w', mods = 'ALT', action = wezterm.action.CloseCurrentPane{ confirm = true } },
  -- 用 Alt + t 新建标签
  { key = 't', mods = 'ALT', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  -- 用 Alt + 键 像前端切标签一样在分屏间切换
  { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },
}

-- 字体配置（已安装的 JetBrainsMono Nerd Font）
config.font = wezterm.font('JetBrainsMono Nerd Font')
config.font_size = 12.0

-- 主题配色
config.color_scheme = 'Tokyo Night'

-- 窗口布局与精致内边距
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.window_background_opacity = 0.95
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE" -- 去掉标题栏，按钮集成到 tab bar
config.show_tab_index_in_tab_bar = false       -- 隐藏 tab 序号

-- 默认打开时的窗口大小
config.initial_cols = 100
config.initial_rows = 25

return config
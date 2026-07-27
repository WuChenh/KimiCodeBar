## v1.2.3

- 自动归档页面支持折叠/展开工作区文件夹，标题行增加悬停高亮反馈
- 设置窗口默认尺寸增大，DMG 文件名加入处理器架构标识
- CI 工作流升级至 Node.js 24，修复弃用警告
- README 添加未签名 app 的 xattr 解决方法
- 代码清理：移除未使用的 import 和无用变量
- DeepSeek API Key 卡片支持中英双语切换

### English

- Archive page: collapsible workspace folders with hover highlight
- Larger default settings window size, DMG filename includes CPU architecture
- CI workflow upgraded to Node.js 24, deprecated warnings resolved
- README: xattr workaround for unsigned app
- Code cleanup: removed unused imports and variables
- DeepSeek API Key card now supports bilingual switching

## v1.2.2

- 自动归档页面支持折叠/展开工作区文件夹
- 设置窗口默认尺寸增大
- CI 工作流版本升级，修复 Node.js 20 弃用警告

### English

- Archive page: collapsible workspace folders
- Larger default settings window size
- CI workflow version upgrade, Node.js 20 deprecation warnings resolved

## v1.2.1

- 修复菜单栏面板语言切换后不响应的问题
- 优化归档扫描性能，减少 UI 卡顿

### English

- Fixed menu bar panel unresponsive after language switch
- Optimized archive scan performance, reduced UI lag

## v1.2.0

- 新增「本机消耗量」卡片：扫描本地 Kimi Code 会话记录，展示 Token 消耗总量、缓存命中率和按天柱状图。
- 支持累计 / 今日 / 7 天三种时间范围切换，首次加载骨架屏 shimmer 动效。
- 增量扫描引擎：记录每个文件的字节偏移量，仅读取新增内容，状态持久化到 Application Support。
- 新增 DeepSeek 平台支持：在 Kimi 和 DeepSeek 之间一键切换，独立查看各平台用量余额。
- 使用 Apple Developer ID 正式签名并通过 Notarization 公证，安装时不再提示"无法验证开发者"。
- 版本行检测到新版本时强制显示，避免用户错过重要更新。
- Skills 预览改用 TextEditor 渲染，解决长文本布局卡死主线程的问题。
- 色彩系统重构为纯 SwiftUI：系统语义色自动适配浅色/深色模式，面板采用 Material 背景。
- Kimi Code Logo 动画由 CALayer 重写为纯 SwiftUI 实现。
- 移除 Sparkle 自动更新框架，精简依赖与包体积。

### English

- New "Local Token Tracking" card: scans local Kimi Code session records to display total Token consumption, cache hit rate, and daily bar charts.
- Cumulative / Today / 7-Day time range switching with skeleton shimmer animation on first load.
- Incremental scan engine: records byte offsets per file, reads only new content, state persisted to Application Support.
- DeepSeek platform support: one-click switch between Kimi and DeepSeek, independent quota display per platform.
- Signed with Apple Developer ID and notarized, no more "unverified developer" warning on install.
- Version row always visible when an update is available, avoiding missed updates.
- Skills preview switched to TextEditor rendering, resolving main thread freeze on long content.
- Color system rewritten in pure SwiftUI: semantic colors auto-adapt to light/dark mode, Material background on panel.
- Kimi Code Logo animation rewritten from CALayer to pure SwiftUI.
- Removed Sparkle auto-update framework, reducing dependencies and bundle size.

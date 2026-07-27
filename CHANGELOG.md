## v1.2.0 更新内容

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

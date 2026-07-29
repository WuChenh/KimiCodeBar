import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

// MARK: - 主题

enum AppTheme: String, CaseIterable, Identifiable {
  case system
  case dark
  case light

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: return LanguageManager.tr("跟随系统")
    case .dark: return LanguageManager.tr("月之暗面")
    case .light: return LanguageManager.tr("月之亮面")
    }
  }

  var iconName: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .dark: return "moon.fill"
    case .light: return "sun.max.fill"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .dark: return .dark
    case .light: return .light
    }
  }

  var nsAppearance: NSAppearance? {
    switch self {
    case .system: return nil
    case .dark: return NSAppearance(named: .darkAqua)
    case .light: return NSAppearance(named: .aqua)
    }
  }
}

@MainActor
final class ThemeManager: ObservableObject {
  static let shared = ThemeManager()

  @Published var theme: AppTheme {
    didSet {
      UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
      NSApplication.shared.appearance = theme.nsAppearance
    }
  }

  private init() {
    let rawValue = UserDefaults.standard.string(forKey: "appTheme") ?? ""
    theme = AppTheme(rawValue: rawValue) ?? .system
  }
}

// MARK: - 开机自动启动

/// 基于 SMAppService（macOS 13+ 官方推荐 API）管理登录项，
/// 注册后 App 会在用户登录 macOS 时自动启动。
@MainActor
final class LaunchAtLoginManager: ObservableObject {
  static let shared = LaunchAtLoginManager()

  @Published private(set) var isEnabled: Bool

  private init() {
    isEnabled = SMAppService.mainApp.status == .enabled
  }

  /// 同步系统侧实际状态（用户可能在系统设置里手动改动了登录项）。
  func refresh() {
    isEnabled = SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      // 注册 / 取消失败时保持原状，以系统实际状态为准
    }
    refresh()
  }
}

@main
struct KimiCodeBarApp: App {
  @StateObject private var themeManager = ThemeManager.shared

  init() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    NSApplication.shared.appearance = ThemeManager.shared.theme.nsAppearance
  }

  var body: some Scene {
    MenuBarExtra {
      KimiMenu()
    } label: {
      KimiLabel()
    }
    .menuBarExtraStyle(.window)
  }
}

// MARK: - 配色

extension ShapeStyle where Self == Color {
  /// Kimi 品牌蓝色
  static var kimiBlue: Color { Color(red: 0.23, green: 0.51, blue: 0.96) }

  /// 主文本色，跟随系统 Light/Dark 自动适配
  static var kimiTextPrimary: Color { .primary }

  /// 次级文本色
  static var kimiTextSecondary: Color { .secondary }

  /// 三级文本色
  static var kimiTextTertiary: Color { .secondary.opacity(0.45) }
}

// MARK: - 菜单栏图标

struct KimiLabel: View {
  @StateObject private var model = KimiCodeBarModel.shared
  @StateObject private var languageManager = LanguageManager.shared

  var body: some View {
    let showKimi = model.showKimiMenuBar && model.quota != nil
    let showDS = model.showDeepseekMenuBar

    if showKimi && showDS {
      // 两者都显示：组合渲染
      Image(
        nsImage: MenuBarTextRenderer.combinedImage(
          scheme: model.menuBarDisplayScheme,
          weekly: model.quota?.weekly.percentage ?? 0,
          fiveHour: model.quota?.fiveHour.percentage ?? 0,
          deepseekText: model.deepseekMenuBarText
        ))
    } else if showKimi {
      Image(
        nsImage: MenuBarTextRenderer.image(
          scheme: model.menuBarDisplayScheme,
          weekly: model.quota?.weekly.percentage ?? 0,
          fiveHour: model.quota?.fiveHour.percentage ?? 0
        ))
    } else {
      Text(model.text)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .monospacedDigit()
    }
  }
}

private func percentageText(_ percentage: Int) -> String {
  // 100% 时去掉数字和百分号之间的细空格，避免菜单栏宽度不够被截断
  percentage == 100 ? "\(percentage)%" : "\(percentage)\u{2009}%"
}

private func percentageFont(for percentage: Int) -> Font {
  .system(size: 10, weight: .medium, design: .default)
}

enum MenuBarDisplayScheme: String, CaseIterable, Identifiable {
  case compact
  case kPrefix
  case singleLine

  /// 旧 case，保留以避免已保存偏好崩溃，但不在 UI 中展示。
  case kimiPrefix

  static var allCases: [MenuBarDisplayScheme] {
    [.compact, .kPrefix, .singleLine]
  }

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .compact: return LanguageManager.tr("默认样式")
    case .kPrefix: return LanguageManager.tr("K 前缀")
    case .singleLine: return LanguageManager.tr("单行")
    case .kimiPrefix: return LanguageManager.tr("Kimi 前缀")
    }
  }
}

@MainActor
enum MenuBarTextRenderer {
  private static let textColor = Color(red: 0.886, green: 0.910, blue: 0.961)

  static func image(scheme: MenuBarDisplayScheme, weekly: Int, fiveHour: Int) -> NSImage {
    switch scheme {
    case .compact:
      return compactImage(weekly: weekly, fiveHour: fiveHour)
    case .kPrefix:
      return prefixImage(prefix: "K", weekly: weekly, fiveHour: fiveHour)
    case .kimiPrefix:
      return prefixImage(prefix: "Kimi", weekly: weekly, fiveHour: fiveHour)
    case .singleLine:
      return singleLineImage(weekly: weekly, fiveHour: fiveHour)
    }
  }

  /// 组合渲染：Kimi 百分比 + DeepSeek 文本，菜单栏同时显示两个平台
  static func combinedImage(
    scheme: MenuBarDisplayScheme, weekly: Int, fiveHour: Int, deepseekText: String
  ) -> NSImage {
    let kimiImage = image(scheme: scheme, weekly: weekly, fiveHour: fiveHour)

    let content = HStack(spacing: 4) {
      Image(nsImage: kimiImage)
      Text(deepseekText)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .monospacedDigit()
        .fixedSize()
    }
    .foregroundStyle(textColor)
    .frame(height: 20)
    .fixedSize(horizontal: true, vertical: false)

    return render(content)
  }

  /// 原始紧凑样式：48pt 宽，两行 7D/5H。
  /// 这是用户已经深度微调过的样式，原封不动保留。
  private static func compactImage(weekly: Int, fiveHour: Int) -> NSImage {
    let content = VStack(alignment: .trailing, spacing: -1) {
      HStack(spacing: 2) {
        Text("7D")
          .font(.system(size: 10, weight: .medium, design: .default))
          .monospacedDigit()
          .frame(width: 16, alignment: .leading)
        Text(percentageText(weekly))
          .font(percentageFont(for: weekly))
          .monospacedDigit()
          .frame(width: 30, alignment: .trailing)
      }
      HStack(spacing: 2) {
        Text("5H")
          .font(.system(size: 10, weight: .medium, design: .default))
          .monospacedDigit()
          .frame(width: 16, alignment: .leading)
        Text(percentageText(fiveHour))
          .font(percentageFont(for: fiveHour))
          .monospacedDigit()
          .frame(width: 30, alignment: .trailing)
      }
    }
    .foregroundStyle(textColor)
    .frame(width: 48, height: 20, alignment: .trailing)

    return render(content)
  }

  /// 前缀样式：K / Kimi 作为左侧大字号前缀，右侧上下两行百分比。
  private static func prefixImage(prefix: String, weekly: Int, fiveHour: Int) -> NSImage {
    let prefixWidth: CGFloat = prefix == "K" ? 14 : 38
    let percentageWidth: CGFloat = 36
    let totalWidth: CGFloat = prefixWidth + 3 + percentageWidth

    let content = HStack(alignment: .center, spacing: 3) {
      Text(prefix)
        .font(.system(size: 20, weight: .bold, design: .default))
        .monospacedDigit()
        .frame(width: prefixWidth, height: 20, alignment: .leading)

      VStack(alignment: .trailing, spacing: 0) {
        Text(percentageText(weekly))
          .font(percentageFont(for: weekly))
          .monospacedDigit()
          .frame(width: percentageWidth, alignment: .trailing)
        Text(percentageText(fiveHour))
          .font(percentageFont(for: fiveHour))
          .monospacedDigit()
          .frame(width: percentageWidth, alignment: .trailing)
      }
    }
    .foregroundStyle(textColor)
    .frame(width: totalWidth, height: 20, alignment: .trailing)

    return render(content)
  }

  /// 单行样式：Kimi 84% · 6%
  private static func singleLineImage(weekly: Int, fiveHour: Int) -> NSImage {
    let content = HStack(spacing: 4) {
      Text("Kimi")
        .font(.system(size: 12, weight: .bold, design: .default))
      Text(percentageText(weekly))
        .font(.system(size: 12, weight: .medium, design: .default))
        .monospacedDigit()
      Text("·")
        .font(.system(size: 12, weight: .medium))
      Text(percentageText(fiveHour))
        .font(.system(size: 12, weight: .medium, design: .default))
        .monospacedDigit()
    }
    .foregroundStyle(textColor)
    .frame(height: 20)
    .fixedSize(horizontal: true, vertical: false)

    return render(content)
  }

  private static func render<V: View>(_ content: V) -> NSImage {
    let renderer = ImageRenderer(content: content)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

    guard let nsImage = renderer.nsImage else {
      return NSImage(size: NSSize(width: 56, height: 22))
    }
    nsImage.isTemplate = false
    return nsImage
  }
}

// MARK: - 窗口可见性探测

/// 监听菜单面板窗口的 key 状态，只在面板打开时让 Logo 动画运行，
/// 避免收起后仍持续刷新。
struct WindowVisibilityDetector: NSViewRepresentable {
  @Binding var isVisible: Bool

  func makeNSView(context: Context) -> WindowVisibilityView {
    let view = WindowVisibilityView()
    view.onChange = { isVisible in
      self.isVisible = isVisible
    }
    return view
  }

  func updateNSView(_ nsView: WindowVisibilityView, context: Context) {}
}

final class WindowVisibilityView: NSView {
  var onChange: ((Bool) -> Void)?
  private var observationTokens: [NSObjectProtocol] = []

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    observe(window: window)
  }

  private func observe(window: NSWindow?) {
    for token in observationTokens {
      NotificationCenter.default.removeObserver(token)
    }
    observationTokens.removeAll()

    guard let window = window else {
      onChange?(false)
      return
    }

    onChange?(window.isKeyWindow || window.isVisible)

    observationTokens = [
      NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.onChange?(true)
      },
      NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.onChange?(false)
      },
    ]
  }
}

// MARK: - Kimi Code 图标（纯 SwiftUI，眨眼 + 左右看动画）

struct AnimatedKimiCodeLogo: View {
  var width: CGFloat = 44
  let isAnimating: Bool

  private var scale: CGFloat { width / 32 }

  var body: some View {
    let bodyW = 30 * scale
    let bodyH = 20 * scale
    let bodyR = 6 * scale
    let eyeW = 2.8 * scale
    let leftCX: CGFloat = 11.8 * scale + eyeW / 2
    let rightCX: CGFloat = 17.4 * scale + eyeW / 2
    let eyeCY: CGFloat = 11 * scale

    ZStack {
      RoundedRectangle(cornerRadius: bodyR)
        .fill(Color.kimiBlue)
        .shadow(color: Color.kimiBlue.opacity(0.35), radius: 8 * scale, x: 0, y: -3 * scale)
        .frame(width: bodyW, height: bodyH)

      KimiCodeEye(scale: scale, isAnimating: isAnimating)
        .position(x: leftCX, y: eyeCY)

      KimiCodeEye(scale: scale, isAnimating: isAnimating)
        .position(x: rightCX, y: eyeCY)
    }
    .frame(width: 32 * scale, height: 22 * scale)
  }
}

private struct KimiCodeEye: View {
  let scale: CGFloat
  let isAnimating: Bool

  @State private var blinkY: CGFloat = 1
  @State private var lookX: CGFloat = 0
  @State private var lookPhase = 0

  private let amplitudeMultiplier: CGFloat = 5
  private var eyeW: CGFloat { 2.8 * scale }
  private var eyeH: CGFloat { 8 * scale }

  var body: some View {
    Capsule()
      .fill(eyeColor)
      .frame(width: eyeW, height: eyeH)
      .scaleEffect(x: 1, y: blinkY)
      .offset(x: lookX)
      .animation(.easeInOut(duration: 0.08), value: blinkY)
      .animation(.easeInOut(duration: 0.3), value: lookX)
      .onAppear {
        if isAnimating {
          startAnimations()
        }
      }
      .onChange(of: isAnimating) { _, animating in
        if animating {
          startAnimations()
        } else {
          stopAnimations()
        }
      }
  }

  private var eyeColor: Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(red: 24 / 255, green: 24 / 255, blue: 23 / 255, alpha: 1)
          : NSColor.white
      })
  }

  // MARK: - Blink

  private func startAnimations() {
    scheduleBlink()
    scheduleLook()
  }

  private func stopAnimations() {
    blinkY = 1
    lookX = 0
    lookPhase = 0
  }

  private func scheduleBlink() {
    // 每 3 秒一次眨眼，第一次随机偏移避免所有眼睛同步
    let initialDelay = Double.random(in: 0..<3.0)
    DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
      performBlink()
    }
  }

  private func performBlink() {
    guard isAnimating else { return }

    // 闭眼 0.08s
    withAnimation(.easeOut(duration: 0.08)) { blinkY = 0.12 }

    // 停留 0.04s 后睁眼
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      guard isAnimating else { return }
      withAnimation(.easeIn(duration: 0.08)) { blinkY = 1 }
    }

    // 3 秒后再眨眼
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      performBlink()
    }
  }

  // MARK: - Look Around

  private func scheduleLook() {
    guard isAnimating else { return }
    let delay = Double.random(in: 1.0...3.0)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      performLook()
    }
  }

  private func performLook() {
    guard isAnimating else { return }
    let amplitude = amplitudeMultiplier * scale
    let targets: [CGFloat] = [amplitude, 0, -amplitude, 0]
    let nextTarget = targets[lookPhase % targets.count]

    withAnimation(.easeInOut(duration: 0.3)) {
      lookX = nextTarget
    }
    lookPhase += 1

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      scheduleLook()
    }
  }
}

// MARK: - macOS 26 设计适配

/// 是否开启了「减弱动态效果」
let isReduceMotionEnabled: Bool = {
  NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}()

/// 统一圆角常量，随系统版本收敛
enum DesignConstants {
  static let cornerRadiusSmall: CGFloat = 6
  static let cornerRadiusMedium: CGFloat = 10
  static let cornerRadiusLarge: CGFloat = 12
  static let cornerRadiusXLarge: CGFloat = 14
}

extension View {
  /// macOS 26 上应用 glassEffect，旧版系统回退到 regularMaterial 背景
  @ViewBuilder
  func glassEffectIfAvailable(in shape: some Shape, isHovered: Bool = false) -> some View {
    if #available(macOS 26, *) {
      self.glassEffect(in: shape)
    } else {
      self.background(
        shape
          .fill(isHovered ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.clear))
      )
    }
  }

  /// MenuBarExtra 面板背景：macOS 26 交给系统 Liquid Glass，旧版使用 ultraThinMaterial
  @ViewBuilder
  func menuBarPanelBackground() -> some View {
    if #available(macOS 26, *) {
      self
    } else {
      self.background(.ultraThinMaterial)
    }
  }
}

// MARK: - App 版本行

struct AppUpdateRow: View {
  @StateObject private var languageManager = LanguageManager.shared
  @State private var isHovered = false

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Text("KimiCode Bar")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.kimiTextTertiary)

      Spacer()

      HStack(spacing: 6) {
        Text(appVersion())
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(.kimiTextSecondary)

        LText("查看更新")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.kimiTextTertiary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(Color.kimiTextPrimary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.kimiTextPrimary.opacity(isHovered ? 0.06 : 0))
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .cursor(.pointingHand)
    .onTapGesture {
      openGitHubReleases()
    }
  }

  private func openGitHubReleases() {
    if let url = URL(string: "https://github.com/WuChenh/KimiCodeBar/releases/") {
      NSWorkspace.shared.open(url)
    }
  }
}

// MARK: - 主面板

struct KimiMenu: View {
  @StateObject private var model = KimiCodeBarModel.shared
  @StateObject private var languageManager = LanguageManager.shared
  @State private var isHoveredUpdateLog = false
  @State private var isMenuVisible = false
  @State private var showUpdateAlert = false
  @State private var kimiServerOperation: KimiServerOperation = .none
  @State private var isKimiServerRestartHintDismissed = false

  private let consoleURL = URL(string: "https://www.kimi.com/code/console")!

  /// CLI 版本行显示条件：用户开启，或检测到 CLI 新版本时强制显示（无视隐藏设置）
  private var shouldShowKimiVersionRow: Bool {
    model.showKimiVersionRow || model.pendingUpdateVersion != nil || model.hasCachedKimiUpdate
  }

  /// App 版本行显示条件：用户开启即显示
  private var shouldShowAppUpdateRow: Bool {
    model.showAppUpdateRow
  }

  /// 当前平台是否正在加载
  private var isProviderLoading: Bool {
    switch model.selectedProvider {
    case .kimi: return model.isLoading
    case .deepseek: return model.deepseekState.isLoading
    }
  }

  // MARK: - 平台区域标题

  private func providerSectionHeader(
    name: String, icon: String?, consoleURL: URL?, isLoading: Bool
  ) -> some View {
    HStack(spacing: 8) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .medium))
      }
      Text(name)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.kimiTextPrimary)

      if isLoading {
        ProgressView()
          .controlSize(.small)
          .scaleEffect(0.7)
      }

      Spacer()

      if let url = consoleURL {
        Button(action: {
          dismissMenuBarPanel()
          NSWorkspace.shared.open(url)
        }) {
          Image(systemName: "arrow.up.forward")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.kimiTextTertiary)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
      }
    }
  }

  // MARK: - Kimi 用量内容

  private var kimiUsageContent: some View {
    Group {
      HStack(spacing: 12) {
        UsageCard(
          title: languageManager.tr("7天用量"),
          subtitle: nil,
          percentage: model.quota?.weekly.percentage ?? 0,
          reset: model.quota?.weekly.timeUntilReset ?? "--",
          color: .kimiBlue,
          isLoading: model.isLoading
        )

        UsageCard(
          title: languageManager.tr("5小时用量"),
          subtitle: nil,
          percentage: model.quota?.fiveHour.percentage ?? 0,
          reset: model.quota?.fiveHour.timeUntilReset ?? "--",
          color: .orange,
          isLoading: model.isLoading
        )
      }

      if model.showBoosterWalletCard {
        BoosterWalletCard(
          wallet: model.quota?.boosterWallet,
          isLoading: model.isLoading
        )
      }

      if model.showLocalUsageCard {
        LocalUsageCard()
      }
    }
  }

  // MARK: - DeepSeek 余额内容

  private var deepseekBalanceContent: some View {
    let state = model.deepseekState
    return Group {
      if let balance = state.balance {
        BalanceCard(
          providerName: "DeepSeek",
          balance: balance,
          isLoading: state.isLoading
        )
      } else if state.isLoading {
        BalanceLoadingCard(providerName: "DeepSeek")
      } else if let error = state.errorMessage {
        BalanceErrorCard(
          providerName: "DeepSeek",
          message: error,
          consoleURL: ProviderType.deepseek.consoleURL
        )
      } else {
        BalanceEmptyCard(
          providerName: "DeepSeek",
          consoleURL: ProviderType.deepseek.consoleURL
        )
      }
    }
  }

  var body: some View {
    VStack(spacing: 14) {
      // Header
      HStack(spacing: 12) {
        AnimatedKimiCodeLogo(width: 44, isAnimating: isMenuVisible && !isReduceMotionEnabled)

        Text("KimiCodeBar")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()
      }

      // 用量内容
      VStack(spacing: 12) {
        if model.showKimiProvider {
          kimiUsageContent
        }
        if model.showDeepseekProvider {
          deepseekBalanceContent
        }

      }

      // 操作按钮
      HStack(spacing: 8) {
        ActionButton(
          title: languageManager.tr("刷新"),
          icon: "arrow.clockwise",
          action: { model.refreshAll() },
          disabled: (!model.hasKimiCredential && !model.hasDeepseekCredential)
            || (model.isLoading && model.deepseekState.isLoading)
        )

        ActionButton(
          title: languageManager.tr("设置"),
          icon: "gearshape",
          action: { SettingsWindowManager.shared.show() }
        )
        .keyboardShortcut(",", modifiers: .command)

        ActionButton(
          title: languageManager.tr("退出"),
          icon: "power",
          action: { NSApplication.shared.terminate(nil) }
        )
      }

      // KimiCode CLI 版本行：仅 Kimi 平台时显示；检测到新版本时无视设置强制显示
      if model.showKimiProvider && shouldShowKimiVersionRow {
        HStack(alignment: .center, spacing: 10) {
          Text("KimiCode CLI")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.kimiTextTertiary)

          Spacer()

          HStack(spacing: 6) {
            Text(formatKimiVersion(model.kimiVersion))
              .font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundStyle(.kimiTextSecondary)

            if model.updateErrorMessage != nil && !model.updateErrorMessage!.isEmpty {
              LText("检查更新失败")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if model.pendingUpdateVersion != nil || model.hasCachedKimiUpdate {
              LText("发现新版本")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
              LText("当前最新")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.kimiTextTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.kimiTextPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.kimiTextPrimary.opacity(isHoveredUpdateLog ? 0.06 : 0))
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onHover { isHoveredUpdateLog = $0 }
        .cursor(.pointingHand)
        .onTapGesture {
          if model.pendingUpdateVersion != nil || model.hasCachedKimiUpdate {
            showUpdateAlert = true
          } else if let url = URL(
            string: "https://moonshotai.github.io/kimi-code/zh/release-notes/changelog.html")
          {
            NSWorkspace.shared.open(url)
          }
        }
      }

      // KimiCodeBar 版本行：仅 Kimi 平台时显示；检测到新版本时无视设置强制显示
      if model.showKimiProvider && shouldShowAppUpdateRow {
        AppUpdateRow()
      }
    }
    .padding(16)
    .frame(width: 340)
    .menuBarPanelBackground()
    .overlay {
      if model.showKimiProvider && !model.hasKimiCredential {
        LoginOverlayView(isMenuVisible: isMenuVisible)
      }
    }
    .background(WindowVisibilityDetector(isVisible: $isMenuVisible))
    .onAppear {
      model.checkCachedKimiUpdate()
      if model.pendingUpdateVersion != nil {
        showUpdateAlert = true
      }
      Task {
        await model.loadKimiVersion()
        await model.checkForKimiCLIUpdate()
        if model.pendingUpdateVersion == nil {
          showUpdateAlert = false
        }
      }
      model.refreshCurrentProvider(showsLoading: false)
      model.refreshDeepseek()
    }
    .onChange(of: isMenuVisible) { _, isVisible in
      if isVisible {
        isKimiServerRestartHintDismissed = false
        Task { await model.refreshKimiServerState() }
        model.refreshCurrentProvider(showsLoading: false)
        model.refreshDeepseek()
        KimiLocalUsageService.shared.refreshIfNeeded()
        model.checkCachedKimiUpdate()
        if model.pendingUpdateVersion != nil {
          showUpdateAlert = true
        }
        Task {
          await model.loadKimiVersion()
          await model.checkForKimiCLIUpdate()
          if model.pendingUpdateVersion == nil {
            showUpdateAlert = false
          }
        }
      }
    }
    .popover(isPresented: $showUpdateAlert, arrowEdge: .trailing) {
      UpdateAlertView(
        currentVersion: formatKimiVersion(model.kimiVersion),
        newVersion: model.pendingUpdateVersion ?? languageManager.tr("新版"),
        onDismiss: {
          showUpdateAlert = false
          model.pendingUpdateVersion = nil
          // 一小时后再次提醒
          model.snoozedKimiUpdateUntil = Date().timeIntervalSince1970 + 3600
        },
        onInstall: {
          showUpdateAlert = false
          model.pendingUpdateVersion = nil
          Task { await installKimiCLIUpdate() }
        }
      )
    }

  }

  private func installKimiCLIUpdate() async {
    // 呼出 Terminal.app 并执行更新命令，让用户在可视化终端里看到进度
    dismissMenuBarPanel()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [
      "-e",
      """
      tell application "Terminal"
          activate
          do script "kimi upgrade"
      end tell
      """,
    ]
    try? task.run()
  }

  private func formatMembershipLevel(_ level: String) -> String {
    switch level.uppercased() {
    case "LEVEL_FREE": return LanguageManager.tr("免费版")
    case "LEVEL_BASIC": return LanguageManager.tr("基础版")
    case "LEVEL_INTERMEDIATE": return LanguageManager.tr("进阶版")
    case "LEVEL_ADVANCED": return LanguageManager.tr("高级版")
    default:
      let trimmed = level.uppercased().replacingOccurrences(of: "LEVEL_", with: "")
      return trimmed.isEmpty ? LanguageManager.tr("未知") : trimmed
    }
  }

}

func formatKimiVersion(_ version: String) -> String {
  guard version != LanguageManager.tr("未检测到") else { return LanguageManager.tr("未检测到") }
  let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
  let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
  if let last = components.last {
    return String(last)
  }
  return version
}

// MARK: - 未登录遮罩

/// 未登录时覆盖在菜单面板上的半透明遮罩，引导用户一键授权登录。
struct LoginOverlayView: View {
  let isMenuVisible: Bool

  @StateObject private var model = KimiCodeBarModel.shared
  @State private var isHoveredLogin = false
  @State private var isHoveredSettings = false
  @State private var isHoveredCancel = false

  var body: some View {
    ZStack {
      Color.clear.background(.ultraThinMaterial)

      VStack(spacing: 16) {
        AnimatedKimiCodeLogo(width: 52, isAnimating: isMenuVisible)

        if model.oauthLoginInProgress {
          authorizingContent
        } else {
          loginContent
        }
      }
      .padding(24)
    }
  }

  // MARK: 未登录

  private var loginContent: some View {
    VStack(spacing: 16) {
      LText("登录后查看 Kimi 用量")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.kimiTextPrimary)

      Button(action: {
        model.loginMethod = .oauth
        model.startOAuthLogin()
      }) {
        LText("Kimi 登录")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .frame(minWidth: 140)
          .padding(.vertical, 10)
          .background(isHoveredLogin ? Color.kimiBlue.opacity(0.85) : Color.kimiBlue)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredLogin = $0 }

      Button(action: { SettingsWindowManager.shared.show() }) {
        LText("其他登录方式")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isHoveredSettings ? .kimiTextPrimary : .kimiTextSecondary)
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredSettings = $0 }
    }
  }

  // MARK: 授权中

  private var authorizingContent: some View {
    VStack(spacing: 14) {
      VStack(spacing: 6) {
        HStack(spacing: 8) {
          LoadingRing()
            .frame(width: 14, height: 14)

          LText("等待浏览器授权…")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.kimiTextPrimary)
        }

        if let auth = model.oauthDeviceAuth {
          LText("授权码 %@", auth.userCode)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.kimiTextSecondary)
            .textSelection(.enabled)
        }
      }

      Button(action: { model.cancelOAuthLogin() }) {
        LText("取消")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isHoveredCancel ? .kimiTextPrimary : .kimiTextSecondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(
            isHoveredCancel
              ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
          )
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredCancel = $0 }
    }
  }
}

// MARK: - 用量卡片

struct UsageCard: View {
  let title: String
  let subtitle: String?
  let percentage: Int
  let reset: String
  let color: Color
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 标题行
      HStack {
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()

        if let subtitle = subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.kimiTextTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.kimiTextPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
      }

      // 数值
      ZStack(alignment: .leading) {
        if !isLoading {
          Text("\(percentage)%")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.kimiTextPrimary)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        }

        if isLoading {
          LoadingRing()
            .frame(width: 24, height: 24)
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
        }
      }
      .frame(height: 38)
      .animation(.easeInOut(duration: 0.2), value: isLoading)

      // 进度条
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .frame(height: 4)
            .foregroundStyle(Color.kimiTextPrimary.opacity(0.10))

          Capsule()
            .frame(width: proxy.size.width * CGFloat(min(percentage, 100)) / 100, height: 4)
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 1)
        }
      }
      .frame(height: 4)

      // 重置时间
      Text(reset)
        .font(.system(size: 11))
        .foregroundStyle(.kimiTextSecondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

// MARK: - 紧凑额度横条

struct CompactQuotaBar: View {
  let title: String
  let badge: String?
  let used: Int
  let limit: Int
  let color: Color
  let isLoading: Bool

  var body: some View {
    let percentage = limit > 0 ? Int(Double(used) / Double(limit) * 100) : 0

    HStack(spacing: 10) {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.kimiTextPrimary)
        .frame(width: 56, alignment: .leading)

      if let badge = badge, !badge.isEmpty {
        Text(badge)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.kimiTextTertiary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.kimiTextPrimary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .frame(height: 4)
            .foregroundStyle(Color.kimiTextPrimary.opacity(0.10))

          Capsule()
            .frame(width: proxy.size.width * CGFloat(min(percentage, 100)) / 100, height: 4)
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
        }
      }
      .frame(height: 4)

      if isLoading {
        LoadingRing()
          .frame(width: 12, height: 12)
      } else {
        Text("\(percentage)%")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(.kimiTextSecondary)
          .frame(width: 32, alignment: .trailing)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - 加油包卡片

struct BoosterWalletCard: View {
  let wallet: BoosterWallet?
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        LText("加油包余额")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)

        if let wallet = wallet {
          LText(wallet.isEnabled ? "已启用" : "未启用")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(wallet.isEnabled ? .green : .kimiTextTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((wallet.isEnabled ? Color.green : Color.kimiTextTertiary).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }

        Spacer()
      }

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        balanceView

        Spacer()

        if let wallet = wallet, !isLoading {
          HStack(spacing: 4) {
            LText("本月消费")
              .font(.system(size: 11))
              .foregroundStyle(.kimiTextSecondary)

            Text(formatCurrency(wallet.monthlyUsedYuan, currency: wallet.currency))
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.kimiTextPrimary)
              .monospacedDigit()

            Text("/")
              .font(.system(size: 11))
              .foregroundStyle(.kimiTextSecondary)

            Text(limitText(for: wallet))
              .font(.system(size: 11))
              .foregroundStyle(.kimiTextSecondary)
              .monospacedDigit()
          }
          .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        }
      }
      .frame(height: 28)
      .animation(.easeInOut(duration: 0.2), value: isLoading)

      if let wallet = wallet {
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule()
              .frame(height: 3)
              .foregroundStyle(Color.kimiTextPrimary.opacity(0.10))

            let progress =
              wallet.monthlyChargeLimitEnabled && wallet.monthlyChargeLimitYuan > 0
              ? min(wallet.monthlyUsedYuan / wallet.monthlyChargeLimitYuan, 1.0)
              : 0
            Capsule()
              .frame(width: proxy.size.width * CGFloat(progress), height: 3)
              .foregroundStyle(wallet.isEnabled ? Color.orange : .kimiTextTertiary)
          }
        }
        .frame(height: 3)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private var balanceView: some View {
    ZStack(alignment: .leading) {
      if !isLoading, let wallet = wallet {
        Text(formatCurrency(wallet.balanceYuan, currency: wallet.currency))
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundStyle(wallet.isEnabled ? .kimiTextPrimary : .kimiTextTertiary)
          .monospacedDigit()
          .transition(.opacity.animation(.easeInOut(duration: 0.25)))
      }

      if isLoading {
        LoadingRing()
          .frame(width: 20, height: 20)
          .transition(.opacity.animation(.easeInOut(duration: 0.15)))
      } else if wallet == nil {
        Text("--")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.kimiTextTertiary)
          .transition(.opacity.animation(.easeInOut(duration: 0.25)))
      }
    }
  }

  private func limitText(for wallet: BoosterWallet) -> String {
    if !wallet.monthlyChargeLimitEnabled || wallet.monthlyChargeLimitCents <= 0 {
      return LanguageManager.tr("无限制")
    }
    return formatCurrency(wallet.monthlyChargeLimitYuan, currency: wallet.currency)
  }
}

// MARK: - Kimi Web 重启提示

struct KimiServerRestartHint: View {
  let runningVersion: String
  let installedVersion: String
  let onRestart: () -> Void
  let onDismiss: () -> Void

  @State private var isHoveredRestart = false
  @State private var isHoveredDismiss = false

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.orange)

      LText(
        "Kimi Web 运行版本 %1$@ 低于已安装版本 %2$@，建议重启服务。", formatKimiVersion(runningVersion),
        formatKimiVersion(installedVersion)
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.kimiTextPrimary)
      .lineLimit(nil)
      .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 8)

      Button(action: onRestart) {
        LText("立即重启")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(isHoveredRestart ? .white : .white)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(isHoveredRestart ? Color.orange.opacity(0.85) : Color.orange)
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredRestart = $0 }

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isHoveredDismiss ? .kimiTextPrimary : .kimiTextSecondary)
          .frame(width: 22, height: 22)
          .background(isHoveredDismiss ? Color.kimiTextPrimary.opacity(0.10) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredDismiss = $0 }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.orange.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Kimi Web 卡片

struct KimiServerCard: View {
  let state: KimiServerState
  let operation: KimiServerOperation
  let onOpenWeb: () -> Void
  let onStart: () -> Void
  let onStop: () -> Void
  let onRestart: () -> Void

  @StateObject private var languageManager = LanguageManager.shared
  @State private var isHoveredOpenWeb = false
  @State private var isHoveredToggle = false
  @State private var isHoveredRestart = false

  private var isLoading: Bool {
    operation != .none
  }

  private var statusColor: Color {
    switch state.status {
    case .running:
      return .green
    case .stopped, .error:
      return .red
    case .unknown:
      return .kimiTextTertiary
    }
  }

  private var statusText: String {
    switch state.status {
    case .running:
      return languageManager.tr("运行中")
    case .stopped:
      return languageManager.tr("已停止")
    case .error:
      return languageManager.tr("异常")
    case .unknown:
      return languageManager.tr("检测中")
    }
  }

  private var toggleTitle: String {
    state.status == .running ? languageManager.tr("停止") : languageManager.tr("启动")
  }

  private var isRunning: Bool {
    state.status == .running
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text("Kimi Web")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.kimiTextPrimary)

        Text(statusText)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(statusColor)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(statusColor.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }

      HStack(spacing: 8) {
        Button(action: onOpenWeb) {
          HStack(spacing: 4) {
            Image(systemName: "globe")
              .font(.system(size: 13, weight: .medium))

            LText("打开")
              .font(.system(size: 13, weight: .medium))
          }
          .frame(width: 130)
          .padding(.vertical, 10)
          .foregroundStyle(
            isLoading || !isRunning
              ? .kimiTextTertiary : (isHoveredOpenWeb ? .kimiTextPrimary : .kimiTextSecondary)
          )
          .background(
            isHoveredOpenWeb && !(isLoading || !isRunning)
              ? Color.kimiTextPrimary.opacity(0.10) : Color.kimiTextPrimary.opacity(0.06)
          )
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || !isRunning)
        .cursor(isLoading || !isRunning ? .arrow : .pointingHand)
        .onHover { isHoveredOpenWeb = $0 }

        serverActionButton(
          title: toggleTitle,
          isHovered: $isHoveredToggle,
          isLoading: operation == (isRunning ? .stopping : .starting),
          action: isRunning ? onStop : onStart,
          disabled: isLoading
        )

        serverActionButton(
          title: languageManager.tr("重启"),
          isHovered: $isHoveredRestart,
          isLoading: operation == .restarting,
          action: onRestart,
          disabled: isLoading
        )
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func serverActionButton(
    title: String,
    isHovered: Binding<Bool>,
    isLoading: Bool,
    action: @escaping () -> Void,
    disabled: Bool
  ) -> some View {
    Button(action: action) {
      ZStack {
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .opacity(isLoading ? 0 : 1)

        if isLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.6)
            .frame(width: 16, height: 16)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .foregroundStyle(
        disabled
          ? .kimiTextTertiary : (isHovered.wrappedValue ? .kimiTextPrimary : .kimiTextSecondary)
      )
      .background(
        isHovered.wrappedValue && !disabled
          ? Color.kimiTextPrimary.opacity(0.10) : Color.kimiTextPrimary.opacity(0.06)
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .cursor(disabled ? .arrow : .pointingHand)
    .onHover { isHovered.wrappedValue = $0 }
  }
}

// MARK: - 操作按钮

struct ActionButton: View {
  let title: String
  var icon: String? = nil
  var textIcon: String? = nil
  let action: () -> Void
  var disabled: Bool = false
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        if let textIcon {
          Text(textIcon)
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 34, height: 18, alignment: .center)
            .multilineTextAlignment(.center)
        } else if let icon {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 18, height: 18, alignment: .center)
        }

        Text(title)
          .font(.system(size: 11, weight: .medium))
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .foregroundStyle(
        disabled ? .kimiTextTertiary : (isHovered ? .kimiTextPrimary : .kimiTextSecondary)
      )
      .glassEffectIfAvailable(in: RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium), isHovered: isHovered && !disabled)
      .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .cursor(disabled ? .arrow : .pointingHand)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - 链接行

struct LinkRow: View {
  let title: String
  let icon: String?
  let imageName: String?
  let imageSize: CGFloat
  let url: URL
  @State private var isHovered = false

  init(
    title: String, icon: String? = nil, imageName: String? = nil, imageSize: CGFloat = 14, url: URL
  ) {
    self.title = title
    self.icon = icon
    self.imageName = imageName
    self.imageSize = imageSize
    self.url = url
  }

  var body: some View {
    Button(action: { NSWorkspace.shared.open(url) }) {
      HStack(spacing: 6) {
        if let imageName {
          Image(imageName)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageSize, height: imageSize)
        } else if let icon {
          Image(systemName: icon)
            .font(.system(size: imageSize))
        }

        Text(title)
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundStyle(isHovered ? Color.kimiBlue : .kimiTextSecondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(isHovered ? Color.kimiBlue.opacity(0.12) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .cursor(.pointingHand)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - 菜单栏面板关闭

/// 关闭 MenuBarExtra 弹出的面板窗口（NSPanel 子类）。
/// 跳转外部链接、打开其他窗口等「离开面板」的操作前调用，避免面板残留遮挡。
@MainActor
func dismissMenuBarPanel() {
  for candidate in NSApp.windows where candidate is NSPanel {
    candidate.close()
  }
}

// MARK: - 设置窗口

@MainActor
final class SettingsWindowManager {
  static let shared = SettingsWindowManager()
  private var window: NSWindow?

  private init() {}

  func show() {
    // LSUIElement 应用（无 Dock 图标）在关闭菜单栏面板后会立即失焦，
    // 必须先激活 App 再关面板，否则后续创建的设置窗口无法正确显示——
    // 窗口会成为 key 但不可见，重新打开菜单栏面板时所有鼠标事件
    // 都被这个不可见的 .floating 窗口吞掉，面板完全无法操作。
    NSApp.activate(ignoringOtherApps: true)

    // 菜单栏面板是高层级的 NSPanel 弹层，会压住设置窗口，打开设置前先关掉它
    dismissMenuBarPanel()

    if let window = window {
      // 复用已有窗口：重新居中，防止多显示器/分辨率变化后窗口跑到屏幕外
      window.center()
      window.makeKeyAndOrderFront(nil)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = LanguageManager.tr("KimiCode Bar 设置")
    window.minSize = NSSize(width: 680, height: 560)
    window.collectionBehavior = [.managed, .canJoinAllSpaces]
    window.level = .floating
    window.titlebarAppearsTransparent = true
    window.backgroundColor = .windowBackgroundColor
    window.center()
    window.contentView = NSHostingView(rootView: SettingsRootView())
    window.isReleasedWhenClosed = false
    self.window = window

    window.makeKeyAndOrderFront(nil)
  }

  /// 语言切换后刷新设置窗口标题
  func refreshTitle() {
    window?.title = LanguageManager.tr("KimiCode Bar 设置")
  }
}

// MARK: - 技能管理

struct SkillInfo: Identifiable {
  let id: String
  let name: String
  let directoryName: String
  let description: String
  let version: String
  let content: String
  let path: String
}

private func skillsDirectoryPath() -> String {
  let home = FileManager.default.homeDirectoryForCurrentUser.path
  return "\(home)/.kimi-code/skills"
}

func loadSkills() -> [SkillInfo] {
  let dir = skillsDirectoryPath()
  guard FileManager.default.fileExists(atPath: dir) else { return [] }

  do {
    let items = try FileManager.default.contentsOfDirectory(atPath: dir)
    let directories =
      items
      .map { "\(dir)/\($0)" }
      .filter { FileManager.default.fileExists(atPath: $0) && isDirectory($0) }
      .sorted()

    return directories.compactMap { parseSkill(at: $0) }
  } catch {
    return []
  }
}

private func isDirectory(_ path: String) -> Bool {
  var isDir: ObjCBool = false
  FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
  return isDir.boolValue
}

private func parseSkill(at directoryPath: String) -> SkillInfo? {
  let skillFile = "\(directoryPath)/SKILL.md"
  guard FileManager.default.fileExists(atPath: skillFile) else { return nil }

  guard let data = FileManager.default.contents(atPath: skillFile),
    let content = String(data: data, encoding: .utf8)
  else { return nil }

  let directoryName = URL(fileURLWithPath: directoryPath).lastPathComponent
  var name = directoryName
  var description = ""
  var version = ""

  let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
  if trimmed.hasPrefix("---") {
    if let endRange = trimmed.range(
      of: "---", range: trimmed.index(trimmed.startIndex, offsetBy: 3)..<trimmed.endIndex)
    {
      let frontMatter = String(
        trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)..<endRange.lowerBound])
      name = parseFrontMatterValue(frontMatter, key: "name") ?? directoryName
      description = parseFrontMatterValue(frontMatter, key: "description") ?? ""
      version =
        parseNestedFrontMatterValue(frontMatter, outerKey: "metadata", innerKey: "version") ?? ""
    }
  }

  return SkillInfo(
    id: directoryName,
    name: name,
    directoryName: directoryName,
    description: description,
    version: version,
    content: content,
    path: skillFile
  )
}

private func parseFrontMatterValue(_ frontMatter: String, key: String) -> String? {
  let lines = frontMatter.components(separatedBy: .newlines)
  var foundKey = false
  var rawValues: [String] = []

  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") { continue }

    if foundKey {
      if trimmed.hasPrefix("-") {
        rawValues.append(trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces))
        continue
      }
      if trimmed.isEmpty || trimmed.contains(":") {
        break
      }
      rawValues.append(line)
      continue
    }

    if trimmed.hasPrefix("\(key):") {
      let remainder = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
      if remainder == "|" {
        foundKey = true
      } else {
        return remainder.trimmingCharacters(in: .whitespaces)
          .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      }
    }
  }

  guard !rawValues.isEmpty else { return nil }
  return dedented(rawValues).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func dedented(_ lines: [String]) -> [String] {
  let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
  guard !nonEmpty.isEmpty else { return lines }

  let leadingSpaces = nonEmpty.compactMap { line -> Int in
    var count = 0
    for char in line {
      if char == " " { count += 1 } else { break }
    }
    return count
  }

  let minSpaces = leadingSpaces.min() ?? 0
  return lines.map { line in
    guard line.count >= minSpaces else { return line }
    return String(line.dropFirst(minSpaces))
  }
}

private func parseNestedFrontMatterValue(_ frontMatter: String, outerKey: String, innerKey: String)
  -> String?
{
  let lines = frontMatter.components(separatedBy: .newlines)
  var insideOuter = false

  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") { continue }

    if trimmed.hasPrefix("\(outerKey):") {
      insideOuter = true
      continue
    }

    if insideOuter {
      if trimmed.hasPrefix("\(innerKey):") {
        let value = trimmed.dropFirst(innerKey.count + 1).trimmingCharacters(in: .whitespaces)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      }
      if trimmed.contains(":") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix(" ") {
        break
      }
    }
  }

  return nil
}

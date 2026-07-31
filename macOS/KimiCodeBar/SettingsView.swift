import SwiftUI

// MARK: - 设置根视图

enum SettingsPane: String, CaseIterable, Identifiable {
  case basic
  case accounts
  case panelCustom
  case archive
  case skills
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .basic: return LanguageManager.tr("基本设置")
    case .accounts: return LanguageManager.tr("多账号")
    case .panelCustom: return LanguageManager.tr("面板自定义")
    case .archive: return LanguageManager.tr("自动归档")
    case .skills: return LanguageManager.tr("技能管理")
    case .about: return LanguageManager.tr("关于")
    }
  }

  var icon: String {
    switch self {
    case .basic: return "gear"
    case .accounts: return "person.2"
    case .panelCustom: return "rectangle.3.group"
    case .archive: return "archivebox"
    case .skills: return "puzzlepiece.extension"
    case .about: return "info.circle"
    }
  }
}

struct SettingsRootView: View {
  @StateObject private var languageManager = LanguageManager.shared
  @State private var selectedPane: SettingsPane = .basic

  var body: some View {
    HSplitView {
      VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(SettingsPane.allCases) { pane in
            SettingsSidebarItem(
              pane: pane,
              isSelected: selectedPane == pane
            ) {
              selectedPane = pane
            }
          }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)

        Spacer()
      }
      .frame(width: 180)
      .background(.ultraThinMaterial)

      switch selectedPane {
      case .basic:
        BasicSettingsView()
      case .accounts:
        AccountsSettingsView()
      case .panelCustom:
        PanelCustomSettingsView()
      case .archive:
        ArchiveSettingsView()
      case .skills:
        SkillsSettingsView()
      case .about:
        AboutSettingsView()
      }
    }
    .onChange(of: languageManager.language) { _, _ in
      SettingsWindowManager.shared.refreshTitle()
    }
  }
}

struct SettingsSidebarItem: View {
  let pane: SettingsPane
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: pane.icon)
        .font(.system(size: 15, weight: .regular))
        .frame(width: 22, alignment: .center)
        .foregroundStyle(isSelected ? .white : .kimiTextPrimary)

      Text(pane.title)
        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
        .foregroundStyle(isSelected ? .white : .kimiTextPrimary)
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(backgroundColor)
    )
    .contentShape(Rectangle())
    .cursor(.pointingHand)
    .onHover { isHovered = $0 }
    .onTapGesture(perform: action)
  }

  private var backgroundColor: Color {
    if isSelected {
      return .accentColor
    } else if isHovered {
      return Color.kimiTextPrimary.opacity(0.08)
    } else {
      return Color.clear
    }
  }
}

// MARK: - 设置卡片组件

struct SettingsCard<Content: View>: View {
  let title: String?
  let footerText: String?
  let content: Content

  init(title: String? = nil, footerText: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footerText = footerText
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let title {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.kimiTextPrimary)
          .padding(.horizontal, 16)
          .padding(.top, 14)
          .padding(.bottom, 10)
      }

      content

      if let footerText {
        Text(footerText)
          .font(.system(size: 12))
          .foregroundStyle(.kimiTextSecondary)
          .lineSpacing(2)
          .padding(.horizontal, 16)
          .padding(.top, 2)
          .padding(.bottom, 14)
      }
    }
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct SettingsCardRow<Trailing: View>: View {
  let title: String
  let subtitle: String?
  @ViewBuilder let trailing: () -> Trailing

  init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)

        if let subtitle {
          Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.kimiTextSecondary)
        }
      }

      Spacer()

      trailing()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
  }
}

struct SettingsCardDivider: View {
  var body: some View {
    Divider()
      .background(Color.kimiTextPrimary.opacity(0.08))
      .padding(.leading, 16)
  }
}

// MARK: - 设置字段焦点

enum APISettingField: Hashable {
  case apiKey
  case quotaInterval
  case updateInterval
}

// MARK: - 设置选项卡片

/// 卡片式单选：图标 + 标题 + 副标题，选中态蓝色描边 + 对勾。
/// 用于登录方式、外观主题等互斥选项的选择。
struct SettingsOptionCard: View {
  let title: String
  let subtitle: String?
  let iconName: String
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  private var hasSubtitle: Bool {
    if let subtitle = subtitle, !subtitle.isEmpty { return true }
    return false
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: iconName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(isSelected ? .kimiBlue : .kimiTextSecondary)
          .frame(width: 24, alignment: .center)

        VStack(alignment: .leading, spacing: hasSubtitle ? 2 : 0) {
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.kimiTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

          if let subtitle = subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(.system(size: 11))
              .foregroundStyle(.kimiTextSecondary)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
        .layoutPriority(0.5)

        Spacer(minLength: 4)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(isSelected ? .kimiBlue : .kimiTextTertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(
            isSelected
              ? Color.kimiBlue.opacity(0.10)
              : (isHovered
                ? Color.kimiTextPrimary.opacity(0.06) : Color.kimiTextPrimary.opacity(0.03)))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            isSelected ? Color.kimiBlue.opacity(0.6) : Color.kimiTextPrimary.opacity(0.08),
            lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .cursor(.pointingHand)
    .onHover { isHovered = $0 }
  }
}

// MARK: - OAuth 授权登录区域

/// 基本设置中「授权登录」方式对应的凭证管理区域。
/// 三个状态：未授权（去授权按钮）→ 授权中（展示 user_code 轮询）→ 已授权（状态 + 退出）。
struct OAuthLoginSection: View {
  @StateObject private var model = KimiCodeBarModel.shared

  @State private var isHoveredStartLogin = false
  @State private var isHoveredLogout = false
  @State private var isHoveredCancel = false
  @State private var isHoveredCopyCode = false
  @State private var isHoveredReopen = false
  @State private var isCodeCopied = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if model.oauthLoginInProgress, let auth = model.oauthDeviceAuth {
        authorizingContent(auth)
      } else if model.oauthToken != nil {
        authorizedContent
      } else {
        loginContent
      }

      if let error = model.oauthLoginError {
        SettingsCardDivider()
        ErrorMessageView(message: error)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
      }

      if let error = model.errorMessage {
        SettingsCardDivider()
        ErrorMessageView(message: error)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
      }
    }
  }

  // MARK: 未授权

  private var loginContent: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.crop.circle")
        .font(.system(size: 22, weight: .regular))
        .foregroundStyle(.kimiTextTertiary)
        .frame(width: 32, height: 32)

      LText("未授权")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.kimiTextPrimary)

      Spacer()

      Button(action: { model.startOAuthLogin() }) {
        ZStack {
          LText("去授权")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .opacity(model.oauthLoginInProgress ? 0 : 1)

          if model.oauthLoginInProgress {
            ProgressView()
              .progressViewStyle(.circular)
              .scaleEffect(0.6)
              .frame(width: 16, height: 16)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
          model.oauthLoginInProgress
            ? Color.kimiBlue.opacity(0.6)
            : (isHoveredStartLogin ? Color.kimiBlue.opacity(0.85) : Color.kimiBlue)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .disabled(model.oauthLoginInProgress)
      .cursor(model.oauthLoginInProgress ? .arrow : .pointingHand)
      .onHover { isHoveredStartLogin = $0 }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
  }

  // MARK: 授权中

  private func authorizingContent(_ auth: KimiDeviceAuthorization) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // 状态行
      HStack(spacing: 10) {
        LoadingRing()
          .frame(width: 16, height: 16)

        LText("等待浏览器授权…")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()

        Button(action: { model.cancelOAuthLogin() }) {
          LText("取消")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHoveredCancel ? .kimiTextPrimary : .kimiTextSecondary)
            .padding(.horizontal, 10)
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
      .padding(.horizontal, 16)
      .padding(.vertical, 13)

      SettingsCardDivider()

      // 授权码行
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          LText("授权码")
            .font(.system(size: 12))
            .foregroundStyle(.kimiTextSecondary)

          Text(auth.userCode)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(.kimiTextPrimary)
            .textSelection(.enabled)
        }

        Spacer()

        Button(action: {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(auth.userCode, forType: .string)
          isCodeCopied = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCodeCopied = false
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: isCodeCopied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 11, weight: .medium))
            LText(isCodeCopied ? "已复制" : "复制")
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundStyle(isHoveredCopyCode ? .kimiTextPrimary : .kimiTextSecondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            isHoveredCopyCode
              ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
          )
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredCopyCode = $0 }

        if let urlString = auth.displayURL, let url = URL(string: urlString) {
          Button(action: { NSWorkspace.shared.open(url) }) {
            HStack(spacing: 4) {
              Image(systemName: "safari")
                .font(.system(size: 11, weight: .medium))
              LText("打开授权页")
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isHoveredReopen ? .white : .white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHoveredReopen ? Color.kimiBlue.opacity(0.85) : Color.kimiBlue)
            .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .cursor(.pointingHand)
          .onHover { isHoveredReopen = $0 }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
    }
  }

  // MARK: 已授权

  private var authorizedContent: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22, weight: .regular))
        .foregroundStyle(.green)
        .frame(width: 32, height: 32)

      LText("已授权 Kimi 账号")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.kimiTextPrimary)

      Spacer()

      Button(action: { model.logoutOAuth() }) {
        LText("退出登录")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isHoveredLogout ? .red.opacity(0.9) : .red)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(isHoveredLogout ? Color.red.opacity(0.18) : Color.red.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .cursor(.pointingHand)
      .onHover { isHoveredLogout = $0 }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
  }
}

// MARK: - 基本设置

struct BasicSettingsView: View {
  @StateObject private var themeManager = ThemeManager.shared
  @StateObject private var model = KimiCodeBarModel.shared
  @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared
  @StateObject private var languageManager = LanguageManager.shared

  @State private var editingKey = ""
  @State private var isEditingKey = false
  @State private var editingDeepseekKey = ""
  @State private var isEditingDeepseekKey = false
  @State private var quotaIntervalText = "5"
  @State private var updateIntervalText = "30"
  @FocusState private var focusedField: APISettingField?

  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: { launchAtLoginManager.isEnabled },
      set: { launchAtLoginManager.setEnabled($0) }
    )
  }

  @ViewBuilder
  private var menuBarPreview: some View {
    let showKimi = model.showKimiMenuBar && model.quota != nil
    let showDS = model.showDeepseekMenuBar
    if showKimi && showDS {
      Image(
        nsImage: MenuBarTextRenderer.combinedImage(
          scheme: model.menuBarDisplayScheme,
          weekly: model.quota?.weekly.percentage ?? 0,
          fiveHour: model.quota?.fiveHour.percentage ?? 0,
          deepseekText: model.deepseekMenuBarText
        )
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    } else if showKimi {
      Image(
        nsImage: MenuBarTextRenderer.image(
          scheme: model.menuBarDisplayScheme,
          weekly: model.quota?.weekly.percentage ?? 0,
          fiveHour: model.quota?.fiveHour.percentage ?? 0
        )
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    } else {
      Text(model.text)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
  }

  /// Token 登录方式下的 API Key 管理区域
  private var apiKeySection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        if isEditingKey {
          SecureField("sk-kimi-...", text: $editingKey)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .focused($focusedField, equals: .apiKey)
            .onChange(of: editingKey) { _, newValue in
              let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
              if trimmed != newValue {
                editingKey = trimmed
              }
            }
        } else {
          Text(maskedKey(model.key))
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.kimiTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kimiTextPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        Button(action: {
          if isEditingKey {
            saveKey()
          } else {
            editingKey = model.key
            isEditingKey = true
            model.errorMessage = nil
            focusedField = .apiKey
          }
        }) {
          LText(isEditingKey ? "保存" : "修改")
        }
        .buttonStyle(.borderedProminent)
        .tint(.kimiBlue)
        .disabled(
          isEditingKey && editingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .cursor(
          isEditingKey && editingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .arrow : .pointingHand)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)

      if let error = model.errorMessage {
        SettingsCardDivider()
        ErrorMessageView(message: error)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
      }

      SettingsCardDivider()
      SettingsCardRow(
        title: languageManager.tr("获取 API Key"),
        subtitle: languageManager.tr("前往 Kimi 控制台创建并复制 API Key。")
      ) {
        LinkRow(
          title: languageManager.tr("去控制台"),
          icon: "arrow.up.right",
          url: URL(string: "https://www.kimi.com/code/console")!
        )
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        LText("基本设置")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        // 登录方式（默认授权登录，凭证独立存储，不影响 KimiCode CLI）
        SettingsCard(title: languageManager.tr("登录方式")) {
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
              ForEach(LoginMethod.allCases) { method in
                SettingsOptionCard(
                  title: method.displayName,
                  subtitle: method.subtitle,
                  iconName: method.iconName,
                  isSelected: model.loginMethod == method
                ) {
                  model.loginMethod = method
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            SettingsCardDivider()

            if model.loginMethod == .oauth {
              OAuthLoginSection()
            } else {
              apiKeySection
            }
          }
        }

        // DeepSeek API Key
        SettingsCard(title: languageManager.tr("DeepSeek API Key")) {
          providerKeySection(
            provider: .deepseek,
            key: $model.deepseekKey,
            editingState: $editingDeepseekKey,
            isEditing: $isEditingDeepseekKey,
            prefixHint: "sk-"
          )
        }

        // 外观主题
        SettingsCard(title: languageManager.tr("外观主题")) {
          HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
              SettingsOptionCard(
                title: theme.displayName,
                subtitle: nil,
                iconName: theme.iconName,
                isSelected: themeManager.theme == theme
              ) {
                themeManager.theme = theme
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 13)
        }

        // 语言
        SettingsCard {
          SettingsCardRow(title: languageManager.tr("语言")) {
            Picker("", selection: $languageManager.language) {
              ForEach(AppLanguage.allCases) { language in
                Text(language.displayName).tag(language)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .cursor(.pointingHand)
          }
        }

        // 启动
        SettingsCard {
          SettingsCardRow(title: languageManager.tr("开机自动启动")) {
            Toggle("", isOn: launchAtLoginBinding)
              .labelsHidden()
              .toggleStyle(.switch)
              .cursor(.pointingHand)
          }
        }

        SettingsCard {
          VStack(alignment: .leading, spacing: 0) {
            SettingsCardRow(title: languageManager.tr("额度刷新间隔")) {
              HStack(spacing: 6) {
                TextField("", text: $quotaIntervalText)
                  .textFieldStyle(.roundedBorder)
                  .frame(width: 60)
                  .focused($focusedField, equals: .quotaInterval)
                  .onChange(of: quotaIntervalText) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                      quotaIntervalText = filtered
                    }
                  }

                LText("分钟")
                  .font(.system(size: 12))
                  .foregroundStyle(.kimiTextSecondary)
              }
            }

            SettingsCardDivider()
            SettingsCardRow(title: languageManager.tr("检查更新间隔")) {
              HStack(spacing: 6) {
                TextField("", text: $updateIntervalText)
                  .textFieldStyle(.roundedBorder)
                  .frame(width: 60)
                  .focused($focusedField, equals: .updateInterval)
                  .onChange(of: updateIntervalText) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                      updateIntervalText = filtered
                    }
                  }

                LText("分钟")
                  .font(.system(size: 12))
                  .foregroundStyle(.kimiTextSecondary)
              }
            }
          }
        }

        // 菜单栏
        SettingsCard(title: languageManager.tr("菜单栏")) {
          VStack(alignment: .leading, spacing: 0) {
            SettingsCardRow(title: languageManager.tr("显示样式")) {
              Picker("", selection: $model.menuBarDisplayScheme) {
                ForEach(MenuBarDisplayScheme.allCases) { scheme in
                  Text(scheme.displayName).tag(scheme)
                }
              }
              .pickerStyle(.segmented)
              .labelsHidden()
              .frame(width: 180)
            }

            SettingsCardDivider()
            SettingsCardRow(title: languageManager.tr("实时预览")) {
              menuBarPreview
            }

            SettingsCardDivider()
            SettingsCardRow(
              title: languageManager.tr("Kimi 用量")
            ) {
              Toggle("", isOn: $model.showKimiMenuBar)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()
            SettingsCardRow(
              title: languageManager.tr("DeepSeek 余额")
            ) {
              Toggle("", isOn: $model.showDeepseekMenuBar)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 44)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.ultraThinMaterial)
    .onAppear {
      editingKey = model.key
      isEditingKey = model.key.isEmpty
      editingDeepseekKey = model.deepseekKey
      isEditingDeepseekKey = false
      quotaIntervalText = intervalText(from: model.quotaRefreshInterval)
      updateIntervalText = intervalText(from: model.updateCheckInterval)
      launchAtLoginManager.refresh()

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        focusedField = nil
      }

      model.refresh(showsLoading: false)
    }
    .onDisappear {
      commitIntervals()
    }
  }

  private func intervalText(from value: Double) -> String {
    let intValue = Int(value)
    return intValue > 0 ? "\(intValue)" : "1"
  }

  private func commitIntervals() {
    let quota = Int(quotaIntervalText) ?? 3
    let update = Int(updateIntervalText) ?? 10
    model.quotaRefreshInterval = Double(max(1, quota))
    model.updateCheckInterval = Double(max(10, update))
    quotaIntervalText = intervalText(from: model.quotaRefreshInterval)
    updateIntervalText = intervalText(from: model.updateCheckInterval)
    model.restartTimers()
  }

  private func saveKey() {
    let trimmed = editingKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("sk-kimi-") else {
      model.errorMessage = LanguageManager.tr("API Key 格式错误，应以 sk-kimi- 开头")
      return
    }
    editingKey = trimmed
    model.key = trimmed
    isEditingKey = false
    commitIntervals()
    model.refresh(showsLoading: false)
  }

  private func maskedKey(_ key: String) -> String {
    guard key.count > 8 else { return key }
    let prefix = String(key.prefix(7))
    let suffix = String(key.suffix(5))
    return "\(prefix)...\(suffix)"
  }

  /// 第三方平台 API Key 输入区域
  private func providerKeySection(
    provider: ProviderType,
    key: Binding<String>,
    editingState: Binding<String>,
    isEditing: Binding<Bool>,
    prefixHint: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        if isEditing.wrappedValue {
          SecureField("\(prefixHint)...", text: editingState)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .onChange(of: editingState.wrappedValue) { _, newValue in
              let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
              if trimmed != newValue {
                editingState.wrappedValue = trimmed
              }
            }
        } else {
          Text(key.wrappedValue.isEmpty ? LanguageManager.tr("未配置") : maskedKey(key.wrappedValue))
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(key.wrappedValue.isEmpty ? .kimiTextTertiary : .kimiTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kimiTextPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        Button(action: {
          if isEditing.wrappedValue {
            saveProviderKey(
              provider: provider, key: key, editingState: editingState, isEditing: isEditing)
          } else {
            editingState.wrappedValue = key.wrappedValue
            isEditing.wrappedValue = true
          }
        }) {
          LText(isEditing.wrappedValue ? "保存" : "修改")
        }
        .buttonStyle(.borderedProminent)
        .tint(.kimiBlue)
        .disabled(
          isEditing.wrappedValue
            && editingState.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .cursor(
          isEditing.wrappedValue
            && editingState.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .arrow : .pointingHand)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)

      SettingsCardDivider()
      SettingsCardRow(
        title: LanguageManager.tr("获取 API Key"),
        subtitle: LanguageManager.tr("前往 %@ 控制台创建并复制 API Key。", arguments: [provider.displayName])
      ) {
        if let url = provider.consoleURL {
          LinkRow(
            title: LanguageManager.tr("去控制台"),
            icon: "arrow.up.right",
            url: url
          )
        } else {
          EmptyView()
        }
      }
    }
  }

  private func saveProviderKey(
    provider: ProviderType, key: Binding<String>, editingState: Binding<String>,
    isEditing: Binding<Bool>
  ) {
    let trimmed = editingState.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    editingState.wrappedValue = trimmed
    key.wrappedValue = trimmed
    isEditing.wrappedValue = false
    commitIntervals()
    if model.selectedProvider == provider {
      model.refreshCurrentProvider(showsLoading: false)
    }
  }
}

// MARK: - 面板自定义

struct PanelCustomSettingsView: View {
  @StateObject private var model = KimiCodeBarModel.shared
  @StateObject private var languageManager = LanguageManager.shared

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          LText("面板自定义")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.kimiTextPrimary)

          LText("勾选要在菜单栏面板中显示的内容，取消勾选可隐藏对应卡片。菜单栏样式请在基本设置中调整。")
            .font(.system(size: 13))
            .foregroundStyle(.kimiTextSecondary)
        }

        SettingsCard {
          VStack(alignment: .leading, spacing: 0) {
            SettingsCardRow(
              title: languageManager.tr("加油包余额卡片")
            ) {
              Toggle("", isOn: $model.showBoosterWalletCard)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()

            SettingsCardRow(
              title: languageManager.tr("本机消耗量卡片")
            ) {
              Toggle("", isOn: $model.showLocalUsageCard)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()

            // 平台显示开关
            SettingsCardRow(
              title: languageManager.tr("Kimi 用量")
            ) {
              Toggle("", isOn: $model.showKimiProvider)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()

            SettingsCardRow(
              title: languageManager.tr("DeepSeek 余额")
            ) {
              Toggle("", isOn: $model.showDeepseekProvider)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()

            // 「Kimi Web 卡片」已弃用（2026-07）：官方砍掉 server 服务，
            // 置灰禁用展示，保留用户历史开关状态但不可操作。
            SettingsCardRow(
              title: languageManager.tr("Kimi Web 卡片"),
              subtitle: languageManager.tr("官方砍掉了 server 服务，临时弃用。")
            ) {
              Toggle("", isOn: $model.showKimiServerCard)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(true)
            }
            .opacity(0.5)

            SettingsCardDivider()

            SettingsCardRow(
              title: languageManager.tr("KimiCode CLI 版本号"),
              subtitle: languageManager.tr("发现新版本时会强制显示")
            ) {
              Toggle("", isOn: $model.showKimiVersionRow)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }

            SettingsCardDivider()

            SettingsCardRow(
              title: languageManager.tr("KimiCodeBar 版本行")
            ) {
              Toggle("", isOn: $model.showAppUpdateRow)
                .labelsHidden()
                .toggleStyle(.switch)
                .cursor(.pointingHand)
            }
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 44)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.ultraThinMaterial)
  }
}

// MARK: - 关于

struct AboutSettingsView: View {
  @StateObject private var model = KimiCodeBarModel.shared
  @StateObject private var languageManager = LanguageManager.shared

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        LText("关于")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        // GitHub 开源社区卡片
        GitHubCommunityCard()

        // 特性亮点
        HStack(alignment: .top, spacing: 16) {
          FeatureHighlightCard(
            icon: "sparkles",
            iconColor: .kimiBlue,
            title: languageManager.tr("量身定制"),
            description: languageManager.tr("为 Kimi Code 量身设计的用量监控小工具，在菜单栏轻量化运行，限额一目了然。")
          )

          FeatureHighlightCard(
            icon: "lock.shield",
            iconColor: .green,
            title: languageManager.tr("隐私安全"),
            description: languageManager.tr("数据仅本地存储，所有 API 只与 Kimi 官方通信，代码全部开源可审计。")
          )
        }

        // 应用信息
        SettingsCard {
          VStack(spacing: 16) {
            AnimatedKimiCodeLogo(width: 64, isAnimating: true)

            Text("KimiCodeBar")
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(.kimiTextPrimary)

            LText("版本 %@", appVersion())
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.secondary)

            if model.kimiVersion != languageManager.tr("检测中…")
              && model.kimiVersion != languageManager.tr("未检测到")
            {
              Text("KimiCode CLI \(formatKimiVersion(model.kimiVersion))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
              LinkRow(
                title: "GitHub",
                imageName: "github-icon",
                imageSize: 16,
                url: URL(string: "https://github.com/WuChenh/KimiCodeBar")!
              )
              LinkRow(
                title: languageManager.tr("反馈问题"),
                icon: "exclamationmark.bubble",
                url: URL(string: "https://github.com/WuChenh/KimiCodeBar/issues")!
              )
            }
            .padding(.top, 8)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 44)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.ultraThinMaterial)
  }
}

// MARK: - 技能管理设置

struct SkillsSettingsView: View {
  @State private var skills: [SkillInfo] = []
  @State private var selectedSkill: SkillInfo?
  @State private var displayedSkill: SkillInfo?
  @State private var isLoading = true
  @State private var isLoadingPreview = false
  @State private var isHoveredFinder = false

  var body: some View {
    ZStack {
      Color.clear.background(.ultraThinMaterial)

      if isLoading {
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
            .scaleEffect(0.8)
          LText("正在加载技能…")
            .font(.system(size: 12))
            .foregroundStyle(.kimiTextSecondary)
        }
      } else if skills.isEmpty {
        VStack(spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 14)
              .fill(Color.kimiTextPrimary.opacity(0.06))
              .frame(width: 56, height: 56)

            Image(systemName: "puzzlepiece.extension")
              .font(.system(size: 24, weight: .medium))
              .foregroundStyle(.kimiTextTertiary)
          }

          VStack(spacing: 4) {
            LText("暂无已安装技能")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.kimiTextSecondary)
            LText("技能包通常位于 ~/.kimi-code/skills/")
              .font(.system(size: 11))
              .foregroundStyle(.kimiTextTertiary)
          }
        }
      } else {
        ScrollView {
          VStack(spacing: 0) {
            // 顶部横向技能列表
            VStack(alignment: .leading, spacing: 0) {
              HStack(spacing: 8) {
                LText("技能管理")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundStyle(.kimiTextPrimary)

                Text("\(skills.count)")
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundStyle(.kimiTextTertiary)
                  .padding(.horizontal, 7)
                  .padding(.vertical, 2)
                  .background(Color.kimiTextPrimary.opacity(0.08))
                  .clipShape(Capsule())
              }
              .padding(.horizontal, 20)
              .padding(.top, 20)
              .padding(.bottom, 12)

              ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                  LazyHStack(spacing: 10) {
                    ForEach(skills) { skill in
                      SkillHorizontalItem(
                        skill: skill,
                        isSelected: selectedSkill?.id == skill.id
                      ) {
                        selectSkill(skill)
                        withAnimation {
                          proxy.scrollTo(skill.id, anchor: .center)
                        }
                      }
                      .id(skill.id)
                    }
                  }
                  .padding(.horizontal, 20)
                  .padding(.vertical, 4)
                }
              }
            }
          .background(.ultraThinMaterial)

            Divider()
              .background(Color.kimiTextPrimary.opacity(0.08))

            // 预览区
            if isLoadingPreview {
              HStack(spacing: 8) {
                ProgressView()
                  .controlSize(.small)
                  .scaleEffect(0.8)
                LText("正在加载内容…")
                  .font(.system(size: 12))
                  .foregroundStyle(.kimiTextSecondary)
              }
              .frame(maxWidth: .infinity, minHeight: 200)
            } else if let skill = displayedSkill {
              skillPreview(skill)
            } else {
              VStack(spacing: 12) {
                ZStack {
                  RoundedRectangle(cornerRadius: 14)
                    .fill(Color.kimiTextPrimary.opacity(0.06))
                    .frame(width: 56, height: 56)

                  Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.kimiTextTertiary)
                }

                LText("选择上方技能以预览内容")
                  .font(.system(size: 13, weight: .medium))
                  .foregroundStyle(.kimiTextSecondary)
              }
              .frame(maxWidth: .infinity, minHeight: 200)
            }
          }
        }
      }
    }
    .onAppear {
      loadAndSelect()
    }
  }

  /// 单个技能的预览：顶部信息卡片 + 正文内容卡片
  private func skillPreview(_ skill: SkillInfo) -> some View {
    VStack(spacing: 14) {
      // 信息卡片
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 14) {
          ZStack {
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.kimiBlue.opacity(0.14))
              .frame(width: 48, height: 48)

            Image(systemName: "puzzlepiece.extension")
              .font(.system(size: 20, weight: .medium))
              .foregroundStyle(.kimiBlue)
          }

          HStack(spacing: 8) {
            Text(skill.name)
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.kimiTextPrimary)
              .lineLimit(1)
              .truncationMode(.tail)

            if !skill.version.isEmpty {
              Text("v\(skill.version)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.kimiBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.kimiBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .fixedSize()
            }
          }
          .layoutPriority(1)

          Spacer(minLength: 8)

          Button(action: { revealSkillInFinder(skill) }) {
            Image(systemName: "folder")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(isHoveredFinder ? .kimiTextPrimary : .kimiTextSecondary)
              .frame(width: 30, height: 30)
              .background(
                isHoveredFinder
                  ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
              )
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .help(Text(LanguageManager.tr("在 Finder 中显示")))
          .cursor(.pointingHand)
          .onHover { isHoveredFinder = $0 }
          .fixedSize()
        }

        if !skill.description.isEmpty {
          Text(skill.description)
            .font(.system(size: 12))
            .foregroundStyle(.kimiTextSecondary)
            .lineSpacing(2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(skill.path)
          .font(.system(size: 11))
          .foregroundStyle(.kimiTextTertiary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      // 正文卡片（使用 TextEditor 按需渲染，避免 Text + textSelection 布局全文卡死主线程）
      VStack(alignment: .leading, spacing: 0) {
        TextEditor(text: .constant(skill.content))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.kimiTextSecondary)
          .scrollContentBackground(.hidden)
          .background(.regularMaterial)
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 500)
          .padding(12)
      }
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding(.horizontal, 20)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  private func loadAndSelect() {
    // 文件读取放后台线程，避免 onAppear 时同步 I/O 卡住设置窗口
    Task {
      let loaded = await Task.detached(priority: .userInitiated) {
        loadSkills()
      }.value
      skills = loaded
      isLoading = false
      if displayedSkill == nil, let first = loaded.first {
        selectSkill(first)
      }
    }
  }

  /// 切换选中技能。
  /// 预览区的大段可选中文本渲染开销较大，直接同步切换会卡住主线程一帧，
  /// 这里先展示转圈、延迟一小段时间再替换内容，让界面看起来是「加载中」而不是「卡死」。
  private func selectSkill(_ skill: SkillInfo) {
    guard skill.id != selectedSkill?.id else { return }
    selectedSkill = skill
    isLoadingPreview = true
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 100_000_000)
      // 快速连点时只有最后一次选择生效
      guard selectedSkill?.id == skill.id else { return }
      displayedSkill = skill
      isLoadingPreview = false
    }
  }

  private func revealSkillInFinder(_ skill: SkillInfo) {
    let url = URL(fileURLWithPath: skill.path)
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}

private struct SkillHorizontalItem: View {
  let skill: SkillInfo
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          ZStack {
            RoundedRectangle(cornerRadius: 8)
              .fill(isSelected ? Color.white.opacity(0.22) : Color.kimiBlue.opacity(0.12))
              .frame(width: 32, height: 32)

            Image(systemName: "puzzlepiece.extension")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(isSelected ? .white : .kimiBlue)
          }

          Spacer()

          if !skill.version.isEmpty {
            Text("v\(skill.version)")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(isSelected ? .white.opacity(0.85) : .kimiTextTertiary)
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(
                isSelected ? Color.white.opacity(0.25) : Color.kimiTextPrimary.opacity(0.08)
              )
              .clipShape(RoundedRectangle(cornerRadius: 3))
          }
        }

        Text(skill.name)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(isSelected ? .white : .kimiTextPrimary)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)

        if !skill.description.isEmpty {
          Text(skill.description)
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? .white.opacity(0.85) : .kimiTextSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(width: 150)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(backgroundColor)
      )
    }
    .buttonStyle(.plain)
    .cursor(.pointingHand)
    .onHover { isHovered = $0 }
  }

  private var backgroundColor: Color {
    if isSelected {
      return .kimiBlue
    } else if isHovered {
      return Color.kimiTextPrimary.opacity(0.08)
    } else {
      return Color.clear
    }
  }
}

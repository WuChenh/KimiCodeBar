import Foundation
import SwiftUI
import UserNotifications

// MARK: - 数据模型

@MainActor
final class KimiCodeBarModel: ObservableObject {
  static let shared = KimiCodeBarModel()

  private let kcAllKeys = "apiSecrets"
  private var cachedKimiKey = ""
  private var cachedDeepseekKey = ""

  var key: String {
    get { cachedKimiKey }
    set {
      cachedKimiKey = newValue
      syncSecretsToKeychain()
    }
  }
  var deepseekKey: String {
    get { cachedDeepseekKey }
    set {
      cachedDeepseekKey = newValue
      syncSecretsToKeychain()
    }
  }

  private func loadSecretsFromKeychain() {
    guard let json = KeychainHelper.read(key: kcAllKeys),
      let data = json.data(using: .utf8),
      let dict = try? JSONDecoder().decode([String: String].self, from: data)
    else { return }
    cachedKimiKey = dict["kimi"] ?? ""
    cachedDeepseekKey = dict["deepseek"] ?? ""
  }

  private func syncSecretsToKeychain() {
    let dict = ["kimi": cachedKimiKey, "deepseek": cachedDeepseekKey]
    guard let data = try? JSONEncoder().encode(dict),
      let json = String(data: data, encoding: .utf8)
    else { return }
    if cachedKimiKey.isEmpty && cachedDeepseekKey.isEmpty {
      KeychainHelper.delete(key: kcAllKeys)
    } else {
      KeychainHelper.save(key: kcAllKeys, value: json)
    }
  }
  @AppStorage("loginMethod") var loginMethod: LoginMethod = .oauth {
    didSet { refresh(showsLoading: false) }
  }
  @AppStorage("quotaRefreshInterval") var quotaRefreshInterval: Double = 3
  @AppStorage("updateCheckInterval") var updateCheckInterval: Double = 10
  @AppStorage("menuBarDisplayScheme") var menuBarDisplayScheme: MenuBarDisplayScheme = .compact
  @AppStorage("cachedKimiLatestVersion") var cachedKimiLatestVersion: String = ""
  @AppStorage("cachedKimiReleaseNotes") var cachedKimiReleaseNotes: String = ""
  @AppStorage("snoozedKimiUpdateUntil") var snoozedKimiUpdateUntil: Double = 0

  // MARK: - 多平台支持
  @AppStorage("selectedProvider") var selectedProviderRaw: String = ProviderType.kimi.rawValue

  // MARK: - 面板自定义（用户控制各卡片是否显示）
  @AppStorage("showBoosterWalletCard") var showBoosterWalletCard: Bool = true
  @AppStorage("showLocalUsageCard") var showLocalUsageCard: Bool = true
  @AppStorage("showKimiServerCard") var showKimiServerCard: Bool = true
  @AppStorage("showKimiVersionRow") var showKimiVersionRow: Bool = false
  @AppStorage("showAppUpdateRow") var showAppUpdateRow: Bool = false
  @AppStorage("showKimiProvider") var showKimiProvider: Bool = true
  @AppStorage("showDeepseekProvider") var showDeepseekProvider: Bool = true
  @AppStorage("showKimiMenuBar") var showKimiMenuBar: Bool = true
  @AppStorage("showDeepseekMenuBar") var showDeepseekMenuBar: Bool = false

  @Published var kimiMenuBarText = "-- · --"
  @Published var deepseekMenuBarText = "--"
  @Published var quota: KimiQuota?
  @Published var errorMessage: String?
  @Published var isLoading = false

  // MARK: - 多账号状态

  /// 已添加的账号列表（从 KimiAccountStore 加载）
  @Published var accounts: [KimiAccount] = []
  /// 主账号 ID
  @Published var primaryAccountID: UUID?
  /// 每个账号的配额加载状态
  @Published var accountStates: [UUID: KimiAccountState] = [:]
  /// 每个账号的最新配额快照
  @Published var accountQuotas: [UUID: KimiQuota] = [:]

  @Published var oauthToken: KimiOAuthToken?
  @Published var oauthDeviceAuth: KimiDeviceAuthorization?
  @Published var oauthLoginInProgress = false
  @Published var oauthLoginError: String?

  @Published var kimiVersion: String = LanguageManager.tr("检测中…")
  @Published var isCheckingUpdate: Bool = false
  @Published var pendingUpdateVersion: String?
  @Published var pendingReleaseNotes: String?
  @Published var updateErrorMessage: String?

  @Published var kimiServerState = KimiServerState()

  // MARK: - 多平台状态
  @Published var selectedProvider: ProviderType = .kimi {
    didSet {
      selectedProviderRaw = selectedProvider.rawValue
      refreshCurrentProvider(showsLoading: false)
    }
  }
  @Published var deepseekState = ProviderState()

  /// 菜单栏文本：根据用户设置组合多个平台
  var text: String {
    var parts: [String] = []
    if showKimiMenuBar { parts.append(kimiMenuBarText) }
    if showDeepseekMenuBar { parts.append(deepseekMenuBarText) }
    return parts.isEmpty ? "--" : parts.joined(separator: " · ")
  }

  var hasCachedKimiUpdate: Bool {
    guard !cachedKimiLatestVersion.isEmpty, kimiVersion != LanguageManager.tr("未检测到"),
      kimiVersion != LanguageManager.tr("检测中…")
    else { return false }
    return compareVersions(normalizeVersion(kimiVersion), normalizeVersion(cachedKimiLatestVersion))
      == .orderedAscending
  }

  var kimiServerNeedsRestart: Bool {
    guard kimiServerState.status == .running,
      !kimiServerState.version.isEmpty,
      kimiServerState.version != LanguageManager.tr("未检测到"),
      !kimiVersion.isEmpty,
      kimiVersion != LanguageManager.tr("未检测到"),
      kimiVersion != LanguageManager.tr("检测中…")
    else { return false }
    return compareVersions(normalizeVersion(kimiServerState.version), normalizeVersion(kimiVersion))
      == .orderedAscending
  }

  private let service = KimiCodeBarQuotaService()
  private let oauthService = KimiOAuthService()
  private let deepseekService = DeepSeekService()
  private var oauthLoginTask: Task<Void, Never>?
  private var timer: Timer?
  private var updateTimer: Timer?

  /// Kimi 平台是否有可用凭证
  var hasKimiCredential: Bool {
    switch loginMethod {
    case .token: return !key.isEmpty
    case .oauth: return !accounts.isEmpty
    }
  }

  /// DeepSeek 平台是否有可用凭证
  var hasDeepseekCredential: Bool {
    !deepseekKey.isEmpty
  }

  /// 当前选中平台的 API Key（Token 登录模式或非 Kimi 平台）
  var currentApiKey: String {
    switch selectedProvider {
    case .kimi: return key
    case .deepseek: return deepseekKey
    }
  }

  init() {
    loadSecretsFromKeychain()
    migrateSecretsToSingleEntry()
    selectedProvider = ProviderType(rawValue: selectedProviderRaw) ?? .kimi
    loadAccountsFromStore()
    refresh(showsLoading: false)
    Task { await loadKimiVersion() }
    startQuotaTimer()
    startUpdateTimer()
    KimiArchiveManager.shared.restartTimer()
  }

  // MARK: - 多账号管理

  /// 从 KimiAccountStore 加载账号列表，同步到 published 属性
  private func loadAccountsFromStore() {
    let snapshot = KimiAccountStore.shared.snapshot
    accounts = snapshot.accounts
    primaryAccountID = snapshot.primaryAccountID
    if let token = accounts.first(where: { $0.id == primaryAccountID })?.token {
      oauthToken = token
    }
  }

  /// 重新从磁盘加载账号（刷新周期中使用）
  private func reloadAccountsFromDisk() {
    KimiAccountStore.shared.reload()
    let snapshot = KimiAccountStore.shared.snapshot
    var changed = false
    if accounts != snapshot.accounts {
      accounts = snapshot.accounts
      changed = true
    }
    if primaryAccountID != snapshot.primaryAccountID {
      primaryAccountID = snapshot.primaryAccountID
      changed = true
    }
    if changed, let token = accounts.first(where: { $0.id == primaryAccountID })?.token {
      oauthToken = token
    }
  }

  /// 获取账号的显示名称（别名 > "账号 N"）
  func displayName(for account: KimiAccount) -> String {
    if let alias = account.alias, !alias.isEmpty { return alias }
    guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return "账号" }
    return LanguageManager.tr("账号 %d", arguments: [index + 1])
  }

  /// 设为主账号
  func setPrimaryAccount(_ id: UUID) {
    KimiAccountStore.shared.setPrimaryAccount(id)
    primaryAccountID = id
    if let token = accounts.first(where: { $0.id == id })?.token {
      oauthToken = token
    }
    refresh(showsLoading: false)
  }

  /// 重命名账号
  func renameAccount(_ id: UUID, alias: String) {
    let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
    KimiAccountStore.shared.setAlias(id: id, alias: trimmed.isEmpty ? nil : trimmed)
    if let index = accounts.firstIndex(where: { $0.id == id }) {
      accounts[index].alias = trimmed.isEmpty ? nil : trimmed
    }
  }

  /// 删除账号
  func removeAccount(_ id: UUID) {
    let wasPrimary = id == primaryAccountID
    KimiAccountStore.shared.removeAccount(id: id)
    KimiAccountStore.shared.ensurePrimaryAccount()

    accounts.removeAll(where: { $0.id == id })
    accountStates.removeValue(forKey: id)
    accountQuotas.removeValue(forKey: id)

    let snapshot = KimiAccountStore.shared.snapshot
    primaryAccountID = snapshot.primaryAccountID

    if accounts.isEmpty {
      oauthToken = nil
      quota = nil
      kimiMenuBarText = LanguageManager.tr("未登录")
    } else if wasPrimary, let token = accounts.first(where: { $0.id == primaryAccountID })?.token {
      oauthToken = token
      refresh(showsLoading: false)
    }
  }

  /// 重新授权指定的账号（登录失效后重新走 OAuth 流程）
  func reauthorizeAccount(_ id: UUID) {
    oauthLoginTask?.cancel()
    oauthLoginError = nil
    oauthDeviceAuth = nil
    oauthLoginInProgress = true

    oauthLoginTask = Task {
      let result = await oauthService.requestDeviceAuthorization()
      guard !Task.isCancelled else { return }

      switch result {
      case .failure(let error):
        oauthLoginInProgress = false
        oauthLoginError = oauthErrorDescription(error)
        return
      case .success(let auth):
        oauthDeviceAuth = auth
        if let urlString = auth.displayURL, let url = URL(string: urlString) {
          NSWorkspace.shared.open(url)
        }

        let pollResult = await oauthService.pollDeviceToken(
          deviceCode: auth.deviceCode,
          initialInterval: TimeInterval(auth.interval ?? 5)
        )
        guard !Task.isCancelled else { return }

        oauthLoginInProgress = false
        oauthDeviceAuth = nil
        switch pollResult {
        case .success(let token):
          KimiAccountStore.shared.updateToken(id: id, token: token)
          if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].token = token
          }
          accountStates[id] = .loaded
          if id == primaryAccountID {
            oauthToken = token
          }
          refresh(showsLoading: false)
        case .failure(let error) where error != .cancelled:
          oauthLoginError = oauthErrorDescription(error)
        case .failure:
          break
        }
      }
    }
  }

  private func migrateSecretsToSingleEntry() {
    let migrated = UserDefaults.standard.bool(forKey: "apiSecretsMigratedV2")
    guard !migrated else { return }

    let oldKimiKey = "kimiApiKey"
    let oldDeepseekKey = "deepseekApiKey"

    if cachedKimiKey.isEmpty, let v = KeychainHelper.read(key: oldKimiKey) {
      cachedKimiKey = v
    }
    if cachedDeepseekKey.isEmpty, let v = KeychainHelper.read(key: oldDeepseekKey) {
      cachedDeepseekKey = v
    }

    if let udKimi = UserDefaults.standard.string(forKey: "kimiApiKey"), !udKimi.isEmpty {
      cachedKimiKey = udKimi
    }
    if let udDS = UserDefaults.standard.string(forKey: "deepseekApiKey"), !udDS.isEmpty {
      cachedDeepseekKey = udDS
    }

    KeychainHelper.delete(key: oldKimiKey)
    KeychainHelper.delete(key: oldDeepseekKey)
    UserDefaults.standard.removeObject(forKey: "kimiApiKey")
    UserDefaults.standard.removeObject(forKey: "deepseekApiKey")

    syncSecretsToKeychain()
    UserDefaults.standard.set(true, forKey: "apiSecretsMigratedV2")
  }

  func startQuotaTimer() {
    timer?.invalidate()
    let interval = max(1.0, quotaRefreshInterval) * 60
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      Task { @MainActor in self.refreshCurrentProvider(showsLoading: false) }
    }
    timer?.tolerance = interval * 0.1
  }

  func startUpdateTimer() {
    updateTimer?.invalidate()
    let interval = max(10.0, updateCheckInterval) * 60
    updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      Task { @MainActor in await self.checkForKimiCLIUpdate() }
    }
    updateTimer?.tolerance = interval * 0.1
  }

  func restartTimers() {
    startQuotaTimer()
    startUpdateTimer()
  }

  /// 拉取当前选中平台的用量/余额。
  func refreshCurrentProvider(showsLoading: Bool = true) {
    switch selectedProvider {
    case .kimi: refreshKimi(showsLoading: showsLoading)
    case .deepseek: refreshDeepSeek(showsLoading: showsLoading)
    }
  }

  /// 拉取 Kimi 额度用量（兼容旧调用方）。
  func refresh(showsLoading: Bool = true) {
    refreshKimi(showsLoading: showsLoading)
  }

  /// 拉取 Kimi 额度用量。
  private func refreshKimi(showsLoading: Bool = true) {
    if showsLoading {
      isLoading = true
    }
    errorMessage = nil
    let startTime = Date()

    Task {
      guard let bearerToken = await resolveBearerToken() else {
        await MainActor.run {
          if showsLoading {
            self.isLoading = false
          }
          self.quota = nil
          self.kimiMenuBarText = LanguageManager.tr("未登录")
        }
        return
      }

      let result = await service.fetchQuota(token: bearerToken)

      let elapsed = Date().timeIntervalSince(startTime)
      let remaining = max(0, 0.5 - elapsed)
      if remaining > 0 {
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
      }

      await MainActor.run {
        if showsLoading {
          self.isLoading = false
        }
        switch result {
        case .success(let quota):
          self.quota = quota
          if let primaryID = self.primaryAccountID {
            self.accountQuotas[primaryID] = quota
            self.accountStates[primaryID] = .loaded
          }
          self.kimiMenuBarText = LanguageManager.tr(
            "7D %1$d%% · 5H %2$d%%",
            arguments: [quota.weekly.percentage, quota.fiveHour.percentage])
          self.errorMessage = nil
        case .failure(let error):
          if self.quota == nil {
            self.kimiMenuBarText = "--"
          }
          if let primaryID = self.primaryAccountID {
            self.accountStates[primaryID] = .failed(kimiErrorDescription(error))
          }
          self.errorMessage = kimiErrorDescription(error)
        }
      }
    }
  }

  /// 拉取 DeepSeek 余额。
  private func refreshDeepSeek(showsLoading: Bool = true) {
    guard !deepseekKey.isEmpty else {
      deepseekState = ProviderState(errorMessage: LanguageManager.tr("未配置 API Key"))
      deepseekMenuBarText = "DS --"
      return
    }

    if showsLoading {
      deepseekState.isLoading = true
    }
    deepseekState.errorMessage = nil

    Task {
      let result = await deepseekService.fetchBalance(apiKey: deepseekKey)
      await MainActor.run {
        deepseekState.isLoading = false
        switch result {
        case .success(let balance):
          deepseekState.balance = balance
          deepseekState.errorMessage = nil
          let amount = formatBalanceShort(balance.totalBalance)
          deepseekMenuBarText = "DS \(amount)"
        case .failure(let error):
          deepseekState.errorMessage = providerErrorDescription(error, provider: .deepseek)
          if deepseekState.balance == nil {
            deepseekMenuBarText = "DS --"
          }
        }
      }
    }
  }

  private func formatBalanceShort(_ amount: Double) -> String {
    if amount >= 1000 {
      return String(format: "%.1fk", amount / 1000)
    }
    return String(format: "%.2f", amount)
  }

  private func providerErrorDescription(_ error: ProviderError, provider: ProviderType) -> String {
    switch error {
    case .invalidKeyFormat:
      return LanguageManager.tr("API Key 无效，请检查是否已正确配置")
    case .badURL:
      return LanguageManager.tr("请求地址无效")
    case .networkError(let msg):
      return LanguageManager.tr("网络错误：%@", arguments: [msg])
    case .httpError(let code, let msg):
      return LanguageManager.tr(
        "%1$@ API 返回错误（%2$@）：%3$@", arguments: [provider.displayName, "\(code)", msg])
    case .badResponse:
      return LanguageManager.tr("无法解析 API 返回数据")
    }
  }

  func refreshAll() {
    refreshCurrentProvider()
    refreshDeepseek()
    Task {
      await checkForKimiCLIUpdate()
      await refreshKimiServerState()
    }
  }

  /// 拉取 DeepSeek 余额（公开入口）
  func refreshDeepseek() {
    refreshDeepSeek(showsLoading: false)
  }

  /// 根据当前登录方式解析 Bearer 凭证。
  /// OAuth 模式下使用 KimiAccountStore（与 CLI 隔离），过期前自动用 refresh_token 换新。
  private func resolveBearerToken() async -> String? {
    switch loginMethod {
    case .token:
      return key.isEmpty ? nil : key
    case .oauth:
      // 重新加载磁盘，确保拿到最新的账号数据
      reloadAccountsFromDisk()
      guard let primaryID = primaryAccountID,
        let index = accounts.firstIndex(where: { $0.id == primaryID })
      else { return nil }
      var token = accounts[index].token
      guard token.isValid else { return nil }

      guard token.needsRefresh else {
        oauthToken = token
        return token.accessToken
      }

      // 刷新前再读一次磁盘：防御其他 Bar 实例刚完成刷新并写入了新凭证
      if let fresh = KimiAccountStore.shared.freshAccount(id: primaryID),
        fresh.token.accessToken != token.accessToken,
        !fresh.token.needsRefresh
      {
        accounts[index].token = fresh.token
        oauthToken = fresh.token
        return fresh.token.accessToken
      }

      let result = await oauthService.refreshAccessToken(token)
      switch result {
      case .success(let newToken):
        KimiAccountStore.shared.updateToken(id: primaryID, token: newToken)
        accounts[index].token = newToken
        oauthToken = newToken
        return newToken.accessToken
      case .failure(.unauthorized):
        if let fresh = KimiAccountStore.shared.freshAccount(id: primaryID),
          fresh.token.accessToken != token.accessToken
        {
          accounts[index].token = fresh.token
          oauthToken = fresh.token
          return fresh.token.accessToken
        }
        accountStates[primaryID] = .unauthorized
        return nil
      case .failure:
        return token.accessToken
      }
    }
  }

  // MARK: - OAuth 授权登录

  /// 启动 Device Code Flow：请求设备码 → 打开浏览器 → 后台轮询直至授权完成。
  /// 授权成功后添加为新账号并设为主账号。
  func startOAuthLogin() {
    oauthLoginTask?.cancel()
    oauthLoginError = nil
    oauthDeviceAuth = nil
    oauthLoginInProgress = true

    oauthLoginTask = Task {
      let result = await oauthService.requestDeviceAuthorization()
      guard !Task.isCancelled else { return }

      let auth: KimiDeviceAuthorization
      switch result {
      case .failure(let error):
        oauthLoginInProgress = false
        oauthLoginError = oauthErrorDescription(error)
        return
      case .success(let value):
        auth = value
        oauthDeviceAuth = auth
        if let urlString = auth.displayURL, let url = URL(string: urlString) {
          NSWorkspace.shared.open(url)
        }
      }

      let pollResult = await oauthService.pollDeviceToken(
        deviceCode: auth.deviceCode,
        initialInterval: TimeInterval(auth.interval ?? 5)
      )
      guard !Task.isCancelled else { return }

      oauthLoginInProgress = false
      oauthDeviceAuth = nil
      switch pollResult {
      case .success(let token):
        let newAccount = KimiAccount(id: UUID(), alias: nil, token: token, accountIdentifier: nil)
        KimiAccountStore.shared.addAccount(newAccount)
        loadAccountsFromStore()
        setPrimaryAccount(newAccount.id)
        accountStates[newAccount.id] = .loaded
        refresh(showsLoading: false)
      case .failure(let error) where error != .cancelled:
        oauthLoginError = oauthErrorDescription(error)
      case .failure:
        break
      }
    }
  }

  func cancelOAuthLogin() {
    oauthLoginTask?.cancel()
    oauthLoginTask = nil
    oauthDeviceAuth = nil
    oauthLoginInProgress = false
  }

  /// 退出授权登录：取消进行中的授权流程并清除所有凭证。
  func logoutOAuth() {
    cancelOAuthLogin()
    oauthLoginError = nil
    for account in accounts {
      KimiAccountStore.shared.removeAccount(id: account.id)
    }
    accounts.removeAll()
    accountStates.removeAll()
    accountQuotas.removeAll()
    primaryAccountID = nil
    oauthToken = nil
    quota = nil
    kimiMenuBarText = LanguageManager.tr("未登录")
    errorMessage = nil
  }

  private func oauthErrorDescription(_ error: KimiOAuthError) -> String {
    switch error {
    case .invalidURL:
      return LanguageManager.tr("授权请求地址无效")
    case .networkError(let msg):
      return LanguageManager.tr("网络错误：%@", arguments: [msg])
    case .httpError(let code, let msg):
      return LanguageManager.tr("授权服务返回错误（%1$@）：%2$@", arguments: ["\(code)", msg])
    case .invalidResponse:
      return LanguageManager.tr("无法解析授权服务返回数据")
    case .authorizationPending, .slowDown:
      return LanguageManager.tr("等待授权中")
    case .expiredToken:
      return LanguageManager.tr("授权码已过期，请重新发起授权")
    case .accessDenied:
      return LanguageManager.tr("授权被拒绝")
    case .unauthorized:
      return LanguageManager.tr("授权已失效，请重新登录")
    case .cancelled:
      return LanguageManager.tr("已取消授权")
    case .timeout:
      return LanguageManager.tr("授权超时，请重新发起授权")
    }
  }

  func refreshKimiServerState() async {
    let state = await detectKimiServerState()
    await MainActor.run {
      self.kimiServerState = state
    }
  }

  func openKimiWeb() {
    let port = kimiServerState.port
    // 使用 --dangerous-bypass-auth 关闭 bearer-token 鉴权，
    // 直接打开本地地址即可，无需再拼接 #token=xxx。
    let urlString = "http://127.0.0.1:\(port)/"

    if let url = URL(string: urlString) {
      NSWorkspace.shared.open(url)
    }
  }

  func restartKimiServer() async {
    await stopKimiServer()
    await startKimiServer()
  }

  func startKimiServer() async {
    // kimi web 是持续运行的前台命令，Kimi 0.28 起不再提供官方后台服务模式。
    // 通过 Terminal.app 前台运行，让用户直接看到日志与生命周期，避免 launchd 后台环境带来的 WebSocket/流式异常。
    dismissMenuBarPanel()

    // 若已有实例在跑，避免重复打开 Terminal 造成端口冲突
    let currentState = await detectKimiServerState()
    guard currentState.status != .running else {
      await refreshKimiServerState()
      return
    }

    // 使用 .command 文件启动 Terminal，绕过 AppleScript 自动化权限限制，
    // 修复某些环境下 Terminal 窗口弹出但命令未输入的问题。
    guard let commandURL = writeKimiWebCommandFile() else { return }
    NSWorkspace.shared.open(commandURL)

    // 轮询等待 server 起来（最多 10 秒）
    for _ in 0..<10 {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      let state = await detectKimiServerState()
      if state.status == .running { break }
    }
    await refreshKimiServerState()
  }

  /// 在 Application Support 目录写入启动脚本并返回其 URL。
  private func writeKimiWebCommandFile() -> URL? {
    guard
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else {
      return nil
    }
    let dir = appSupport.appendingPathComponent("KimiCodeBar", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let commandURL = dir.appendingPathComponent("start-kimi-web.command")
    let script = "#!/bin/zsh\nkimi web --no-open --dangerous-bypass-auth\n"
    try? script.write(to: commandURL, atomically: true, encoding: .utf8)

    var attributes = [FileAttributeKey: Any]()
    attributes[.posixPermissions] = 0o755
    try? FileManager.default.setAttributes(attributes, ofItemAtPath: commandURL.path)

    return commandURL
  }

  func stopKimiServer() async {
    // 与启动同一机制：写 .command 脚本由 Terminal 执行 pkill。
    // App 内直接 kill 进程在部分环境下不可靠（与启动时 AppleScript 权限问题同理），
    // Terminal 的用户会话环境执行 pkill 与启动路径一致。
    dismissMenuBarPanel()

    // 若服务本来就没在跑，跳过脚本执行，避免无谓弹出 Terminal 窗口
    let currentState = await detectKimiServerState()
    guard currentState.status == .running else {
      await closeKimiWebTerminalWindows()
      await KimiWebLaunchAgentManager.shared.uninstall()
      await refreshKimiServerState()
      return
    }

    guard let commandURL = writeKimiWebStopCommandFile() else { return }
    NSWorkspace.shared.open(commandURL)

    // 轮询等待 server 停止（最多 10 秒）
    for _ in 0..<10 {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      let state = await detectKimiServerState()
      if state.status != .running { break }
    }

    // 进程结束后 Terminal 不再提示“终止运行中的进程”，尝试关闭残留窗口（无自动化权限时静默失败，无害）
    await closeKimiWebTerminalWindows()

    // 清理可能残留的旧 LaunchAgent，避免 KeepAlive 反复拉起进程
    await KimiWebLaunchAgentManager.shared.uninstall()

    await refreshKimiServerState()
  }

  /// 在 Application Support 目录写入停止脚本并返回其 URL。
  private func writeKimiWebStopCommandFile() -> URL? {
    guard
      let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else {
      return nil
    }
    let dir = appSupport.appendingPathComponent("KimiCodeBar", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let commandURL = dir.appendingPathComponent("stop-kimi-web.command")
    let script = "#!/bin/zsh\npkill -f 'kimi web'\n"
    try? script.write(to: commandURL, atomically: true, encoding: .utf8)

    var attributes = [FileAttributeKey: Any]()
    attributes[.posixPermissions] = 0o755
    try? FileManager.default.setAttributes(attributes, ofItemAtPath: commandURL.path)

    return commandURL
  }

  /// 关闭标题包含启动/停止脚本名的 Terminal 标签页/窗口。
  /// 进程结束后 Terminal 不再提示“终止运行中的进程”，可直接关闭。
  private func closeKimiWebTerminalWindows() async {
    await Task.detached(priority: .utility) {
      let script = """
        tell application "Terminal"
            set targetNames to {"start-kimi-web.command", "stop-kimi-web.command"}
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with targetName in targetNames
                        if name of t contains targetName then
                            close t
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
      var errorInfo: NSDictionary?
      guard let appleScript = NSAppleScript(source: script) else { return }
      appleScript.executeAndReturnError(&errorInfo)
    }.value
  }

  private func detectKimiServerState() async -> KimiServerState {
    // 直接探测本地端口判定运行状态。
    // Kimi Code 0.28 起 `kimi web ps` 已被移除，不再通过 CLI 判断。
    let port = 58627
    guard let version = await fetchKimiServerVersion(port: port) else {
      return KimiServerState(
        status: .stopped,
        version: LanguageManager.tr("未检测到"),
        port: port
      )
    }

    return KimiServerState(
      status: .running,
      version: version,
      port: port
    )
  }

  /// 探测本地 Kimi Web 服务，返回 server 版本号；端口不可达（服务未运行）时返回 nil
  private func fetchKimiServerVersion(port: Int) async -> String? {
    guard let url = URL(string: "http://127.0.0.1:\(port)/api/v1/meta") else {
      return nil
    }

    struct MetaResponse: Decodable {
      struct MetaData: Decodable {
        let server_version: String
      }
      let code: Int
      let data: MetaData
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        return nil
      }
      let meta = try JSONDecoder().decode(MetaResponse.self, from: data)
      let version = meta.data.server_version.trimmingCharacters(in: .whitespacesAndNewlines)
      return version.isEmpty ? LanguageManager.tr("未检测到") : version
    } catch {
      return nil
    }
  }

  func loadKimiVersion() async {
    let version = await detectKimiCLIVersion()
    await MainActor.run {
      kimiVersion = version
    }
  }

  func checkForKimiCLIUpdate() async {
    guard !isCheckingUpdate else { return }
    await MainActor.run {
      isCheckingUpdate = true
    }

    let current = await detectKimiCLIVersion()

    await MainActor.run {
      kimiVersion = current
    }

    guard current != LanguageManager.tr("未检测到") else {
      await MainActor.run {
        isCheckingUpdate = false
      }
      return
    }

    let (latest, _) = await fetchLatestKimiVersion()
    guard let latest = latest else {
      await MainActor.run {
        isCheckingUpdate = false
      }
      return
    }

    let currentNormalized = normalizeVersion(current)
    let latestNormalized = normalizeVersion(latest)
    let hasUpdate = compareVersions(currentNormalized, latestNormalized) == .orderedAscending

    // 检测到有新版本时，按版本号精确抓取对应 release notes，避免缓存与版本不匹配
    let notes = hasUpdate ? await fetchKimiReleaseNotes(forVersion: latest) : nil

    await MainActor.run {
      cachedKimiLatestVersion = latest
      isCheckingUpdate = false

      if hasUpdate {
        // 如果还在"稍后提醒"的延迟期内，不设置 pendingUpdateVersion，也不发通知
        let now = Date().timeIntervalSince1970
        guard now >= snoozedKimiUpdateUntil else {
          return
        }

        // 避免重复通知：只有首次发现该版本时才发送通知
        if pendingUpdateVersion != latest {
          pendingUpdateVersion = latest
          cachedKimiReleaseNotes = notes ?? ""
          pendingReleaseNotes = notes
          snoozedKimiUpdateUntil = 0
          sendUpdateNotification(version: latest)
        }
      } else {
        // 本地已经是最新版，清空待更新状态和延迟记录
        pendingUpdateVersion = nil
        snoozedKimiUpdateUntil = 0
      }
    }
  }

  func checkCachedKimiUpdate() {
    guard !cachedKimiLatestVersion.isEmpty,
      kimiVersion != LanguageManager.tr("未检测到"), kimiVersion != LanguageManager.tr("检测中…")
    else { return }

    let currentNormalized = normalizeVersion(kimiVersion)
    let cachedNormalized = normalizeVersion(cachedKimiLatestVersion)

    guard !currentNormalized.isEmpty, !cachedNormalized.isEmpty else { return }

    if compareVersions(currentNormalized, cachedNormalized) == .orderedAscending {
      // 如果还在延迟提醒期内，不弹窗
      let now = Date().timeIntervalSince1970
      guard now >= snoozedKimiUpdateUntil else { return }

      if pendingUpdateVersion != cachedKimiLatestVersion {
        pendingUpdateVersion = cachedKimiLatestVersion
        pendingReleaseNotes = cachedKimiReleaseNotes.isEmpty ? nil : cachedKimiReleaseNotes
        // 再次弹出时清空延迟记录
        snoozedKimiUpdateUntil = 0
      }
    } else {
      // 本地已经是最新版，清空待更新状态和延迟记录
      pendingUpdateVersion = nil
      snoozedKimiUpdateUntil = 0
    }
  }

  func loadKimiReleaseNotesIfNeeded() async {
    guard pendingReleaseNotes == nil || pendingReleaseNotes!.isEmpty else { return }

    let (changelog, _) = await fetchLatestChineseChangelog()
    await MainActor.run {
      if let changelog = changelog {
        pendingReleaseNotes = changelog.notes
        cachedKimiReleaseNotes = changelog.notes
      }
    }
  }

  private func sendUpdateNotification(version: String) {
    let content = UNMutableNotificationContent()
    content.title = LanguageManager.tr("KimiCode 有新版本")
    content.body = LanguageManager.tr("KimiCode %@ 已发布，点击更新。", arguments: [version])
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "kimi-code-update-\(version)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func detectKimiCLIVersion() async -> String {
    let result = await runKimiCommand(arguments: ["--version"])
    let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    return output.isEmpty || output.contains("No such file") ? LanguageManager.tr("未检测到") : output
  }

  private func runKimiCommand(arguments: [String]) async -> (output: String, exitCode: Int32) {
    return await Task.detached(priority: .utility) {
      let home = FileManager.default.homeDirectoryForCurrentUser.path
      let candidates = [
        "kimi",
        "\(home)/.kimi-code/bin/kimi",
        "\(home)/.kimi/bin/kimi",
        "/usr/local/bin/kimi",
        "/opt/homebrew/bin/kimi",
      ]

      for kimiPath in candidates {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        let argsString = arguments.map { "\($0)" }.joined(separator: " ")
        task.arguments = ["-lc", "\(kimiPath) \(argsString)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
          try task.run()
          task.waitUntilExit()
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          let output = String(data: data, encoding: .utf8) ?? ""
          let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

          if task.terminationStatus == 0 {
            return (trimmed, 0)
          }

          let lower = trimmed.lowercased()
          if lower.contains("no such file") || lower.contains("command not found")
            || lower.contains("permission denied")
          {
            continue
          }

          return (trimmed, task.terminationStatus)
        } catch {
          continue
        }
      }
      return ("", -1)
    }.value
  }

  private func kimiErrorDescription(_ error: QuotaError) -> String {
    switch error {
    case .invalidKeyFormat:
      return LanguageManager.tr("API Key 格式错误，应以 sk-kimi- 开头")
    case .invalidURL:
      return LanguageManager.tr("请求地址无效")
    case .networkError(let msg):
      return LanguageManager.tr("网络错误：%@", arguments: [msg])
    case .httpError(let code, let msg):
      return LanguageManager.tr("Kimi API 返回错误（%1$@）：%2$@", arguments: ["\(code)", msg])
    case .invalidResponse:
      return LanguageManager.tr("无法解析 API 返回数据")
    }
  }
}

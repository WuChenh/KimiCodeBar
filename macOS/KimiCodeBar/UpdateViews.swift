import AppKit
import SwiftUI

// MARK: - 中文更新日志抓取

func fetchLatestKimiVersion() async -> (version: String?, error: String?) {
  let url = URL(string: "https://moonshotai.github.io/kimi-code/zh/release-notes/changelog.md")!

  // 先尝试 Range 请求，只拿前 4KB 快速解析版本号
  var rangeRequest = URLRequest(url: url)
  rangeRequest.setValue("KimiCodeBar/\(appVersion())", forHTTPHeaderField: "User-Agent")
  rangeRequest.setValue("bytes=0-4095", forHTTPHeaderField: "Range")
  rangeRequest.timeoutInterval = 10

  do {
    let (data, response) = try await URLSession.shared.data(for: rangeRequest)
    if let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 || httpResponse.statusCode == 206,
      let text = String(data: data, encoding: .utf8),
      let version = parseChineseChangelog(text)?.version
    {
      return (version, nil)
    }
    // Range 请求成功但没能解析出版本号，继续回退到完整请求
  } catch {
    // Range 请求失败，继续回退到完整请求
  }

  // 回退：下载完整日志并解析版本号
  var fullRequest = URLRequest(url: url)
  fullRequest.setValue("KimiCodeBar/\(appVersion())", forHTTPHeaderField: "User-Agent")
  fullRequest.timeoutInterval = 20

  do {
    let (data, response) = try await URLSession.shared.data(for: fullRequest)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
      return (nil, LanguageManager.tr("版本接口返回异常状态码：%@", arguments: ["\(statusCode)"]))
    }
    guard let text = String(data: data, encoding: .utf8) else {
      return (nil, LanguageManager.tr("版本接口返回内容无法解析"))
    }
    guard let version = parseChineseChangelog(text)?.version else {
      return (nil, LanguageManager.tr("版本接口返回内容中未找到版本号"))
    }
    return (version, nil)
  } catch {
    return (nil, LanguageManager.tr("版本接口请求失败：%@", arguments: [error.localizedDescription]))
  }
}

func fetchLatestChineseChangelog() async -> (
  value: (version: String, notes: String)?, error: String?
) {
  let url = URL(string: "https://moonshotai.github.io/kimi-code/zh/release-notes/changelog.md")!
  var request = URLRequest(url: url)
  request.setValue("KimiCodeBar/\(appVersion())", forHTTPHeaderField: "User-Agent")
  request.timeoutInterval = 20

  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
      return (nil, LanguageManager.tr("日志接口返回异常状态码：%@", arguments: ["\(statusCode)"]))
    }
    guard let text = String(data: data, encoding: .utf8) else {
      return (nil, LanguageManager.tr("日志接口返回内容无法解析"))
    }
    guard let result = parseChineseChangelog(text) else {
      return (nil, LanguageManager.tr("日志接口返回内容中未找到版本信息"))
    }
    return (result, nil)
  } catch {
    return (nil, LanguageManager.tr("日志接口请求失败：%@", arguments: [error.localizedDescription]))
  }
}

func parseChineseChangelog(_ text: String) -> (version: String, notes: String)? {
  let lines = text.components(separatedBy: .newlines)

  // 找到第一个版本标题，例如：## 0.23.5（2026-07-10）
  var startIndex: Int?
  var version: String?

  for (i, line) in lines.enumerated() {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("## ") else { continue }

    let content = String(trimmed.dropFirst(3))
    if let parenRange = content.range(of: "（") {
      version = String(content[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    } else {
      version = content
    }
    startIndex = i
    break
  }

  guard let start = startIndex, let ver = version else { return nil }

  // 收集到下一个 ## 标题之前
  var endIndex = lines.count
  for i in (start + 1)..<lines.count {
    let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("## ") {
      endIndex = i
      break
    }
  }

  let sectionLines = Array(lines[start..<endIndex])

  var formatted: [String] = []
  for line in sectionLines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { continue }

    if trimmed.hasPrefix("## ") {
      continue  // 跳过版本标题
    } else if trimmed.hasPrefix("### ") {
      continue  // 跳过分类大标题
    } else if trimmed.hasPrefix("* ") {
      formatted.append("• " + String(trimmed.dropFirst(2)))
    } else {
      formatted.append(trimmed)
    }
  }

  return (ver, formatted.joined(separator: "\n"))
}

func fetchChineseChangelogEntries(maxCount: Int = 10) async -> [(version: String, notes: String)] {
  let url = URL(string: "https://moonshotai.github.io/kimi-code/zh/release-notes/changelog.md")!
  var request = URLRequest(url: url)
  request.setValue("KimiCodeBar/\(appVersion())", forHTTPHeaderField: "User-Agent")
  request.timeoutInterval = 20

  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      return []
    }
    guard let text = String(data: data, encoding: .utf8) else { return [] }
    return parseChineseChangelogEntries(text, maxCount: maxCount)
  } catch {
    return []
  }
}

func parseChineseChangelogEntries(_ text: String, maxCount: Int = 10) -> [(
  version: String, notes: String
)] {
  let lines = text.components(separatedBy: .newlines)

  // 收集所有 ## 版本标题的位置和版本号
  var headings: [(index: Int, version: String)] = []
  for (i, line) in lines.enumerated() {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("## ") else { continue }

    let content = String(trimmed.dropFirst(3))
    let version: String
    if let parenRange = content.range(of: "（") {
      version = String(content[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    } else {
      version = content
    }
    headings.append((i, version))
  }

  var entries: [(version: String, notes: String)] = []
  for (idx, heading) in headings.enumerated() {
    let start = heading.index
    let end = idx + 1 < headings.count ? headings[idx + 1].index : lines.count
    let sectionLines = Array(lines[start..<end])

    var formatted: [String] = []
    for line in sectionLines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }

      if trimmed.hasPrefix("## ") {
        continue  // 跳过版本标题
      } else if trimmed.hasPrefix("### ") {
        continue  // 跳过分类大标题
      } else if trimmed.hasPrefix("* ") {
        formatted.append("• " + String(trimmed.dropFirst(2)))
      } else {
        formatted.append(trimmed)
      }
    }

    let notes = formatted.joined(separator: "\n")
    entries.append((heading.version, notes))
    if entries.count >= maxCount { break }
  }

  return entries
}

/// 从中文 changelog 中抓取指定版本的 release notes。
/// 版本号会先做 normalize，因此 "0.28.0" 与 "v0.28.0" 都能匹配。
func fetchKimiReleaseNotes(forVersion version: String) async -> String? {
  let normalizedTarget = normalizeVersion(version)
  let entries = await fetchChineseChangelogEntries(maxCount: 20)
  return entries.first { normalizeVersion($0.version) == normalizedTarget }?.notes
}

func normalizeVersion(_ version: String) -> String {
  let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)

  // 优先提取 package@x.x.x 后面的版本号
  if let atRange = trimmed.range(of: "@", options: .backwards) {
    let suffix = String(trimmed[atRange.upperBound...])
    return extractSemver(suffix) ?? suffix
  }

  // 否则从字符串里提取第一个 semver
  return extractSemver(trimmed) ?? trimmed
}

func extractSemver(_ text: String) -> String? {
  let pattern = #"(\d+\.\d+\.\d+(?:\.\d+)?)"#
  guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
  let range = NSRange(text.startIndex..., in: text)
  guard let match = regex.firstMatch(in: text, range: range) else { return nil }
  return String(text[Range(match.range, in: text)!])
}

func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
  let left = normalizeVersion(lhs).split(separator: ".").compactMap { Int($0) }
  let right = normalizeVersion(rhs).split(separator: ".").compactMap { Int($0) }

  for i in 0..<max(left.count, right.count) {
    let l = i < left.count ? left[i] : 0
    let r = i < right.count ? right[i] : 0
    if l < r { return .orderedAscending }
    if l > r { return .orderedDescending }
  }
  return .orderedSame
}

func appVersion() -> String {
  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
}

func formatCurrency(_ yuan: Double, currency: String) -> String {
  let symbol: String
  switch currency.uppercased() {
  case "CNY": symbol = "¥"
  case "USD": symbol = "$"
  case "EUR": symbol = "€"
  default: symbol = currency.uppercased()
  }
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.minimumFractionDigits = 0
  formatter.maximumFractionDigits = 2
  let amount = formatter.string(from: NSNumber(value: yuan)) ?? String(format: "%.2f", yuan)
  return "\(symbol)\(amount)"
}

// MARK: - GitHub Release 检查

struct GitHubRelease: Decodable {
  let tagName: String

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
  }
}

func fetchLatestGitHubRelease(owner: String, repo: String) async -> (
  version: String?, error: String?
) {
  let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
  var request = URLRequest(url: url)
  request.setValue("KimiCodeBar/\(appVersion())", forHTTPHeaderField: "User-Agent")
  request.timeoutInterval = 20

  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
      return (nil, LanguageManager.tr("GitHub Release 接口返回异常状态码：%@", arguments: ["\(statusCode)"]))
    }
    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
    return (normalizeVersion(release.tagName), nil)
  } catch let decodingError as DecodingError {
    return (
      nil,
      LanguageManager.tr(
        "GitHub Release 接口返回数据解析失败：%@", arguments: [decodingError.localizedDescription])
    )
  } catch {
    return (
      nil, LanguageManager.tr("GitHub Release 接口请求失败：%@", arguments: [error.localizedDescription])
    )
  }
}

// MARK: - 更新弹窗

struct UpdateAlertView: View {
  let currentVersion: String
  let newVersion: String
  let onDismiss: () -> Void
  let onInstall: () -> Void
  @StateObject private var model = KimiCodeBarModel.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 标题栏
      LText("新版本的 KimiCode 已经发布")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.kimiTextPrimary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)

      // 内容
      VStack(alignment: .leading, spacing: 12) {
        LText("KimiCode %1$@ 可供下载，您现在的版本是 %2$@。要现在下载吗？", newVersion, currentVersion)
          .font(.system(size: 13))
          .foregroundStyle(.kimiTextSecondary)

        VStack(alignment: .leading, spacing: 10) {
          Text("KimiCode \(newVersion)")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.kimiTextPrimary)

          LText("更新内容")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.kimiTextPrimary)

          ScrollView {
            if model.pendingReleaseNotes == nil || model.pendingReleaseNotes!.isEmpty {
              HStack(spacing: 6) {
                ProgressView()
                  .controlSize(.small)
                  .scaleEffect(0.7)
                LText("正在加载更新内容…")
                  .font(.system(size: 12))
                  .foregroundStyle(.kimiTextSecondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 20)
            } else {
              Text(model.pendingReleaseNotes!)
                .font(.system(size: 12))
                .foregroundStyle(.kimiTextSecondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .frame(maxHeight: 180)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.kimiTextPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding(.horizontal, 24)

      Spacer(minLength: 24)

      // 底部按钮
      HStack(spacing: 12) {
        Button(action: onDismiss) {
          LText("稍后再说")
            .frame(minWidth: 80)
        }
        .buttonStyle(.bordered)
        .cursor(.pointingHand)

        Spacer()

        Button(action: onInstall) {
          LText("安装更新")
            .frame(minWidth: 80)
        }
        .buttonStyle(.borderedProminent)
        .tint(.kimiBlue)
        .cursor(.pointingHand)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 20)
    }
    .frame(width: 400)
    .background(.ultraThinMaterial)
    .onAppear {
      Task {
        await model.loadKimiReleaseNotesIfNeeded()
      }
    }
  }
}

// MARK: - App 自身更新提示

struct AppUpdateAlertView: View {
  let currentVersion: String
  let newVersion: String
  let onIgnore: () -> Void
  let onViewUpdate: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 标题栏
      LText("发现新版本")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.kimiTextPrimary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)

      // 内容
      LText("KimiCodeBar %1$@ 已发布，您现在的版本是 %2$@。", newVersion, currentVersion)
        .font(.system(size: 13))
        .foregroundStyle(.kimiTextSecondary)
        .padding(.horizontal, 24)

      Spacer(minLength: 24)

      // 底部按钮
      HStack(spacing: 12) {
        Button(action: onIgnore) {
          LText("忽略本次更新")
            .frame(minWidth: 80)
        }
        .buttonStyle(.bordered)
        .cursor(.pointingHand)

        Spacer()

        Button(action: onViewUpdate) {
          LText("查看更新")
            .frame(minWidth: 80)
        }
        .buttonStyle(.borderedProminent)
        .tint(.kimiBlue)
        .cursor(.pointingHand)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 20)
    }
    .frame(width: 360)
    .background(.ultraThinMaterial)
  }
}

// MARK: - 更新日志气泡

struct UpdateLogView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var entries: [(version: String, notes: String)] = []
  @State private var isLoading = true
  @State private var isHoveredCloseButton = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 顶部标题
      HStack(spacing: 12) {
        LText("近期更新日志")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()

        Button(action: { dismiss() }) {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHoveredCloseButton ? .kimiTextPrimary : .kimiTextSecondary)
            .frame(width: 24, height: 24)
            .background(
              isHoveredCloseButton
                ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
            )
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredCloseButton = $0 }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // 优雅分割线
      Divider()
        .background(Color.kimiTextPrimary.opacity(0.10))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

      if isLoading {
        ProgressView()
          .controlSize(.small)
          .frame(maxWidth: .infinity, minHeight: 180)
      } else if entries.isEmpty {
        LText("暂无更新记录。")
          .font(.system(size: 12))
          .foregroundStyle(.kimiTextSecondary)
          .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            ForEach(entries.indices, id: \.self) { index in
              let entry = entries[index]
              VStack(alignment: .leading, spacing: 6) {
                Text(entry.version)
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(.kimiTextPrimary)

                Text(entry.notes)
                  .font(.system(size: 11))
                  .foregroundStyle(.kimiTextSecondary)
                  .lineSpacing(3)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
        }
        .frame(maxHeight: 320)
      }

      Spacer(minLength: 16)
    }
    .frame(width: 320)
    .background(.ultraThinMaterial)
    .onAppear {
      load()
    }
  }

  private func load() {
    Task {
      entries = await fetchChineseChangelogEntries(maxCount: 10)
      isLoading = false
    }
  }
}

// MARK: - 更新错误提示气泡

struct UpdateErrorPopoverView: View {
  let errorMessage: String
  @Environment(\.dismiss) private var dismiss
  @State private var isHoveredCloseButton = false
  @State private var isHoveredCopyButton = false
  @State private var isHoveredIssueButton = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 顶部标题
      HStack(spacing: 12) {
        LText("检查更新失败")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()

        Button(action: { dismiss() }) {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHoveredCloseButton ? .kimiTextPrimary : .kimiTextSecondary)
            .frame(width: 24, height: 24)
            .background(
              isHoveredCloseButton
                ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
            )
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredCloseButton = $0 }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // 优雅分割线
      Divider()
        .background(Color.kimiTextPrimary.opacity(0.10))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

      // 错误信息
      ScrollView {
        Text(errorMessage)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.kimiTextSecondary)
          .lineSpacing(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 120)
      .padding(.horizontal, 16)

      // 操作按钮
      HStack(spacing: 10) {
        Button(action: {
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(errorMessage, forType: .string)
        }) {
          HStack(spacing: 4) {
            Image(systemName: "doc.on.doc")
              .font(.system(size: 10))
            LText("复制错误信息")
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundStyle(isHoveredCopyButton ? .kimiTextPrimary : .kimiTextSecondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            isHoveredCopyButton
              ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
          )
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredCopyButton = $0 }

        Button(action: {
          let body = LanguageManager.tr(
            "## 检查更新接口错误反馈\n\n错误信息：\n```\n%1$@\n```\n\n请补充以下信息：\n- 当前 KimiCodeBar 版本：%2$@\n- 当前网络环境：\n- 问题描述：\n",
            arguments: [errorMessage, appVersion()])
          var components = URLComponents(
            string: "https://github.com/WuChenh/KimiCodeBar/issues/new")!
          components.queryItems = [
            URLQueryItem(name: "title", value: LanguageManager.tr("检查更新接口错误反馈")),
            URLQueryItem(name: "body", value: body),
          ]
          if let url = components.url {
            dismissMenuBarPanel()
            NSWorkspace.shared.open(url)
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "exclamationmark.bubble")
              .font(.system(size: 10))
            LText("去 GitHub 反馈")
              .font(.system(size: 12, weight: .medium))
          }
          .foregroundStyle(isHoveredIssueButton ? .kimiTextPrimary : .kimiTextSecondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            isHoveredIssueButton
              ? Color.kimiTextPrimary.opacity(0.14) : Color.kimiTextPrimary.opacity(0.08)
          )
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredIssueButton = $0 }

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .frame(width: 320)
    .background(.ultraThinMaterial)
  }
}

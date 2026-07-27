import AppKit
import SwiftUI

// MARK: - GitHub 社区开源卡片

struct GitHubCommunityCard: View {
  @State private var isHoveredRepo = false
  @State private var isHoveredIssue = false

  private let repoURL = URL(string: "https://github.com/WuChenh/KimiCodeBar")!
  private let issuesURL = URL(string: "https://github.com/WuChenh/KimiCodeBar/issues")!

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 18) {
        ZStack {
          Circle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 54, height: 54)

          Image("github-icon")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
            .foregroundStyle(.white)
        }

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            LText("社区开源版")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(.white)

            Text("Open Source")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.white.opacity(0.85))
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(Color.white.opacity(0.18))
              .clipShape(RoundedRectangle(cornerRadius: 5))
          }

          LText("基于 xifandev/KimiCodeBar 的分支版本，面向 macOS 原生体验全面重构。")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)

          LText("KimiCodeBar 完全开源，代码公开透明。欢迎 Star、提交 Issue 或参与共建，让这款工具变得更好。")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 18)

      HStack(spacing: 12) {
        Button(action: { NSWorkspace.shared.open(repoURL) }) {
          HStack(spacing: 6) {
            Image("github-icon")
              .renderingMode(.template)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 14, height: 14)

            LText("查看仓库")
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundStyle(isHoveredRepo ? Color.kimiBlue : .white)
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(isHoveredRepo ? Color.white : Color.white.opacity(0.16))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredRepo = $0 }

        Button(action: { NSWorkspace.shared.open(issuesURL) }) {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.bubble")
              .font(.system(size: 13, weight: .semibold))

            LText("提交反馈")
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(isHoveredIssue ? Color.white.opacity(0.24) : Color.white.opacity(0.14))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.white.opacity(0.25), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHoveredIssue = $0 }

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(
          LinearGradient(
            gradient: Gradient(colors: [
              Color(red: 0.18, green: 0.38, blue: 0.82),
              Color(red: 0.35, green: 0.22, blue: 0.72),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    )
    .shadow(color: Color.kimiBlue.opacity(0.22), radius: 18, x: 0, y: 8)
  }
}

// MARK: - 特性亮点卡片

struct FeatureHighlightCard: View {
  let icon: String
  let iconColor: Color
  let title: String
  let description: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(iconColor.opacity(0.12))
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(iconColor)
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.kimiTextPrimary)

        Text(description)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.kimiTextSecondary)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct StatusTag: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}

struct LoadingRing: View {
  @State private var rotation: Double = 0

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.75)
      .stroke(
        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
      )
      .foregroundStyle(Color.kimiTextPrimary.opacity(0.7))
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
  }
}

struct ErrorMessageView: View {
  let message: String
  @State private var isHoveredCopy = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .font(.system(size: 12))
        .padding(.top, 2)

      Text(message)
        .font(.system(size: 11))
        .foregroundStyle(.orange.opacity(0.9))
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 4)

      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
      } label: {
        Image(systemName: "doc.on.doc")
          .font(.system(size: 11))
      }
      .buttonStyle(.plain)
      .foregroundStyle(isHoveredCopy ? .kimiTextPrimary : .kimiTextSecondary)
      .help(Text(LanguageManager.tr("复制错误信息")))
      .cursor(.pointingHand)
      .onHover { isHoveredCopy = $0 }
      .padding(.top, 2)
    }
    .padding(8)
    .background(Color.orange.opacity(0.10))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

// MARK: - 工具扩展

extension View {
  func cursor(_ cursor: NSCursor) -> some View {
    self.onHover { hovering in
      if hovering {
        cursor.set()
      } else {
        NSCursor.arrow.set()
      }
    }
  }
}

// MARK: - 多平台余额卡片

struct BalanceCard: View {
  let providerName: String
  let balance: ProviderBalance
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        LText("%@ 余额", providerName)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)

        Spacer()

        Text(balance.isAvailable ? LanguageManager.tr("可用") : LanguageManager.tr("不可用"))
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(balance.isAvailable ? .green : .red)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background((balance.isAvailable ? Color.green : Color.red).opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(balance.currency == "CNY" ? "¥" : "$")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(.kimiTextSecondary)
        Text(String(format: "%.2f", balance.totalBalance))
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundStyle(.kimiTextPrimary)
          .monospacedDigit()
      }

      if balance.grantedBalance > 0 || balance.toppedUpBalance > 0 {
        VStack(spacing: 4) {
          if balance.grantedBalance > 0 {
            HStack {
              LText("赠送余额")
                .font(.system(size: 11))
                .foregroundStyle(.kimiTextTertiary)
              Spacer()
              Text(String(format: "%.2f", balance.grantedBalance))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.kimiTextSecondary)
            }
          }
          if balance.toppedUpBalance > 0 {
            HStack {
              LText("充值余额")
                .font(.system(size: 11))
                .foregroundStyle(.kimiTextTertiary)
              Spacer()
              Text(String(format: "%.2f", balance.toppedUpBalance))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.kimiTextSecondary)
            }
          }
        }
        .padding(10)
        .background(Color.kimiTextPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

struct BalanceLoadingCard: View {
  let providerName: String

  var body: some View {
    VStack(spacing: 14) {
      LText("%@ 余额", providerName)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.kimiTextPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      LoadingRing()
        .frame(width: 28, height: 28)
        .frame(maxWidth: .infinity)
    }
    .padding(14)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

struct BalanceErrorCard: View {
  let providerName: String
  let message: String
  let consoleURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        LText("%@ 余额", providerName)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)
        Spacer()
      }

      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(.red)

      if let url = consoleURL {
        Button(action: { NSWorkspace.shared.open(url) }) {
          LText("去控制台查看")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.kimiBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.kimiBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

struct BalanceEmptyCard: View {
  let providerName: String
  let consoleURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        LText("%@ 余额", providerName)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.kimiTextPrimary)
        Spacer()
      }

      LText("请在设置中配置 API Key")
        .font(.system(size: 12))
        .foregroundStyle(.kimiTextSecondary)

      if let url = consoleURL {
        Button(action: { NSWorkspace.shared.open(url) }) {
          LText("获取 API Key")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.kimiBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.kimiBlue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

// MARK: - 登录方式

enum LoginMethod: String, CaseIterable, Identifiable {
  case oauth
  case token

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .oauth: return LanguageManager.tr("授权登录")
    case .token: return LanguageManager.tr("Token 登录")
    }
  }

  var subtitle: String {
    switch self {
    case .oauth: return LanguageManager.tr("浏览器一键授权")
    case .token: return LanguageManager.tr("手动填写 API Key")
    }
  }

  var iconName: String {
    switch self {
    case .oauth: return "person.badge.key"
    case .token: return "key"
    }
  }
}

// MARK: - 本地服务状态

enum KimiServerStatus: Equatable {
  case unknown
  case running
  case stopped
  case error(String)
}

struct KimiServerState: Equatable {
  var status: KimiServerStatus = .unknown
  var version: String = ""
  var port: Int = 58627
}

enum KimiServerOperation: Equatable {
  case none
  case starting
  case stopping
  case restarting
}

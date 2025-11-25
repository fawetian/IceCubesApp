/*
 * AccountPopoverView.swift
 * IceCubesApp - 账户弹出卡片视图
 *
 * 文件功能：
 * 在鼠标悬停时显示账户预览卡片（类似 Twitter 的用户卡片）。
 *
 * 核心职责：
 * - 显示账户头像、横幅、名称和简介
 * - 展示关注者、关注中、帖子数量统计
 * - 支持自动消失和悬停保持
 * - 提供自定义对齐和布局
 *
 * 技术要点：
 * - onHover 监听鼠标悬停
 * - Task 防抖延迟显示/隐藏
 * - @Binding 状态绑定控制显示
 * - 自定义对齐引导线（bottomAvatar）
 * - ViewModifier 封装弹出逻辑
 *
 * 使用场景：
 * - 时间线中的账户名称悬停
 * - 账户列表中的快速预览
 *
 * 依赖关系：
 * - Env: Theme、UserPreferences
 * - Models: Account
 * - NukeUI: LazyImage
 */

import Env
import Models
import Nuke
import NukeUI
import SwiftUI

/// 账户弹出卡片视图。
///
/// 显示账户的详细预览信息，包括头像、横幅、统计数据和简介。
@MainActor
struct AccountPopoverView: View {
  /// 要展示的账户。
  let account: Account
  /// 主题设置（注意：使用 @Environment 会导致预览崩溃）。
  let theme: Theme
  /// 头像配置。
  private let config: AvatarView.FrameConfig = .account

  /// 控制弹出窗口显示状态。
  @Binding var showPopup: Bool
  /// 是否自动消失。
  @Binding var autoDismiss: Bool
  /// 控制自动消失的任务。
  @Binding var toggleTask: Task<Void, Never>

  /// 视图主体。
  var body: some View {
    VStack(alignment: .leading) {
      LazyImage(
        request: ImageRequest(url: account.header)
      ) { state in
        if let image = state.image {
          image.resizable().scaledToFill()
        }
      }
      .frame(width: 500, height: 150)
      .clipped()
      .background(theme.secondaryBackgroundColor)

      VStack(alignment: .leading) {
        HStack(alignment: .bottomAvatar) {
          AvatarImage(account.avatar, config: adaptiveConfig)
          Spacer()
          makeCustomInfoLabel(title: "account.following", count: account.followingCount ?? 0)
          makeCustomInfoLabel(title: "account.posts", count: account.statusesCount ?? 0)
          makeCustomInfoLabel(title: "account.followers", count: account.followersCount ?? 0)
        }
        .frame(height: adaptiveConfig.height / 2, alignment: .bottom)

        EmojiTextApp(.init(stringValue: account.safeDisplayName), emojis: account.emojis)
          .font(.headline)
          .foregroundColor(theme.labelColor)
          .emojiText.size(Font.scaledHeadlineFont.emojiSize)
          .emojiText.baselineOffset(Font.scaledHeadlineFont.emojiBaselineOffset)
          .accessibilityAddTraits(.isHeader)
          .help(account.safeDisplayName)

        Text("@\(account.acct)")
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .accessibilityRespondsToUserInteraction(false)
          .help("@\(account.acct)")

        HStack(spacing: 4) {
          Image(systemName: "calendar")
            .accessibilityHidden(true)
          Text("account.joined")
          Text(account.createdAt.asDate, style: .date)
        }
        .foregroundStyle(.secondary)
        .font(.footnote)
        .accessibilityElement(children: .combine)

        EmojiTextApp(account.note, emojis: account.emojis, lineLimit: 5)
          .font(.body)
          .emojiText.size(Font.scaledFootnoteFont.emojiSize)
          .emojiText.baselineOffset(Font.scaledFootnoteFont.emojiBaselineOffset)
          .padding(.top, 3)
      }
      .padding([.leading, .trailing, .bottom])
    }
    .frame(width: 500)
    .onAppear {
      toggleTask.cancel()
      toggleTask = Task {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
        guard !Task.isCancelled else { return }
        if autoDismiss {
          showPopup = false
        }
      }
    }
    .onHover { hovering in
      toggleTask.cancel()
      toggleTask = Task {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 2)
        guard !Task.isCancelled else { return }
        if hovering {
          autoDismiss = false
        } else {
          showPopup = false
          autoDismiss = true
        }
      }
    }
  }

  /// 创建自定义信息标签（显示统计数字和标题）。
  ///
  /// - Parameters:
  ///   - title: 标签标题。
  ///   - count: 数量值。
  ///   - needsBadge: 是否显示红点徽章。
  /// - Returns: 信息标签视图。
  @MainActor
  private func makeCustomInfoLabel(title: LocalizedStringKey, count: Int, needsBadge: Bool = false)
    -> some View
  {
    VStack {
      Text(count, format: .number.notation(.compactName))
        .font(.scaledHeadline)
        .foregroundColor(theme.tintColor)
        .overlay(alignment: .trailing) {
          if needsBadge {
            Circle()
              .fill(Color.red)
              .frame(width: 9, height: 9)
              .offset(x: 12)
          }
        }
      Text(title)
        .font(.scaledFootnote)
        .foregroundStyle(.secondary)
        .alignmentGuide(
          .bottomAvatar,
          computeValue: { dimension in
            dimension[.firstTextBaseline]
          })
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue("\(count)")
  }

  /// 适应性头像配置（根据主题调整圆角）。
  private var adaptiveConfig: AvatarView.FrameConfig {
    let cornerRadius: CGFloat =
      if config == .badge || theme.avatarShape == .circle {
        config.width / 2
      } else {
        config.cornerRadius
      }
    return AvatarView.FrameConfig(
      width: config.width, height: config.height, cornerRadius: cornerRadius)
  }
}

/// 底部头像对齐引导线（用于对齐统计数字和头像底部）。
private enum BottomAvatarAlignment: AlignmentID {
  static func defaultValue(in context: ViewDimensions) -> CGFloat {
    context.height
  }
}

extension VerticalAlignment {
  /// 自定义垂直对齐：底部头像对齐。
  static let bottomAvatar = VerticalAlignment(BottomAvatarAlignment.self)
}

/// 账户弹出卡片修饰器。
///
/// 为视图添加悬停显示账户卡片的功能。
public struct AccountPopoverModifier: ViewModifier {
  /// 全局主题。
  @Environment(Theme.self) private var theme
  /// 用户偏好设置（控制是否启用弹出卡片）。
  @Environment(UserPreferences.self) private var userPreferences

  /// 是否显示弹出窗口。
  @State private var showPopup = false
  /// 是否自动消失。
  @State private var autoDismiss = true
  /// 控制延迟显示/隐藏的任务。
  @State private var toggleTask: Task<Void, Never> = Task {}

  /// 要展示的账户。
  let account: Account

  /// 修饰器主体（应用到目标视图）。
  public func body(content: Content) -> some View {
    if !userPreferences.showAccountPopover {
      return AnyView(content)
    }

    return AnyView(
      content
        .onHover { hovering in
          if hovering {
            toggleTask.cancel()
            toggleTask = Task {
              try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 2)
              guard !Task.isCancelled else { return }
              if !showPopup {
                showPopup = true
              }
            }
          } else {
            if !showPopup {
              toggleTask.cancel()
            }
          }
        }
        .hoverEffect(.lift)
        .popover(isPresented: $showPopup) {
          AccountPopoverView(
            account: account,
            theme: theme,
            showPopup: $showPopup,
            autoDismiss: $autoDismiss,
            toggleTask: $toggleTask
          )
        })
  }

  /// 初始化方法。
  ///
  /// - Parameter account: 要展示的账户。
  init(_ account: Account) {
    self.account = account
  }
}

extension View {
  /// 为视图添加账户弹出卡片功能。
  ///
  /// - Parameter account: 要展示的账户。
  /// - Returns: 应用了弹出卡片修饰器的视图。
  public func accountPopover(_ account: Account) -> some View {
    modifier(AccountPopoverModifier(account))
  }
}

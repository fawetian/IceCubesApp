/*
 * NotificationRowView.swift
 * IceCubesApp - 通知行视图
 *
 * 文件功能：
 * 展示单条通知的行视图，包括头像、图标、主标签和内容。
 *
 * 核心职责：
 * - 根据通知类型显示不同的图标或头像
 * - 显示通知的主标签（谁做了什么）
 * - 显示通知内容（帖子、关注请求等）
 * - iOS 26 适配（Liquid Glass 效果）
 * - 无障碍支持
 *
 * 技术要点：
 * - ConsolidatedNotification 合并通知
 * - 条件渲染（单账户显示头像，多账户显示图标）
 * - iOS 26 glassEffect
 * - 子组件组合（Avatar、Icon、MainLabel、Content）
 * - 无障碍合并和操作
 *
 * 使用场景：
 * - 通知列表中的单行
 * - 各种通知类型（提及、关注、点赞、转发等）
 *
 * 依赖关系：
 * - DesignSystem: AvatarView、Theme
 * - Env: RouterPath
 * - Models: ConsolidatedNotification、Account
 * - StatusKit: 状态显示组件
 * - NetworkClient: MastodonClient
 */

import DesignSystem
import EmojiText
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

/// 通知行视图。
///
/// 展示单条合并通知，包括图标/头像、主标签和内容。
@MainActor
struct NotificationRowView: View {
  @Environment(Theme.self) private var theme
  @Environment(\.redactionReasons) private var reasons

  /// 合并通知对象。
  let notification: ConsolidatedNotification
  /// Mastodon 客户端。
  let client: MastodonClient
  /// 路由路径。
  let routerPath: RouterPath
  /// 关注请求列表。
  let followRequests: [Account]

  /// 视图主体。
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if notification.accounts.count == 1 {
        NotificationRowAvatarView(
          account: notification.accounts[0],
          notificationType: notification.type,
          status: notification.status,
          routerPath: routerPath
        )
        .accessibilityHidden(true)
      } else {
        if #available(iOS 26.0, *) {
          NotificationRowIconView(
            type: notification.type,
            status: notification.status,
            showBorder: false
          )
          .frame(
            width: AvatarView.FrameConfig.status.width,
            height: AvatarView.FrameConfig.status.height
          )
          .accessibilityHidden(true)
          .glassEffect(
            .regular.tint(
              notification.type.tintColor(isPrivate: notification.status?.visibility == .direct)))
        } else {
          NotificationRowIconView(
            type: notification.type,
            status: notification.status,
            showBorder: true
          )
          .frame(
            width: AvatarView.FrameConfig.status.width,
            height: AvatarView.FrameConfig.status.height
          )
          .accessibilityHidden(true)
        }
      }
      VStack(alignment: .leading, spacing: 0) {
        NotificationRowMainLabelView(
          notification: notification,
          routerPath: routerPath
        )
        // The main label is redundant for mentions
        .accessibilityHidden(notification.type == .mention)
        .padding(.trailing, -.layoutPadding)
        NotificationRowContentView(
          notification: notification,
          client: client,
          routerPath: routerPath
        )
        .environment(\.isNotificationsTab, true)
        if notification.type == .follow_request,
          followRequests.map(\.id).contains(notification.accounts[0].id)
        {
          FollowRequestButtons(account: notification.accounts[0])
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityActions {
      if notification.type == .follow {
        NotificationRowAccessibilityActionsView(
          accounts: notification.accounts,
          routerPath: routerPath
        )
      }
    }
    .alignmentGuide(.listRowSeparatorLeading) { _ in
      -100
    }
  }
}

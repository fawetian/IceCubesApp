/*
 * AccountAvatarView.swift
 * IceCubesApp - 账户详情头像视图
 *
 * 文件功能：
 * 在账户详情页展示可点击的头像，支持大图预览和支持者徽章。
 *
 * 核心职责：
 * - 显示账户头像（可点击放大）
 * - 为订阅用户显示蓝色认证徽章
 * - 支持无障碍访问
 * - 打开头像大图预览
 *
 * 技术要点：
 * - AvatarView 组件复用
 * - QuickLook 集成（iOS）
 * - openWindow 集成（macOS/visionOS）
 * - 根据头像形状调整徽章位置
 *
 * 使用场景：
 * - 账户详情页头部
 * - 个人资料页面
 *
 * 依赖关系：
 * - DesignSystem: AvatarView
 * - Env: Theme、QuickLook、isSupporter
 * - Models: Account、MediaAttachment
 */

import DesignSystem
import Env
import Models
import SwiftUI

/// 账户详情头像视图。
///
/// 展示可点击的大头像，支持订阅者徽章。
struct AccountAvatarView: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.isSupporter) private var isSupporter: Bool
  @Environment(Theme.self) private var theme
  @Environment(QuickLook.self) private var quickLook

  /// 账户数据。
  let account: Account
  /// 是否为当前用户。
  let isCurrentUser: Bool

  /// 视图主体。
  var body: some View {
    ZStack(alignment: .topTrailing) {
      AvatarView(account.avatar, config: .account)
        .accessibilityLabel("accessibility.tabs.profile.user-avatar.label")

      if isCurrentUser, isSupporter {
        supporterBadge
      }
    }
    .onTapGesture {
      guard account.haveAvatar else { return }
      let attachement = MediaAttachment.imageWith(url: account.avatar)
      #if targetEnvironment(macCatalyst) || os(visionOS)
        openWindow(
          value: WindowDestinationMedia.mediaViewer(
            attachments: [attachement],
            selectedAttachment: attachement))
      #else
        quickLook.prepareFor(
          selectedMediaAttachment: attachement, mediaAttachments: [attachement])
      #endif
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits([.isImage, .isButton])
    .accessibilityHint("accessibility.tabs.profile.user-avatar.hint")
    .accessibilityHidden(account.haveAvatar == false)
  }

  /// 订阅者徽章视图。
  ///
  /// 在头像右上角显示蓝色认证勾选标记。
  private var supporterBadge: some View {
    Image(systemName: "checkmark.seal.fill")
      .resizable()
      .frame(width: 25, height: 25)
      .foregroundColor(theme.tintColor)
      .offset(
        x: theme.avatarShape == .circle ? 0 : 10,
        y: theme.avatarShape == .circle ? 0 : -10
      )
      .accessibilityRemoveTraits(.isSelected)
      .accessibilityLabel("accessibility.tabs.profile.user-avatar.supporter.label")
  }
}

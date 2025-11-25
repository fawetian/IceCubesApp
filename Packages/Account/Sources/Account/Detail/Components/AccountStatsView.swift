/*
 * AccountStatsView.swift
 * IceCubesApp - 账户统计数据视图
 *
 * 文件功能：
 * 在账户详情页展示帖子数、关注数、粉丝数统计按钮。
 *
 * 核心职责：
 * - 显示账户的三个关键统计数据
 * - 提供点击导航功能（跳转到关注/粉丝列表）
 * - 点击帖子数滚动到帖子列表
 * - 显示未读关注请求徽章
 *
 * 技术要点：
 * - 格式化数字显示（紧凑记法）
 * - ScrollViewProxy 滚动控制
 * - RouterPath 导航
 * - 红点徽章提示
 *
 * 使用场景：
 * - 账户详情页统计区域
 * - 个人资料页面
 *
 * 依赖关系：
 * - DesignSystem: Theme
 * - Env: RouterPath、CurrentAccount
 * - Models: Account
 */

import DesignSystem
import Env
import Models
import SwiftUI

/// 账户统计数据视图。
///
/// 展示帖子、关注、粉丝三个统计数据按钮。
struct AccountStatsView: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath
  @Environment(CurrentAccount.self) private var currentAccount

  /// 账户数据。
  let account: Account
  /// 滚动代理（用于滚动到帖子列表）。
  let scrollViewProxy: ScrollViewProxy?

  /// 视图主体。
  var body: some View {
    Group {
      Button {
        withAnimation {
          scrollViewProxy?.scrollTo("status", anchor: .top)
        }
      } label: {
        makeCustomInfoLabel(title: "account.posts", count: account.statusesCount ?? 0)
      }
      .accessibilityHint("accessibility.tabs.profile.post-count.hint")
      .buttonStyle(.borderless)

      Button {
        routerPath.navigate(to: .following(id: account.id))
      } label: {
        makeCustomInfoLabel(title: "account.following", count: account.followingCount ?? 0)
      }
      .accessibilityHint("accessibility.tabs.profile.following-count.hint")
      .buttonStyle(.borderless)

      Button {
        routerPath.navigate(to: .followers(id: account.id))
      } label: {
        makeCustomInfoLabel(
          title: "account.followers",
          count: account.followersCount ?? 0,
          needsBadge: currentAccount.account?.id == account.id
            && !currentAccount.followRequests.isEmpty
        )
      }
      .accessibilityHint("accessibility.tabs.profile.follower-count.hint")
      .buttonStyle(.borderless)
    }
    .offset(y: 20)
  }

  /// 创建自定义统计标签。
  ///
  /// - Parameters:
  ///   - title: 标签标题。
  ///   - count: 数量值。
  ///   - needsBadge: 是否显示红点徽章。
  /// - Returns: 统计标签视图。
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
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue("\(count)")
  }
}

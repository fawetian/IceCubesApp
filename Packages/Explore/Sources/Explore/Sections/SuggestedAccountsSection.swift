/*
 * SuggestedAccountsSection.swift
 * IceCubesApp - 推荐账户区块视图
 *
 * 文件功能：
 * 在探索页展示推荐关注的账户列表（前 3 个）。
 *
 * 核心职责：
 * - 显示最多 3 个推荐账户
 * - 使用 AccountsListRow 渲染账户行
 * - 显示账户关系状态
 * - 提供"查看更多"链接
 * - 支持 visionOS 适配
 *
 * 技术要点：
 * - Section 分组
 * - AccountsListRow 账户行
 * - NavigationLink 导航
 * - 关系状态匹配
 *
 * 使用场景：
 * - ExploreView 的推荐账户区域
 *
 * 依赖关系：
 * - Account: AccountsListRow
 * - DesignSystem: Theme
 * - Env: RouterPath
 * - Models: Account、Relationship
 */

import Account
import DesignSystem
import Env
import Models
import SwiftUI

/// 推荐账户区块视图。
///
/// 展示前 3 个推荐账户和查看更多链接。
struct SuggestedAccountsSection: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath

  /// 推荐账户列表。
  let suggestedAccounts: [Account]
  /// 推荐账户的关系状态列表。
  let suggestedAccountsRelationShips: [Relationship]

  /// 视图主体。
  var body: some View {
    Section("explore.section.suggested-users") {
      ForEach(
        suggestedAccounts
          .prefix(
            upTo: suggestedAccounts.count > 3 ? 3 : suggestedAccounts.count)
      ) { account in
        if let relationship = suggestedAccountsRelationShips.first(where: {
          $0.id == account.id
        }) {
          AccountsListRow(viewModel: .init(account: account, relationShip: relationship))
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #else
              .listRowBackground(
                RoundedRectangle(cornerRadius: 8)
                  .foregroundStyle(.background).hoverEffect()
              )
              .listRowHoverEffectDisabled()
            #endif
        }
      }
      NavigationLink(value: RouterDestination.accountsList(accounts: suggestedAccounts)) {
        Text("see-more")
          .foregroundColor(theme.tintColor)
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #else
        .listRowBackground(
          RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background).hoverEffect()
        )
        .listRowHoverEffectDisabled()
      #endif
    }
  }
}

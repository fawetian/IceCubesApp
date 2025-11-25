/*
 * SearchResultsView.swift
 * IceCubesApp - 搜索结果视图
 *
 * 文件功能：
 * 展示搜索结果，按类型分组显示账户、标签和帖子。
 *
 * 核心职责：
 * - 根据搜索范围（全部、用户、标签、帖子）过滤结果
 * - 分区显示搜索结果
 * - 支持分页加载更多结果
 * - 根据平台适配背景样式
 *
 * 技术要点：
 * - SearchResults 搜索结果对象
 * - SearchScope 搜索范围
 * - Section 分组显示
 * - NextPageView 分页组件
 * - visionOS 适配
 *
 * 使用场景：
 * - ExploreView 中的搜索结果展示
 * - 根据搜索范围切换显示内容
 *
 * 依赖关系：
 * - Account: AccountsListRow
 * - DesignSystem: Theme、TagRowView
 * - Env: RouterPath、MastodonClient
 * - Models: SearchResults、Account、Tag、Status
 * - StatusKit: StatusRowExternalView
 */

import Account
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

/// 搜索结果视图。
///
/// 按类型分组展示搜索结果，支持分页加载。
struct SearchResultsView: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath

  /// 搜索结果对象。
  let results: SearchResults
  /// 搜索范围（全部、用户、标签、帖子）。
  let searchScope: SearchScope
  /// 加载下一页回调。
  let onNextPage: (Search.EntityType) async -> Void

  /// 视图主体。
  var body: some View {
    Group {
      if !results.accounts.isEmpty, searchScope == .all || searchScope == .people {
        Section("explore.section.users") {
          ForEach(results.accounts) { account in
            if let relationship = results.relationships.first(where: { $0.id == account.id }) {
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
          if searchScope == .people {
            NextPageView {
              await onNextPage(.accounts)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }

      if !results.hashtags.isEmpty,
        searchScope == .all || searchScope == .hashtags
      {
        Section("explore.section.tags") {
          ForEach(results.hashtags) { tag in
            TagRowView(tag: tag)
              #if !os(visionOS)
                .listRowBackground(theme.primaryBackgroundColor)
              #else
                .listRowBackground(
                  RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background).hoverEffect()
                )
                .listRowHoverEffectDisabled()
              #endif
              .padding(.vertical, 4)
          }
          if searchScope == .hashtags {
            NextPageView {
              await onNextPage(.hashtags)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }

      if !results.statuses.isEmpty, searchScope == .all || searchScope == .posts {
        Section("explore.section.posts") {
          ForEach(results.statuses) { status in
            StatusRowExternalView(
              viewModel: .init(status: status, client: client, routerPath: routerPath)
            )
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #else
              .listRowBackground(
                RoundedRectangle(cornerRadius: 8)
                  .foregroundStyle(.background).hoverEffect()
              )
              .listRowHoverEffectDisabled()
            #endif
            .padding(.vertical, 8)
          }
          if searchScope == .posts {
            NextPageView {
              await onNextPage(.statuses)
            }
            .padding(.horizontal, .layoutPadding)
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }
    }
  }
}

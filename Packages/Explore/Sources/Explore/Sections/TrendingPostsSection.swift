/*
 * TrendingPostsSection.swift
 * IceCubesApp - 趋势帖子区块视图
 *
 * 文件功能：
 * 在探索页展示热门趋势帖子列表（前 3 个）。
 *
 * 核心职责：
 * - 显示最多 3 个趋势帖子
 * - 使用 StatusRowExternalView 渲染帖子
 * - 提供"查看更多"链接到趋势时间线
 * - 支持 visionOS 适配
 *
 * 技术要点：
 * - Section 分组
 * - StatusRowExternalView 帖子行
 * - NavigationLink 导航
 * - 平台条件编译
 *
 * 使用场景：
 * - ExploreView 的趋势帖子区域
 *
 * 依赖关系：
 * - DesignSystem: Theme
 * - Env: RouterPath、MastodonClient
 * - Models: Status
 * - StatusKit: StatusRowExternalView
 */

import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

/// 趋势帖子区块视图。
///
/// 展示前 3 个热门帖子和查看更多链接。
struct TrendingPostsSection: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath

  /// 趋势帖子列表。
  let trendingStatuses: [Status]

  /// 视图主体。
  var body: some View {
    Section("explore.section.trending.posts") {
      ForEach(
        trendingStatuses
          .prefix(upTo: trendingStatuses.count > 3 ? 3 : trendingStatuses.count)
      ) { status in
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

      NavigationLink(value: RouterDestination.trendingTimeline) {
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

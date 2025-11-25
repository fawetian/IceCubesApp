/*
 * TrendingLinksSection.swift
 * IceCubesApp - 趋势链接区块视图
 *
 * 文件功能：
 * 在探索页展示热门趋势链接列表（前 3 个）。
 *
 * 核心职责：
 * - 显示最多 3 个趋势链接（文章、新闻等）
 * - 使用 StatusRowCardView 渲染链接卡片
 * - 提供"查看更多"链接
 * - 支持 visionOS 适配
 *
 * 技术要点：
 * - Section 分组
 * - StatusRowCardView 链接卡片
 * - NavigationLink 导航
 * - 紧凑模式环境变量
 *
 * 使用场景：
 * - ExploreView 的趋势链接区域
 *
 * 依赖关系：
 * - DesignSystem: Theme
 * - Env: RouterPath
 * - Models: Card
 * - StatusKit: StatusRowCardView
 */

import DesignSystem
import Env
import Models
import StatusKit
import SwiftUI

/// 趋势链接区块视图。
///
/// 展示前 3 个热门链接卡片和查看更多链接。
struct TrendingLinksSection: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath

  /// 趋势链接列表。
  let trendingLinks: [Card]

  /// 视图主体。
  var body: some View {
    Section("explore.section.trending.links") {
      ForEach(
        trendingLinks
          .prefix(upTo: trendingLinks.count > 3 ? 3 : trendingLinks.count)
      ) { card in
        StatusRowCardView(card: card)
          .environment(\.isCompact, true)
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

      NavigationLink(value: RouterDestination.trendingLinks(cards: trendingLinks)) {
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

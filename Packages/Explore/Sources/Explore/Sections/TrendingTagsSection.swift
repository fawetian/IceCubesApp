/*
 * TrendingTagsSection.swift
 * IceCubesApp - 趋势标签区块视图
 *
 * 文件功能：
 * 在探索页展示热门趋势标签列表（前 5 个）。
 *
 * 核心职责：
 * - 显示最多 5 个趋势标签
 * - 提供"查看更多"链接
 * - 支持 visionOS 适配
 *
 * 技术要点：
 * - Section 分组
 * - TagRowView 标签行
 * - NavigationLink 导航
 * - 平台条件编译
 *
 * 使用场景：
 * - ExploreView 的趋势标签区域
 *
 * 依赖关系：
 * - DesignSystem: TagRowView、Theme
 * - Env: RouterPath
 * - Models: Tag
 */

import DesignSystem
import Env
import Models
import SwiftUI

/// 趋势标签区块视图。
///
/// 展示前 5 个热门标签和查看更多链接。
struct TrendingTagsSection: View {
  @Environment(Theme.self) private var theme
  @Environment(RouterPath.self) private var routerPath

  /// 趋势标签列表。
  let trendingTags: [Tag]

  /// 视图主体。
  var body: some View {
    Section("explore.section.trending.tags") {
      ForEach(
        trendingTags
          .prefix(upTo: trendingTags.count > 5 ? 5 : trendingTags.count)
      ) { tag in
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
      NavigationLink(value: RouterDestination.tagsList(tags: trendingTags)) {
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

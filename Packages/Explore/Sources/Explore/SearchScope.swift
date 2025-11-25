/*
 * SearchScope.swift
 * IceCubesApp - 搜索范围枚举
 *
 * 文件功能：
 * 定义探索页面的搜索范围类型。
 *
 * 核心职责：
 * - 枚举所有可用的搜索范围
 * - 提供本地化标题
 *
 * 技术要点：
 * - CaseIterable 可遍历
 * - String 原始值
 * - LocalizedStringKey 本地化
 *
 * 使用场景：
 * - ExploreView 搜索范围选择
 * - SearchResultsView 结果过滤
 *
 * 依赖关系：
 * - SwiftUI: LocalizedStringKey
 */

import SwiftUI

/// 搜索范围枚举。
///
/// 定义搜索结果的过滤范围。
enum SearchScope: String, CaseIterable {
  /// 全部结果。
  case all
  /// 仅用户。
  case people
  /// 仅标签。
  case hashtags
  /// 仅帖子。
  case posts

  /// 本地化标题。
  var localizedString: LocalizedStringKey {
    switch self {
    case .all:
      .init("explore.scope.all")
    case .people:
      .init("explore.scope.people")
    case .hashtags:
      .init("explore.scope.hashtags")
    case .posts:
      .init("explore.scope.posts")
    }
  }
}

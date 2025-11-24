// 文件功能：Mastodon 内容过滤器数据模型
//
// 核心职责：
// - 表示 Mastodon 的内容过滤规则
// - 定义过滤器的匹配结果
// - 支持关键词过滤
// - 控制过滤器的应用场景
//
// 技术要点：
// - Filter：过滤器的完整配置
// - Filtered：过滤匹配的结果
// - Action：过滤动作（警告或隐藏）
// - Context：过滤应用的场景
//
// 过滤器特性：
// - 关键词匹配
// - 多场景支持（主页、通知、公共时间线等）
// - 两种处理方式（警告或完全隐藏）
// - 匹配关键词列表
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Status, Timeline, Notifications

import Foundation

/// 过滤匹配结果
///
/// 表示内容被过滤器匹配的结果。
///
/// 包含信息：
/// - **filter**：匹配的过滤器
/// - **keywordMatches**：匹配的关键词列表
///
/// 使用场景：
/// - 显示为什么内容被过滤
/// - 提供解除过滤的选项
/// - 显示匹配的关键词
///
/// 示例：
/// ```swift
/// if let filtered = status.filtered?.first {
///     Text("此内容被过滤：\(filtered.filter.title)")
///     if let keywords = filtered.keywordMatches {
///         Text("匹配关键词：\(keywords.joined(separator: ", "))")
///     }
/// }
/// ```
public struct Filtered: Codable, Equatable, Hashable {
  /// 匹配的过滤器
  ///
  /// 触发此过滤结果的过滤器对象。
  public let filter: Filter

  /// 匹配的关键词
  ///
  /// 导致内容被过滤的关键词列表。
  ///
  /// 用途：
  /// - 显示具体匹配的关键词
  /// - 帮助用户理解为什么被过滤
  /// - 提供调整过滤器的依据
  public let keywordMatches: [String]?
}

/// 内容过滤器
///
/// 表示 Mastodon 的内容过滤规则。
///
/// 主要功能：
/// - **关键词过滤**：根据关键词过滤内容
/// - **场景控制**：在特定场景应用过滤
/// - **动作选择**：警告或完全隐藏
/// - **自定义标题**：为过滤器命名
///
/// 使用场景：
/// - 过滤不想看到的内容
/// - 屏蔽特定话题
/// - 减少干扰信息
/// - 自定义时间线内容
///
/// 示例：
/// ```swift
/// // 创建过滤器
/// let filter = Filter(
///     id: "1",
///     title: "政治话题",
///     context: ["home", "public"],
///     filterAction: .warn
/// )
///
/// // 检查内容是否被过滤
/// if status.filtered?.contains(where: { $0.filter.id == filter.id }) == true {
///     // 显示过滤警告
/// }
/// ```
public struct Filter: Codable, Identifiable, Equatable, Hashable {
  /// 过滤动作
  ///
  /// 定义内容被过滤后的处理方式。
  public enum Action: String, Codable, Equatable {
    /// 警告
    ///
    /// 显示警告，但允许用户查看内容。
    /// 内容会被折叠，需要点击才能展开。
    case warn

    /// 隐藏
    ///
    /// 完全隐藏内容，不在时间线中显示。
    case hide
  }

  /// 过滤场景
  ///
  /// 定义过滤器应用的场景。
  public enum Context: String, Codable {
    /// 主页时间线
    ///
    /// 在主页时间线中应用过滤。
    case home

    /// 通知
    ///
    /// 在通知列表中应用过滤。
    case notifications

    /// 账户页面
    ///
    /// 在查看账户时应用过滤。
    case account

    /// 对话串
    ///
    /// 在查看对话串时应用过滤。
    case thread

    /// 公共时间线
    ///
    /// 在公共时间线中应用过滤。
    case pub = "public"
  }

  /// 过滤器 ID
  ///
  /// 过滤器的唯一标识符。
  public let id: String

  /// 过滤器标题
  ///
  /// 过滤器的自定义名称。
  ///
  /// 示例："政治话题"、"体育新闻"、"广告内容"
  public let title: String

  /// 应用场景
  ///
  /// 过滤器应用的场景列表。
  ///
  /// 可以在多个场景同时应用同一个过滤器。
  /// 示例：["home", "public", "notifications"]
  public let context: [String]

  /// 过滤动作
  ///
  /// 内容被过滤后的处理方式。
  ///
  /// - warn：显示警告，允许查看
  /// - hide：完全隐藏
  public let filterAction: Action
}

// MARK: - Sendable 扩展

/// 使 Filtered 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Filtered: Sendable {}

/// 使 Filter 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Filter: Sendable {}

/// 使 Filter.Action 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Filter.Action: Sendable {}

/// 使 Filter.Context 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Filter.Context: Sendable {}

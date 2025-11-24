// 文件功能：Mastodon 自定义表情 API 端点定义
//
// 核心职责：
// - 定义自定义表情相关的 API 端点
// - 支持获取实例的自定义表情列表
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：EmojiPicker, MastodonClient

import Foundation

/// Mastodon 自定义表情 API 端点
///
/// 定义了获取自定义表情的操作。
///
/// 自定义表情：
/// - 每个实例可以有自己的自定义表情
/// - 用户可以在帖子中使用 :shortcode: 格式
/// - 表情可以分类组织
/// - 支持动画表情（GIF）
///
/// 使用示例：
/// ```swift
/// // 获取实例的所有自定义表情
/// let emojis: [Emoji] = try await client.get(
///     endpoint: CustomEmojis.customEmojis
/// )
///
/// // 在表情选择器中显示
/// ForEach(emojis) { emoji in
///     AsyncImage(url: URL(string: emoji.url))
///         .onTapGesture {
///             insertEmoji(emoji.shortcode)
///         }
/// }
/// ```
public enum CustomEmojis: Endpoint {
  /// 获取自定义表情列表
  ///
  /// 返回：Emoji 数组，包含：
  /// - shortcode: 表情代码（如 "blobcat"）
  /// - url: 表情图片 URL
  /// - staticUrl: 静态图片 URL（非动画）
  /// - visibleInPicker: 是否在选择器中显示
  /// - category: 分类名称
  ///
  /// 使用场景：
  /// - 表情选择器
  /// - 表情自动补全
  /// - 表情预览
  ///
  /// API 路径：`/api/v1/custom_emojis`
  /// HTTP 方法：GET
  case customEmojis

  public func path() -> String {
    switch self {
    case .customEmojis:
      "custom_emojis"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    nil
  }
}

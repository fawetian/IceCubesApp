// 文件功能：Mastodon 提及数据模型
//
// 核心职责：
// - 表示帖子中提及的用户
// - 包含用户的基本信息
// - 提供用户的链接
// - 支持跨实例提及
//
// 技术要点：
// - Mention：提及的用户信息
// - 包含用户名和完整账户名
// - 提供用户页面的 URL
// - Sendable 并发安全
//
// 提及特性：
// - 使用 @username 语法
// - 支持跨实例提及（@user@server）
// - 可点击跳转到用户页面
// - 在帖子内容中高亮显示
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Status

import Foundation

/// 提及数据模型
///
/// 表示帖子中提及（@mention）的用户。
///
/// 主要用途：
/// - **显示提及**：在帖子中高亮显示被提及的用户
/// - **用户跳转**：点击提及可跳转到用户页面
/// - **通知触发**：被提及的用户会收到通知
///
/// 使用场景：
/// - 解析帖子内容中的 @username
/// - 显示被提及的用户列表
/// - 处理提及的点击事件
///
/// 示例：
/// ```swift
/// // 显示提及的用户
/// ForEach(status.mentions, id: \.id) { mention in
///     Button(action: {
///         router.navigate(to: .accountDetail(id: mention.id))
///     }) {
///         Text("@\(mention.username)")
///             .foregroundColor(.blue)
///     }
/// }
///
/// // 在帖子内容中高亮提及
/// Text(status.content)
///     .environment(\.openURL, OpenURLAction { url in
///         if let mention = status.mentions.first(where: { $0.url == url }) {
///             router.navigate(to: .accountDetail(id: mention.id))
///             return .handled
///         }
///         return .systemAction
///     })
/// ```
public struct Mention: Codable, Equatable, Hashable {
  /// 用户 ID
  ///
  /// 被提及用户的唯一标识符。
  ///
  /// 用途：
  /// - 跳转到用户页面
  /// - 查询用户信息
  public let id: String

  /// 用户名
  ///
  /// 被提及用户的用户名（不含 @ 符号）。
  ///
  /// 示例：
  /// - "alice"
  /// - "bob"
  ///
  /// 用途：
  /// - 显示提及文本
  /// - 构建 @username 格式
  public let username: String

  /// 用户页面 URL
  ///
  /// 被提及用户的个人页面链接。
  ///
  /// 示例：
  /// - https://mastodon.social/@alice
  /// - https://mastodon.online/@bob
  ///
  /// 用途：
  /// - 点击提及时跳转
  /// - 在浏览器中打开
  public let url: URL

  /// 完整账户名
  ///
  /// 被提及用户的完整账户名（含实例域名）。
  ///
  /// 格式：
  /// - 本实例用户："username"
  /// - 其他实例用户："username@server"
  ///
  /// 示例：
  /// - "alice"（本实例）
  /// - "bob@mastodon.online"（其他实例）
  ///
  /// 用途：
  /// - 显示完整的用户标识
  /// - 区分不同实例的同名用户
  public let acct: String
}

// MARK: - Sendable 扩展

/// 使 Mention 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Mention: Sendable {}

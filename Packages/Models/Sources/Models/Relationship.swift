// 文件功能：Mastodon 关注关系数据模型
//
// 核心职责：
// - 表示当前用户与其他用户的关系
// - 包含关注、屏蔽、静音等状态
// - 提供关系的完整信息
// - 支持双向关系查询
//
// 技术要点：
// - Relationship：关系的完整状态
// - 多种关系类型（关注、屏蔽、静音等）
// - 双向关系（following 和 followedBy）
// - 自定义解码处理默认值
//
// 关系类型：
// - 关注关系：following, followedBy
// - 屏蔽关系：blocking, blockedBy
// - 静音关系：muting, mutingNotifications
// - 其他：requested, endorsed, notifying
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：Account, ProfileView, FollowButton

import Foundation

/// 用户关系数据模型
///
/// 表示当前用户与另一个用户之间的关系状态。
///
/// 主要功能：
/// - **关注状态**：是否关注对方，对方是否关注你
/// - **屏蔽状态**：是否屏蔽对方，是否被对方屏蔽
/// - **静音状态**：是否静音对方，是否静音通知
/// - **其他状态**：关注请求、推荐、通知等
///
/// 使用场景：
/// - 显示关注按钮状态
/// - 判断是否可以查看内容
/// - 显示关系标签
/// - 控制交互权限
///
/// 示例：
/// ```swift
/// let relationship = try await client.get(
///     endpoint: Accounts.relationships(ids: [accountId])
/// ).first
///
/// if relationship.following {
///     Text("已关注")
/// } else if relationship.requested {
///     Text("已请求关注")
/// } else {
///     Button("关注") { /* ... */ }
/// }
///
/// if relationship.blocking {
///     Text("已屏蔽此用户")
/// }
/// ```
public struct Relationship: Codable, Equatable, Identifiable {
  /// 用户 ID
  ///
  /// 关系对应的用户 ID。
  public let id: String

  /// 是否正在关注
  ///
  /// 当前用户是否关注了此用户。
  ///
  /// 用途：
  /// - 显示关注按钮状态
  /// - 判断是否可以取消关注
  public let following: Bool

  /// 是否显示转发
  ///
  /// 是否在时间线中显示此用户的转发。
  ///
  /// 说明：
  /// - 只有在关注时才有意义
  /// - 可以关注但不看转发
  public let showingReblogs: Bool

  /// 是否被关注
  ///
  /// 此用户是否关注了当前用户。
  ///
  /// 用途：
  /// - 显示"互相关注"标签
  /// - 判断是否可以发私信
  public let followedBy: Bool

  /// 是否已屏蔽
  ///
  /// 当前用户是否屏蔽了此用户。
  ///
  /// 效果：
  /// - 不会看到对方的帖子
  /// - 对方无法关注你
  /// - 对方无法看到你的帖子
  public let blocking: Bool

  /// 是否被屏蔽
  ///
  /// 此用户是否屏蔽了当前用户。
  ///
  /// 效果：
  /// - 无法关注对方
  /// - 无法看到对方的帖子
  public let blockedBy: Bool

  /// 是否已静音
  ///
  /// 当前用户是否静音了此用户。
  ///
  /// 效果：
  /// - 不会在时间线中看到对方的帖子
  /// - 仍然可以访问对方的个人页面
  /// - 对方不知道被静音
  public let muting: Bool

  /// 是否静音通知
  ///
  /// 是否静音了此用户的通知。
  ///
  /// 效果：
  /// - 不会收到对方的通知
  /// - 仍然保持关注关系
  public let mutingNotifications: Bool

  /// 是否已请求关注
  ///
  /// 是否已向此用户发送关注请求。
  ///
  /// 说明：
  /// - 只在对方账户为私密时有效
  /// - 等待对方批准
  public let requested: Bool

  /// 是否屏蔽域名
  ///
  /// 是否屏蔽了此用户所在的整个实例。
  ///
  /// 效果：
  /// - 屏蔽该实例的所有用户
  /// - 不会看到该实例的任何内容
  public let domainBlocking: Bool

  /// 是否已推荐
  ///
  /// 是否在个人资料中推荐了此用户。
  ///
  /// 用途：
  /// - 在个人资料中展示推荐的用户
  /// - 类似于"特别关注"
  public let endorsed: Bool

  /// 备注
  ///
  /// 为此用户添加的私人备注。
  ///
  /// 特点：
  /// - 只有自己可见
  /// - 用于记录用户信息
  public let note: String

  /// 是否开启通知
  ///
  /// 是否开启了此用户的帖子通知。
  ///
  /// 效果：
  /// - 对方发帖时会收到通知
  /// - 类似于"特别关注"
  public let notifying: Bool

  /// 创建占位符关系
  ///
  /// 创建一个默认的关系对象，所有状态都为 false。
  ///
  /// 用途：
  /// - 预览和测试
  /// - 默认状态
  /// - 加载前的占位
  public static func placeholder() -> Relationship {
    .init(
      id: UUID().uuidString,
      following: false,
      showingReblogs: false,
      followedBy: false,
      blocking: false,
      blockedBy: false,
      muting: false,
      mutingNotifications: false,
      requested: false,
      domainBlocking: false,
      endorsed: false,
      note: "",
      notifying: false)
  }
}

// MARK: - 自定义解码

/// Relationship 的自定义解码扩展
///
/// 为所有字段提供默认值，确保解码不会失败。
extension Relationship {
  /// 自定义初始化方法
  ///
  /// 从 JSON 解码时，为所有字段提供默认值。
  ///
  /// 默认值策略：
  /// - String 类型：空字符串 ""
  /// - Bool 类型：false
  ///
  /// 这样即使服务器返回的数据不完整，也能正常解码。
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
    following = try values.decodeIfPresent(Bool.self, forKey: .following) ?? false
    showingReblogs = try values.decodeIfPresent(Bool.self, forKey: .showingReblogs) ?? false
    followedBy = try values.decodeIfPresent(Bool.self, forKey: .followedBy) ?? false
    blocking = try values.decodeIfPresent(Bool.self, forKey: .blocking) ?? false
    blockedBy = try values.decodeIfPresent(Bool.self, forKey: .blockedBy) ?? false
    muting = try values.decodeIfPresent(Bool.self, forKey: .muting) ?? false
    mutingNotifications =
      try values.decodeIfPresent(Bool.self, forKey: .mutingNotifications) ?? false
    requested = try values.decodeIfPresent(Bool.self, forKey: .requested) ?? false
    domainBlocking = try values.decodeIfPresent(Bool.self, forKey: .domainBlocking) ?? false
    endorsed = try values.decodeIfPresent(Bool.self, forKey: .endorsed) ?? false
    note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
    notifying = try values.decodeIfPresent(Bool.self, forKey: .notifying) ?? false
  }
}

// MARK: - Sendable 扩展

/// 使 Relationship 符合 Sendable 协议
///
/// 允许在并发上下文中安全传递。
extension Relationship: Sendable {}

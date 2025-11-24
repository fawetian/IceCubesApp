// 文件功能：Mastodon 通知数据模型
//
// 核心职责：
// - 表示 Mastodon 的各种通知类型
// - 包含通知的触发者、相关帖子等信息
// - 支持通知分组（groupKey）
// - 提供类型安全的通知类型枚举
//
// 技术要点：
// - NotificationType：定义所有支持的通知类型
// - groupKey：用于合并相似通知（如多人点赞同一条帖子）
// - supportedType：类型安全的通知类型访问
// - status：某些通知类型包含相关帖子
//
// 通知类型说明：
// - follow：有人关注了你
// - follow_request：有人请求关注你（锁定账户）
// - mention：有人在帖子中提及你
// - reblog：有人转发了你的帖子
// - favourite：有人点赞了你的帖子
// - poll：你参与的投票结束了
// - status：你关注的人发布了新帖子
// - update：有人编辑了帖子
// - quote：有人引用了你的帖子
// - quoted_update：被引用的帖子被编辑了
//
// 依赖关系：
// - 依赖：Account, Status, ServerDate
// - 被依赖：NotificationsListView, ConsolidatedNotification

import Foundation

/// Mastodon 通知数据模型
///
/// 表示用户收到的各种类型的通知，包括：
/// - 社交互动：关注、关注请求、提及
/// - 内容互动：点赞、转发、引用
/// - 内容更新：投票结束、帖子编辑
/// - 订阅更新：关注的人发布新帖子
///
/// 通知分组：
/// - Mastodon 会将相似的通知合并显示
/// - 例如："Alice、Bob 和其他 3 人点赞了你的帖子"
/// - groupKey 用于标识可以合并的通知
///
/// 使用示例：
/// ```swift
/// let notifications: [Notification] = try await client.get(endpoint: Notifications.notifications)
/// for notification in notifications {
///     switch notification.supportedType {
///     case .follow:
///         print("\(notification.account.displayName) 关注了你")
///     case .favourite:
///         print("\(notification.account.displayName) 点赞了你的帖子")
///     default:
///         break
///     }
/// }
/// ```
public struct Notification: Decodable, Identifiable, Equatable {
  /// 通知类型枚举
  ///
  /// 定义 Mastodon 支持的所有通知类型。
  ///
  /// 类型说明：
  /// - follow: 新关注者
  /// - follow_request: 关注请求（锁定账户）
  /// - mention: 被提及（@你）
  /// - reblog: 帖子被转发
  /// - status: 关注的人发布新帖子
  /// - favourite: 帖子被点赞
  /// - poll: 投票结束
  /// - update: 帖子被编辑
  /// - quote: 帖子被引用
  /// - quoted_update: 被引用的帖子被编辑
  ///
  /// 使用场景：
  /// - 根据类型显示不同的通知 UI
  /// - 过滤特定类型的通知
  /// - 设置通知偏好（只接收某些类型）
  ///
  /// - Note: 不同 Mastodon 实例可能支持不同的通知类型
  public enum NotificationType: String, CaseIterable {
    case follow           // 新关注者
    case follow_request   // 关注请求
    case mention          // 被提及
    case reblog           // 被转发
    case status           // 新帖子
    case favourite        // 被点赞
    case poll             // 投票结束
    case update           // 帖子编辑
    case quote            // 被引用
    case quoted_update    // 引用的帖子被编辑
  }

  // MARK: - 基本信息
  
  /// 通知的唯一标识符
  public let id: String
  
  /// 通知类型（字符串格式）
  ///
  /// 直接来自 API 的原始类型字符串。
  /// 使用 supportedType 获取类型安全的枚举值。
  ///
  /// 为什么保留字符串类型？
  /// - API 可能返回新的、未知的通知类型
  /// - 保持向后兼容性
  /// - 允许处理未来的通知类型
  public let type: String
  
  /// 通知创建时间
  public let createdAt: ServerDate
  
  // MARK: - 关联数据
  
  /// 触发通知的账户
  ///
  /// 例如：
  /// - follow: 关注你的人
  /// - favourite: 点赞你帖子的人
  /// - mention: 提及你的人
  public let account: Account
  
  /// 相关的帖子（如果有）
  ///
  /// 某些通知类型包含相关帖子：
  /// - mention: 提及你的帖子
  /// - reblog: 被转发的帖子
  /// - favourite: 被点赞的帖子
  /// - quote: 引用你的帖子
  ///
  /// 某些通知类型不包含帖子：
  /// - follow: 只是关注，没有帖子
  /// - follow_request: 只是请求，没有帖子
  public let status: Status?
  
  /// 通知分组键
  ///
  /// 用于将相似的通知合并显示。
  ///
  /// 工作原理：
  /// - 相同 groupKey 的通知可以合并
  /// - 例如：多人点赞同一条帖子
  /// - UI 显示："Alice、Bob 和其他 3 人点赞了你的帖子"
  ///
  /// 分组规则：
  /// - 相同类型（如都是 favourite）
  /// - 相同目标（如都是同一条帖子）
  /// - 时间接近（通常在几小时内）
  ///
  /// - Note: 如果为 nil，表示不参与分组
  public let groupKey: String?

  // MARK: - 计算属性
  
  /// 类型安全的通知类型
  ///
  /// 将字符串类型转换为枚举类型，提供类型安全。
  ///
  /// 返回值：
  /// - 如果 type 是已知类型，返回对应的枚举值
  /// - 如果 type 是未知类型（新类型或自定义类型），返回 nil
  ///
  /// 使用示例：
  /// ```swift
  /// if let type = notification.supportedType {
  ///     switch type {
  ///     case .follow:
  ///         showFollowNotification()
  ///     case .favourite:
  ///         showFavouriteNotification()
  ///     default:
  ///         showGenericNotification()
  ///     }
  /// } else {
  ///     // 处理未知类型
  ///     print("未知通知类型: \(notification.type)")
  /// }
  /// ```
  ///
  /// - Note: 使用 supportedType 而不是直接使用 type，可以获得编译时类型检查
  public var supportedType: NotificationType? {
    .init(rawValue: type)
  }

  // MARK: - 占位符
  
  /// 创建占位符通知
  ///
  /// 用于 SwiftUI 预览、测试和加载状态。
  ///
  /// 使用场景：
  /// ```swift
  /// #Preview {
  ///     NotificationRowView(notification: .placeholder())
  /// }
  /// ```
  public static func placeholder() -> Notification {
    .init(
      id: UUID().uuidString,
      type: NotificationType.favourite.rawValue,
      createdAt: ServerDate(),
      account: .placeholder(),
      status: .placeholder(),
      groupKey: nil)
  }
}

// MARK: - Sendable 一致性

/// Notification 符合 Sendable 协议
///
/// 原因：
/// - 所有属性都是不可变的（let）
/// - 所有属性类型都是 Sendable
/// - 可以安全地在并发上下文中传递
///
/// 这使得 Notification 可以：
/// - 在 Actor 之间传递
/// - 在 Task 中使用
/// - 在 @MainActor 和后台线程之间传递
extension Notification: Sendable {}

/// NotificationType 符合 Sendable 协议
///
/// 枚举类型默认是 Sendable，这里显式声明以确保一致性
extension Notification.NotificationType: Sendable {}

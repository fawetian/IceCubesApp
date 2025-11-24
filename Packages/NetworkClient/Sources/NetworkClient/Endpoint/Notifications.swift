// 文件功能：Mastodon 通知 API 端点定义
//
// 核心职责：
// - 定义所有通知相关的 API 端点
// - 支持通知的获取、过滤和管理
// - 支持通知策略和请求管理
// - 提供 v1 和 v2 两个版本的 API
//
// 技术要点：
// - Notifications：枚举类型，定义通知相关操作
// - v1 API：传统的通知列表
// - v2 API：分组通知（Grouped Notifications）
// - 通知类型过滤：支持包含和排除特定类型
// - 通知策略：控制谁可以给你发送通知
//
// 通知操作类型：
// - V1：notifications, notification, clear
// - V2：notificationsV2, notificationGroupV2, unreadCountV2
// - 策略：policy, putPolicy
// - 请求：requests, acceptRequests, dismissRequests
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：NotificationsListView, MastodonClient

import Foundation
import Models

/// Mastodon 通知 API 端点
///
/// 定义了所有与通知相关的操作，包括 v1 和 v2 两个版本的 API。
///
/// 主要功能：
/// - **获取通知**：获取通知列表，支持分页和过滤
/// - **通知管理**：清除通知、标记为已读
/// - **通知策略**：控制谁可以给你发送通知
/// - **通知请求**：管理来自陌生人的通知请求
/// - **分组通知（v2）**：将相似通知分组显示
///
/// 通知类型：
/// - **mention**: 有人提及你
/// - **status**: 你关注的人发布了新帖子
/// - **reblog**: 有人转发了你的帖子
/// - **follow**: 有人关注了你
/// - **follow_request**: 有人请求关注你
/// - **favourite**: 有人点赞了你的帖子
/// - **poll**: 你参与的投票结束了
/// - **update**: 你互动过的帖子被编辑了
/// - **admin.sign_up**: 有新用户注册（管理员）
/// - **admin.report**: 有新举报（管理员）
///
/// 使用示例：
/// ```swift
/// // 获取通知列表（v1）
/// let notifications: [Notification] = try await client.get(
///     endpoint: Notifications.notifications(
///         minId: nil,
///         maxId: nil,
///         types: ["mention", "reblog"],  // 排除这些类型
///         limit: 20
///     )
/// )
///
/// // 获取分组通知（v2）
/// let groupedNotifications: GroupedNotificationsResults = try await client.get(
///     endpoint: Notifications.notificationsV2(
///         sinceId: nil,
///         maxId: nil,
///         types: nil,
///         excludeTypes: ["status"],
///         accountId: nil,
///         groupedTypes: ["reblog", "favourite"],
///         expandAccounts: "partial_avatars"
///     )
/// )
///
/// // 清除所有通知
/// try await client.post(endpoint: Notifications.clear)
/// ```
///
/// - Note: v2 API 提供了更好的通知分组体验
/// - SeeAlso: `NotificationsPolicy` 用于配置通知策略
public enum Notifications: Endpoint {
  /// 获取通知列表（v1 API）
  ///
  /// - Parameters:
  ///   - minId: 获取此 ID 之后的通知（可选）
  ///   - maxId: 获取此 ID 之前的通知（可选）
  ///   - types: 要排除的通知类型（可选）
  ///   - limit: 限制返回的通知数量
  ///
  /// 返回：Notification 数组
  ///
  /// 使用场景：
  /// - 显示通知列表
  /// - 下拉刷新
  /// - 无限滚动
  ///
  /// API 路径：`/api/v1/notifications`
  /// HTTP 方法：GET
  case notifications(
    minId: String?,
    maxId: String?,
    types: [String]?,
    limit: Int)
  
  /// 获取特定账户的通知
  ///
  /// - Parameters:
  ///   - accountId: 账户 ID
  ///   - maxId: 分页参数（可选）
  ///
  /// 返回：Notification 数组（来自指定账户的通知）
  ///
  /// 使用场景：
  /// - 查看某个用户的所有互动
  /// - 过滤特定用户的通知
  ///
  /// API 路径：`/api/v1/notifications`
  /// HTTP 方法：GET
  case notificationsForAccount(accountId: String, maxId: String?)
  
  /// 获取单个通知详情
  ///
  /// - Parameter id: 通知 ID
  ///
  /// 返回：Notification 对象
  ///
  /// API 路径：`/api/v1/notifications/:id`
  /// HTTP 方法：GET
  case notification(id: String)
  
  /// 获取通知策略
  ///
  /// 返回：NotificationsPolicy 对象
  ///
  /// 通知策略控制：
  /// - 谁可以给你发送通知
  /// - 是否需要过滤陌生人的通知
  /// - 通知请求的处理方式
  ///
  /// API 路径：`/api/v1/notifications/policy`
  /// HTTP 方法：GET
  case policy
  
  /// 更新通知策略
  ///
  /// - Parameter policy: 新的通知策略
  ///
  /// 返回：更新后的 NotificationsPolicy 对象
  ///
  /// 策略选项：
  /// - 接受所有通知
  /// - 只接受关注者的通知
  /// - 只接受互相关注的通知
  /// - 过滤陌生人的通知到请求列表
  ///
  /// API 路径：`/api/v1/notifications/policy`
  /// HTTP 方法：PUT
  case putPolicy(policy: Models.NotificationsPolicy)
  
  /// 获取通知请求列表
  ///
  /// 返回：NotificationRequest 数组
  ///
  /// 通知请求：
  /// - 来自陌生人的通知
  /// - 需要手动批准或拒绝
  /// - 减少垃圾通知
  ///
  /// API 路径：`/api/v1/notifications/requests`
  /// HTTP 方法：GET
  case requests
  
  /// 批准通知请求
  ///
  /// - Parameter ids: 要批准的请求 ID 数组
  ///
  /// 批准后：
  /// - 通知会出现在主通知列表
  /// - 该用户的后续通知会自动接受
  ///
  /// API 路径：`/api/v1/notifications/requests/accept`
  /// HTTP 方法：POST
  case acceptRequests(ids: [String])
  
  /// 拒绝通知请求
  ///
  /// - Parameter ids: 要拒绝的请求 ID 数组
  ///
  /// 拒绝后：
  /// - 通知会被删除
  /// - 该用户的后续通知会继续被过滤
  ///
  /// API 路径：`/api/v1/notifications/requests/dismiss`
  /// HTTP 方法：POST
  case dismissRequests(ids: [String])
  
  /// 清除所有通知
  ///
  /// 删除所有通知，但不影响通知设置。
  ///
  /// 使用场景：
  /// - 一键清空通知
  /// - 重置通知状态
  ///
  /// API 路径：`/api/v1/notifications/clear`
  /// HTTP 方法：POST
  case clear

  // MARK: - V2 分组通知 API
  
  /// 获取分组通知列表（v2 API）
  ///
  /// - Parameters:
  ///   - sinceId: 获取此 ID 之后的通知（可选）
  ///   - maxId: 获取此 ID 之前的通知（可选）
  ///   - types: 要包含的通知类型（可选）
  ///   - excludeTypes: 要排除的通知类型（可选）
  ///   - accountId: 只显示来自此账户的通知（可选）
  ///   - groupedTypes: 要分组的通知类型（可选）
  ///   - expandAccounts: 账户展开方式（可选）
  ///
  /// 返回：GroupedNotificationsResults 对象
  ///
  /// v2 API 的改进：
  /// - **智能分组**：相似通知自动分组
  /// - **更好的性能**：减少网络请求
  /// - **灵活过滤**：支持包含和排除类型
  /// - **账户展开**：控制账户信息的详细程度
  ///
  /// 分组示例：
  /// - "Alice、Bob 和其他 5 人点赞了你的帖子"
  /// - "3 个新关注者"
  /// - "Charlie 提及了你 2 次"
  ///
  /// expandAccounts 选项：
  /// - "partial_avatars": 显示部分头像
  /// - "full": 显示完整账户信息
  /// - nil: 不展开账户信息
  ///
  /// API 路径：`/api/v2/notifications`
  /// HTTP 方法：GET
  case notificationsV2(
    sinceId: String?,
    maxId: String?,
    types: [String]?,
    excludeTypes: [String]?,
    accountId: String?,
    groupedTypes: [String]?,
    expandAccounts: String?)
  
  /// 获取通知组详情（v2 API）
  ///
  /// - Parameter groupKey: 通知组的唯一键
  ///
  /// 返回：NotificationGroup 对象
  ///
  /// 使用场景：
  /// - 查看分组通知的详细信息
  /// - 展开分组查看所有通知
  ///
  /// API 路径：`/api/v2/notifications/:groupKey`
  /// HTTP 方法：GET
  case notificationGroupV2(groupKey: String)
  
  /// 忽略通知组（v2 API）
  ///
  /// - Parameter groupKey: 通知组的唯一键
  ///
  /// 忽略后：
  /// - 通知组会从列表中移除
  /// - 不会再收到该组的通知
  ///
  /// API 路径：`/api/v2/notifications/:groupKey/dismiss`
  /// HTTP 方法：POST
  case dismissNotificationGroupV2(groupKey: String)
  
  /// 获取通知组中的账户列表（v2 API）
  ///
  /// - Parameter groupKey: 通知组的唯一键
  ///
  /// 返回：Account 数组
  ///
  /// 使用场景：
  /// - 查看"谁点赞了你的帖子"
  /// - 查看"谁关注了你"
  /// - 展开分组查看所有参与者
  ///
  /// API 路径：`/api/v2/notifications/:groupKey/accounts`
  /// HTTP 方法：GET
  case notificationGroupAccountsV2(groupKey: String)
  
  /// 获取未读通知数量（v2 API）
  ///
  /// - Parameters:
  ///   - limit: 限制计数的最大值
  ///   - types: 要包含的通知类型（可选）
  ///   - excludeTypes: 要排除的通知类型（可选）
  ///   - accountId: 只计算来自此账户的通知（可选）
  ///   - groupedTypes: 要分组的通知类型（可选）
  ///
  /// 返回：未读通知数量
  ///
  /// 使用场景：
  /// - 显示通知角标
  /// - 更新应用图标的未读数
  /// - 决定是否显示通知提示
  ///
  /// API 路径：`/api/v2/notifications/unread_count`
  /// HTTP 方法：GET
  case unreadCountV2(
    limit: Int,
    types: [String]?,
    excludeTypes: [String]?,
    accountId: String?,
    groupedTypes: [String]?)

  public func path() -> String {
    switch self {
    case .notifications, .notificationsForAccount:
      "notifications"
    case .notification(let id):
      "notifications/\(id)"
    case .policy, .putPolicy:
      "notifications/policy"
    case .requests:
      "notifications/requests"
    case .acceptRequests:
      "notifications/requests/accept"
    case .dismissRequests:
      "notifications/requests/dismiss"
    case .clear:
      "notifications/clear"
    case .notificationsV2:
      "notifications"
    case .notificationGroupV2(let groupKey):
      "notifications/\(groupKey)"
    case .dismissNotificationGroupV2(let groupKey):
      "notifications/\(groupKey)/dismiss"
    case .notificationGroupAccountsV2(let groupKey):
      "notifications/\(groupKey)/accounts"
    case .unreadCountV2:
      "notifications/unread_count"
    }
  }

  public var jsonValue: (any Encodable)? {
    switch self {
    case .putPolicy(let policy):
      return policy
    default:
      return nil
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case .notificationsForAccount(let accountId, let maxId):
      var params = makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil) ?? []
      params.append(.init(name: "account_id", value: accountId))
      return params
    case .notifications(let mindId, let maxId, let types, let limit):
      var params = makePaginationParam(sinceId: nil, maxId: maxId, mindId: mindId) ?? []
      params.append(.init(name: "limit", value: String(limit)))
      if let types {
        for type in types {
          params.append(.init(name: "exclude_types[]", value: type))
        }
      }
      return params
    case .acceptRequests(let ids), .dismissRequests(let ids):
      return ids.map { URLQueryItem(name: "id[]", value: $0) }
    case .notificationsV2(
      let sinceId, let maxId, let types, let excludeTypes, let accountId, let groupedTypes,
      let expandAccounts):
      var params = makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: nil) ?? []
      if let types {
        for type in types {
          params.append(.init(name: "types[]", value: type))
        }
      }
      if let excludeTypes {
        for type in excludeTypes {
          params.append(.init(name: "exclude_types[]", value: type))
        }
      }
      if let accountId {
        params.append(.init(name: "account_id", value: accountId))
      }
      if let groupedTypes {
        for type in groupedTypes {
          params.append(.init(name: "grouped_types[]", value: type))
        }
      }
      if let expandAccounts {
        params.append(.init(name: "expand_accounts", value: expandAccounts))
      }
      return params
    case .unreadCountV2(let limit, let types, let excludeTypes, let accountId, let groupedTypes):
      var params: [URLQueryItem] = []
      params.append(.init(name: "limit", value: String(limit)))
      if let types {
        for type in types {
          params.append(.init(name: "types[]", value: type))
        }
      }
      if let excludeTypes {
        for type in excludeTypes {
          params.append(.init(name: "exclude_types[]", value: type))
        }
      }
      if let accountId {
        params.append(.init(name: "account_id", value: accountId))
      }
      if let groupedTypes {
        for type in groupedTypes {
          params.append(.init(name: "grouped_types[]", value: type))
        }
      }
      return params
    default:
      return nil
    }
  }
}

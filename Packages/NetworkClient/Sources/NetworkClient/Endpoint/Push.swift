// 文件功能：Mastodon 推送通知 API 端点定义
//
// 核心职责：
// - 定义推送通知订阅的 API 端点
// - 支持创建和管理推送订阅
// - 配置通知类型和提醒设置
//
// 技术要点：
// - Push：枚举类型，定义推送操作
// - Web Push API：使用标准的 Web 推送协议
// - p256dh 和 auth：加密密钥
// - 通知类型过滤
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：PushNotificationService, MastodonClient

import Foundation

/// Mastodon 推送通知 API 端点
///
/// 定义了推送通知订阅的管理操作。
///
/// 推送通知：
/// - 使用 Web Push API 标准
/// - 端到端加密
/// - 可配置通知类型
/// - 支持多设备
///
/// 使用示例：
/// ```swift
/// // 获取当前订阅
/// let subscription: PushSubscription = try await client.get(
///     endpoint: Push.subscription
/// )
///
/// // 创建新订阅
/// let newSubscription: PushSubscription = try await client.post(
///     endpoint: Push.createSub(
///         endpoint: "https://push.example.com/...",
///         p256dh: publicKey,
///         auth: authSecret,
///         mentions: true,
///         status: true,
///         reblog: true,
///         follow: true,
///         favorite: true,
///         poll: true
///     )
/// )
/// ```
public enum Push: Endpoint {
  /// 获取推送订阅
  ///
  /// 返回：PushSubscription 对象
  ///
  /// API 路径：`/api/v1/push/subscription`
  /// HTTP 方法：GET
  case subscription
  
  /// 创建推送订阅
  ///
  /// - Parameters:
  ///   - endpoint: 推送服务器端点 URL
  ///   - p256dh: 公钥（用于加密）
  ///   - auth: 认证密钥
  ///   - mentions: 是否推送提及通知
  ///   - status: 是否推送新帖子通知
  ///   - reblog: 是否推送转发通知
  ///   - follow: 是否推送关注通知
  ///   - favorite: 是否推送点赞通知
  ///   - poll: 是否推送投票通知
  ///
  /// 返回：PushSubscription 对象
  ///
  /// Web Push 加密：
  /// - p256dh: ECDH 公钥（Base64 URL 编码）
  /// - auth: 认证密钥（Base64 URL 编码）
  /// - 使用这些密钥加密推送内容
  ///
  /// 通知类型：
  /// - mentions: 有人提及你
  /// - status: 关注的人发布新帖子
  /// - reblog: 有人转发你的帖子
  /// - follow: 有人关注你
  /// - favorite: 有人点赞你的帖子
  /// - poll: 投票结束
  ///
  /// API 路径：`/api/v1/push/subscription`
  /// HTTP 方法：POST
  case createSub(
    endpoint: String,
    p256dh: Data,
    auth: Data,
    mentions: Bool,
    status: Bool,
    reblog: Bool,
    follow: Bool,
    favorite: Bool,
    poll: Bool)

  public func path() -> String {
    switch self {
    case .subscription, .createSub:
      "push/subscription"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .createSub(endpoint, p256dh, auth, mentions, status, reblog, follow, favorite, poll):
      var params: [URLQueryItem] = []
      params.append(.init(name: "subscription[endpoint]", value: endpoint))
      params.append(
        .init(name: "subscription[keys][p256dh]", value: p256dh.base64UrlEncodedString()))
      params.append(.init(name: "subscription[keys][auth]", value: auth.base64UrlEncodedString()))
      params.append(.init(name: "data[alerts][mention]", value: mentions ? "true" : "false"))
      params.append(.init(name: "data[alerts][status]", value: status ? "true" : "false"))
      params.append(.init(name: "data[alerts][follow]", value: follow ? "true" : "false"))
      params.append(.init(name: "data[alerts][reblog]", value: reblog ? "true" : "false"))
      params.append(.init(name: "data[alerts][favourite]", value: favorite ? "true" : "false"))
      params.append(.init(name: "data[alerts][poll]", value: poll ? "true" : "false"))
      params.append(.init(name: "policy", value: "all"))
      return params
    default:
      return nil
    }
  }
}

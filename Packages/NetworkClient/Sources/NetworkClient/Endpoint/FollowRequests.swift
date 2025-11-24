// 文件功能：Mastodon 关注请求 API 端点定义
//
// 核心职责：
// - 定义关注请求管理的 API 端点
// - 支持获取关注请求列表
// - 支持批准和拒绝关注请求
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：FollowRequestsView, MastodonClient

import Foundation

/// Mastodon 关注请求 API 端点
///
/// 定义了管理关注请求的操作。
///
/// 关注请求：
/// - 当账户是锁定状态时，关注需要批准
/// - 用户可以批准或拒绝关注请求
/// - 批准后对方成为关注者
/// - 拒绝后请求被删除
///
/// 使用示例：
/// ```swift
/// // 获取关注请求列表
/// let requests: [Account] = try await client.get(
///     endpoint: FollowRequests.list
/// )
///
/// // 批准关注请求
/// try await client.post(
///     endpoint: FollowRequests.accept(id: "123")
/// )
///
/// // 拒绝关注请求
/// try await client.post(
///     endpoint: FollowRequests.reject(id: "456")
/// )
/// ```
public enum FollowRequests: Endpoint {
  /// 获取关注请求列表
  ///
  /// 返回：Account 数组（请求关注你的账户）
  ///
  /// 使用场景：
  /// - 显示待处理的关注请求
  /// - 管理关注者
  ///
  /// API 路径：`/api/v1/follow_requests`
  /// HTTP 方法：GET
  case list
  
  /// 批准关注请求
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 批准后：
  /// - 对方成为你的关注者
  /// - 可以看到你的仅关注者可见帖子
  /// - 请求从列表中移除
  ///
  /// API 路径：`/api/v1/follow_requests/:id/authorize`
  /// HTTP 方法：POST
  case accept(id: String)
  
  /// 拒绝关注请求
  ///
  /// - Parameter id: 账户 ID
  ///
  /// 拒绝后：
  /// - 请求被删除
  /// - 对方不会收到通知
  /// - 对方可以再次发送请求
  ///
  /// API 路径：`/api/v1/follow_requests/:id/reject`
  /// HTTP 方法：POST
  case reject(id: String)

  public func path() -> String {
    switch self {
    case .list:
      "follow_requests"
    case let .accept(id):
      "follow_requests/\(id)/authorize"
    case let .reject(id):
      "follow_requests/\(id)/reject"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    nil
  }
}

// 文件功能：Mastodon 对话（私信）API 端点定义
//
// 核心职责：
// - 定义对话管理的 API 端点
// - 支持获取对话列表
// - 支持删除和标记已读
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：ConversationsView, MastodonClient

import Foundation

/// Mastodon 对话 API 端点
///
/// 定义了私信对话的管理操作。
///
/// 使用示例：
/// ```swift
/// // 获取对话列表
/// let conversations: [Conversation] = try await client.get(
///     endpoint: Conversations.conversations(maxId: nil)
/// )
///
/// // 标记对话为已读
/// try await client.post(
///     endpoint: Conversations.read(id: "123")
/// )
///
/// // 删除对话
/// try await client.delete(
///     endpoint: Conversations.delete(id: "123")
/// )
/// ```
public enum Conversations: Endpoint {
  /// 获取对话列表
  case conversations(maxId: String?)
  
  /// 删除对话
  case delete(id: String)
  
  /// 标记对话为已读
  case read(id: String)

  public func path() -> String {
    switch self {
    case .conversations:
      "conversations"
    case let .delete(id):
      "conversations/\(id)"
    case let .read(id):
      "conversations/\(id)/read"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .conversations(maxId):
      makePaginationParam(sinceId: nil, maxId: maxId, mindId: nil)
    default:
      nil
    }
  }
}

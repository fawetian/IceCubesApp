// 文件功能：定义 API 端点协议，用于构建 Mastodon API 请求
//
// 核心职责：
// - 提供统一的端点接口，所有 API 端点都实现此协议
// - 定义请求路径、查询参数和 JSON 请求体的规范
// - 提供分页参数的通用构建方法
//
// 技术要点：
// - Sendable：确保端点可以安全地跨并发边界传递
// - 协议扩展：为 jsonValue 提供默认实现（大多数端点不需要 JSON 请求体）
// - 分页支持：Mastodon API 使用 since_id/max_id/min_id 进行分页
//
// 使用示例：
// ```swift
// enum Timelines: Endpoint {
//     case home(sinceId: String?, maxId: String?)
//
//     func path() -> String {
//         return "timelines/home"
//     }
//
//     func queryItems() -> [URLQueryItem]? {
//         return makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: nil)
//     }
// }
// ```

import Foundation

/// API 端点协议
///
/// 所有 Mastodon API 端点都必须实现此协议。
/// 端点定义了 API 请求的路径、查询参数和可选的 JSON 请求体。
///
/// - Note: 实现此协议的类型必须是 Sendable，以确保并发安全
public protocol Endpoint: Sendable {
  /// 返回 API 端点的路径
  ///
  /// 例如：
  /// - "timelines/home" 对应 /api/v1/timelines/home
  /// - "accounts/verify_credentials" 对应 /api/v1/accounts/verify_credentials
  ///
  /// - Returns: 不包含 /api/v1 前缀的路径字符串
  func path() -> String

  /// 返回 URL 查询参数
  ///
  /// 用于 GET 请求的参数，如分页参数、过滤条件等
  ///
  /// - Returns: URLQueryItem 数组，如果没有参数则返回 nil
  func queryItems() -> [URLQueryItem]?

  /// 返回 JSON 请求体
  ///
  /// 用于 POST/PUT/PATCH 请求的 JSON 数据
  ///
  /// - Returns: 可编码的对象，如果不需要请求体则返回 nil
  var jsonValue: Encodable? { get }
}

// MARK: - 默认实现

extension Endpoint {
  /// 默认情况下，端点不需要 JSON 请求体
  ///
  /// 只有 POST/PUT/PATCH 等需要发送数据的端点才需要重写此属性
  public var jsonValue: Encodable? {
    nil
  }
}

// MARK: - 分页支持

extension Endpoint {
  /// 构建 Mastodon API 的分页参数
  ///
  /// Mastodon 使用三种 ID 进行分页：
  /// - since_id: 返回比此 ID 更新的结果（向前翻页）
  /// - max_id: 返回比此 ID 更旧的结果（向后翻页）
  /// - min_id: 返回比此 ID 更新的结果，但从最旧的开始（不常用）
  ///
  /// - Parameters:
  ///   - sinceId: 起始 ID，获取更新的内容
  ///   - maxId: 最大 ID，获取更旧的内容
  ///   - mindId: 最小 ID，获取更新的内容（从最旧开始）
  /// - Returns: URLQueryItem 数组，如果所有参数都为 nil 则返回 nil
  ///
  /// 使用示例：
  /// ```swift
  /// // 获取比 ID "12345" 更新的帖子
  /// makePaginationParam(sinceId: "12345", maxId: nil, mindId: nil)
  ///
  /// // 获取比 ID "67890" 更旧的帖子（向下滚动加载更多）
  /// makePaginationParam(sinceId: nil, maxId: "67890", mindId: nil)
  /// ```
  func makePaginationParam(sinceId: String?, maxId: String?, mindId: String?) -> [URLQueryItem]? {
    var params: [URLQueryItem] = []

    if let sinceId {
      params.append(.init(name: "since_id", value: sinceId))
    }
    if let maxId {
      params.append(.init(name: "max_id", value: maxId))
    }
    if let mindId {
      params.append(.init(name: "min_id", value: mindId))
    }

    return params.isEmpty ? nil : params
  }
}

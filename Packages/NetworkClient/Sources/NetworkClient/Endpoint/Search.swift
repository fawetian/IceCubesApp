// 文件功能：Mastodon 搜索 API 端点定义
//
// 核心职责：
// - 定义搜索相关的 API 端点
// - 支持全局搜索和账户搜索
// - 支持按类型过滤搜索结果
// - 支持跨实例搜索（resolve）
//
// 技术要点：
// - Search：枚举类型，定义搜索操作
// - EntityType：搜索结果类型（账户、标签、帖子）
// - resolve：自动解析跨实例 URL
// - following：限制搜索范围到关注的账户
//
// 搜索类型：
// - search：全局搜索（账户、标签、帖子）
// - accountsSearch：账户搜索
//
// 依赖关系：
// - 依赖：Foundation
// - 被依赖：SearchView, MastodonClient

import Foundation

/// Mastodon 搜索 API 端点
///
/// 定义了搜索功能的 API 端点。
///
/// 主要功能：
/// - **全局搜索**：搜索账户、标签和帖子
/// - **账户搜索**：专门搜索账户
/// - **类型过滤**：按结果类型过滤
/// - **跨实例解析**：自动解析其他实例的 URL
/// - **关注过滤**：只搜索关注的账户
///
/// 搜索特性：
/// - 支持模糊匹配
/// - 支持 @ 提及搜索
/// - 支持 # 标签搜索
/// - 支持 URL 解析
/// - 支持分页
///
/// 使用示例：
/// ```swift
/// // 全局搜索
/// let results: SearchResults = try await client.get(
///     endpoint: Search.search(
///         query: "swift",
///         type: nil,  // 搜索所有类型
///         offset: 0,
///         following: nil
///     )
/// )
///
/// // 只搜索账户
/// let accountResults: SearchResults = try await client.get(
///     endpoint: Search.search(
///         query: "@user",
///         type: .accounts,
///         offset: 0,
///         following: false
///     )
/// )
///
/// // 只搜索关注的账户
/// let followingResults: SearchResults = try await client.get(
///     endpoint: Search.search(
///         query: "alice",
///         type: .accounts,
///         offset: 0,
///         following: true
///     )
/// )
///
/// // 搜索标签
/// let tagResults: SearchResults = try await client.get(
///     endpoint: Search.search(
///         query: "#ios",
///         type: .hashtags,
///         offset: 0,
///         following: nil
///     )
/// )
///
/// // 解析跨实例 URL
/// let resolved: SearchResults = try await client.get(
///     endpoint: Search.search(
///         query: "https://mastodon.social/@user/123456",
///         type: nil,
///         offset: 0,
///         following: nil
///     )
/// )
/// ```
///
/// - Note: 搜索会自动启用 resolve 参数，支持跨实例 URL 解析
/// - SeeAlso: `SearchResults` 包含账户、标签和帖子的搜索结果
public enum Search: Endpoint {
  /// 搜索结果类型
  ///
  /// 用于过滤搜索结果。
  public enum EntityType: String, Sendable {
    /// 账户
    ///
    /// 搜索用户账户，匹配：
    /// - 显示名称
    /// - 用户名
    /// - 简介
    case accounts
    
    /// 标签
    ///
    /// 搜索话题标签，匹配：
    /// - 标签名称
    /// - 标签描述
    case hashtags
    
    /// 帖子
    ///
    /// 搜索帖子内容，匹配：
    /// - 帖子文本
    /// - 内容警告
    /// - 媒体描述
    case statuses
  }

  /// 全局搜索
  ///
  /// - Parameters:
  ///   - query: 搜索查询字符串
  ///   - type: 结果类型过滤（可选，nil 表示搜索所有类型）
  ///   - offset: 分页偏移量（可选）
  ///   - following: 是否只搜索关注的账户（可选）
  ///
  /// 返回：SearchResults 对象，包含：
  /// - accounts: 匹配的账户数组
  /// - hashtags: 匹配的标签数组
  /// - statuses: 匹配的帖子数组
  ///
  /// 搜索语法：
  /// - **普通文本**：模糊匹配
  /// - **@username**：搜索用户
  /// - **@username@instance**：搜索跨实例用户
  /// - **#hashtag**：搜索标签
  /// - **URL**：解析 Mastodon URL
  ///
  /// 跨实例搜索：
  /// - 自动启用 resolve 参数
  /// - 可以搜索其他实例的内容
  /// - 支持 URL 解析
  ///
  /// 示例查询：
  /// - "swift" → 搜索包含 "swift" 的所有内容
  /// - "@alice" → 搜索用户名包含 "alice" 的账户
  /// - "@bob@mastodon.social" → 搜索特定实例的用户
  /// - "#ios" → 搜索 iOS 标签
  /// - "https://mastodon.social/@user/123" → 解析帖子 URL
  ///
  /// API 路径：`/api/v2/search`
  /// HTTP 方法：GET
  case search(query: String, type: EntityType?, offset: Int?, following: Bool?)
  
  /// 账户搜索
  ///
  /// - Parameters:
  ///   - query: 搜索查询字符串
  ///   - type: 结果类型过滤（可选）
  ///   - offset: 分页偏移量（可选）
  ///   - following: 是否只搜索关注的账户（可选）
  ///
  /// 返回：SearchResults 对象（只包含账户结果）
  ///
  /// 与全局搜索的区别：
  /// - 专门用于账户搜索
  /// - 可能有不同的排序算法
  /// - 可能返回更多账户结果
  ///
  /// 使用场景：
  /// - 用户选择器
  /// - 提及建议
  /// - 关注推荐
  ///
  /// API 路径：`/api/v1/accounts/search`
  /// HTTP 方法：GET
  case accountsSearch(query: String, type: EntityType?, offset: Int?, following: Bool?)

  public func path() -> String {
    switch self {
    case .search:
      "search"
    case .accountsSearch:
      "accounts/search"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .search(query, type, offset, following),
      let .accountsSearch(query, type, offset, following):
      var params: [URLQueryItem] = [.init(name: "q", value: query)]
      if let type {
        params.append(.init(name: "type", value: type.rawValue))
      }
      if let offset {
        params.append(.init(name: "offset", value: String(offset)))
      }
      if let following {
        params.append(.init(name: "following", value: following ? "true" : "false"))
      }
      // 自动启用 resolve，支持跨实例 URL 解析
      params.append(.init(name: "resolve", value: "true"))
      return params
    }
  }
}

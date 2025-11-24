// 文件功能：Mastodon 时间线 API 端点定义
//
// 核心职责：
// - 定义所有时间线相关的 API 端点
// - 提供时间线的分页参数
// - 支持不同类型的时间线（主页、公共、列表、标签等）
// - 构建正确的 URL 路径和查询参数
//
// 技术要点：
// - Timelines：枚举类型，每个 case 代表一种时间线
// - 分页支持：使用 sinceId、maxId、minId 进行分页
// - 查询参数：通过 queryItems() 构建 URL 查询参数
// - 符合 Endpoint 协议：提供 path() 和 queryItems() 方法
//
// 时间线类型：
// - pub：公共时间线（本地或联邦）
// - home：主页时间线（关注的用户）
// - list：列表时间线（自定义列表）
// - hashtag：标签时间线（特定标签）
// - link：链接时间线（包含特定链接的帖子）
//
// 依赖关系：
// - 依赖：Foundation, Endpoint 协议
// - 被依赖：TimelineView, MastodonClient

import Foundation

/// Mastodon 时间线 API 端点
///
/// 定义了所有可用的时间线类型和它们的参数。
///
/// 时间线类型：
/// - **pub**: 公共时间线，显示所有公开的帖子
/// - **home**: 主页时间线，显示关注用户的帖子
/// - **list**: 列表时间线，显示特定列表中的帖子
/// - **hashtag**: 标签时间线，显示包含特定标签的帖子
/// - **link**: 链接时间线，显示包含特定链接的帖子
///
/// 分页机制：
/// 所有时间线都支持分页，使用以下参数：
/// - **sinceId**: 获取此 ID 之后的帖子（向上翻页）
/// - **maxId**: 获取此 ID 之前的帖子（向下翻页）
/// - **minId**: 获取此 ID 之后的帖子（刷新）
/// - **limit**: 限制返回的帖子数量（默认 20，最大 40）
///
/// 使用示例：
/// ```swift
/// // 获取主页时间线
/// let statuses: [Status] = try await client.get(
///     endpoint: Timelines.home(
///         sinceId: nil,
///         maxId: nil,
///         minId: nil,
///         limit: 20
///     )
/// )
///
/// // 加载更多（向下翻页）
/// let olderStatuses: [Status] = try await client.get(
///     endpoint: Timelines.home(
///         sinceId: nil,
///         maxId: statuses.last?.id,
///         minId: nil,
///         limit: 20
///     )
/// )
///
/// // 刷新（获取新帖子）
/// let newerStatuses: [Status] = try await client.get(
///     endpoint: Timelines.home(
///         sinceId: statuses.first?.id,
///         maxId: nil,
///         minId: nil,
///         limit: 20
///     )
/// )
///
/// // 获取本地公共时间线
/// let localStatuses: [Status] = try await client.get(
///     endpoint: Timelines.pub(
///         sinceId: nil,
///         maxId: nil,
///         minId: nil,
///         local: true,
///         limit: 20
///     )
/// )
///
/// // 获取标签时间线
/// let tagStatuses: [Status] = try await client.get(
///     endpoint: Timelines.hashtag(
///         tag: "swift",
///         additional: ["ios", "swiftui"],
///         maxId: nil,
///         minId: nil
///     )
/// )
/// ```
///
/// - Note: 时间线返回的帖子按时间倒序排列（最新的在前）
/// - SeeAlso: `Endpoint` 协议定义了端点的基本接口
public enum Timelines: Endpoint {
  /// 公共时间线
  ///
  /// 显示所有公开的帖子。
  ///
  /// - Parameters:
  ///   - sinceId: 获取此 ID 之后的帖子（可选）
  ///   - maxId: 获取此 ID 之前的帖子（可选）
  ///   - minId: 获取此 ID 之后的帖子，用于刷新（可选）
  ///   - local: 是否只显示本实例的帖子
  ///     - true: 本地时间线（只显示本实例用户的帖子）
  ///     - false: 联邦时间线（显示所有已知实例的帖子）
  ///   - limit: 限制返回的帖子数量（可选，默认 20，最大 40）
  ///
  /// 使用场景：
  /// - 探索公共内容
  /// - 发现新用户和话题
  /// - 了解实例或联邦宇宙的动态
  ///
  /// API 路径：`/api/v1/timelines/public`
  case pub(sinceId: String?, maxId: String?, minId: String?, local: Bool, limit: Int?)
  
  /// 主页时间线
  ///
  /// 显示当前用户关注的账户的帖子。
  ///
  /// - Parameters:
  ///   - sinceId: 获取此 ID 之后的帖子（可选）
  ///   - maxId: 获取此 ID 之前的帖子（可选）
  ///   - minId: 获取此 ID 之后的帖子，用于刷新（可选）
  ///   - limit: 限制返回的帖子数量（可选，默认 20，最大 40）
  ///
  /// 特点：
  /// - 需要认证
  /// - 只显示关注用户的帖子
  /// - 包含转发的帖子（除非设置了隐藏转发）
  /// - 按时间倒序排列
  ///
  /// 使用场景：
  /// - 应用的主要时间线
  /// - 查看关注用户的最新动态
  /// - 下拉刷新和无限滚动
  ///
  /// API 路径：`/api/v1/timelines/home`
  case home(sinceId: String?, maxId: String?, minId: String?, limit: Int?)
  
  /// 列表时间线
  ///
  /// 显示特定列表中账户的帖子。
  ///
  /// - Parameters:
  ///   - listId: 列表的 ID
  ///   - sinceId: 获取此 ID 之后的帖子（可选）
  ///   - maxId: 获取此 ID 之前的帖子（可选）
  ///   - minId: 获取此 ID 之后的帖子，用于刷新（可选）
  ///
  /// 列表功能：
  /// - 用户可以创建多个列表
  /// - 每个列表包含选定的账户
  /// - 列表可以设置回复策略（显示所有回复、只显示列表内回复等）
  /// - 列表可以设置为独占（不在主页显示）
  ///
  /// 使用场景：
  /// - 组织关注的账户（如"朋友"、"工作"、"新闻"）
  /// - 减少主页时间线的噪音
  /// - 专注于特定群体的内容
  ///
  /// API 路径：`/api/v1/timelines/list/:listId`
  case list(listId: String, sinceId: String?, maxId: String?, minId: String?)
  
  /// 标签时间线
  ///
  /// 显示包含特定标签的帖子。
  ///
  /// - Parameters:
  ///   - tag: 主标签（不含 # 符号）
  ///   - additional: 额外的标签（可选），帖子需要包含主标签和任一额外标签
  ///   - maxId: 获取此 ID 之前的帖子（可选）
  ///   - minId: 获取此 ID 之后的帖子，用于刷新（可选）
  ///
  /// 标签功能：
  /// - 不需要认证（公开标签）
  /// - 可以关注标签（关注后会出现在主页时间线）
  /// - 支持多标签组合（主标签 + 任一额外标签）
  /// - 按时间倒序排列
  ///
  /// 使用场景：
  /// - 探索特定话题
  /// - 发现相关内容
  /// - 跟踪热门话题
  ///
  /// 示例：
  /// - tag: "swift", additional: ["ios", "swiftui"]
  ///   → 显示包含 #swift 且包含 #ios 或 #swiftui 的帖子
  ///
  /// API 路径：`/api/v1/timelines/tag/:tag`
  case hashtag(tag: String, additional: [String]?, maxId: String?, minId: String?)
  
  /// 链接时间线
  ///
  /// 显示包含特定链接的帖子。
  ///
  /// - Parameters:
  ///   - url: 要搜索的链接
  ///   - sinceId: 获取此 ID 之后的帖子（可选）
  ///   - maxId: 获取此 ID 之前的帖子（可选）
  ///   - minId: 获取此 ID 之后的帖子，用于刷新（可选）
  ///
  /// 链接功能：
  /// - 查找分享了特定链接的所有帖子
  /// - 查看链接的讨论和评论
  /// - 发现相关内容
  ///
  /// 使用场景：
  /// - 查看某篇文章的讨论
  /// - 发现分享了相同链接的用户
  /// - 追踪链接的传播
  ///
  /// API 路径：`/api/v1/timelines/link`
  case link(url: URL, sinceId: String?, maxId: String?, minId: String?)

  /// 返回 API 端点的路径
  ///
  /// - Returns: 相对于 API 基础 URL 的路径
  ///
  /// 路径格式：
  /// - pub: `timelines/public`
  /// - home: `timelines/home`
  /// - list: `timelines/list/:listId`
  /// - hashtag: `timelines/tag/:tag`
  /// - link: `timelines/link`
  ///
  /// 完整 URL 示例：
  /// - `https://mastodon.social/api/v1/timelines/public`
  /// - `https://mastodon.social/api/v1/timelines/home`
  /// - `https://mastodon.social/api/v1/timelines/list/123`
  /// - `https://mastodon.social/api/v1/timelines/tag/swift`
  /// - `https://mastodon.social/api/v1/timelines/link`
  public func path() -> String {
    switch self {
    case .pub:
      "timelines/public"
    case .home:
      "timelines/home"
    case let .list(listId, _, _, _):
      "timelines/list/\(listId)"
    case let .hashtag(tag, _, _, _):
      "timelines/tag/\(tag)"
    case .link:
      "timelines/link"
    }
  }

  /// 返回 URL 查询参数
  ///
  /// - Returns: URL 查询参数数组，如果没有参数则返回 nil
  ///
  /// 查询参数说明：
  ///
  /// **分页参数**（所有时间线都支持）：
  /// - `since_id`: 获取此 ID 之后的帖子
  /// - `max_id`: 获取此 ID 之前的帖子
  /// - `min_id`: 获取此 ID 之后的帖子（用于刷新）
  ///
  /// **公共时间线特有参数**：
  /// - `local`: "true" 或 "false"，是否只显示本地帖子
  /// - `limit`: 限制返回的帖子数量
  ///
  /// **主页时间线特有参数**：
  /// - `limit`: 限制返回的帖子数量
  ///
  /// **标签时间线特有参数**：
  /// - `any[]`: 额外的标签（可以有多个），帖子需要包含主标签和任一额外标签
  ///
  /// **链接时间线特有参数**：
  /// - `url`: 要搜索的链接 URL
  ///
  /// 查询参数示例：
  /// ```
  /// // 公共时间线
  /// ?local=true&limit=20&max_id=123456
  ///
  /// // 主页时间线
  /// ?since_id=123456&limit=20
  ///
  /// // 标签时间线
  /// ?any[]=ios&any[]=swiftui&max_id=123456
  ///
  /// // 链接时间线
  /// ?url=https://example.com/article&max_id=123456
  /// ```
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .pub(sinceId, maxId, minId, local, limit):
      // 公共时间线：分页 + local + limit
      var params = makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: minId) ?? []
      params.append(.init(name: "local", value: local ? "true" : "false"))
      if let limit {
        params.append(.init(name: "limit", value: String(limit)))
      }
      return params
      
    case let .home(sinceId, maxId, minId, limit):
      // 主页时间线：分页 + limit
      var params = makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: minId) ?? []
      if let limit {
        params.append(.init(name: "limit", value: String(limit)))
      }
      return params
      
    case let .list(_, sinceId, maxId, minId):
      // 列表时间线：只有分页参数
      return makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: minId)
      
    case let .hashtag(_, additional, maxId, minId):
      // 标签时间线：分页 + 额外标签
      var params = makePaginationParam(sinceId: nil, maxId: maxId, mindId: minId) ?? []
      // 添加额外标签（any[] 参数可以有多个）
      params.append(
        contentsOf: (additional ?? [])
          .map { URLQueryItem(name: "any[]", value: $0) })
      return params
      
    case let .link(url, sinceId, maxId, minId):
      // 链接时间线：分页 + url
      var params = makePaginationParam(sinceId: sinceId, maxId: maxId, mindId: minId) ?? []
      params.append(.init(name: "url", value: url.absoluteString))
      return params
    }
  }
}

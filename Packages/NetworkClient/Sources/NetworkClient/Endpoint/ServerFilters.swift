// 文件功能：Mastodon 内容过滤 API 端点定义
//
// 核心职责：
// - 定义内容过滤器的 API 端点
// - 支持创建、更新、删除过滤器
// - 管理过滤关键词
// - 配置过滤规则和上下文
//
// 技术要点：
// - ServerFilters：枚举类型，定义过滤器操作
// - ServerFilterData：过滤器数据结构
// - Context：过滤器应用的上下文（主页、通知等）
// - Action：过滤动作（隐藏或警告）
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：FiltersView, MastodonClient

import Foundation
import Models

/// Mastodon 内容过滤 API 端点
///
/// 定义了内容过滤器的管理操作。
///
/// 内容过滤：
/// - 根据关键词过滤帖子
/// - 可应用于不同上下文
/// - 支持隐藏或警告
/// - 可设置过期时间
///
/// 使用示例：
/// ```swift
/// // 获取所有过滤器
/// let filters: [ServerFilter] = try await client.get(
///     endpoint: ServerFilters.filters
/// )
///
/// // 创建新过滤器
/// let newFilter: ServerFilter = try await client.post(
///     endpoint: ServerFilters.createFilter(
///         json: ServerFilterData(
///             title: "政治话题",
///             context: [.home, .public],
///             filterAction: .hide,
///             expiresIn: nil
///         )
///     )
/// )
///
/// // 添加关键词
/// try await client.post(
///     endpoint: ServerFilters.addKeyword(
///         filter: newFilter.id,
///         keyword: "politics",
///         wholeWord: true
///     )
/// )
/// ```
public enum ServerFilters: Endpoint {
  /// 获取所有过滤器
  ///
  /// 返回：ServerFilter 数组
  ///
  /// API 路径：`/api/v2/filters`
  /// HTTP 方法：GET
  case filters
  
  /// 创建新过滤器
  ///
  /// - Parameter json: 过滤器数据
  ///
  /// 返回：新创建的 ServerFilter 对象
  ///
  /// API 路径：`/api/v2/filters`
  /// HTTP 方法：POST
  case createFilter(json: ServerFilterData)
  
  /// 更新过滤器
  ///
  /// - Parameters:
  ///   - id: 过滤器 ID
  ///   - json: 更新后的过滤器数据
  ///
  /// 返回：更新后的 ServerFilter 对象
  ///
  /// API 路径：`/api/v2/filters/:id`
  /// HTTP 方法：PUT
  case editFilter(id: String, json: ServerFilterData)
  
  /// 添加过滤关键词
  ///
  /// - Parameters:
  ///   - filter: 过滤器 ID
  ///   - keyword: 关键词
  ///   - wholeWord: 是否全词匹配
  ///
  /// 全词匹配：
  /// - true: 只匹配完整单词（"cat" 不匹配 "category"）
  /// - false: 部分匹配（"cat" 匹配 "category"）
  ///
  /// API 路径：`/api/v2/filters/:id/keywords`
  /// HTTP 方法：POST
  case addKeyword(filter: String, keyword: String, wholeWord: Bool)
  
  /// 删除过滤关键词
  ///
  /// - Parameter id: 关键词 ID
  ///
  /// API 路径：`/api/v2/filters/keywords/:id`
  /// HTTP 方法：DELETE
  case removeKeyword(id: String)
  
  /// 获取单个过滤器
  ///
  /// - Parameter id: 过滤器 ID
  ///
  /// 返回：ServerFilter 对象
  ///
  /// API 路径：`/api/v2/filters/:id`
  /// HTTP 方法：GET
  case filter(id: String)

  public func path() -> String {
    switch self {
    case .filters:
      "filters"
    case .createFilter:
      "filters"
    case let .filter(id):
      "filters/\(id)"
    case let .editFilter(id, _):
      "filters/\(id)"
    case let .addKeyword(id, _, _):
      "filters/\(id)/keywords"
    case let .removeKeyword(id):
      "filters/keywords/\(id)"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .addKeyword(_, keyword, wholeWord):
      [
        .init(name: "keyword", value: keyword),
        .init(name: "whole_word", value: wholeWord ? "true" : "false"),
      ]
    default:
      nil
    }
  }

  public var jsonValue: Encodable? {
    switch self {
    case let .createFilter(json):
      json
    case let .editFilter(_, json):
      json
    default:
      nil
    }
  }
}

/// 过滤器数据结构
///
/// 用于创建和更新过滤器。
public struct ServerFilterData: Encodable, Sendable {
  /// 过滤器标题
  ///
  /// 用于识别过滤器的名称。
  public let title: String
  
  /// 应用上下文
  ///
  /// 过滤器在哪些地方生效：
  /// - .home: 主页时间线
  /// - .notifications: 通知
  /// - .public: 公共时间线
  /// - .thread: 对话线程
  /// - .account: 账户页面
  public let context: [ServerFilter.Context]
  
  /// 过滤动作
  ///
  /// 匹配时的处理方式：
  /// - .hide: 完全隐藏
  /// - .warn: 显示警告，可点击查看
  public let filterAction: ServerFilter.Action
  
  /// 过期时间（秒）
  ///
  /// 注意：使用 String 类型是为了支持清除过期时间。
  /// - nil: 不设置过期时间
  /// - "": 清除现有过期时间（永久有效）
  /// - "3600": 1 小时后过期
  /// - "86400": 24 小时后过期
  ///
  /// 技术说明：
  /// API 通常使用 Int，但更新时无法发送空值来清除过期时间。
  /// 使用 String 可以发送空字符串来删除过期设置。
  public let expiresIn: String?

  public init(
    title: String,
    context: [ServerFilter.Context],
    filterAction: ServerFilter.Action,
    expiresIn: String?
  ) {
    self.title = title
    self.context = context
    self.filterAction = filterAction
    self.expiresIn = expiresIn
  }
}

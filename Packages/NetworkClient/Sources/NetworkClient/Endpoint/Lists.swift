// 文件功能：Mastodon 列表 API 端点定义
//
// 核心职责：
// - 定义列表管理的 API 端点
// - 支持列表的创建、更新、删除
// - 支持列表成员的管理
// - 提供列表配置选项
//
// 技术要点：
// - Lists：枚举类型，定义列表操作
// - RepliesPolicy：回复策略（显示哪些回复）
// - exclusive：独占模式（不在主页显示）
// - 列表成员管理
//
// 列表操作类型：
// - lists：获取所有列表
// - list：获取单个列表
// - createList：创建新列表
// - updateList：更新列表设置
// - accounts：获取列表成员
// - updateAccounts：更新列表成员
//
// 依赖关系：
// - 依赖：Foundation, Models
// - 被依赖：ListsView, MastodonClient

import Foundation
import Models

/// Mastodon 列表 API 端点
///
/// 定义了列表管理的所有操作。
///
/// 主要功能：
/// - **列表管理**：创建、更新、删除列表
/// - **成员管理**：添加、移除列表成员
/// - **配置选项**：回复策略、独占模式
///
/// 列表功能：
/// - 组织关注的账户
/// - 创建自定义时间线
/// - 减少主页噪音
/// - 专注特定群体
///
/// 使用示例：
/// ```swift
/// // 获取所有列表
/// let lists: [List] = try await client.get(
///     endpoint: Lists.lists
/// )
///
/// // 创建新列表
/// let newList: List = try await client.post(
///     endpoint: Lists.createList(
///         title: "iOS 开发者",
///         repliesPolicy: .list,
///         exclusive: false
///     )
/// )
///
/// // 添加成员到列表
/// try await client.post(
///     endpoint: Lists.updateAccounts(
///         listId: newList.id,
///         accounts: ["123", "456", "789"]
///     )
/// )
///
/// // 更新列表设置
/// let updatedList: List = try await client.put(
///     endpoint: Lists.updateList(
///         id: newList.id,
///         title: "Swift 开发者",
///         repliesPolicy: .followed,
///         exclusive: true
///     )
/// )
/// ```
///
/// - Note: 列表是组织时间线的强大工具
/// - SeeAlso: `List.RepliesPolicy` 定义回复显示策略
public enum Lists: Endpoint {
  /// 获取所有列表
  ///
  /// 返回：List 数组（当前用户创建的所有列表）
  ///
  /// 使用场景：
  /// - 显示列表选择器
  /// - 列表管理界面
  /// - 侧边栏导航
  ///
  /// API 路径：`/api/v1/lists`
  /// HTTP 方法：GET
  case lists
  
  /// 获取单个列表详情
  ///
  /// - Parameter id: 列表 ID
  ///
  /// 返回：List 对象
  ///
  /// API 路径：`/api/v1/lists/:id`
  /// HTTP 方法：GET
  case list(id: String)
  
  /// 创建新列表
  ///
  /// - Parameters:
  ///   - title: 列表标题
  ///   - repliesPolicy: 回复策略
  ///   - exclusive: 是否独占（不在主页显示）
  ///
  /// 返回：新创建的 List 对象
  ///
  /// 回复策略：
  /// - **.followed**: 显示你关注的人的回复
  /// - **.list**: 只显示列表内成员之间的回复
  /// - **.none**: 不显示任何回复
  ///
  /// 独占模式：
  /// - true: 列表成员的帖子只在列表中显示，不在主页显示
  /// - false: 列表成员的帖子同时在列表和主页显示
  ///
  /// 使用场景：
  /// - "工作"列表：只看工作相关内容
  /// - "朋友"列表：只看朋友的帖子
  /// - "新闻"列表：只看新闻账户
  ///
  /// API 路径：`/api/v1/lists`
  /// HTTP 方法：POST
  case createList(title: String, repliesPolicy: List.RepliesPolicy, exclusive: Bool)
  
  /// 更新列表设置
  ///
  /// - Parameters:
  ///   - id: 列表 ID
  ///   - title: 新标题
  ///   - repliesPolicy: 新回复策略
  ///   - exclusive: 新独占设置
  ///
  /// 返回：更新后的 List 对象
  ///
  /// 可更新的设置：
  /// - 标题
  /// - 回复策略
  /// - 独占模式
  ///
  /// API 路径：`/api/v1/lists/:id`
  /// HTTP 方法：PUT
  case updateList(id: String, title: String, repliesPolicy: List.RepliesPolicy, exclusive: Bool)
  
  /// 获取列表成员
  ///
  /// - Parameter listId: 列表 ID
  ///
  /// 返回：Account 数组（列表中的所有账户）
  ///
  /// 使用场景：
  /// - 显示列表成员列表
  /// - 管理列表成员
  /// - 检查账户是否在列表中
  ///
  /// API 路径：`/api/v1/lists/:listId/accounts`
  /// HTTP 方法：GET
  case accounts(listId: String)
  
  /// 更新列表成员
  ///
  /// - Parameters:
  ///   - listId: 列表 ID
  ///   - accounts: 账户 ID 数组
  ///
  /// 操作：
  /// - 添加指定的账户到列表
  /// - 不会移除现有成员
  /// - 可以批量添加
  ///
  /// 使用场景：
  /// - 添加新成员到列表
  /// - 批量导入账户
  ///
  /// 移除成员：
  /// 需要使用 DELETE 方法调用相同的端点
  ///
  /// API 路径：`/api/v1/lists/:listId/accounts`
  /// HTTP 方法：POST
  case updateAccounts(listId: String, accounts: [String])

  public func path() -> String {
    switch self {
    case .lists, .createList:
      "lists"
    case .list(let id), .updateList(let id, _, _, _):
      "lists/\(id)"
    case .accounts(let listId):
      "lists/\(listId)/accounts"
    case .updateAccounts(let listId, _):
      "lists/\(listId)/accounts"
    }
  }

  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case .accounts:
      return [.init(name: "limit", value: String(0))]
    case .createList(let title, let repliesPolicy, let exclusive),
      .updateList(_, let title, let repliesPolicy, let exclusive):
      return [
        .init(name: "title", value: title),
        .init(name: "replies_policy", value: repliesPolicy.rawValue),
        .init(name: "exclusive", value: exclusive ? "true" : "false"),
      ]
    case .updateAccounts(_, let accounts):
      var params: [URLQueryItem] = []
      for account in accounts {
        params.append(.init(name: "account_ids[]", value: account))
      }
      return params
    default:
      return nil
    }
  }
}

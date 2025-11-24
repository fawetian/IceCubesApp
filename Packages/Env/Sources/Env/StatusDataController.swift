// 文件功能：帖子数据控制器
//
// 核心职责：
// - 管理单个帖子的交互状态（点赞、转发、书签）
// - 处理帖子的交互操作（切换点赞、转发、书签）
// - 缓存和复用帖子控制器实例
// - 同步帖子状态和计数
// - 提供乐观更新和错误回滚
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - @MainActor：确保所有操作在主线程执行，保证 UI 安全
// - 协议抽象：StatusDataControlling 定义控制器接口
// - 缓存机制：使用 NSMutableDictionary 缓存控制器实例
// - 乐观更新：先更新 UI，再发送网络请求
// - 错误回滚：请求失败时恢复原状态
//
// 架构设计：
// - StatusDataControlling：协议定义控制器接口
// - StatusDataControllerProvider：单例提供者，管理控制器缓存
// - StatusDataController：具体实现，管理单个帖子的状态
//
// 使用场景：
// - 帖子列表中的交互按钮
// - 帖子详情页的操作
// - 时间线中的快速操作
//
// 依赖关系：
// - 依赖：Foundation, Models, NetworkClient, SwiftUI
// - 被依赖：帖子视图、时间线视图等需要交互的组件

import Foundation
import Models
import NetworkClient
import Observation
import SwiftUI

/// 帖子数据控制协议
///
/// 定义了帖子交互状态和操作的接口。
///
/// 状态属性：
/// - **isReblogged**：是否已转发
/// - **isBookmarked**：是否已收藏
/// - **isFavorited**：是否已点赞
/// - **计数属性**：点赞数、转发数、回复数
///
/// 操作方法：
/// - **toggleBookmark**：切换收藏状态
/// - **toggleReblog**：切换转发状态
/// - **toggleFavorite**：切换点赞状态
///
/// 使用场景：
/// - 定义控制器的标准接口
/// - 支持协议导向编程
/// - 便于测试和模拟
@MainActor
public protocol StatusDataControlling {
  /// 是否已转发
  ///
  /// 表示当前用户是否已转发此帖子。
  var isReblogged: Bool { get set }
  
  /// 是否已收藏
  ///
  /// 表示当前用户是否已将此帖子加入书签。
  var isBookmarked: Bool { get set }
  
  /// 是否已点赞
  ///
  /// 表示当前用户是否已点赞此帖子。
  var isFavorited: Bool { get set }

  /// 点赞数
  ///
  /// 此帖子的总点赞数量。
  var favoritesCount: Int { get set }
  
  /// 转发数
  ///
  /// 此帖子的总转发数量。
  var reblogsCount: Int { get set }
  
  /// 回复数
  ///
  /// 此帖子的总回复数量。
  var repliesCount: Int { get set }

  /// 切换收藏状态
  ///
  /// 添加或移除帖子的书签。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选）
  func toggleBookmark(remoteStatus: String?) async
  
  /// 切换转发状态
  ///
  /// 转发或取消转发帖子。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选）
  func toggleReblog(remoteStatus: String?) async
  
  /// 切换点赞状态
  ///
  /// 点赞或取消点赞帖子。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选）
  func toggleFavorite(remoteStatus: String?) async
}

/// 帖子数据控制器提供者
///
/// 管理帖子控制器的创建和缓存，确保每个帖子只有一个控制器实例。
///
/// 主要功能：
/// - **控制器缓存**：避免重复创建控制器
/// - **实例复用**：相同帖子使用相同控制器
/// - **批量更新**：支持批量更新多个帖子的状态
/// - **内存管理**：使用 NSMutableDictionary 管理缓存
///
/// 缓存策略：
/// - 使用 (statusId, client) 作为缓存键
/// - 同一帖子在不同客户端有不同的控制器
/// - 控制器在内存中持久化，直到应用退出
///
/// 使用方式：
/// ```swift
/// let provider = StatusDataControllerProvider.shared
/// let controller = provider.dataController(for: status, client: client)
///
/// // 使用控制器
/// await controller.toggleFavorite(remoteStatus: nil)
///
/// // 批量更新
/// provider.updateDataControllers(for: statuses, client: client)
/// ```
///
/// - Note: 使用单例模式，通过 `StatusDataControllerProvider.shared` 访问
/// - Important: 所有操作都在主线程执行
@MainActor
public final class StatusDataControllerProvider {
  /// 单例实例
  ///
  /// 全局共享的控制器提供者。
  public static let shared = StatusDataControllerProvider()

  /// 控制器缓存
  ///
  /// 使用 NSMutableDictionary 存储控制器实例。
  ///
  /// 键：CacheKey（statusId + client）
  /// 值：StatusDataController 实例
  private var cache: NSMutableDictionary = [:]

  /// 缓存键
  ///
  /// 组合帖子 ID 和客户端作为唯一标识。
  ///
  /// 设计原因：
  /// - 同一帖子在不同账户下可能有不同的状态
  /// - 需要区分不同客户端的控制器
  private struct CacheKey: Hashable {
    /// 帖子 ID
    let statusId: String
    /// Mastodon 客户端
    let client: MastodonClient
  }

  /// 获取帖子的数据控制器
  ///
  /// 从缓存中获取或创建新的控制器实例。
  ///
  /// - Parameters:
  ///   - status: 帖子对象
  ///   - client: Mastodon 客户端
  /// - Returns: 帖子的数据控制器
  ///
  /// 执行流程：
  /// 1. 构建缓存键（statusId + client）
  /// 2. 检查缓存中是否存在控制器
  /// 3. 如果存在，直接返回
  /// 4. 如果不存在，创建新控制器
  /// 5. 将新控制器加入缓存
  /// 6. 返回控制器
  ///
  /// 使用场景：
  /// - 帖子视图初始化时
  /// - 需要操作帖子状态时
  ///
  /// 示例：
  /// ```swift
  /// let controller = StatusDataControllerProvider.shared.dataController(
  ///     for: status,
  ///     client: client
  /// )
  /// await controller.toggleFavorite(remoteStatus: nil)
  /// ```
  public func dataController(for status: any AnyStatus, client: MastodonClient)
    -> StatusDataController
  {
    let key = CacheKey(statusId: status.id, client: client)
    if let controller = cache[key] as? StatusDataController {
      return controller
    }
    let controller = StatusDataController(status: status, client: client)
    cache[key] = controller
    return controller
  }

  /// 批量更新数据控制器
  ///
  /// 更新多个帖子的控制器状态。
  ///
  /// - Parameters:
  ///   - statuses: 帖子列表
  ///   - client: Mastodon 客户端
  ///
  /// 执行流程：
  /// 1. 遍历所有帖子
  /// 2. 处理转发帖子（使用原始帖子）
  /// 3. 获取或创建控制器
  /// 4. 更新控制器状态
  ///
  /// 使用场景：
  /// - 时间线刷新后
  /// - 批量加载帖子后
  /// - 需要同步多个帖子状态时
  ///
  /// 示例：
  /// ```swift
  /// let statuses = try await client.get(endpoint: Timelines.home())
  /// StatusDataControllerProvider.shared.updateDataControllers(
  ///     for: statuses,
  ///     client: client
  /// )
  /// ```
  ///
  /// - Note: 自动处理转发帖子，使用原始帖子的状态
  public func updateDataControllers(for statuses: [Status], client: MastodonClient) {
    for status in statuses {
      // 如果是转发，使用原始帖子
      let realStatus: AnyStatus = status.reblog ?? status
      let controller = dataController(for: realStatus, client: client)
      controller.updateFrom(status: realStatus)
    }
  }
}

/// 帖子数据控制器
///
/// 管理单个帖子的交互状态和操作。
///
/// 主要功能：
/// - **状态管理**：跟踪点赞、转发、收藏状态
/// - **计数管理**：管理点赞数、转发数、回复数
/// - **交互操作**：处理点赞、转发、收藏的切换
/// - **乐观更新**：先更新 UI，再发送请求
/// - **错误回滚**：请求失败时恢复原状态
///
/// 乐观更新策略：
/// 1. 立即更新本地状态和计数
/// 2. 发送网络请求
/// 3. 请求成功：使用服务器返回的最新状态
/// 4. 请求失败：回滚到原状态
///
/// 使用方式：
/// ```swift
/// // 获取控制器
/// let controller = StatusDataControllerProvider.shared.dataController(
///     for: status,
///     client: client
/// )
///
/// // 切换点赞
/// await controller.toggleFavorite(remoteStatus: nil)
///
/// // 在视图中使用
/// Button {
///     Task {
///         await controller.toggleFavorite(remoteStatus: nil)
///     }
/// } label: {
///     Image(systemName: controller.isFavorited ? "star.fill" : "star")
///     Text("\(controller.favoritesCount)")
/// }
/// ```
///
/// - Note: 所有操作都在主线程执行，确保 UI 安全
/// - Important: 使用 @Observable 自动触发 UI 更新
@MainActor
@Observable public final class StatusDataController: StatusDataControlling {
  /// 关联的帖子
  ///
  /// 此控制器管理的帖子对象。
  private let status: AnyStatus
  
  /// Mastodon 客户端
  ///
  /// 用于执行 API 请求的客户端。
  private let client: MastodonClient

  /// 是否已转发
  ///
  /// 当前用户是否已转发此帖子。
  public var isReblogged: Bool
  
  /// 是否已收藏
  ///
  /// 当前用户是否已将此帖子加入书签。
  public var isBookmarked: Bool
  
  /// 是否已点赞
  ///
  /// 当前用户是否已点赞此帖子。
  public var isFavorited: Bool
  
  /// 帖子内容
  ///
  /// HTML 格式的帖子内容。
  public var content: HTMLString

  /// 点赞数
  ///
  /// 此帖子的总点赞数量。
  public var favoritesCount: Int
  
  /// 转发数
  ///
  /// 此帖子的总转发数量。
  public var reblogsCount: Int
  
  /// 回复数
  ///
  /// 此帖子的总回复数量。
  public var repliesCount: Int
  
  /// 引用数
  ///
  /// 此帖子被引用的次数。
  public var quotesCount: Int

  /// 初始化控制器
  ///
  /// 从帖子对象创建控制器，初始化所有状态。
  ///
  /// - Parameters:
  ///   - status: 帖子对象
  ///   - client: Mastodon 客户端
  ///
  /// 初始化内容：
  /// - 交互状态（点赞、转发、收藏）
  /// - 计数数据（点赞数、转发数、回复数、引用数）
  /// - 帖子内容
  init(status: AnyStatus, client: MastodonClient) {
    self.status = status
    self.client = client

    isReblogged = status.reblogged == true
    isBookmarked = status.bookmarked == true
    isFavorited = status.favourited == true

    reblogsCount = status.reblogsCount
    repliesCount = status.repliesCount
    favoritesCount = status.favouritesCount
    quotesCount = status.quotesCount ?? 0
    content = status.content
  }

  /// 从帖子对象更新状态
  ///
  /// 使用新的帖子数据更新控制器的所有状态。
  ///
  /// - Parameter status: 新的帖子对象
  ///
  /// 更新内容：
  /// - 交互状态（点赞、转发、收藏）
  /// - 计数数据（点赞数、转发数、回复数、引用数）
  /// - 帖子内容
  ///
  /// 使用场景：
  /// - 时间线刷新后同步状态
  /// - 批量更新帖子数据
  /// - 从服务器获取最新状态后
  ///
  /// - Note: 这个方法会触发 UI 更新
  public func updateFrom(status: AnyStatus) {
    isReblogged = status.reblogged == true
    isBookmarked = status.bookmarked == true
    isFavorited = status.favourited == true

    reblogsCount = status.reblogsCount
    repliesCount = status.repliesCount
    favoritesCount = status.favouritesCount
    quotesCount = status.quotesCount ?? 0
    content = status.content
  }

  /// 切换点赞状态
  ///
  /// 点赞或取消点赞帖子，使用乐观更新策略。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选，用于跨实例操作）
  ///
  /// 执行流程：
  /// 1. 检查客户端是否已认证
  /// 2. 立即切换点赞状态（乐观更新）
  /// 3. 使用动画更新点赞数
  /// 4. 发送 API 请求
  /// 5. 成功：使用服务器返回的最新状态
  /// 6. 失败：回滚状态和计数
  ///
  /// 乐观更新：
  /// - 先更新 UI，提供即时反馈
  /// - 再发送网络请求
  /// - 失败时回滚，保证数据一致性
  ///
  /// 使用场景：
  /// - 用户点击点赞按钮
  /// - 快速操作菜单中的点赞
  /// - 滑动手势点赞
  ///
  /// 示例：
  /// ```swift
  /// Button {
  ///     Task {
  ///         await controller.toggleFavorite(remoteStatus: nil)
  ///     }
  /// } label: {
  ///     Image(systemName: controller.isFavorited ? "star.fill" : "star")
  ///         .foregroundColor(controller.isFavorited ? .yellow : .gray)
  ///     Text("\(controller.favoritesCount)")
  /// }
  /// ```
  ///
  /// - Note: 使用 withAnimation 提供流畅的计数变化动画
  public func toggleFavorite(remoteStatus: String?) async {
    guard client.isAuth else { return }
    // 乐观更新：立即切换状态
    isFavorited.toggle()
    let id = remoteStatus ?? status.id
    let endpoint = isFavorited ? Statuses.favorite(id: id) : Statuses.unfavorite(id: id)
    // 使用动画更新计数
    withAnimation(.default) {
      favoritesCount += isFavorited ? 1 : -1
    }
    do {
      // 发送 API 请求
      let status: Status = try await client.post(endpoint: endpoint)
      // 使用服务器返回的最新状态
      updateFrom(status: status)
    } catch {
      // 请求失败，回滚状态
      isFavorited.toggle()
      favoritesCount += isFavorited ? -1 : 1
    }
  }

  /// 切换转发状态
  ///
  /// 转发或取消转发帖子，使用乐观更新策略。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选，用于跨实例操作）
  ///
  /// 执行流程：
  /// 1. 检查客户端是否已认证
  /// 2. 立即切换转发状态（乐观更新）
  /// 3. 使用动画更新转发数
  /// 4. 发送 API 请求
  /// 5. 成功：使用服务器返回的最新状态
  /// 6. 失败：回滚状态和计数
  ///
  /// 特殊处理：
  /// - 转发操作返回的是转发帖子本身
  /// - 需要提取原始帖子（reblog）的状态
  ///
  /// 使用场景：
  /// - 用户点击转发按钮
  /// - 快速操作菜单中的转发
  /// - 滑动手势转发
  ///
  /// 示例：
  /// ```swift
  /// Button {
  ///     Task {
  ///         await controller.toggleReblog(remoteStatus: nil)
  ///     }
  /// } label: {
  ///     Image(systemName: "arrow.2.squarepath")
  ///         .foregroundColor(controller.isReblogged ? .green : .gray)
  ///     Text("\(controller.reblogsCount)")
  /// }
  /// ```
  ///
  /// - Note: 转发操作会在用户的时间线中创建一条新帖子
  public func toggleReblog(remoteStatus: String?) async {
    guard client.isAuth else { return }
    // 乐观更新：立即切换状态
    isReblogged.toggle()
    let id = remoteStatus ?? status.id
    let endpoint = isReblogged ? Statuses.reblog(id: id) : Statuses.unreblog(id: id)
    // 使用动画更新计数
    withAnimation(.default) {
      reblogsCount += isReblogged ? 1 : -1
    }
    do {
      // 发送 API 请求
      let status: Status = try await client.post(endpoint: endpoint)
      // 提取原始帖子的状态（转发操作返回的是转发帖子）
      updateFrom(status: status.reblog ?? status)
    } catch {
      // 请求失败，回滚状态
      isReblogged.toggle()
      reblogsCount += isReblogged ? -1 : 1
    }
  }

  /// 切换收藏状态
  ///
  /// 添加或移除帖子的书签，使用乐观更新策略。
  ///
  /// - Parameter remoteStatus: 远程帖子 ID（可选，用于跨实例操作）
  ///
  /// 执行流程：
  /// 1. 检查客户端是否已认证
  /// 2. 立即切换收藏状态（乐观更新）
  /// 3. 发送 API 请求
  /// 4. 成功：使用服务器返回的最新状态
  /// 5. 失败：回滚状态
  ///
  /// 特点：
  /// - 收藏不影响计数（没有收藏数）
  /// - 只改变用户自己的收藏状态
  /// - 收藏的帖子可以在书签页面查看
  ///
  /// 使用场景：
  /// - 用户点击收藏按钮
  /// - 快速操作菜单中的收藏
  /// - 保存帖子以便稍后阅读
  ///
  /// 示例：
  /// ```swift
  /// Button {
  ///     Task {
  ///         await controller.toggleBookmark(remoteStatus: nil)
  ///     }
  /// } label: {
  ///     Image(systemName: controller.isBookmarked ? "bookmark.fill" : "bookmark")
  ///         .foregroundColor(controller.isBookmarked ? .blue : .gray)
  /// }
  /// ```
  ///
  /// - Note: 收藏是私密的，其他用户看不到你收藏了哪些帖子
  public func toggleBookmark(remoteStatus: String?) async {
    guard client.isAuth else { return }
    // 乐观更新：立即切换状态
    isBookmarked.toggle()
    let id = remoteStatus ?? status.id
    let endpoint = isBookmarked ? Statuses.bookmark(id: id) : Statuses.unbookmark(id: id)
    do {
      // 发送 API 请求
      let status: Status = try await client.post(endpoint: endpoint)
      // 使用服务器返回的最新状态
      updateFrom(status: status)
    } catch {
      // 请求失败，回滚状态
      isBookmarked.toggle()
    }
  }
}

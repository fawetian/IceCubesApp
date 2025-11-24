// 文件功能：帖子嵌入缓存
//
// 核心职责：
// - 缓存已加载的帖子对象
// - 支持通过 URL 和 ID 两种方式查询
// - 记录无效的帖子 URL
// - 避免重复加载相同的帖子
//
// 技术要点：
// - @MainActor：确保所有操作在主线程执行
// - 单例模式：全局共享的缓存实例
// - 双重索引：同时支持 URL 和 ID 查询
// - Set 集合：记录无效 URL，避免重复请求
//
// 使用场景：
// - 帖子详情页的嵌入帖子
// - 引用帖子的预览
// - 链接卡片中的帖子预览
// - 避免重复加载相同帖子
//
// 依赖关系：
// - 依赖：Foundation, Models, SwiftUI
// - 被依赖：帖子视图、链接预览等需要嵌入帖子的组件

import Foundation
import Models
import SwiftUI

/// 帖子嵌入缓存
///
/// 缓存已加载的帖子对象，避免重复请求。
///
/// 主要功能：
/// - **URL 索引**：通过帖子 URL 查询缓存
/// - **ID 索引**：通过帖子 ID 查询缓存
/// - **无效 URL 记录**：记录加载失败的 URL
/// - **内存缓存**：快速访问已加载的帖子
///
/// 缓存策略：
/// - 使用两个字典分别索引（URL 和 ID）
/// - 同一帖子可以通过两种方式查询
/// - 缓存在内存中，应用退出后清空
/// - 无大小限制，依赖系统内存管理
///
/// 使用方式：
/// ```swift
/// let cache = StatusEmbedCache.shared
///
/// // 缓存帖子
/// cache.set(url: statusURL, status: status)
/// cache.set(id: status.id, status: status)
///
/// // 查询缓存
/// if let cachedStatus = cache.get(url: statusURL) {
///     // 使用缓存的帖子
/// } else {
///     // 从服务器加载
///     let status = try await client.get(endpoint: Statuses.status(id: id))
///     cache.set(url: statusURL, status: status)
/// }
///
/// // 记录无效 URL
/// cache.badStatusesURLs.insert(failedURL)
/// ```
///
/// 典型场景：
/// - 帖子中包含其他帖子的链接
/// - 引用帖子的预览
/// - 链接卡片中的帖子预览
/// - 避免重复加载相同帖子
///
/// - Note: 使用单例模式，通过 `StatusEmbedCache.shared` 访问
/// - Important: 所有操作都在主线程执行
@MainActor
public class StatusEmbedCache {
  /// 单例实例
  ///
  /// 全局共享的缓存实例。
  public static let shared = StatusEmbedCache()

  /// URL 索引缓存
  ///
  /// 使用帖子 URL 作为键的缓存字典。
  ///
  /// 键：帖子的完整 URL
  /// 值：帖子对象
  ///
  /// 使用场景：
  /// - 从链接中提取帖子
  /// - 预览嵌入的帖子链接
  private var cache: [URL: Status] = [:]
  
  /// ID 索引缓存
  ///
  /// 使用帖子 ID 作为键的缓存字典。
  ///
  /// 键：帖子 ID 字符串
  /// 值：帖子对象
  ///
  /// 使用场景：
  /// - 通过 ID 快速查找帖子
  /// - 引用帖子的预览
  private var cacheById: [String: Status] = [:]

  /// 无效帖子 URL 集合
  ///
  /// 记录加载失败的帖子 URL，避免重复请求。
  ///
  /// 使用场景：
  /// - 帖子已被删除
  /// - 帖子不存在
  /// - 权限不足无法访问
  /// - 避免重复请求失败的 URL
  ///
  /// 示例：
  /// ```swift
  /// if cache.badStatusesURLs.contains(url) {
  ///     // 跳过加载，显示错误提示
  ///     return
  /// }
  ///
  /// do {
  ///     let status = try await loadStatus(url: url)
  ///     cache.set(url: url, status: status)
  /// } catch {
  ///     // 记录为无效 URL
  ///     cache.badStatusesURLs.insert(url)
  /// }
  /// ```
  public var badStatusesURLs = Set<URL>()

  /// 私有初始化方法
  ///
  /// 确保单例模式，防止外部创建实例。
  private init() {}

  /// 通过 URL 缓存帖子
  ///
  /// 将帖子对象存储到 URL 索引缓存中。
  ///
  /// - Parameters:
  ///   - url: 帖子的 URL
  ///   - status: 帖子对象
  ///
  /// 使用场景：
  /// - 从服务器加载帖子后
  /// - 解析链接中的帖子后
  ///
  /// 示例：
  /// ```swift
  /// let status = try await client.get(endpoint: Statuses.status(id: id))
  /// StatusEmbedCache.shared.set(url: statusURL, status: status)
  /// ```
  public func set(url: URL, status: Status) {
    cache[url] = status
  }

  /// 通过 ID 缓存帖子
  ///
  /// 将帖子对象存储到 ID 索引缓存中。
  ///
  /// - Parameters:
  ///   - id: 帖子 ID
  ///   - status: 帖子对象
  ///
  /// 使用场景：
  /// - 从服务器加载帖子后
  /// - 引用帖子的预览
  ///
  /// 示例：
  /// ```swift
  /// let status = try await client.get(endpoint: Statuses.status(id: id))
  /// StatusEmbedCache.shared.set(id: status.id, status: status)
  /// ```
  public func set(id: String, status: Status) {
    cacheById[id] = status
  }

  /// 通过 URL 获取缓存的帖子
  ///
  /// 从 URL 索引缓存中查询帖子。
  ///
  /// - Parameter url: 帖子的 URL
  /// - Returns: 缓存的帖子对象，如果不存在返回 nil
  ///
  /// 使用场景：
  /// - 检查帖子是否已缓存
  /// - 避免重复加载
  ///
  /// 示例：
  /// ```swift
  /// if let cachedStatus = StatusEmbedCache.shared.get(url: url) {
  ///     // 使用缓存的帖子
  ///     displayStatus(cachedStatus)
  /// } else {
  ///     // 从服务器加载
  ///     let status = try await loadStatus(url: url)
  ///     StatusEmbedCache.shared.set(url: url, status: status)
  /// }
  /// ```
  public func get(url: URL) -> Status? {
    cache[url]
  }

  /// 通过 ID 获取缓存的帖子
  ///
  /// 从 ID 索引缓存中查询帖子。
  ///
  /// - Parameter id: 帖子 ID
  /// - Returns: 缓存的帖子对象，如果不存在返回 nil
  ///
  /// 使用场景：
  /// - 检查帖子是否已缓存
  /// - 快速查找帖子
  ///
  /// 示例：
  /// ```swift
  /// if let cachedStatus = StatusEmbedCache.shared.get(id: statusId) {
  ///     // 使用缓存的帖子
  ///     displayStatus(cachedStatus)
  /// } else {
  ///     // 从服务器加载
  ///     let status = try await client.get(endpoint: Statuses.status(id: statusId))
  ///     StatusEmbedCache.shared.set(id: statusId, status: status)
  /// }
  /// ```
  public func get(id: String) -> Status? {
    cacheById[id]
  }
}

/*
 * TimelineCache.swift
 * IceCubesApp - 时间线持久化缓存 Actor
 *
 * 文件功能：
 * 将时间线条目（帖子与 Gap）序列化到本地 SQLite（Bodega 引擎），
 * 支持多账户/多过滤器的独立缓存，并记录「最新已读帖子」信息。
 *
 * 核心职责：
 * - 计算各过滤器的缓存数量并提供清理能力
 * - 将内存中的 `TimelineItem` 列表压缩、序列化并写入缓存
 * - 从缓存恢复时间线条目，保证离线启动的可用性
 * - 记录/读取最新已读的帖子 ID 列表
 *
 * 技术要点：
 * - `actor` + Bodega `SQLiteStorageEngine` 组合实现线程安全写入
 * - JSON 编解码器负责序列化 `TimelineItem`
 * - 限制最多缓存 800 条帖子，避免缓存无限增长
 * - 通过目录结构区分账号、过滤器（Home / Lists / Tags）
 *
 * 依赖关系：
 * - Bodega: SQLiteStorageEngine 与文件目录工具
 * - Models: `Status`、`TimelineItem`、`TimelineGap`
 * - NetworkClient: `MastodonClient` 唯一 ID
 */

import Bodega
import Models
import NetworkClient
import SwiftUI

/// 提供时间线缓存能力的 Actor。
///
/// - Note: 只在主线程调度也能保证安全，但使用 actor 可以在后台写入缓存。
public actor TimelineCache {
  /// 缓存条目序列化模型，避免直接存储复杂枚举。
  private struct CachedTimelineItem: Codable {
    enum Kind: String, Codable { case status, gap }

    var kind: Kind
    var status: Status?
    var gap: CachedGap?
  }

  /// Gap 在缓存中的精简结构。
  private struct CachedGap: Codable {
    var sinceId: String
    var maxId: String
  }

  /// 根据账号与过滤器名称返回对应存储引擎。
  private func storageFor(_ client: String, _ filter: String) -> SQLiteStorageEngine {
    if filter == "Home" {
      SQLiteStorageEngine.default(appendingPath: "\(client)")
    } else {
      SQLiteStorageEngine.default(appendingPath: "\(client)/\(filter)")
    }
  }

  /// JSON 解码器，用于恢复缓存。
  private let decoder = JSONDecoder()
  /// JSON 编码器，用于写入缓存。
  private let encoder = JSONEncoder()

  public init() {}

  /// 统计某个账号下所有过滤器缓存的帖子条数。
  public func cachedPostsCount(for client: String) async -> Int {
    do {
      let directory = FileManager.Directory.defaultStorageDirectory(appendingPath: client).url
      let content = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
      var total: Int = await storageFor(client, "Home").allKeys().count
      for storage in content {
        if !storage.lastPathComponent.hasSuffix("sqlite3") {
          total += await storageFor(client, storage.lastPathComponent).allKeys().count
        }
      }
      return total
    } catch {
      return 0
    }
  }

  /// 清空账号下所有缓存（Home + 其他过滤器）。
  public func clearCache(for client: String) async {
    let directory = FileManager.Directory.defaultStorageDirectory(appendingPath: client)
    try? FileManager.default.removeItem(at: directory.url)
  }

  /// 清空某个过滤器的缓存。
  public func clearCache(for client: String, filter: String) async {
    let engine = storageFor(client, filter)
    do {
      try await engine.removeAllData()
    } catch {}
  }

  /// 将内存中的时间线条目写入缓存。
  ///
  /// - Parameters:
  ///   - items: 当前时间线条目（帖子 + Gap）
  ///   - client: Mastodon 客户端 ID
  ///   - filter: 时间线过滤器名称（Home / List / Hashtag）
  func set(items: [TimelineItem], client: String, filter: String) async {
    guard items.contains(where: { $0.status != nil }) else { return }
    do {
      let engine = storageFor(client, filter)
      try await engine.removeAllData()
      let payload = try encoder.encode(prepareItemsForCaching(items))
      try await engine.write([(CacheKey("items"), payload)])
    } catch {}
  }

  /// 从缓存恢复时间线条目。
  func getItems(for client: String, filter: String) async -> [TimelineItem]? {
    let engine = storageFor(client, filter)
    do {
      let storedData = await engine.readAllData()
      guard let data = storedData.first else { return nil }
      return try restoreItems(from: data)
    } catch {
      return nil
    }
  }

  /// 记录最新看到的帖子 ID（用于未读提示）。
  func setLatestSeenStatuses(_ statuses: [Status], for client: MastodonClient, filter: String) {
    let statuses = statuses.sorted(by: { $0.createdAt.asDate > $1.createdAt.asDate })
    if filter == "Home" {
      UserDefaults.standard.set(statuses.map { $0.id }, forKey: "timeline-last-seen-\(client.id)")
    } else {
      UserDefaults.standard.set(
        statuses.map { $0.id }, forKey: "timeline-last-seen-\(client.id)-\(filter)")
    }
  }

  /// 读取最新看到的帖子 ID。
  func getLatestSeenStatus(for client: MastodonClient, filter: String) -> [String]? {
    if filter == "Home" {
      UserDefaults.standard.array(forKey: "timeline-last-seen-\(client.id)") as? [String]
    } else {
      UserDefaults.standard.array(forKey: "timeline-last-seen-\(client.id)-\(filter)") as? [String]
    }
  }
}

// MARK: - Encoding helpers

extension TimelineCache {
  /// 单个过滤器最多缓存的帖子数量。
  fileprivate var maxCachedStatuses: Int { 800 }

  /// 将内存条目压缩成缓存模型。
  private func prepareItemsForCaching(_ items: [TimelineItem]) -> [CachedTimelineItem] {
    limitedItems(items, limit: maxCachedStatuses).map { item in
      switch item {
      case .status(let status):
        return CachedTimelineItem(kind: .status, status: status, gap: nil)
      case .gap(let gap):
        let cachedGap = CachedGap(
          sinceId: gap.sinceId,
          maxId: gap.maxId)
        return CachedTimelineItem(kind: .gap, status: nil, gap: cachedGap)
      }
    }
  }

  /// 将缓存数据恢复为 `TimelineItem`。
  private func restoreItems(from data: Data) throws -> [TimelineItem] {
    let cachedItems = try decoder.decode([CachedTimelineItem].self, from: data)
    return cachedItems.compactMap { item in
      switch item.kind {
      case .status:
        if let status = item.status {
          return .status(status)
        }
        return nil
      case .gap:
        guard let gap = item.gap else { return nil }
        return .gap(
          TimelineGap(
            sinceId: gap.sinceId.isEmpty ? nil : gap.sinceId,
            maxId: gap.maxId))
      }
    }
  }

  /// 根据帖子数量限制截取条目，确保 Gap 与帖子顺序合法。
  private func limitedItems(_ items: [TimelineItem], limit: Int) -> [TimelineItem] {
    guard limit > 0 else { return [] }

    var collected: [TimelineItem] = []
    var statusCount = 0

    for item in items {
      switch item {
      case .status:
        guard statusCount < limit else { continue }
        collected.append(item)
        statusCount += 1
      case .gap:
        guard statusCount > 0 else { continue }
        collected.append(item)
        if statusCount >= limit { return collected }
      }
    }

    return collected
  }
}

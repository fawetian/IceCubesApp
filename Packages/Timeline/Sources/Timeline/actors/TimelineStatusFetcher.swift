/*
 * TimelineStatusFetcher.swift
 * IceCubesApp - 时间线数据拉取器
 *
 * 文件功能：
 * 抽象并实现时间线的分页拉取逻辑，支持首页、向上增量以及向下分页三种场景。
 *
 * 核心职责：
 * - 根据 `TimelineFilter` 构造对应的 NetworkClient 端点
 * - 对接 `TimelineViewModel` 的分页请求，返回标准化的 `Status` 数组
 * - 处理客户端缺失、任务取消及分页边界条件
 *
 * 技术要点：
 * - 采用 `Sendable` 协议，方便在 actor 或 Task 中安全传递
 * - 使用 MastodonClient 的 `get(endpoint:)` 统一访问 API
 * - 针对“向上拉取”循环控制最大页数与 Task 取消
 *
 * 依赖关系：
 * - Models: `Status`, `TimelineFilter`
 * - NetworkClient: `MastodonClient`
 */

import Foundation
import Models
import NetworkClient

/// 定义时间线分页拉取行为的协议。
protocol TimelineStatusFetching: Sendable {
  /// 拉取时间线首页。
  func fetchFirstPage(
    client: MastodonClient?,
    timeline: TimelineFilter
  ) async throws -> [Status]
  /// 向上拉取最新页。通常用于补齐未读部分。
  func fetchNewPages(
    client: MastodonClient?,
    timeline: TimelineFilter,
    minId: String,
    maxPages: Int
  ) async throws -> [Status]
  /// 向下拉取下一页历史时间线。
  func fetchNextPage(
    client: MastodonClient?,
    timeline: TimelineFilter,
    lastId: String,
    offset: Int
  ) async throws -> [Status]
}

/// 拉取时间线时可能出现的错误。
enum StatusFetcherError: Error {
  /// 当前没有可用的客户端（未登录或初始化失败）。
  case noClientAvailable
}

/// 默认的时间线分页实现。
struct TimelineStatusFetcher: TimelineStatusFetching {
  /// 拉取首页：固定 limit=50，用于刷新或首次进入页面。
  func fetchFirstPage(client: MastodonClient?, timeline: TimelineFilter) async throws -> [Status] {
    guard let client = client else { throw StatusFetcherError.noClientAvailable }
    return try await client.get(
      endpoint: timeline.endpoint(
        sinceId: nil,
        maxId: nil,
        minId: nil,
        offset: 0,
        limit: 50))
  }

  /// 拉取最新页：以 `minId` 为起点，最多连续请求 `maxPages` 次。
  func fetchNewPages(
    client: MastodonClient?, timeline: TimelineFilter, minId: String, maxPages: Int
  )
    async throws -> [Status]
  {
    guard let client = client else { throw StatusFetcherError.noClientAvailable }
    guard maxPages > 0 else { return [] }

    var pagesLoaded = 0
    var allStatuses: [Status] = []
    var latestMinId = minId

    while !Task.isCancelled, pagesLoaded < maxPages {
      let newStatuses: [Status] = try await client.get(
        endpoint: timeline.endpoint(
          sinceId: nil,
          maxId: nil,
          minId: latestMinId,
          offset: nil,
          limit: 40
        ))

      if newStatuses.isEmpty { break }

      pagesLoaded += 1
      allStatuses.insert(contentsOf: newStatuses, at: 0)
      latestMinId = newStatuses.first?.id ?? latestMinId
    }
    return allStatuses
  }

  /// 拉取下一页历史数据，使用 `lastId` 作为 maxId 并支持 offset（用于 gap 填充）。
  func fetchNextPage(client: MastodonClient?, timeline: TimelineFilter, lastId: String, offset: Int)
    async throws -> [Status]
  {
    guard let client = client else { throw StatusFetcherError.noClientAvailable }
    return try await client.get(
      endpoint: timeline.endpoint(
        sinceId: nil,
        maxId: lastId,
        minId: nil,
        offset: offset,
        limit: 40))
  }
}

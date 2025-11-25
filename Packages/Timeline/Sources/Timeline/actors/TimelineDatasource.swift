/*
 * TimelineDatasource.swift
 * IceCubesApp - 时间线数据源 Actor
 *
 * 文件功能：
 * 以线程安全的 Actor 形式维护时间线条目（帖子 + Gap），提供过滤、插入、删除等操作。
 *
 * 核心职责：
 * - 缓存时间线的完整条目数组，避免重复拉取网络数据
 * - 根据内容过滤配置返回可展示的帖子或条目列表
 * - 管理 Gap（时间线缺口）的插入、替换与加载状态
 * - 提供查找、替换、拼接方法供 `TimelineViewModel` 调度
 *
 * 技术要点：
 * - Swift Concurrency `actor` 确保多线程访问安全
 * - 依赖 `TimelineContentFilter` 的 async 属性进行动态过滤
 * - 通过内部私有搜索方法定位状态或 Gap 索引
 *
 * 使用场景：
 * - 时间线初始化时设置全部状态
 * - 实时事件或下拉刷新时增量插入/替换
 * - 点击 Gap 时加载缺失区段并替换占位
 *
 * 依赖关系：
 * - Env: `TimelineContentFilter` 全局过滤配置
 * - Models: `Status`、`TimelineItem`、`TimelineGap`
 */

import Env
import Foundation
import Models

/// 负责管理时间线条目的 Actor。
///
/// 所有读写均在 Actor 内部串行执行，避免 UI 与网络线程竞争。
actor TimelineDatasource {
  /// 内存中的时间线条目集合，包含帖子与 Gap。
  private var items: [TimelineItem] = []

  /// 是否没有任何可用条目。
  var isEmpty: Bool {
    items.isEmpty
  }

  /// 返回所有帖子（忽略 Gap）。
  func get() -> [Status] {
    items.compactMap { item in
      if case .status(let status) = item {
        return status
      }
      return nil
    }
  }

  /// 返回原始条目数组（包含 Gap）。
  func getItems() -> [TimelineItem] {
    items
  }

  /// 根据全局内容过滤规则返回可展示的帖子。
  func getFiltered() async -> [Status] {
    let contentFilter = await TimelineContentFilter.shared
    var filtered: [Status] = []
    for item in items {
      guard case .status(let status) = item else { continue }
      if await shouldShowStatus(status, filter: contentFilter) {
        filtered.append(status)
      }
    }
    return filtered
  }

  /// 根据过滤规则返回可展示的条目（保留 Gap）。
  func getFilteredItems() async -> [TimelineItem] {
    let contentFilter = await TimelineContentFilter.shared
    var filtered: [TimelineItem] = []
    for item in items {
      switch item {
      case .gap:
        filtered.append(item)
      case .status(let status):
        if await shouldShowStatus(status, filter: contentFilter) {
          filtered.append(item)
        }
      }
    }
    return filtered
  }

  /// 当前条目数量。
  func count() -> Int {
    items.count
  }

  /// 清空所有缓存条目。
  func reset() {
    items = []
  }

  // MARK: - Status Finding Helpers

  /// 根据状态 ID 寻找其索引。
  private func findStatusIndex(id: String) -> Int? {
    items.firstIndex(where: { item in
      if case .status(let status) = item {
        return status.id == id
      }
      return false
    })
  }

  /// 根据 Gap ID 寻找索引。
  private func findGapIndex(id: String) -> Int? {
    items.firstIndex(where: { item in
      if case .gap(let gap) = item {
        return gap.id == id
      }
      return false
    })
  }

  // MARK: - Status Operations

  /// 返回指定状态的索引。
  func indexOf(statusId: String) -> Int? {
    findStatusIndex(id: statusId)
  }

  /// 判断是否包含指定状态。
  func contains(statusId: String) -> Bool {
    findStatusIndex(id: statusId) != nil
  }

  /// 以帖子数组重置数据源。
  func set(_ statuses: [Status]) {
    self.items = statuses.map { .status($0) }
  }

  /// 以完整条目数组重置数据源。
  func setItems(_ items: [TimelineItem]) {
    self.items = items
  }

  /// 末尾追加单个帖子。
  func append(_ status: Status) {
    items.append(.status(status))
  }

  /// 末尾追加多个帖子。
  func append(contentOf statuses: [Status]) {
    items.append(contentsOf: statuses.map { .status($0) })
  }

  /// 在指定位置插入单个帖子。
  func insert(_ status: Status, at index: Int) {
    items.insert(.status(status), at: index)
  }

  /// 在指定位置插入多个帖子。
  func insert(contentOf statuses: [Status], at index: Int) {
    items.insert(contentsOf: statuses.map { .status($0) }, at: index)
  }

  /// 删除给定状态之后的所有条目，保留 safeOffset 数量。
  func remove(after status: Status, safeOffset: Int) {
    guard let index = findStatusIndex(id: status.id) else { return }
    let safeIndex = index + safeOffset
    if items.count > safeIndex {
      items.removeSubrange(safeIndex..<items.endIndex)
    }
  }

  /// 使用新的帖子替换指定索引。
  func replace(_ status: Status, at index: Int) {
    items[index] = .status(status)
  }

  /// 根据 ID 删除帖子并返回被移除对象。
  func remove(_ statusId: String) -> Status? {
    guard let index = findStatusIndex(id: statusId),
      case .status(let status) = items.remove(at: index)
    else {
      return nil
    }
    return status
  }

  // MARK: - Gap Operations

  /// 在指定位置插入 Gap 占位。
  func insertGap(_ gap: TimelineGap, at index: Int) {
    items.insert(.gap(gap), at: index)
  }

  /// 用帖子列表替换已加载完成的 Gap。
  func replaceGap(id: String, with statuses: [Status]) {
    guard let gapIndex = findGapIndex(id: id) else { return }
    items.remove(at: gapIndex)
    items.insert(contentsOf: statuses.map { .status($0) }, at: gapIndex)
  }

  /// 更新 Gap 的加载中状态（用于展示 Loading UI）。
  func updateGapLoadingState(id: String, isLoading: Bool) {
    guard let gapIndex = findGapIndex(id: id),
      case .gap(var gap) = items[gapIndex]
    else { return }
    gap.isLoading = isLoading
    items[gapIndex] = .gap(gap)
  }

  // MARK: - Private Helpers

  /// 根据内容过滤设置判断某条状态是否应该展示。
  private func shouldShowStatus(_ status: Status, filter: TimelineContentFilter) async -> Bool {
    let showReplies = await filter.showReplies
    let showBoosts = await filter.showBoosts
    let showThreads = await filter.showThreads
    let showQuotePosts = await filter.showQuotePosts

    return !status.isHidden
      && (showReplies || status.inReplyToId == nil
        || status.inReplyToAccountId == status.account.id)
      && (showBoosts || status.reblog == nil)
      && (showThreads || status.inReplyToAccountId != status.account.id)
      && (showQuotePosts || status.content.statusesURLs.isEmpty)
  }
}

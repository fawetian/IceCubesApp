/*
 * TimelineViewModel.swift
 * IceCubesApp - 时间线视图模型
 *
 * 文件功能：
 * 管理时间线的业务逻辑，包括数据拉取、缓存、分页、实时更新和状态管理。
 *
 * 核心职责：
 * - 协调 TimelineDatasource、TimelineCache 和 TimelineStatusFetcher 完成数据流转
 * - 监听过滤器切换并触发数据重新加载
 * - 处理下拉刷新、向上/向下分页、Gap 加载等交互
 * - 管理实时流事件（新帖子、删除、更新）
 * - 维护已读标记和未读提示
 *
 * 技术要点：
 * - @Observable + @MainActor 保证 UI 更新线程安全
 * - willSet/didSet 监听 timeline 变化自动触发任务
 * - Task 管理异步拉取并支持取消
 * - 与 StreamWatcher 集成实现实时推送
 * - 支持缓存恢复和 Marker 断点续传
 *
 * 使用场景：
 * - TimelineView 的核心数据源
 * - 时间线列表的刷新、分页逻辑
 * - 实时流事件的处理和 UI 更新
 *
 * 依赖关系：
 * - Env: StreamWatcher、UserPreferences、StatusDataControllerProvider
 * - Models: Status、TimelineFilter、Marker、Tag
 * - NetworkClient: MastodonClient
 * - StatusKit: StatusesState
 */

import Env
import Models
import NetworkClient
import Observation
import StatusKit
import SwiftUI

/// 时间线视图模型。
///
/// 负责管理时间线的完整生命周期，包括数据拉取、缓存、分页和实时更新。
/// 与 `TimelineView` 绑定，驱动 UI 状态变化。
@MainActor
@Observable class TimelineViewModel {
  /// 需要滚动到的帖子 ID（用于自动定位）。
  var scrollToId: String?
  /// 当前时间线的状态（加载中、已加载、错误）。
  var statusesState: StatusesState = .loading
  /// 当前展示的时间线过滤器（触发数据重新加载）。
  var timeline: TimelineFilter = .home {
    willSet {
      if timeline == .home,
        newValue != .resume,
        newValue != timeline
      {
        saveMarker()
      }
    }
    didSet {
      timelineTask?.cancel()

      // Stop streaming when leaving streamable timeline
      if isStreamingTimeline && !canStreamTimeline(timeline) {
        isStreamingTimeline = false
      }

      timelineTask = Task {
        await handleLatestOrResume(oldValue)

        if oldValue != timeline {
          Telemetry.signal(
            "timeline.filter.updated",
            parameters: ["timeline": timeline.rawValue])

          await reset()
          pendingStatusesObserver.pendingStatuses = []
          tag = nil
        }

        guard !Task.isCancelled else {
          return
        }

        await fetchNewestStatuses(pullToRefresh: false)
        switch timeline {
        case .hashtag(let tag, _):
          await fetchTag(id: tag)
        default:
          break
        }
      }
    }
  }

  /// 当前正在执行的时间线拉取任务（用于取消）。
  private(set) var timelineTask: Task<Void, Never>?

  /// 当前标签详情（仅标签时间线使用）。
  var tag: Tag?

  /// 时间线数据源（内存中的状态与 Gap 管理）。
  @ObservationIgnored
  private(set) var datasource = TimelineDatasource()
  /// 状态拉取器（网络请求抽象）。
  private let statusFetcher: TimelineStatusFetching

  /// 持久化缓存（SQLite 存储）。
  @ObservationIgnored
  private let cache = TimelineCache()

  /// 时间线拉取限制常量。
  private enum Constants {
    /// 单次完整拉取最多获取的帖子数（用于追赶未读）。
    static let fullTimelineFetchLimit = 800
    /// 最大分页数（按每页 40 条计算）。
    static let fullTimelineFetchMaxPages = fullTimelineFetchLimit / 40
  }

  /// 是否启用完整时间线拉取（追赶未读）。
  private var isFullTimelineFetchEnabled: Bool {
    guard UserPreferences.shared.fullTimelineFetch else { return false }

    switch timeline {
    case .local, .federated:
      return false
    default:
      return true
    }
  }

  /// 是否启用缓存功能（需满足多个条件）。
  private var isCacheEnabled: Bool {
    canFilterTimeline && timeline.supportNewestPagination && client?.isAuth == true
  }

  /// 当前可见的帖子列表（用于记录已读位置）。
  @ObservationIgnored
  private var visibleStatuses: [Status] = []

  /// 是否允许处理实时流事件（拉取期间禁用）。
  private var canStreamEvents: Bool = true {
    didSet {
      if canStreamEvents {
        pendingStatusesObserver.isLoadingNewStatuses = false
      }
    }
  }

  /// 是否允许过滤时间线内容。
  @ObservationIgnored
  var canFilterTimeline: Bool = true

  /// 是否正在流式监听时间线（用于本地/联邦时间线）。
  var isStreamingTimeline: Bool = false {
    didSet {
      if isStreamingTimeline != oldValue {
        updateStreamWatcher()
      }
    }
  }

  /// Mastodon API 客户端（切换时重置数据源）。
  var client: MastodonClient? {
    didSet {
      if oldValue != client {
        Task {
          await reset()
        }
      }
    }
  }

  /// 顶部"回到顶部"按钮是否可见。
  var scrollToTopVisible: Bool = false

  /// 当前服务器名称（用于显示）。
  var serverName: String {
    client?.server ?? "Error"
  }

  /// 未读帖子观察器（管理待读提示）。
  let pendingStatusesObserver: TimelineUnreadStatusesObserver = .init()
  /// Mastodon Marker 数据（用于断点续传）。
  var marker: Marker.Content?

  /// 初始化方法。
  ///
  /// - Parameter statusFetcher: 自定义状态拉取器（默认使用 `TimelineStatusFetcher`）。
  init(statusFetcher: TimelineStatusFetching = TimelineStatusFetcher()) {
    self.statusFetcher = statusFetcher
  }

  /// 拉取标签详情（仅标签时间线使用）。
  private func fetchTag(id: String) async {
    guard let client else { return }
    do {
      let tag: Tag = try await client.get(endpoint: Tags.tag(id: id))
      withAnimation {
        self.tag = tag
      }
    } catch {}
  }

  /// 重置数据源（清空所有缓存的帖子）。
  func reset() async {
    await datasource.reset()
  }

  /// 处理特殊过滤器 `.latest` 和 `.resume`（用于刷新或恢复）。
  private func handleLatestOrResume(_ oldValue: TimelineFilter) async {
    if timeline == .latest || timeline == .resume {
      await clearCache(filter: oldValue)
      if timeline == .resume, let marker = await fetchMarker() {
        self.marker = marker
      }
      timeline = oldValue
    }
  }
}

// MARK: - Cache
// 缓存管理扩展

extension TimelineViewModel {
  /// 将当前数据源内容写入缓存。
  private func cache() async {
    if let client, isCacheEnabled {
      let items = await datasource.getItems()
      await cache.set(items: items, client: client.id, filter: timeline.id)
    }
  }

  /// 从缓存恢复时间线条目。
  private func getCachedItems() async -> [TimelineItem]? {
    if let client, isCacheEnabled {
      return await cache.getItems(for: client.id, filter: timeline.id)
    }
    return nil
  }

  /// 清空指定过滤器的缓存。
  private func clearCache(filter: TimelineFilter) async {
    if let client, isCacheEnabled {
      await cache.clearCache(for: client.id, filter: filter.id)
      await cache.setLatestSeenStatuses([], for: client, filter: filter.id)
    }
  }
}

// MARK: - StatusesFetcher
// 状态拉取与刷新扩展

extension TimelineViewModel: GapLoadingFetcher {
  /// 下拉刷新（用户主动触发）。
  func pullToRefresh() async {
    timelineTask?.cancel()

    if !timeline.supportNewestPagination {
      await reset()
    }
    await fetchNewestStatuses(pullToRefresh: true)
  }

  /// 刷新时间线（程序自动触发）。
  func refreshTimeline() {
    timelineTask?.cancel()
    timelineTask = Task {
      await fetchNewestStatuses(pullToRefresh: false)
    }
  }

  /// 刷新内容过滤器（用户修改过滤设置时）。
  func refreshTimelineContentFilter() async {
    timelineTask?.cancel()
    await updateStatusesState()
  }

  /// 从 Marker 断点恢复时间线。
  ///
  /// - Parameter from: Marker 内容（包含上次阅读的帖子 ID）。
  func fetchStatuses(from: Marker.Content) async throws {
    guard let client else { return }
    statusesState = .loading
    let statuses: [Status] = try await client.get(
      endpoint: timeline.endpoint(
        sinceId: nil,
        maxId: from.lastReadId,
        minId: nil,
        offset: 0,
        limit: 40))

    await updateDatasourceAndState(statuses: statuses, client: client, replaceExisting: true)
    marker = nil
    await fetchNewestStatuses(pullToRefresh: false)
  }

  /// 拉取最新帖子（首页加载或增量刷新）。
  ///
  /// - Parameter pullToRefresh: 是否为用户主动下拉刷新。
  func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client else { return }
    do {
      if let marker {
        try await fetchStatuses(from: marker)
      } else if await datasource.isEmpty {
        try await fetchFirstPage(client: client)
      } else if let latest = await datasource.get().first, timeline.supportNewestPagination {
        pendingStatusesObserver.isLoadingNewStatuses = !pullToRefresh
        try await fetchNewPagesFrom(latestStatus: latest.id, client: client)
      }
    } catch {
      if await datasource.isEmpty {
        statusesState = .error(error: .noData)
      }
      canStreamEvents = true
    }
  }

  /// 拉取首页（数据源为空时使用，优先从缓存恢复）。
  private func fetchFirstPage(client: MastodonClient) async throws {
    pendingStatusesObserver.pendingStatuses = []

    let datasourceIsEmpty = await datasource.isEmpty
    if datasourceIsEmpty {
      statusesState = .loading
    }

    // If we get statuses from the cache for the home timeline, we displays those.
    // Else we fetch top most page from the API.
    if timeline.supportNewestPagination,
      let cachedItems = await getCachedItems(),
      !cachedItems.isEmpty
    {
      await datasource.setItems(cachedItems)
      let items = await datasource.getFilteredItems()
      if let latestSeenId = await cache.getLatestSeenStatus(for: client, filter: timeline.id)?.first
      {
        // Restore cache and scroll to latest seen status.
        scrollToId = latestSeenId
        statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
      } else {
        // Restore cache and scroll to top.
        withAnimation {
          statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
        }
      }
      // And then we fetch statuses again to get newest statuses from there.
      await fetchNewestStatuses(pullToRefresh: false)
    } else {
      let statuses: [Status] = try await statusFetcher.fetchFirstPage(
        client: client,
        timeline: timeline)

      await updateDatasourceAndState(statuses: statuses, client: client, replaceExisting: true)

      // If we got 40 or more statuses, there might be older ones - create a gap
      if statuses.count >= 40, let oldestStatus = statuses.last, !datasourceIsEmpty {
        await createGapForOlderStatuses(maxId: oldestStatus.id, at: statuses.count)
      }
    }
  }

  /// 从最顶部的帖子开始向上拉取新页（追赶未读）。
  ///
  /// - Parameters:
  ///   - latestStatus: 当前最新的帖子 ID。
  ///   - client: Mastodon 客户端。
  private func fetchNewPagesFrom(latestStatus: String, client: MastodonClient) async throws {
    canStreamEvents = false
    let initialTimeline = timeline

    // First, fetch the absolute newest statuses (no ID parameters)
    let newestStatuses: [Status] = try await statusFetcher.fetchFirstPage(
      client: client,
      timeline: timeline)

    guard !newestStatuses.isEmpty,
      !Task.isCancelled,
      initialTimeline == timeline
    else {
      canStreamEvents = true
      return
    }

    let currentIds = await datasource.get().map(\.id)
    let actuallyNewStatuses = newestStatuses.filter { status in
      !currentIds.contains(where: { $0 == status.id }) && status.id > latestStatus
    }

    guard !actuallyNewStatuses.isEmpty else {
      canStreamEvents = true
      return
    }

    var statusesToInsert = actuallyNewStatuses

    if isFullTimelineFetchEnabled, statusesToInsert.count < Constants.fullTimelineFetchLimit {
      let additionalStatuses: [Status] = try await statusFetcher.fetchNewPages(
        client: client,
        timeline: timeline,
        minId: latestStatus,
        maxPages: Constants.fullTimelineFetchMaxPages)

      if !additionalStatuses.isEmpty {
        var knownIds = Set(currentIds)
        knownIds.formUnion(statusesToInsert.map(\.id))

        let filteredAdditional = additionalStatuses.filter { status in
          guard status.id > latestStatus else { return false }
          if knownIds.contains(status.id) {
            return false
          }
          knownIds.insert(status.id)
          return true
        }

        if !filteredAdditional.isEmpty {
          let remainingCapacity = max(0, Constants.fullTimelineFetchLimit - statusesToInsert.count)
          if remainingCapacity > 0 {
            statusesToInsert.append(contentsOf: filteredAdditional.prefix(remainingCapacity))
          }
        }
      }
    }

    statusesToInsert.sort { $0.id > $1.id }

    if statusesToInsert.count > Constants.fullTimelineFetchLimit {
      statusesToInsert = Array(statusesToInsert.prefix(Constants.fullTimelineFetchLimit))
    }

    StatusDataControllerProvider.shared.updateDataControllers(
      for: statusesToInsert, client: client)

    // Pass the original count to determine if we need a gap
    await updateTimelineWithNewStatuses(
      statusesToInsert,
      latestStatus: latestStatus,
      fetchedCount: newestStatuses.count,
      shouldCreateGap: !isFullTimelineFetchEnabled
    )
    canStreamEvents = true
  }

  private func updateTimelineWithNewStatuses(
    _ newStatuses: [Status], latestStatus: String, fetchedCount: Int, shouldCreateGap: Bool
  ) async {
    let topStatus = await datasource.getFiltered().first

    // Insert new statuses at the top
    await datasource.insert(contentOf: newStatuses, at: 0)

    // Only create a gap if:
    // 1. We fetched a full page (suggesting there might be more)
    // 2. AND we have a significant number of actually new statuses
    if shouldCreateGap,
      fetchedCount >= 40,
      newStatuses.count >= 40,
      let oldestNewStatus = newStatuses.last
    {
      // Create a gap to load statuses between the oldest new status and our previous top
      let gap = TimelineGap(sinceId: latestStatus, maxId: oldestNewStatus.id)
      // Insert the gap after all the new statuses
      await datasource.insertGap(gap, at: newStatuses.count)
    }

    if let lastVisible = visibleStatuses.last {
      await datasource.remove(after: lastVisible, safeOffset: 15)
    }
    await cache()
    pendingStatusesObserver.pendingStatuses.insert(contentsOf: newStatuses.map(\.id), at: 0)

    let items = await datasource.getFilteredItems()

    if let topStatus = topStatus,
      visibleStatuses.contains(where: { $0.id == topStatus.id }),
      scrollToTopVisible
    {
      scrollToId = topStatus.id
      statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
    } else {
      withAnimation {
        statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
      }
    }
  }

  /// 下一页拉取错误。
  enum NextPageError: Error {
    /// 内部错误（如数据源为空或缺少客户端）。
    case internalError
  }

  /// 拉取下一页历史帖子（向下分页）。
  func fetchNextPage() async throws {
    let statuses = await datasource.get()
    guard let client, let lastId = statuses.last?.id else { throw NextPageError.internalError }
    let newStatuses: [Status] = try await statusFetcher.fetchNextPage(
      client: client,
      timeline: timeline,
      lastId: lastId,
      offset: statuses.count)

    await datasource.append(contentOf: newStatuses)
    StatusDataControllerProvider.shared.updateDataControllers(for: newStatuses, client: client)

    statusesState = await .displayWithGaps(
      items: datasource.getFilteredItems(),
      nextPageState: newStatuses.count < 20 ? .none : .hasNextPage)
  }

  /// 帖子出现在视口时调用（用于记录已读）。
  ///
  /// - Parameter status: 出现的帖子。
  func statusDidAppear(status: Status) {
    pendingStatusesObserver.removeStatus(status: status)
    visibleStatuses.insert(status, at: 0)

    if let client, timeline.supportNewestPagination {
      Task {
        await cache.setLatestSeenStatuses(visibleStatuses, for: client, filter: timeline.id)
      }
    }
  }

  /// 帖子从视口消失时调用。
  ///
  /// - Parameter status: 消失的帖子。
  func statusDidDisappear(status: Status) {
    visibleStatuses.removeAll(where: { $0.id == status.id })
  }

  /// 加载 Gap（填充时间线缺口）。
  ///
  /// - Parameter gap: 需要加载的 Gap。
  func loadGap(gap: TimelineGap) async {
    guard let client else { return }

    // Update gap loading state
    await datasource.updateGapLoadingState(id: gap.id, isLoading: true)

    // Update UI to show loading state without causing jumps
    await updateStatusesState()

    do {
      // Fetch statuses within the gap
      let statuses: [Status] = try await client.get(
        endpoint: timeline.endpoint(
          sinceId: gap.sinceId.isEmpty ? nil : gap.sinceId,
          maxId: gap.maxId,
          minId: nil,
          offset: 0,
          limit: 50))

      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)

      // Get the original gap index before replacing
      let items = await datasource.getItems()
      let gapIndex = items.firstIndex(where: { item in
        if case .gap(let g) = item {
          return g.id == gap.id
        }
        return false
      })

      // Replace the gap with the fetched statuses
      await datasource.replaceGap(id: gap.id, with: statuses)

      // If we fetched 40 or more statuses, there might be more older statuses
      // Lower threshold because some instances might not return exactly 50
      if statuses.count >= 40, let oldestLoadedStatus = statuses.last,
        let originalGapIndex = gapIndex
      {
        // Create a new gap from the original gap's sinceId to the oldest status we just loaded
        await createGapForOlderStatuses(
          sinceId: gap.sinceId.isEmpty ? nil : gap.sinceId,
          maxId: oldestLoadedStatus.id,
          at: originalGapIndex + statuses.count
        )
      }

      // Update the display
      await updateStatusesStateWithAnimation()
    } catch {
      // If loading fails, reset the gap loading state
      await datasource.updateGapLoadingState(id: gap.id, isLoading: false)
      await refreshTimelineContentFilter()
    }
  }

  // MARK: - Helper Methods

  private func updateDatasourceAndState(
    statuses: [Status], client: MastodonClient, replaceExisting: Bool
  )
    async
  {
    StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)

    if replaceExisting {
      await datasource.set(statuses)
    } else {
      await datasource.append(contentOf: statuses)
    }

    await cache()
    await updateStatusesStateWithAnimation()
  }

  private func updateStatusesState() async {
    let items = await datasource.getFilteredItems()
    statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
  }

  private func updateStatusesStateWithAnimation() async {
    let items = await datasource.getFilteredItems()
    withAnimation {
      statusesState = .displayWithGaps(items: items, nextPageState: .hasNextPage)
    }
  }

  private func createGapForOlderStatuses(sinceId: String? = nil, maxId: String, at index: Int) async
  {
    guard !isFullTimelineFetchEnabled else { return }
    let gap = TimelineGap(sinceId: sinceId, maxId: maxId)
    await datasource.insertGap(gap, at: index)
  }
}

// MARK: - Marker handling
// Mastodon 阅读进度标记管理

extension TimelineViewModel {
  /// 拉取 Marker（用于恢复上次阅读位置）。
  ///
  /// - Returns: Marker 内容（如果存在）。
  func fetchMarker() async -> Marker.Content? {
    guard let client else {
      return nil
    }
    do {
      let data: Marker = try await client.get(endpoint: Markers.markers)
      return data.home
    } catch {
      return nil
    }
  }

  /// 保存当前阅读进度到服务器。
  func saveMarker() {
    guard timeline == .home, let client else { return }
    Task {
      guard let id = await cache.getLatestSeenStatus(for: client, filter: timeline.id)?.first else {
        return
      }
      do {
        let _: Marker = try await client.post(endpoint: Markers.markHome(lastReadId: id))
      } catch {}
    }
  }
}

// MARK: - Stream management
// 实时流管理

extension TimelineViewModel {
  /// 判断时间线是否支持实时流。
  ///
  /// - Parameter timeline: 时间线过滤器。
  /// - Returns: 是否支持流式更新。
  func canStreamTimeline(_ timeline: TimelineFilter) -> Bool {
    switch timeline {
    case .federated, .local:
      return true
    default:
      return false
    }
  }

  /// 更新实时流监听器（根据当前时间线调整订阅）。
  private func updateStreamWatcher() {
    guard let client, client.isAuth else { return }

    let watcher = StreamWatcher.shared
    var streams: [StreamWatcher.Stream] = []

    streams.append(.user)
    streams.append(.direct)

    // Add timeline-specific streams
    if isStreamingTimeline {
      switch timeline {
      case .federated:
        streams.append(.federated)
      case .local:
        streams.append(.local)
      default:
        break
      }
    }

    watcher.stopWatching()
    if !streams.isEmpty {
      watcher.watch(streams: streams)
    }
  }
}

// MARK: - Event handling
// 实时流事件处理

extension TimelineViewModel {
  /// 处理实时流事件（新帖子、删除、更新）。
  ///
  /// - Parameter event: 流事件对象。
  func handleEvent(event: any StreamEvent) async {
    guard let client = client, canStreamEvents else { return }

    switch event {
    case let updateEvent as StreamEventUpdate:
      await handleUpdateEvent(updateEvent, client: client)
    case let deleteEvent as StreamEventDelete:
      await handleDeleteEvent(deleteEvent)
    case let statusUpdateEvent as StreamEventStatusUpdate:
      await handleStatusUpdateEvent(statusUpdateEvent, client: client)
    default:
      break
    }
  }

  /// 处理新帖子事件（插入到顶部）。
  private func handleUpdateEvent(_ event: StreamEventUpdate, client: MastodonClient) async {
    let shouldStream =
      switch timeline {
      case .home:
        UserPreferences.shared.streamHomeTimeline
      case .federated, .local:
        isStreamingTimeline
      default:
        false
      }

    guard shouldStream,
      await !datasource.contains(statusId: event.status.id),
      let topStatus = await datasource.get().first,
      topStatus.createdAt.asDate < event.status.createdAt.asDate
    else { return }

    pendingStatusesObserver.pendingStatuses.insert(event.status.id, at: 0)
    await datasource.insert(event.status, at: 0)
    await cache()
    StatusDataControllerProvider.shared.updateDataControllers(for: [event.status], client: client)
    await updateStatusesStateWithAnimation()
  }

  /// 处理帖子删除事件（从列表中移除）。
  private func handleDeleteEvent(_ event: StreamEventDelete) async {
    if await datasource.remove(event.status) != nil {
      await cache()
      await updateStatusesStateWithAnimation()
    }
  }

  /// 处理帖子更新事件（替换原有内容）。
  private func handleStatusUpdateEvent(_ event: StreamEventStatusUpdate, client: MastodonClient)
    async
  {
    guard let originalIndex = await datasource.indexOf(statusId: event.status.id) else { return }

    StatusDataControllerProvider.shared.updateDataControllers(for: [event.status], client: client)
    await datasource.replace(event.status, at: originalIndex)
    await cache()
    await updateStatusesStateWithAnimation()
  }
}

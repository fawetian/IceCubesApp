/*
 * NotificationsListDataSource.swift
 * IceCubesApp - 通知列表数据源
 *
 * 文件功能：
 * 管理通知列表的数据加载、分页、合并和实时更新。
 *
 * 核心职责：
 * - 支持 Mastodon V1 和 V2 通知 API
 * - 合并相似通知（如多个点赞合并显示）
 * - 处理分页加载和下拉刷新
 * - 处理实时流事件更新
 * - 标记通知为已读
 *
 * 技术要点：
 * - V2 API 使用分组通知（NotificationGroup）
 * - V1 API 使用传统通知列表
 * - 合并逻辑（ConsolidatedNotification）
 * - 实时流事件集成
 * - 分页策略（30 条/页）
 *
 * 使用场景：
 * - NotificationsListView 的数据管理
 * - 通知列表加载和刷新
 * - 实时通知更新
 *
 * 依赖关系：
 * - Models: Notification、ConsolidatedNotification、NotificationGroup
 * - NetworkClient: Notifications 端点
 * - Env: CurrentInstance、StreamEvent
 */

import Env
import Foundation
import Models
import NetworkClient

/// 通知列表数据源。
///
/// 管理通知的加载、合并和实时更新。
@MainActor
public final class NotificationsListDataSource {
  /// 常量定义。
  enum Constants {
    /// 每页通知数量限制。
    static let notificationLimit: Int = 30
  }

  // MARK: - Internal state

  /// 合并后的通知列表（内部存储）。
  private var consolidatedNotifications: [ConsolidatedNotification] = []
  /// 最后一个通知组（V2 API 分页用）。
  private var lastNotificationGroup: Models.NotificationGroup?

  /// 初始化方法。
  public init() {}

  // MARK: - Public Methods

  /// 重置数据源状态。
  public func reset() {
    consolidatedNotifications = []
    lastNotificationGroup = nil
  }

  /// 拉取结果结构。
  public struct FetchResult {
    /// 合并后的通知列表。
    let notifications: [ConsolidatedNotification]
    /// 下一页状态。
    let nextPageState: NotificationsListState.PagingState
    /// 是否包含关注请求。
    let containsFollowRequests: Bool
  }

  /// 拉取通知列表（首次加载或下拉刷新）。
  ///
  /// 根据实例支持的 API 版本自动选择 V1 或 V2 API。
  ///
  /// - Parameters:
  ///   - client: Mastodon 客户端。
  ///   - selectedType: 可选的通知类型过滤器。
  ///   - lockedAccountId: 可选的锁定账户 ID（仅显示特定用户的通知）。
  /// - Returns: 拉取结果。
  public func fetchNotifications(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async throws -> FetchResult {
    let useV2API = CurrentInstance.shared.isGroupedNotificationsSupported && lockedAccountId == nil

    if consolidatedNotifications.isEmpty {
      // Initial load
      if useV2API {
        try await fetchNotificationsV2(client: client, selectedType: selectedType)
      } else {
        try await fetchNotificationsV1(
          client: client,
          selectedType: selectedType,
          lockedAccountId: lockedAccountId
        )
      }
    } else {
      // Pull to refresh
      if useV2API {
        try await refreshNotificationsV2(client: client, selectedType: selectedType)
      } else {
        try await refreshNotificationsV1(
          client: client,
          selectedType: selectedType,
          lockedAccountId: lockedAccountId
        )
      }
    }

    markAsRead(client: client)

    let nextPageState: NotificationsListState.PagingState =
      consolidatedNotifications.isEmpty
      ? .none
      : (lastNotificationGroup != nil
        || consolidatedNotifications.count >= Constants.notificationLimit
        ? .hasNextPage : .none)

    return FetchResult(
      notifications: consolidatedNotifications,
      nextPageState: nextPageState,
      containsFollowRequests: consolidatedNotifications.contains { $0.type == .follow_request }
    )
  }

  /// 拉取下一页通知。
  ///
  /// - Parameters:
  ///   - client: Mastodon 客户端。
  ///   - selectedType: 可选的通知类型过滤器。
  ///   - lockedAccountId: 可选的锁定账户 ID。
  /// - Returns: 拉取结果。
  public func fetchNextPage(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async throws -> FetchResult {
    let useV2API = CurrentInstance.shared.isGroupedNotificationsSupported && lockedAccountId == nil

    if useV2API {
      try await fetchNextPageV2(client: client, selectedType: selectedType)
    } else {
      try await fetchNextPageV1(
        client: client,
        selectedType: selectedType,
        lockedAccountId: lockedAccountId
      )
    }

    let hasMore =
      useV2API
      ? (lastNotificationGroup != nil)
      : (consolidatedNotifications.count % Constants.notificationLimit == 0)

    return FetchResult(
      notifications: consolidatedNotifications,
      nextPageState: hasMore ? .hasNextPage : .none,
      containsFollowRequests: consolidatedNotifications.contains { $0.type == .follow_request }
    )
  }

  /// 拉取通知策略（V2 API）。
  ///
  /// 通知策略控制哪些通知被过滤。
  ///
  /// - Parameter client: Mastodon 客户端。
  /// - Returns: 通知策略对象（如果支持）。
  public func fetchPolicy(client: MastodonClient) async -> Models.NotificationsPolicy? {
    try? await client.get(endpoint: Notifications.policy, forceVersion: .v2)
  }

  // MARK: - V1 API Methods

  /// 使用 V1 API 拉取通知（首次加载）。
  private func fetchNotificationsV1(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async throws {
    let notifications: [Models.Notification]
    let queryTypes = queryTypes(for: selectedType)

    if let lockedAccountId {
      notifications = try await client.get(
        endpoint: Notifications.notificationsForAccount(
          accountId: lockedAccountId,
          maxId: nil))
    } else {
      notifications = try await client.get(
        endpoint: Notifications.notifications(
          minId: nil,
          maxId: nil,
          types: queryTypes,
          limit: Constants.notificationLimit))
    }
    consolidatedNotifications = await notifications.consolidated(selectedType: selectedType)
  }

  /// 使用 V1 API 刷新通知（下拉刷新）。
  private func refreshNotificationsV1(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async throws {
    guard let firstId = consolidatedNotifications.first?.id else { return }

    var newNotifications: [Models.Notification] = await fetchNewPages(
      client: client,
      minId: firstId,
      maxPages: 10,
      selectedType: selectedType,
      lockedAccountId: lockedAccountId
    )
    newNotifications = newNotifications.filter { notification in
      !consolidatedNotifications.contains(where: { $0.id == notification.id })
    }

    consolidatedNotifications.insert(
      contentsOf: await newNotifications.consolidated(selectedType: selectedType),
      at: 0
    )
  }

  /// 使用 V1 API 拉取下一页通知。
  private func fetchNextPageV1(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async throws {
    guard let lastId = consolidatedNotifications.last?.notificationIds.last else { return }

    let queryTypes = queryTypes(for: selectedType)
    let newNotifications: [Models.Notification]

    if let lockedAccountId {
      newNotifications = try await client.get(
        endpoint: Notifications.notificationsForAccount(accountId: lockedAccountId, maxId: lastId)
      )
    } else {
      newNotifications = try await client.get(
        endpoint: Notifications.notifications(
          minId: nil,
          maxId: lastId,
          types: queryTypes,
          limit: Constants.notificationLimit))
    }

    consolidatedNotifications.append(
      contentsOf: await newNotifications.consolidated(selectedType: selectedType))
  }

  private func fetchNewPages(
    client: MastodonClient,
    minId: String,
    maxPages: Int,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async -> [Models.Notification] {
    guard lockedAccountId == nil else { return [] }

    var pagesLoaded = 0
    var allNotifications: [Models.Notification] = []
    var latestMinId = minId
    let queryTypes = queryTypes(for: selectedType)

    do {
      while let newNotifications: [Models.Notification] =
        try await client.get(
          endpoint: Notifications.notifications(
            minId: latestMinId,
            maxId: nil,
            types: queryTypes,
            limit: Constants.notificationLimit)),
        !newNotifications.isEmpty,
        pagesLoaded < maxPages
      {
        pagesLoaded += 1
        allNotifications.insert(contentsOf: newNotifications, at: 0)
        latestMinId = newNotifications.first?.id ?? ""
      }
    } catch {
      return allNotifications
    }
    return allNotifications
  }

  // MARK: - V2 API Methods

  /// 使用 V2 API 拉取通知（首次加载）。
  private func fetchNotificationsV2(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?
  ) async throws {
    let results = try await fetchGroupedNotifications(
      client: client,
      sinceId: nil,
      maxId: nil,
      selectedType: selectedType
    )
    consolidatedNotifications = results.consolidated
    lastNotificationGroup = results.lastGroup
  }

  private func refreshNotificationsV2(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?
  ) async throws {
    guard let firstGroup = consolidatedNotifications.first else { return }
    let results = try await fetchGroupedNotifications(
      client: client,
      sinceId: firstGroup.mostRecentNotificationId,
      maxId: nil,
      selectedType: selectedType
    )

    mergeV2Notifications(results.consolidated)
  }

  private func fetchNextPageV2(
    client: MastodonClient,
    selectedType: Models.Notification.NotificationType?
  ) async throws {
    guard let lastGroup = lastNotificationGroup else { return }

    let results = try await fetchGroupedNotifications(
      client: client,
      sinceId: nil,
      maxId: String(lastGroup.mostRecentNotificationId),
      selectedType: selectedType
    )

    consolidatedNotifications.append(contentsOf: results.consolidated)
    lastNotificationGroup = results.lastGroup
  }

  // MARK: - Stream Event Handling

  /// 实时流事件处理结果。
  public struct StreamEventResult {
    let notifications: [ConsolidatedNotification]
    let containsFollowRequest: Bool
  }

  /// 处理实时流通知事件。
  ///
  /// 将新通知合并到现有列表中。
  ///
  /// - Parameters:
  ///   - event: 流事件。
  ///   - selectedType: 可选的通知类型过滤器。
  ///   - lockedAccountId: 可选的锁定账户 ID。
  /// - Returns: 流事件处理结果（如果事件有效）。
  public func handleStreamEvent(
    event: any StreamEvent,
    selectedType: Models.Notification.NotificationType?,
    lockedAccountId: String?
  ) async -> StreamEventResult? {
    guard lockedAccountId == nil,
      let event = event as? StreamEventNotification,
      !consolidatedNotifications.flatMap(\.notificationIds).contains(event.notification.id),
      selectedType == nil || selectedType?.rawValue == event.notification.type
    else { return nil }

    let useV2API =
      CurrentInstance.shared.isGroupedNotificationsSupported
      && event.notification.groupKey != nil

    if useV2API {
      await handleStreamEventV2(event: event, selectedType: selectedType)
    } else {
      await handleStreamEventV1(event: event, selectedType: selectedType)
    }

    return StreamEventResult(
      notifications: consolidatedNotifications,
      containsFollowRequest: event.notification.supportedType == .follow_request
    )
  }

  private func handleStreamEventV1(
    event: StreamEventNotification,
    selectedType: Models.Notification.NotificationType?
  ) async {
    if event.notification.isConsolidable(selectedType: selectedType),
      !consolidatedNotifications.isEmpty
    {
      if let index = consolidatedNotifications.firstIndex(where: {
        $0.type == event.notification.supportedType
          && $0.status?.id == event.notification.status?.id
      }) {
        let latestConsolidatedNotification = consolidatedNotifications.remove(at: index)
        consolidatedNotifications.insert(
          contentsOf: await ([event.notification] + latestConsolidatedNotification.notifications)
            .consolidated(selectedType: selectedType),
          at: 0
        )
      } else {
        let latestConsolidatedNotification = consolidatedNotifications.removeFirst()
        consolidatedNotifications.insert(
          contentsOf: await ([event.notification] + latestConsolidatedNotification.notifications)
            .consolidated(selectedType: selectedType),
          at: 0
        )
      }
    } else {
      consolidatedNotifications.insert(
        contentsOf: await [event.notification].consolidated(selectedType: selectedType),
        at: 0
      )
    }
  }

  private func handleStreamEventV2(
    event: StreamEventNotification,
    selectedType: Models.Notification.NotificationType?
  ) async {
    guard let groupKey = event.notification.groupKey else { return }

    let newGroup = ConsolidatedNotification(
      notifications: [event.notification],
      mostRecentNotificationId: event.notification.id,
      type: event.notification.supportedType ?? .favourite,
      createdAt: event.notification.createdAt,
      accounts: [event.notification.account],
      status: event.notification.status,
      groupKey: groupKey
    )

    mergeV2Notifications([newGroup])
  }

  // MARK: - Helper Methods

  /// 计算查询类型（V1 API 排除类型）。
  ///
  /// 如果选择了特定类型，返回要排除的其他类型。
  private func queryTypes(for selectedType: Models.Notification.NotificationType?) -> [String]? {
    if let selectedType {
      var excludedTypes = Models.Notification.NotificationType.allCases
      excludedTypes.removeAll(where: { $0 == selectedType })
      return excludedTypes.map(\.rawValue)
    }
    return nil
  }

  /// 标记通知为已读。
  ///
  /// 使用最新通知 ID 更新已读标记。
  private func markAsRead(client: MastodonClient) {
    guard let id = consolidatedNotifications.first?.mostRecentNotificationId else { return }
    Task {
      do {
        let _: Marker = try await client.post(endpoint: Markers.markNotifications(lastReadId: id))
      } catch {}
    }
  }

  /// 合并 V2 通知组。
  ///
  /// 将新的通知组与现有组合并，更新账户列表和时间戳。
  private func mergeV2Notifications(_ newGroups: [ConsolidatedNotification]) {
    for newGroup in newGroups.reversed() {
      if let groupKey = newGroup.groupKey {
        if let existingIndex = consolidatedNotifications.firstIndex(where: {
          $0.groupKey == groupKey
        }) {
          let existingGroup = consolidatedNotifications[existingIndex]
          var updatedAccounts = existingGroup.accounts

          for newAccount in newGroup.accounts {
            if !updatedAccounts.contains(where: { $0.id == newAccount.id }) {
              updatedAccounts.insert(newAccount, at: 0)
            }
          }

          let updatedGroup = ConsolidatedNotification(
            notifications: existingGroup.notifications,
            mostRecentNotificationId: newGroup.mostRecentNotificationId,
            type: existingGroup.type,
            createdAt: newGroup.createdAt,
            accounts: updatedAccounts,
            status: existingGroup.status,
            groupKey: groupKey
          )

          consolidatedNotifications.remove(at: existingIndex)
          consolidatedNotifications.insert(updatedGroup, at: 0)
        } else {
          consolidatedNotifications.insert(newGroup, at: 0)
        }
      } else {
        consolidatedNotifications.insert(newGroup, at: 0)
      }
    }
  }

  private struct GroupedNotificationsFetchResult {
    let consolidated: [ConsolidatedNotification]
    let lastGroup: Models.NotificationGroup?
    let hasMore: Bool
  }

  private func fetchGroupedNotifications(
    client: MastodonClient,
    sinceId: String?,
    maxId: String?,
    selectedType: Models.Notification.NotificationType?
  ) async throws -> GroupedNotificationsFetchResult {
    let groupableTypes = ["favourite", "follow", "reblog"]
    let groupedTypes = selectedType == nil ? groupableTypes : []
    let queryTypes = queryTypes(for: selectedType)

    let results: Models.GroupedNotificationsResults = try await client.get(
      endpoint: Notifications.notificationsV2(
        sinceId: sinceId,
        maxId: maxId,
        types: selectedType != nil ? [selectedType!.rawValue] : nil,
        excludeTypes: queryTypes,
        accountId: nil,
        groupedTypes: groupedTypes,
        expandAccounts: "full"
      ),
      forceVersion: .v2
    )

    var consolidated: [ConsolidatedNotification] = []
    for group in results.notificationGroups {
      let accounts = group.sampleAccountIds.compactMap { accountId in
        results.accounts.first { $0.id == accountId }
      }
      let status = group.statusId.flatMap { statusId in
        results.statuses.first { $0.id == statusId }
      }

      if let notificationType = Models.Notification.NotificationType(rawValue: group.type),
        !accounts.isEmpty
      {
        consolidated.append(
          ConsolidatedNotification(
            notifications: [],
            mostRecentNotificationId: String(group.mostRecentNotificationId),
            type: notificationType,
            createdAt: group.latestPageNotificationAt,
            accounts: accounts,
            status: status,
            groupKey: group.groupKey
          ))
      }
    }

    return GroupedNotificationsFetchResult(
      consolidated: consolidated,
      lastGroup: results.notificationGroups.last,
      hasMore: results.notificationGroups.count >= 40
    )
  }
}

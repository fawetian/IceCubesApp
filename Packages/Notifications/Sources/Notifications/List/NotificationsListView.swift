/*
 * NotificationsListView.swift
 * IceCubesApp - 通知列表视图
 *
 * 文件功能：
 * 展示 Mastodon 通知列表，支持按类型过滤、下拉刷新和实时更新。
 *
 * 核心职责：
 * - 加载并显示通知列表（提及、关注、点赞、转发等）
 * - 提供通知类型过滤（可选）
 * - 展示通知策略和过滤的通知数量
 * - 处理实时流事件更新
 * - 支持下拉刷新和分页加载
 *
 * 技术要点：
 * - NotificationsListDataSource 管理数据
 * - NotificationsListState 管理视图状态
 * - 支持锁定类型和账户 ID（查看特定通知）
 * - 实时流事件处理
 * - scenePhase 监听前后台切换
 *
 * 使用场景：
 * - 通知 Tab 的主视图
 * - 查看所有通知或特定类型通知
 * - 查看特定用户的通知
 *
 * 依赖关系：
 * - DesignSystem: 主题和布局
 * - Env: CurrentAccount、StreamWatcher、RouterPath
 * - Models: Notification、NotificationsPolicy
 * - NetworkClient: MastodonClient
 */

import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

/// 通知列表视图。
///
/// 展示 Mastodon 通知，支持过滤和实时更新。
@MainActor
public struct NotificationsListView: View {
  @Environment(\.scenePhase) private var scenePhase

  @Environment(Theme.self) private var theme
  @Environment(StreamWatcher.self) private var watcher
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath
  @Environment(CurrentAccount.self) private var account
  @Environment(CurrentInstance.self) private var currentInstance

  /// 通知数据源。
  @State private var dataSource = NotificationsListDataSource()
  /// 视图状态（加载中、已加载、错误）。
  @State private var viewState: NotificationsListState = .loading
  /// 当前选择的通知类型过滤器。
  @State private var selectedType: Models.Notification.NotificationType?
  /// 通知策略（控制哪些通知被过滤）。
  @State private var policy: Models.NotificationsPolicy?
  /// 是否显示通知策略设置页面。
  @State private var isNotificationsPolicyPresented: Bool = false

  /// 锁定的通知类型（只显示特定类型）。
  let lockedType: Models.Notification.NotificationType?
  /// 锁定的账户 ID（只显示特定账户的通知）。
  let lockedAccountId: String?
  /// 是否为锁定类型模式。
  let isLockedType: Bool

  /// 初始化方法。
  ///
  /// - Parameters:
  ///   - lockedType: 可选的锁定通知类型。
  ///   - lockedAccountId: 可选的锁定账户 ID。
  public init(
    lockedType: Models.Notification.NotificationType? = nil,
    lockedAccountId: String? = nil
  ) {
    self.lockedType = lockedType
    self.lockedAccountId = lockedAccountId
    self.isLockedType = lockedType != nil
  }

  public var body: some View {
    List {
      if lockedAccountId == nil, let summary = policy?.summary {
        NotificationsHeaderFilteredView(filteredNotifications: summary)
      }
      notificationsView
        .listSectionSeparator(.hidden, edges: .top)
    }
    .id(account.account?.id)
    .environment(\.defaultMinListRowHeight, 1)
    .listStyle(.plain)
    .toolbar {
      ToolbarItem(placement: .principal) {
        let title =
          lockedType?.menuTitle() ?? selectedType?.menuTitle()
          ?? "notifications.navigation-title"
        if lockedType == nil {
          Text(title)
            .font(.headline)
            .accessibilityRepresentation {
              Menu(title) {}
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityRemoveTraits(.isButton)
            .accessibilityRespondsToUserInteraction(true)
        } else {
          Text(title)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
        }
      }
    }
    .toolbar {
      if lockedType == nil && lockedAccountId == nil {
        ToolbarTitleMenu {
          Button {
            applyFilter(type: nil)
          } label: {
            Label("notifications.navigation-title", systemImage: "bell.fill")
              .tint(theme.labelColor)
          }
          Divider()
          ForEach(Notification.NotificationType.allCases, id: \.self) { type in
            Button {
              applyFilter(type: type)
            } label: {
              Label {
                Text(type.menuTitle())
              } icon: {
                type.icon(isPrivate: false)
              }
            }
            .tint(theme.labelColor)
          }
          if currentInstance.isNotificationsFilterSupported {
            Divider()
            Button {
              isNotificationsPolicyPresented = true
            } label: {
              Label("notifications.content-filter.title", systemImage: "line.3.horizontal.decrease")
            }
            .tint(theme.labelColor)
          }
          Divider()
          Button {
            routerPath.navigate(to: .conversations)
          } label: {
            Label("Direct Messages", systemImage: "message")
          }
          .tint(theme.labelColor)
        }
      }
    }
    .sheet(isPresented: $isNotificationsPolicyPresented) {
      NotificationsPolicyView()
        .environment(client)
        .environment(theme)
    }
    .navigationBarTitleDisplayMode(.inline)
    #if !os(visionOS)
      .scrollContentBackground(.hidden)
      .background(theme.primaryBackgroundColor)
    #endif
    .task {
      if let lockedType {
        selectedType = lockedType
      }
      await fetchNotifications()
      policy = await dataSource.fetchPolicy(client: client)
    }
    .refreshable {
      SoundEffectManager.shared.playSound(.pull)
      HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
      await fetchNotifications()
      policy = await dataSource.fetchPolicy(client: client)
      HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
      SoundEffectManager.shared.playSound(.refresh)
    }
    .onChange(of: watcher.latestEvent?.id) {
      if let latestEvent = watcher.latestEvent {
        Task {
          await handleStreamEvent(latestEvent)
        }
      }
    }
    .onChange(of: scenePhase) { _, newValue in
      switch newValue {
      case .active:
        Task {
          await fetchNotifications()
        }
      default:
        break
      }
    }
    .onChange(of: client) { oldValue, newValue in
      guard oldValue.id != newValue.id else { return }
      dataSource.reset()
      viewState = .loading
      Task {
        await fetchNotifications()
        policy = await dataSource.fetchPolicy(client: client)
      }
    }
  }

  @ViewBuilder
  private var notificationsView: some View {
    switch viewState {
    case .loading:
      ForEach(ConsolidatedNotification.placeholders()) { notification in
        NotificationRowView(
          notification: notification,
          client: client,
          routerPath: routerPath,
          followRequests: account.followRequests
        )
        .listRowInsets(
          .init(
            top: 12,
            leading: .layoutPadding + 4,
            bottom: 0,
            trailing: .layoutPadding)
        )
        #if os(visionOS)
          .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
              .foregroundStyle(.background))
        #else
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
      }

    case .display(let notifications, let nextPageState):
      if notifications.isEmpty {
        PlaceholderView(
          iconName: "bell.slash",
          title: "notifications.empty.title",
          message: "notifications.empty.message"
        )
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
        .listSectionSeparator(.hidden)
      } else {
        ForEach(notifications) { notification in
          NotificationRowView(
            notification: notification,
            client: client,
            routerPath: routerPath,
            followRequests: account.followRequests
          )
          .listRowInsets(
            .init(
              top: 12,
              leading: .layoutPadding + 4,
              bottom: 6,
              trailing: .layoutPadding)
          )
          #if os(visionOS)
            .listRowBackground(
              RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(
                  notification.type == .mention && lockedType != .mention
                    ? Material.thick : Material.regular
                ).hoverEffect()
            )
            .listRowHoverEffectDisabled()
          #else
            .listRowBackground(
              notification.type == .mention && lockedType != .mention
                ? theme.secondaryBackgroundColor : theme.primaryBackgroundColor)
          #endif
          .id(notification.id)
        }

        switch nextPageState {
        case .none:
          EmptyView()
        case .hasNextPage:
          NextPageView {
            await fetchNextPage()
          }
          .listRowInsets(
            .init(
              top: .layoutPadding,
              leading: .layoutPadding + 4,
              bottom: .layoutPadding,
              trailing: .layoutPadding)
          )
          #if !os(visionOS)
            .listRowBackground(theme.primaryBackgroundColor)
          #endif
        }
      }

    case .error:
      ErrorView(
        title: "notifications.error.title",
        message: "notifications.error.message",
        buttonTitle: "action.retry"
      ) {
        await fetchNotifications()
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
      .listSectionSeparator(.hidden)
    }
  }
}

extension NotificationsListView {
  private func applyFilter(type: Models.Notification.NotificationType?) {
    selectedType = type
    dataSource.reset()
    viewState = .loading

    Task {
      await fetchNotifications()
    }
  }

  private func fetchNotifications() async {
    do {
      let result = try await dataSource.fetchNotifications(
        client: client,
        selectedType: selectedType,
        lockedAccountId: lockedAccountId
      )

      withAnimation {
        viewState = .display(
          notifications: result.notifications,
          nextPageState: result.nextPageState
        )
      }

      if result.containsFollowRequests {
        await account.fetchFollowerRequests()
      }
    } catch {
      if !Task.isCancelled {
        viewState = .error(error: error)
      }
    }
  }

  private func fetchNextPage() async {
    do {
      let result = try await dataSource.fetchNextPage(
        client: client,
        selectedType: selectedType,
        lockedAccountId: lockedAccountId
      )

      viewState = .display(
        notifications: result.notifications,
        nextPageState: result.nextPageState
      )

      if result.containsFollowRequests {
        await account.fetchFollowerRequests()
      }
    } catch {}
  }

  private func handleStreamEvent(_ event: any StreamEvent) async {
    if let result = await dataSource.handleStreamEvent(
      event: event,
      selectedType: selectedType,
      lockedAccountId: lockedAccountId
    ) {
      withAnimation {
        viewState = .display(
          notifications: result.notifications,
          nextPageState: .hasNextPage
        )
      }

      if result.containsFollowRequest {
        await account.fetchFollowerRequests()
      }
    }
  }
}

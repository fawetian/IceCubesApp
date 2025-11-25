/*
 * TimelineView.swift
 * IceCubesApp - 时间线主视图
 *
 * 文件功能：
 * 在 iOS、macOS 和 visionOS 上展示 Mastodon 时间线，处理滚动、筛选、实时更新和快捷操作。
 *
 * 核心职责：
 * - 渲染时间线列表并根据筛选条件切换不同数据源
 * - 管理 pinned filter、标签组和内容过滤等用户偏好
 * - 监听 WebSocket 事件和 App 前后台切换，以保持时间线实时同步
 * - 在工具栏中提供流式刷新、标签筛选等操作入口
 *
 * 技术要点：
 * - SwiftUI + @MainActor 统一管理 UI 更新
 * - 通过 Environment 注入 Theme、Router、StreamWatcher、MastodonClient 等全局依赖
 * - 使用 @State 管理 TimelineViewModel、内容过滤器以及滚动定位
 * - 结合 iOS 26 的 safeAreaBar / ToolbarSpacer 与 26 以下版本的 toolbarBackground 做兼容适配
 * - 借助 refreshable / onChange / scenePhase 等修饰符实现数据刷新与生命周期管理
 *
 * 使用场景：
 * - 应用主界面的「主页 / 本地 / 标签 / 列表」等时间线
 * - 快速在已固定的过滤器之间切换
 * - 实时追踪未读帖子并自动滚动到新的状态
 * - 响应推送/实时事件并更新 UI
 *
 * 依赖关系：
 * - DesignSystem: 主题、配色与布局常量
 * - Env: CurrentAccount、RouterPath、StreamWatcher 等环境对象
 * - NetworkClient: MastodonClient 网络访问
 * - StatusKit: 时间线列表与单条帖子组件
 * - SwiftData / Models: 数据持久化与 Mastodon 数据模型
 */

import Charts
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftData
import SwiftUI

@MainActor
/// 时间线主入口视图。
///
/// - 负责渲染任意 `TimelineFilter` 对应的数据源（主页、本地、列表、标签等）。
/// - 根据系统版本提供不同的顶部辅助 UI（safeAreaBar / toolbarBackground）。
/// - 管理 pinned filters、标签组、内容过滤、实时事件以及前后台切换。
/// - 提供下拉刷新、未读提示条和流式加载开关等交互。
public struct TimelineView: View {
  /// 监听场景生命周期，判断应用是否进入后台。
  @Environment(\.scenePhase) private var scenePhase

  /// 全局主题，负责配色与材质。
  @Environment(Theme.self) private var theme
  /// 当前登录账户，用于读取列表和偏好。
  @Environment(CurrentAccount.self) private var account
  /// 实时流监听器，接收服务器推送的时间线事件。
  @Environment(StreamWatcher.self) private var watcher
  /// Mastodon API 客户端，根据不同时间线切换实例。
  @Environment(MastodonClient.self) private var client
  /// 应用路由，用于跳转到标签、列表等页面。
  @Environment(RouterPath.self) private var routerPath

  /// 时间线视图模型，封装分页、实时刷新等逻辑。
  @State private var viewModel = TimelineViewModel()
  /// 内容过滤配置，决定是否展示转发、回复等。
  @State private var contentFilter = TimelineContentFilter.shared

  /// 指向需要平滑滚动到的帖子 ID。
  @State private var scrollToIdAnimated: String? = nil

  /// 标记应用是否曾离开前台，用于回来时触发刷新。
  @State private var wasBackgrounded: Bool = false

  /// 当前展示的时间线过滤器（例如 home / local / list）。
  @Binding var timeline: TimelineFilter
  /// 用户固定在工具栏下方的快捷过滤器。
  @Binding var pinnedFilters: [TimelineFilter]
  /// 当前选择的标签组（探索 Tab 使用）。
  @Binding var selectedTagGroup: TagGroup?

  /// 是否允许在 UI 中切换过滤器。
  private let canFilterTimeline: Bool

  /// 在 iOS 26 之前，通过切换 toolbarBackground 的可见性来模拟 iOS 26 的 safeAreaBar 行为。
  private var toolbarBackgroundVisibility: SwiftUI.Visibility {
    if canFilterTimeline, !pinnedFilters.isEmpty {
      return .hidden
    }
    return .visible
  }

  /// 初始化方法
  ///
  /// - Parameters:
  ///   - timeline: 绑定到当前时间线过滤器
  ///   - pinnedFilters: 绑定到已固定的过滤器集合
  ///   - selectedTagGroup: 绑定到探索页的标签组选择
  ///   - canFilterTimeline: 控制是否显示过滤器 UI
  public init(
    timeline: Binding<TimelineFilter>,
    pinnedFilters: Binding<[TimelineFilter]>,
    selectedTagGroup: Binding<TagGroup?>,
    canFilterTimeline: Bool
  ) {
    _timeline = timeline
    _pinnedFilters = pinnedFilters
    _selectedTagGroup = selectedTagGroup
    self.canFilterTimeline = canFilterTimeline
  }

  /// 视图主体
  ///
  /// 根据系统版本选择 safeAreaBar（iOS26+）或 toolbarBackground（iOS25-）方案，
  /// 并在顶部插入 pinned filter pills。
  public var body: some View {
    if #available(iOS 26.0, *) {
      timelineView
        .safeAreaBar(edge: .top) {
          if canFilterTimeline, !pinnedFilters.isEmpty {
            TimelineQuickAccessPills(pinnedFilters: $pinnedFilters, timeline: $timeline)
              .padding(.horizontal, .layoutPadding)
          }
        }
    } else {
      timelineView
        .toolbarBackground(toolbarBackgroundVisibility, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
          if canFilterTimeline, !pinnedFilters.isEmpty {
            VStack(spacing: 0) {
              TimelineQuickAccessPills(pinnedFilters: $pinnedFilters, timeline: $timeline)
                .padding(.vertical, 8)
                .padding(.horizontal, .layoutPadding)
                .background(theme.primaryBackgroundColor.opacity(0.30))
                .background(Material.ultraThin)
              Divider()
            }
          }
        }
    }
  }

  /// 时间线核心内容
  ///
  /// - 使用 `TimelineListView` 显示帖子列表。
  /// - 当时间线支持「最新分页」时展示未读提示条，点击后滚动到最新帖子。
  /// - 工具栏中提供流式刷新按钮、标签组按钮等操作。
  private var timelineView: some View {
    ZStack(alignment: .top) {
      TimelineListView(
        viewModel: viewModel,
        timeline: $timeline,
        pinnedFilters: $pinnedFilters,
        selectedTagGroup: $selectedTagGroup,
        scrollToIdAnimated: $scrollToIdAnimated)
      if viewModel.timeline.supportNewestPagination {
        TimelineUnreadStatusesView(observer: viewModel.pendingStatusesObserver) { statusId in
          if let statusId {
            scrollToIdAnimated = statusId
          }
        }
      }
    }
    .toolbar {
      TimelineToolbarTitleView(timeline: $timeline, canFilterTimeline: canFilterTimeline)
      if #available(iOS 26.0, *) {
        ToolbarSpacer(placement: .topBarTrailing)
      }
      if viewModel.canStreamTimeline(timeline) {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            viewModel.isStreamingTimeline.toggle()
          } label: {
            Image(
              systemName: viewModel.isStreamingTimeline
                ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
          }
          .tint(theme.labelColor)
        }
      }
      TimelineToolbarTagGroupButton(timeline: $timeline)
    }
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      // 首次出现时同步 viewModel 的过滤支持与网络客户端。
      viewModel.canFilterTimeline = canFilterTimeline

      if viewModel.client == nil {
        switch timeline {
        case .remoteLocal(let server, _):
          viewModel.client = MastodonClient(server: server)
        default:
          viewModel.client = client
        }
      }

      viewModel.timeline = timeline
    }
    .onDisappear {
      // 离开页面前保存上次阅读的帖子进度。
      viewModel.saveMarker()
    }
    .refreshable {
      SoundEffectManager.shared.playSound(.pull)
      HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
      await viewModel.pullToRefresh()
      HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
      SoundEffectManager.shared.playSound(.refresh)
    }
    .onChange(of: watcher.latestEvent?.id) {
      // 收到 WebSocket 新事件后交给 viewModel 处理。
      Task {
        if let latestEvent = watcher.latestEvent {
          await viewModel.handleEvent(event: latestEvent)
        }
      }
    }
    .onChange(of: account.lists) { _, lists in
      // 本地列表标题更新时，保持当前时间线与服务器数据一致。
      guard client.isAuth else { return }
      switch timeline {
      case .list(let list):
        if let accountList = lists.first(where: { $0.id == list.id }),
          list.id == accountList.id,
          accountList.title != list.title
        {
          timeline = .list(list: accountList)
        }
      default:
        break
      }
    }
    .onChange(of: timeline) { oldValue, newValue in
      // 当外部切换时间线时，更新 viewModel 的 client 与 timeline。
      guard oldValue != newValue else { return }
      switch newValue {
      case .remoteLocal(let server, _):
        viewModel.client = MastodonClient(server: server)
      default:
        switch oldValue {
        case .remoteLocal(let server, _):
          if newValue == .latest {
            viewModel.client = MastodonClient(server: server)
          } else {
            viewModel.client = client
          }
        default:
          viewModel.client = client
        }
      }
      viewModel.timeline = newValue
    }
    .onChange(of: viewModel.timeline) { oldValue, newValue in
      // 当内部 viewModel 变更时，反向写回绑定，保持状态一致。
      guard oldValue != newValue, timeline != newValue else { return }
      timeline = newValue
    }
    .onChange(of: contentFilter.showReplies) { _, _ in
      // 用户切换内容过滤时刷新时间线数据。
      Task { await viewModel.refreshTimelineContentFilter() }
    }
    .onChange(of: contentFilter.showBoosts) { _, _ in
      Task { await viewModel.refreshTimelineContentFilter() }
    }
    .onChange(of: contentFilter.showThreads) { _, _ in
      Task { await viewModel.refreshTimelineContentFilter() }
    }
    .onChange(of: contentFilter.showQuotePosts) { _, _ in
      Task { await viewModel.refreshTimelineContentFilter() }
    }
    .onChange(of: scenePhase) { _, newValue in
      switch newValue {
      case .active:
        if wasBackgrounded {
          wasBackgrounded = false
          viewModel.refreshTimeline()
        }
      case .background:
        wasBackgrounded = true
        viewModel.saveMarker()

      default:
        break
      }
    }
  }
}

/*
 * AppView.swift
 * IceCubesApp - 应用主视图
 *
 * 文件功能：
 * 应用的根视图，管理标签栏、侧边栏和多窗口布局。
 *
 * 核心职责：
 * - 构建 TabView 和侧边栏布局
 * - 管理标签页切换和导航
 * - 支持 iPad 副栏显示（通知列）
 * - 加载本地时间线和标签组
 * - 处理不同设备类型的布局（iPhone/iPad/Mac/visionOS）
 * - 显示未读徽章
 *
 * 技术要点：
 * - TabView 新 API（iOS 18+）
 * - SwiftData @Query 查询本地数据
 * - 自适应布局（horizontalSizeClass）
 * - SidebarSections 动态侧边栏
 * - TabPlacement 标签位置控制
 *
 * 使用场景：
 * - 应用的根视图容器
 * - 多标签页导航
 * - iPad 分屏显示
 *
 * 依赖关系：
 * - Env: 所有环境对象
 * - SwiftData: 本地数据查询
 * - Timeline: 时间线视图
 * - Account: 账户视图
 */

import AVFoundation
import Account
import AppAccount
import DesignSystem
import Env
import KeychainSwift
import MediaUI
import Models
import NetworkClient
import RevenueCat
import StatusKit
import SwiftData
import SwiftUI
import Timeline

/// 应用主视图。
///
/// 构建应用的根布局，包括标签栏和侧边栏。
@MainActor
struct AppView: View {
  /// SwiftData 模型上下文。
  @Environment(\.modelContext) private var context
  /// 打开新窗口的函数。
  @Environment(\.openWindow) var openWindow
  /// 水平尺寸类（紧凑/常规）。
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// 多账户管理器。
  @Environment(AppAccountsManager.self) private var appAccountsManager
  /// 用户偏好设置。
  @Environment(UserPreferences.self) private var userPreferences
  /// 主题管理器。
  @Environment(Theme.self) private var theme
  /// 实时流监听器。
  @Environment(StreamWatcher.self) private var watcher
  /// 当前账户管理器。
  @Environment(CurrentAccount.self) private var currentAccount

  /// 当前选中的标签页（绑定到父视图）。
  @Binding var selectedTab: AppTab
  /// 应用路由路径（绑定到父视图）。
  @Binding var appRouterPath: RouterPath

  /// iOS 标签页管理器。
  @State var iosTabs = iOSTabs.shared
  /// 标签页滚动到顶部的触发器。
  @State var selectedTabScrollToTop: Int = -1
  /// 当前时间线过滤器。
  @State var timeline: TimelineFilter = .home

  /// 固定的时间线过滤器列表（持久化）。
  @AppStorage("timeline_pinned_filters") private var pinnedFilters: [TimelineFilter] = []

  /// 本地时间线列表（SwiftData 查询）。
  @Query(sort: \LocalTimeline.creationDate, order: .reverse) var localTimelines: [LocalTimeline]
  /// 标签组列表（SwiftData 查询）。
  @Query(sort: \TagGroup.creationDate, order: .reverse) var tagGroups: [TagGroup]

  /// 视图主体。
  var body: some View {
    HStack(spacing: 0) {
      tabBarView
        .tabViewStyle(.sidebarAdaptable)
      if horizontalSizeClass == .regular
        && (UIDevice.current.userInterfaceIdiom == .pad
          || UIDevice.current.userInterfaceIdiom == .mac),
        appAccountsManager.currentClient.isAuth,
        userPreferences.showiPadSecondaryColumn
      {
        Divider().edgesIgnoringSafeArea(.all)
        notificationsSecondaryColumn
      }
    }
  }

  /// 可用的侧边栏区块列表。
  ///
  /// 根据设备类型、登录状态和数据动态生成侧边栏区块。
  var availableSections: [SidebarSections] {
    guard appAccountsManager.currentClient.isAuth else {
      return [SidebarSections.loggedOutTabs]
    }
    if UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact {
      return [SidebarSections.iosTabs]
    } else if UIDevice.current.userInterfaceIdiom == .vision {
      return [SidebarSections.visionOSTabs]
    }
    var sections = SidebarSections.macOrIpadOSSections
    if !localTimelines.isEmpty {
      sections.append(.localTimeline)
    }
    if !tagGroups.isEmpty {
      sections.append(.tagGroup)
    }
    sections.append(.app)
    return sections
  }

  /// 标签栏视图。
  ///
  /// 使用 iOS 18+ 的新 TabView API 构建动态标签栏。
  @ViewBuilder
  var tabBarView: some View {
    TabView(
      selection: .init(
        get: {
          selectedTab
        },
        set: { newTab in
          updateTab(with: newTab)
        })
    ) {
      ForEach(availableSections) { section in
        TabSection(section.title) {
          if section == .localTimeline {
            ForEach(localTimelines) { timeline in
              let tab = AppTab.anyTimelineFilter(
                filter: .remoteLocal(server: timeline.instance, filter: .local))
              Tab(value: tab) {
                tab.makeContentView(
                  homeTimeline: $timeline, selectedTab: $selectedTab, pinnedFilters: $pinnedFilters)
              } label: {
                tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
              }
              .tabPlacement(tab.tabPlacement)
            }
          } else if section == .tagGroup {
            ForEach(tagGroups) { tagGroup in
              let tab = AppTab.anyTimelineFilter(
                filter: TimelineFilter.tagGroup(
                  title: tagGroup.title,
                  tags: tagGroup.tags,
                  symbolName: tagGroup.symbolName))
              Tab(value: tab) {
                tab.makeContentView(
                  homeTimeline: $timeline, selectedTab: $selectedTab, pinnedFilters: $pinnedFilters)
              } label: {
                tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
              }
              .tabPlacement(tab.tabPlacement)
            }
          } else {
            ForEach(section.tabs) { tab in
              Tab(value: tab, role: tab == .explore ? .search : .none) {
                tab.makeContentView(
                  homeTimeline: $timeline, selectedTab: $selectedTab, pinnedFilters: $pinnedFilters)
              } label: {
                tab.label.environment(\.symbolVariants, tab == selectedTab ? .fill : .none)
              }
              .tabPlacement(tab.tabPlacement)
              .badge(badgeFor(tab: tab))
            }
          }
        }
        .tabPlacement(.sidebarOnly)
      }
    }
    .id(appAccountsManager.currentClient.id)
    .withSheetDestinations(sheetDestinations: $appRouterPath.presentedSheet)
    .environment(\.selectedTabScrollToTop, selectedTabScrollToTop)
  }

  /// 更新当前选中的标签页。
  ///
  /// 处理标签切换逻辑，包括发帖特殊处理、触觉反馈和滚动到顶部。
  ///
  /// - Parameter newTab: 新选中的标签页。
  private func updateTab(with newTab: AppTab) {
    if newTab == .post {
      #if os(visionOS)
        openWindow(
          value: WindowDestinationEditor.newStatusEditor(visibility: userPreferences.postVisibility)
        )
      #else
        appRouterPath.presentedSheet = .newStatusEditor(visibility: userPreferences.postVisibility)
      #endif
      return
    }

    HapticManager.shared.fireHaptic(.tabSelection)
    SoundEffectManager.shared.playSound(.tabSelection)

    if selectedTab == newTab {
      selectedTabScrollToTop = newTab.id
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        selectedTabScrollToTop = -1
      }
    } else {
      selectedTabScrollToTop = -1
    }

    selectedTab = newTab
  }

  /// 计算标签页的未读徽章数量。
  ///
  /// 仅通知标签显示未读数（实时流 + 本地计数）。
  ///
  /// - Parameter tab: 标签页。
  /// - Returns: 未读数量。
  private func badgeFor(tab: AppTab) -> Int {
    if tab == .notifications, selectedTab != tab,
      let token = appAccountsManager.currentAccount.oauthToken
    {
      return watcher.unreadNotificationsCount + (userPreferences.notificationsCount[token] ?? 0)
    }
    return 0
  }

  /// 通知副栏视图（iPad/Mac 分屏显示）。
  var notificationsSecondaryColumn: some View {
    NotificationsTab(selectedTab: .constant(.notifications), lockedType: nil)
      .environment(\.isSecondaryColumn, true)
      .frame(maxWidth: .secondaryColumnWidth)
      .id(appAccountsManager.currentAccount.id)
  }
}

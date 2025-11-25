/*
 * TimelineListView.swift
 * IceCubesApp - 时间线列表视图
 *
 * 文件功能：
 * 时间线的核心列表容器，负责渲染帖子列表、标签头部和滚动控制。
 *
 * 核心职责：
 * - 使用 ScrollViewReader 管理列表滚动和定位
 * - 根据时间线类型（本地/远程）切换不同的 StatusesListView
 * - 显示标签组头部和标签详情头部
 * - 响应 Tab 点击回到顶部的交互
 *
 * 技术要点：
 * - ScrollViewReader + proxy.scrollTo 实现编程滚动
 * - @Binding 绑定外部状态（timeline、pinnedFilters、scrollToIdAnimated）
 * - 通过 onChange 监听滚动目标 ID 变化
 * - 根据 client.id 刷新列表视图
 *
 * 使用场景：
 * - TimelineView 的子视图，承载实际的帖子列表
 * - 处理滚动到顶部、滚动到指定帖子等交互
 *
 * 依赖关系：
 * - DesignSystem: Theme、ScrollToView
 * - Env: RouterPath、MastodonClient
 * - StatusKit: StatusesListView
 * - Models: TimelineFilter、TagGroup
 */

import Charts
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftData
import SwiftUI

/// 时间线列表视图。
///
/// 包装 StatusesListView，提供滚动控制和标签头部显示。
@MainActor
struct TimelineListView: View {
  /// 监听 Tab 双击事件（用于滚动到顶部）。
  @Environment(\.selectedTabScrollToTop) private var selectedTabScrollToTop

  /// Mastodon 客户端。
  @Environment(MastodonClient.self) private var client
  /// 应用路由。
  @Environment(RouterPath.self) private var routerPath
  /// 全局主题。
  @Environment(Theme.self) private var theme

  /// 时间线视图模型（提供数据和业务逻辑）。
  var viewModel: TimelineViewModel
  /// 当前时间线过滤器。
  @Binding var timeline: TimelineFilter
  /// 已固定的过滤器列表。
  @Binding var pinnedFilters: [TimelineFilter]
  /// 选中的标签组。
  @Binding var selectedTagGroup: TagGroup?
  /// 需要动画滚动到的帖子 ID。
  @Binding var scrollToIdAnimated: String?

  /// 视图主体。
  var body: some View {
    @Bindable var viewModel = viewModel
    ScrollViewReader { proxy in
      List {
        ScrollToView()
          .frame(height: pinnedFilters.isEmpty ? .layoutPadding : 0)
          .onAppear {
            viewModel.scrollToTopVisible = true
          }
          .onDisappear {
            viewModel.scrollToTopVisible = false
          }
        TimelineTagGroupheaderView(group: $selectedTagGroup, timeline: $timeline)
        TimelineTagHeaderView(tag: $viewModel.tag)
        switch viewModel.timeline {
        case .remoteLocal:
          StatusesListView(
            fetcher: viewModel, client: client, routerPath: routerPath, isRemote: true)
        default:
          StatusesListView(fetcher: viewModel, client: client, routerPath: routerPath)
            .environment(\.isHomeTimeline, timeline == .home)
        }
      }
      .id(client.id)
      .environment(\.defaultMinListRowHeight, 1)
      .listStyle(.plain)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.primaryBackgroundColor)
      #endif
      .onChange(of: viewModel.scrollToId) { _, newValue in
        if let newValue {
          proxy.scrollTo(newValue, anchor: .top)
          viewModel.scrollToId = nil
        }
      }
      .onChange(of: scrollToIdAnimated) { _, newValue in
        if let newValue {
          withAnimation {
            proxy.scrollTo(newValue, anchor: .top)
            scrollToIdAnimated = nil
          }
        }
      }
      .onChange(of: selectedTabScrollToTop) { _, newValue in
        if newValue == 0, routerPath.path.isEmpty {
          withAnimation {
            proxy.scrollTo(ScrollToView.Constants.scrollToTop, anchor: .top)
          }
        }
      }
    }
  }
}

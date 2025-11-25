/*
 * ExploreView.swift
 * IceCubesApp - 探索页视图
 *
 * 文件功能：
 * 提供 Mastodon 的发现和搜索功能，展示趋势标签、热门帖子、推荐账户和趋势链接。
 *
 * 核心职责：
 * - 加载并显示趋势内容（标签、帖子、链接）
 * - 提供全文搜索功能（账户、标签、帖子）
 * - 展示推荐关注账户
 * - 支持搜索范围切换和分页加载
 *
 * 技术要点：
 * - @State 管理搜索状态和趋势数据
 * - async let 并发加载多个 API
 * - searchable 修饰符提供搜索栏
 * - searchScopes 提供搜索范围选择
 * - Task.sleep 防抖搜索请求
 *
 * 使用场景：
 * - 探索 Tab 的主视图
 * - 发现新内容和账户
 * - 搜索帖子、用户、标签
 *
 * 依赖关系：
 * - DesignSystem: 主题和布局
 * - Env: RouterPath、MastodonClient
 * - Models: Tag、Status、Account、Card
 * - NetworkClient: Search、Trends、Accounts 端点
 * - StatusKit: 帖子显示组件
 */

import Account
import DesignSystem
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

/// 探索页视图。
///
/// 提供趋势内容展示和全文搜索功能。
@MainActor
public struct ExploreView: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath

  /// 搜索查询字符串。
  @State private var searchQuery = ""
  /// 搜索范围（全部、账户、标签、帖子）。
  @State private var searchScope: SearchScope = .all
  /// 是否显示搜索界面。
  @State private var isSearchPresented = false
  /// 是否已加载趋势数据。
  @State private var isLoaded = false
  /// 是否正在搜索。
  @State private var isSearching = false
  /// 搜索结果缓存（键为搜索词）。
  @State private var results: [String: SearchResults] = [:]
  /// 推荐关注账户列表。
  @State private var suggestedAccounts: [Account] = []
  /// 推荐账户的关系状态。
  @State private var suggestedAccountsRelationShips: [Relationship] = []
  /// 趋势标签列表。
  @State private var trendingTags: [Tag] = []
  /// 趋势帖子列表。
  @State private var trendingStatuses: [Status] = []
  /// 趋势链接列表。
  @State private var trendingLinks: [Card] = []
  /// 顶部滚动锚点是否可见。
  @State private var scrollToTopVisible = false

  /// 是否所有区块都为空（用于显示占位符）。
  private var allSectionsEmpty: Bool {
    trendingLinks.isEmpty && trendingTags.isEmpty && trendingStatuses.isEmpty
      && suggestedAccounts.isEmpty
  }

  /// 初始化方法。
  public init() {}

  public var body: some View {
    ScrollViewReader { proxy in
      List {
        scrollToTopView
        if !isLoaded {
          QuickAccessView(
            trendingLinks: trendingLinks,
            suggestedAccounts: suggestedAccounts,
            trendingTags: trendingTags
          )
          loadingView
        } else if !searchQuery.isEmpty {
          if let results = results[searchQuery] {
            if results.isEmpty, !isSearching {
              PlaceholderView(
                iconName: "magnifyingglass",
                title: "explore.search.empty.title",
                message: "explore.search.empty.message"
              )
              .listRowBackground(theme.secondaryBackgroundColor)
              .listRowSeparator(.hidden)
            } else {
              SearchResultsView(
                results: results,
                searchScope: searchScope,
                onNextPage: fetchNextPage
              )
            }
          } else {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            #if !os(visionOS)
              .listRowBackground(theme.secondaryBackgroundColor)
            #endif
            .listRowSeparator(.hidden)
            .id(UUID())
          }
        } else if allSectionsEmpty {
          PlaceholderView(
            iconName: "magnifyingglass",
            title: "explore.search.title",
            message: "explore.search.message-\(client.server)"
          )
          #if !os(visionOS)
            .listRowBackground(theme.secondaryBackgroundColor)
          #endif
          .listRowSeparator(.hidden)
        } else {
          QuickAccessView(
            trendingLinks: trendingLinks,
            suggestedAccounts: suggestedAccounts,
            trendingTags: trendingTags
          )
          .padding(.bottom, 4)

          if !trendingTags.isEmpty {
            TrendingTagsSection(trendingTags: trendingTags)
          }
          if !suggestedAccounts.isEmpty {
            SuggestedAccountsSection(
              suggestedAccounts: suggestedAccounts,
              suggestedAccountsRelationShips: suggestedAccountsRelationShips
            )
          }
          if !trendingStatuses.isEmpty {
            TrendingPostsSection(trendingStatuses: trendingStatuses)
          }
          if !trendingLinks.isEmpty {
            TrendingLinksSection(trendingLinks: trendingLinks)
          }
        }
      }
      .environment(\.defaultMinListRowHeight, .scrollToViewHeight)
      .task {
        await fetchTrending()
      }
      .refreshable {
        Task {
          SoundEffectManager.shared.playSound(.pull)
          HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
          await fetchTrending()
          HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
          SoundEffectManager.shared.playSound(.refresh)
        }
      }
      .listStyle(.grouped)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.secondaryBackgroundColor.edgesIgnoringSafeArea(.all))
      #endif
      .navigationTitle("explore.navigation-title")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(
        text: $searchQuery,
        isPresented: $isSearchPresented,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: Text("explore.search.prompt")
      )
      .searchScopes($searchScope) {
        ForEach(SearchScope.allCases, id: \.self) { scope in
          Text(scope.localizedString)
        }
      }
      .task(id: searchQuery) {
        await search()
      }
    }
  }

  private var loadingView: some View {
    ForEach(Status.placeholders()) { status in
      StatusRowExternalView(
        viewModel: .init(status: status, client: client, routerPath: routerPath)
      )
      .padding(.vertical, 8)
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
  }

  private var scrollToTopView: some View {
    ScrollToView()
      .frame(height: .scrollToViewHeight)
      .onAppear {
        scrollToTopVisible = true
      }
      .onDisappear {
        scrollToTopVisible = false
      }
  }
}

extension ExploreView {
  /// 拉取趋势数据（标签、帖子、链接、推荐账户）。
  private func fetchTrending() async {
    do {
      let data = try await fetchTrendingsData()
      suggestedAccounts = data.suggestedAccounts
      trendingTags = data.trendingTags
      trendingStatuses = data.trendingStatuses
      trendingLinks = data.trendingLinks

      suggestedAccountsRelationShips = try await client.get(
        endpoint: Accounts.relationships(ids: suggestedAccounts.map(\.id)))
      withAnimation {
        isLoaded = true
      }
    } catch {
      isLoaded = true
    }
  }

  /// 趋势数据聚合结构。
  private struct TrendingData {
    let suggestedAccounts: [Account]
    let trendingTags: [Tag]
    let trendingStatuses: [Status]
    let trendingLinks: [Card]
  }

  /// 并发拉取所有趋势数据。
  ///
  /// - Returns: 趋势数据聚合对象。
  private func fetchTrendingsData() async throws -> TrendingData {
    async let suggestedAccounts: [Account] = client.get(endpoint: Accounts.suggestions)
    async let trendingTags: [Tag] = client.get(endpoint: Trends.tags)
    async let trendingStatuses: [Status] = client.get(endpoint: Trends.statuses(offset: nil))
    async let trendingLinks: [Card] = client.get(endpoint: Trends.links(offset: nil))
    return try await .init(
      suggestedAccounts: suggestedAccounts,
      trendingTags: trendingTags,
      trendingStatuses: trendingStatuses,
      trendingLinks: trendingLinks)
  }

  /// 执行搜索（带防抖延迟）。
  private func search() async {
    guard !searchQuery.isEmpty else { return }
    isSearching = true
    do {
      try await Task.sleep(for: .milliseconds(250))
      var results: SearchResults = try await client.get(
        endpoint: Search.search(
          query: searchQuery,
          type: nil,
          offset: nil,
          following: nil),
        forceVersion: .v2)
      let relationships: [Relationship] =
        try await client.get(endpoint: Accounts.relationships(ids: results.accounts.map(\.id)))
      results.relationships = relationships
      withAnimation {
        self.results[searchQuery] = results
        isSearching = false
      }
    } catch {
      isSearching = false
    }
  }

  /// 加载搜索结果的下一页。
  ///
  /// - Parameter type: 实体类型（账户、标签、帖子）。
  private func fetchNextPage(of type: Search.EntityType) async {
    guard !searchQuery.isEmpty,
      let results = results[searchQuery]
    else { return }
    do {
      let offset =
        switch type {
        case .accounts:
          results.accounts.count
        case .hashtags:
          results.hashtags.count
        case .statuses:
          results.statuses.count
        }

      var newPageResults: SearchResults = try await client.get(
        endpoint: Search.search(
          query: searchQuery,
          type: type,
          offset: offset,
          following: nil),
        forceVersion: .v2)
      if type == .accounts {
        let relationships: [Relationship] =
          try await client.get(
            endpoint: Accounts.relationships(ids: newPageResults.accounts.map(\.id)))
        newPageResults.relationships = relationships
      }

      switch type {
      case .accounts:
        self.results[searchQuery]?.accounts.append(contentsOf: newPageResults.accounts)
        self.results[searchQuery]?.relationships.append(contentsOf: newPageResults.relationships)
      case .hashtags:
        self.results[searchQuery]?.hashtags.append(contentsOf: newPageResults.hashtags)
      case .statuses:
        self.results[searchQuery]?.statuses.append(contentsOf: newPageResults.statuses)
      }
    } catch {}
  }
}

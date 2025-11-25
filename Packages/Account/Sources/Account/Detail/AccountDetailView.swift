/*
 * AccountDetailView.swift
 * IceCubesApp - 账户详情视图
 *
 * 文件功能：
 * 展示 Mastodon 账户的完整个人资料，包括头像、横幅、简介、统计数据、特色标签和帖子列表。
 *
 * 核心职责：
 * - 加载并显示账户信息和关系状态
 * - 提供关注/取消关注等账户操作
 * - 展示账户的帖子、回复、媒体等标签页
 * - 处理账户翻译和关系备注编辑
 * - 监听实时事件更新账户状态
 *
 * 技术要点：
 * - @State 管理加载状态和账户数据
 * - TaskGroup 并发加载账户、关系、熟悉关注者
 * - TabManager 管理多个标签页的数据源
 * - ScrollViewReader 实现滚动到标签
 * - 实时流事件处理
 *
 * 使用场景：
 * - 点击用户名跳转到个人资料页
 * - 查看其他用户的详细信息
 * - 关注/屏蔽等账户操作
 *
 * 依赖关系：
 * - DesignSystem: 主题和布局
 * - Env: CurrentAccount、RouterPath、StreamWatcher
 * - Models: Account、Relationship
 * - NetworkClient: MastodonClient
 * - StatusKit: 状态列表组件
 */

import DesignSystem
import EmojiText
import Env
import Models
import NetworkClient
import StatusKit
import SwiftUI

/// 账户详情视图。
///
/// 完整展示 Mastodon 账户的个人资料和帖子列表。
@MainActor
public struct AccountDetailView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.redactionReasons) private var reasons
  @Environment(\.openWindow) private var openWindow

  @Environment(StreamWatcher.self) private var watcher
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(CurrentInstance.self) private var currentInstance
  @Environment(UserPreferences.self) private var preferences
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(RouterPath.self) private var routerPath

  /// 账户 ID。
  private let accountId: String

  /// 视图状态（加载中、已加载、错误）。
  @State private var viewState: AccountDetailState = .loading
  /// 当前账户与目标账户的关系。
  @State private var relationship: Relationship?
  /// 熟悉的关注者列表。
  @State private var familiarFollowers: [Account] = []
  /// 关注按钮视图模型。
  @State private var followButtonViewModel: FollowButtonViewModel?
  /// 账户简介翻译结果。
  @State private var translation: Translation?
  /// 是否正在加载翻译。
  @State private var isLoadingTranslation = false
  /// 是否为当前用户自己的账户。
  @State private var isCurrentUser: Bool = false

  /// 是否显示屏蔽确认对话框。
  @State private var showBlockConfirmation: Bool = false
  /// 是否正在编辑关系备注。
  @State private var isEditingRelationshipNote: Bool = false
  /// 是否显示翻译视图。
  @State private var showTranslateView: Bool = false
  /// 标签页管理器（管理帖子、回复、媒体等标签）。
  @State private var tabManager: AccountTabManager?

  /// 是否在导航栏显示账户名称。
  @State private var displayTitle: Bool = false

  /// 初始化方法（通过账户 ID）。
  ///
  /// 用于从 URL 或提及跳转到账户详情。
  ///
  /// - Parameter accountId: 账户 ID。
  public init(accountId: String) {
    self.accountId = accountId
    _viewState = .init(initialValue: .loading)
  }

  /// 初始化方法（已有账户对象）。
  ///
  /// 当父视图已经获取了账户数据时使用。
  ///
  /// - Parameter account: 账户对象。
  public init(account: Account) {
    self.accountId = account.id
    _viewState = .init(
      initialValue: .display(account: account, featuredTags: [], relationships: [], fields: []))
  }

  public var body: some View {
    ScrollViewReader { proxy in
      List {
        ScrollToView()
          .onAppear { displayTitle = false }
          .onDisappear { displayTitle = true }
        makeHeaderView(proxy: proxy)
          .applyAccountDetailsRowStyle(theme: theme)
          .padding(.bottom, -20)

        switch viewState {
        case .display(let account, let featuredTags, _, _):
          FamiliarFollowersView(familiarFollowers: familiarFollowers)
            .applyAccountDetailsRowStyle(theme: theme)
          FeaturedTagsView(featuredTags: featuredTags, accountId: accountId)
            .applyAccountDetailsRowStyle(theme: theme)
          if let tabManager {
            makeTabPicker(tabManager: tabManager)
              .pickerStyle(.segmented)
              .padding(.layoutPadding)
              .applyAccountDetailsRowStyle(theme: theme)
              .id("status")

            AnyView(
              tabManager.selectedTab.makeView(
                fetcher: tabManager.getFetcher(for: tabManager.selectedTab),
                client: client,
                routerPath: routerPath,
                account: account
              ))
          }
        default:
          EmptyView()
        }
      }
      .environment(\.defaultMinListRowHeight, 0)
      .listStyle(.plain)
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.primaryBackgroundColor)
      #endif
    }
    .onAppear {
      guard reasons != .placeholder else { return }
      isCurrentUser = currentAccount.account?.id == accountId

      if tabManager == nil {
        tabManager = AccountTabManager(
          accountId: accountId,
          client: client,
          isCurrentUser: isCurrentUser
        )
      }

      if let tabManager {
        Task {
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              await fetchAccount()
            }
            switch tabManager.currentTabFetcher.statusesState {
            case .loading, .error:
              group.addTask {
                await tabManager.currentTabFetcher.fetchNewestStatuses(pullToRefresh: false)
              }
            default:
              break
            }
            if !isCurrentUser {
              group.addTask {
                await fetchFamiliarFollowers()
              }
            }
          }
        }
      }
    }
    .refreshable {
      Task {
        SoundEffectManager.shared.playSound(.pull)
        HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.3))
        await fetchAccount()
        if let tabManager {
          await tabManager.refreshCurrentTab()
        }
        HapticManager.shared.fireHaptic(.dataRefresh(intensity: 0.7))
        SoundEffectManager.shared.playSound(.refresh)
      }
    }
    .onChange(of: watcher.latestEvent?.id) {
      if let latestEvent = watcher.latestEvent,
        accountId == currentAccount.account?.id,
        let tabManager
      {
        // Handle stream events directly with the current tab's fetcher
        if let fetcher = tabManager.currentTabFetcher as? AccountTabFetcher {
          fetcher.handleEvent(event: latestEvent, currentAccount: currentAccount)
        }
      }
    }
    .onChange(of: routerPath.presentedSheet) { oldValue, newValue in
      if oldValue == .accountEditInfo || newValue == .accountEditInfo {
        Task {
          await fetchAccount()
          await preferences.refreshServerPreferences()
        }
      }
    }
    .sheet(
      isPresented: $isEditingRelationshipNote,
      content: {
        EditRelationshipNoteView(
          accountId: accountId,
          relationship: relationship,
          onSave: {
            Task {
              await fetchAccount()
            }
          }
        )
      }
    )
    .edgesIgnoringSafeArea(.top)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      switch viewState {
      case .display(let account, _, _, _):
        AccountDetailToolbar(
          account: account,
          displayTitle: displayTitle,
          isCurrentUser: isCurrentUser,
          relationship: $relationship,
          showBlockConfirmation: $showBlockConfirmation,
          showTranslateView: $showTranslateView,
          isEditingRelationshipNote: $isEditingRelationshipNote
        )
      default:
        ToolbarItem {
          EmptyView()
        }
      }
    }
  }

  @ViewBuilder
  private func makeTabPicker(tabManager: AccountTabManager) -> some View {
    Picker(
      "",
      selection: .init(
        get: { tabManager.selectedTabId },
        set: { newTabId in
          if let newTab = tabManager.availableTabs.first(where: { $0.id == newTabId }) {
            tabManager.selectedTab = newTab
          }
        })
    ) {
      ForEach(tabManager.availableTabs, id: \.id) { tab in
        Image(systemName: tab.iconName)
          .tag(tab.id as String?)
          .accessibilityLabel(tab.accessibilityLabel)
      }
    }
  }

  @ViewBuilder
  private func makeHeaderView(proxy: ScrollViewProxy?) -> some View {
    switch viewState {
    case .loading:
      AccountDetailHeaderView(
        account: .placeholder(),
        relationship: relationship,
        fields: [],
        followButtonViewModel: $followButtonViewModel,
        translation: $translation,
        isLoadingTranslation: $isLoadingTranslation,
        isCurrentUser: isCurrentUser,
        accountId: accountId,
        scrollViewProxy: proxy
      )
      .redacted(reason: .placeholder)
      .allowsHitTesting(false)
    case .display(let account, _, _, let fields):
      AccountDetailHeaderView(
        account: account,
        relationship: relationship,
        fields: fields,
        followButtonViewModel: $followButtonViewModel,
        translation: $translation,
        isLoadingTranslation: $isLoadingTranslation,
        isCurrentUser: isCurrentUser,
        accountId: accountId,
        scrollViewProxy: proxy)
    case .error(let error):
      Text("Error: \(error.localizedDescription)")
    }
  }

}

extension View {
  @MainActor
  func applyAccountDetailsRowStyle(theme: Theme) -> some View {
    listRowInsets(.init())
      .listRowSeparator(.hidden)
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
  }
}

struct AccountDetailView_Previews: PreviewProvider {
  static var previews: some View {
    AccountDetailView(account: .placeholder())
  }
}

// MARK: - Data Fetching
extension AccountDetailView {
  private struct AccountData {
    let account: Account
    let featuredTags: [FeaturedTag]
    let relationships: [Relationship]
  }

  private func fetchAccount() async {
    do {
      let data = try await fetchAccountData(accountId: accountId, client: client)

      var featuredTags = data.featuredTags
      featuredTags.sort { $0.statusesCountInt > $1.statusesCountInt }
      relationship = data.relationships.first

      viewState = .display(
        account: data.account,
        featuredTags: featuredTags,
        relationships: data.relationships,
        fields: data.account.fields)

      if let relationship {
        if let existingFollowButtonViewModel = followButtonViewModel {
          existingFollowButtonViewModel.relationship = relationship
        } else {
          followButtonViewModel = .init(
            client: client,
            accountId: accountId,
            relationship: relationship,
            shouldDisplayNotify: true,
            relationshipUpdated: { relationship in
              self.relationship = relationship
            })
        }
      }
    } catch {
      if case .display(let account, _, _, _) = viewState {
        viewState = .display(account: account, featuredTags: [], relationships: [], fields: [])
      } else {
        viewState = .error(error: error)
      }
    }
  }

  private func fetchAccountData(accountId: String, client: MastodonClient) async throws
    -> AccountData
  {
    async let account: Account = client.get(endpoint: Accounts.accounts(id: accountId))
    async let featuredTags: [FeaturedTag] = client.get(
      endpoint: Accounts.featuredTags(id: accountId))
    if client.isAuth, !isCurrentUser {
      async let relationships: [Relationship] = client.get(
        endpoint: Accounts.relationships(ids: [accountId]))
      do {
        return try await .init(
          account: account,
          featuredTags: featuredTags,
          relationships: relationships)
      } catch {
        return try await .init(
          account: account,
          featuredTags: [],
          relationships: relationships)
      }
    }
    return try await .init(
      account: account,
      featuredTags: featuredTags,
      relationships: [])
  }

  private func fetchFamiliarFollowers() async {
    let familiarFollowersResponse: [FamiliarAccounts]? = try? await client.get(
      endpoint: Accounts.familiarFollowers(withAccount: accountId))
    self.familiarFollowers = familiarFollowersResponse?.first?.accounts ?? []
  }
}

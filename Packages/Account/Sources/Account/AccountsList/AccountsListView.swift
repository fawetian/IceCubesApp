/*
 * AccountsListView.swift
 * IceCubesApp - 账户列表视图
 *
 * 文件功能：
 * 展示账户列表，支持关注者、正在关注、屏蔽、静音等多种模式。
 *
 * 核心职责：
 * - 根据模式（followers、following、blocked 等）加载账户列表
 * - 显示账户行和关系状态
 * - 支持搜索和分页加载
 * - 显示关注请求（如果有）
 *
 * 技术要点：
 * - AccountsListViewModel 管理数据和状态
 * - 支持可搜索列表（仅限当前用户）
 * - 分页加载下一页
 * - 关注请求处理
 *
 * 使用场景：
 * - 查看用户的关注者列表
 * - 查看正在关注的账户
 * - 管理屏蔽和静音列表
 *
 * 依赖关系：
 * - DesignSystem: 主题和布局
 * - Env: CurrentAccount、MastodonClient
 * - Models: Account、Relationship
 * - NetworkClient: Accounts 端点
 */

import DesignSystem
import Env
import Models
import NetworkClient
import SwiftUI

/// 账户列表视图。
///
/// 根据不同模式展示账户列表（关注者、正在关注等）。
@MainActor
public struct AccountsListView: View {
  @Environment(Theme.self) private var theme
  @Environment(MastodonClient.self) private var client
  @Environment(CurrentAccount.self) private var currentAccount

  /// 账户列表视图模型。
  @State private var viewModel: AccountsListViewModel
  /// 是否已出现过（避免重复加载）。
  @State private var didAppear: Bool = false

  /// 初始化方法。
  ///
  /// - Parameter mode: 账户列表模式（followers、following 等）。
  public init(mode: AccountsListMode) {
    _viewModel = .init(initialValue: .init(mode: mode))
  }

  public var body: some View {
    listView
      #if !os(visionOS)
        .scrollContentBackground(.hidden)
        .background(theme.primaryBackgroundColor)
      #endif
      .listStyle(.plain)
      .toolbar {
        ToolbarItem(placement: .principal) {
          VStack {
            Text(viewModel.mode.title)
              .font(.headline)
            if let count = viewModel.totalCount {
              Text(String(count))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle(viewModel.mode.title)
      .navigationBarTitleDisplayMode(.inline)
      .task {
        viewModel.client = client
        guard !didAppear else { return }
        didAppear = true
        await viewModel.fetch()
      }
  }

  @ViewBuilder
  private var listView: some View {
    if currentAccount.account?.id == viewModel.accountId {
      searchableList
    } else {
      standardList
        .refreshable {
          await viewModel.fetch()
        }
    }
  }

  private var searchableList: some View {
    List {
      listContent
    }
    .searchable(
      text: $viewModel.searchQuery,
      placement: .navigationBarDrawer(displayMode: .always)
    )
    .task(id: viewModel.searchQuery) {
      if !viewModel.searchQuery.isEmpty {
        await viewModel.search()
      }
    }
    .onChange(of: viewModel.searchQuery) { _, newValue in
      if newValue.isEmpty {
        Task {
          await viewModel.fetch()
        }
      }
    }
  }

  private var standardList: some View {
    List {
      listContent
    }
  }

  @ViewBuilder
  private var listContent: some View {
    switch viewModel.state {
    case .loading:
      ForEach(Account.placeholders()) { _ in
        AccountsListRow(viewModel: .init(account: .placeholder(), relationShip: .placeholder()))
          .redacted(reason: .placeholder)
          .allowsHitTesting(false)
          #if !os(visionOS)
            .listRowBackground(theme.primaryBackgroundColor)
          #endif
      }
    case .display(let accounts, let relationships, let nextPageState):
      if case .followers = viewModel.mode,
        !currentAccount.followRequests.isEmpty
      {
        Section(
          header: Text("account.follow-requests.pending-requests"),
          footer: Text("account.follow-requests.instructions")
            .font(.scaledFootnote)
            .foregroundColor(.secondary)
            .offset(y: -8)
        ) {
          ForEach(currentAccount.followRequests) { account in
            AccountsListRow(
              viewModel: .init(account: account),
              isFollowRequest: true,
              requestUpdated: {
                Task {
                  await viewModel.fetch()
                }
              }
            )
            #if !os(visionOS)
              .listRowBackground(theme.primaryBackgroundColor)
            #endif
          }
        }
      }
      Section {
        if accounts.isEmpty {
          PlaceholderView(
            iconName: "person.icloud",
            title: "No accounts found",
            message: "This list of accounts is empty"
          )
          .listRowSeparator(.hidden)
        } else {
          ForEach(accounts) { account in
            if let relationship = relationships.first(where: { $0.id == account.id }) {
              AccountsListRow(
                viewModel: .init(
                  account: account,
                  relationShip: relationship))
            }
          }
        }
      }
      #if !os(visionOS)
        .listRowBackground(theme.primaryBackgroundColor)
      #endif

      switch nextPageState {
      case .hasNextPage:
        NextPageView {
          try await viewModel.fetchNextPage()
        }
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif

      case .none:
        EmptyView()
      }

    case .error(let error):
      Text(error.localizedDescription)
        #if !os(visionOS)
          .listRowBackground(theme.primaryBackgroundColor)
        #endif
    }
  }
}

#Preview {
  List {
    AccountsListRow(
      viewModel: .init(
        account: .placeholder(),
        relationShip: .placeholder()))
  }
  .listStyle(.plain)
  .withPreviewsEnv()
  .environment(Theme.shared)
}

/*
 * AccountsListRow.swift
 * IceCubesApp - 账户列表行视图
 *
 * 文件功能：
 * 展示账户列表中的单行，包括头像、名称、关注者数和操作按钮。
 *
 * 核心职责：
 * - 显示账户头像、显示名、用户名和关注者数
 * - 展示已验证字段（绿色勾选标记）
 * - 提供关注/屏蔽等账户操作
 * - 支持关注请求模式（接受/拒绝按钮）
 * - 显示账户详情上下文菜单
 *
 * 技术要点：
 * - AccountsListRowViewModel 管理行状态
 * - EmojiText 渲染自定义表情
 * - AvatarView 展示头像
 * - AccountDetailContextMenu 上下文菜单
 * - FollowRequestButtons 关注请求按钮
 *
 * 使用场景：
 * - 关注者/正在关注列表
 * - 点赞/转发用户列表
 * - 搜索结果列表
 * - 关注请求列表
 *
 * 依赖关系：
 * - DesignSystem: AvatarView、EmojiText
 * - Env: Theme、CurrentAccount、RouterPath
 * - Models: Account、Relationship
 */

import AppAccount
import Combine
import DesignSystem
import EmojiText
import Env
import Models
import NetworkClient
import Observation
import SwiftUI

/// 账户列表行视图模型。
///
/// 管理单行的账户数据和关系状态。
@MainActor
@Observable public class AccountsListRowViewModel {
  /// Mastodon 客户端。
  var client: MastodonClient?

  /// 账户数据。
  var account: Account
  /// 与当前用户的关系状态。
  var relationShip: Relationship?

  /// 初始化方法。
  ///
  /// - Parameters:
  ///   - account: 账户数据。
  ///   - relationShip: 可选的关系状态。
  public init(account: Account, relationShip: Relationship? = nil) {
    self.account = account
    self.relationShip = relationShip
  }
}

/// 账户列表行视图。
///
/// 展示单个账户的信息和操作按钮。
@MainActor
public struct AccountsListRow: View {
  @Environment(Theme.self) private var theme
  @Environment(CurrentAccount.self) private var currentAccount
  @Environment(RouterPath.self) private var routerPath
  @Environment(MastodonClient.self) private var client
  @Environment(QuickLook.self) private var quickLook
  @Environment(StreamWatcher.self) private var watcher
  @Environment(AppAccountsManager.self) private var appAccountsManager

  @State var viewModel: AccountsListRowViewModel

  @State private var isEditingRelationshipNote: Bool = false
  @State private var showBlockConfirmation: Bool = false
  @State private var showTranslateView: Bool = false

  let isFollowRequest: Bool
  let requestUpdated: (() -> Void)?

  public init(
    viewModel: AccountsListRowViewModel, isFollowRequest: Bool = false,
    requestUpdated: (() -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.isFollowRequest = isFollowRequest
    self.requestUpdated = requestUpdated
  }

  public var body: some View {
    HStack(alignment: .top) {
      AvatarView(viewModel.account.avatar)
      VStack(alignment: .leading, spacing: 2) {
        EmojiTextApp(
          .init(stringValue: viewModel.account.safeDisplayName), emojis: viewModel.account.emojis
        )
        .font(.scaledSubheadline)
        .emojiText.size(Font.scaledSubheadlineFont.emojiSize)
        .emojiText.baselineOffset(Font.scaledSubheadlineFont.emojiBaselineOffset)
        .fontWeight(.semibold)
        Text("@\(viewModel.account.acct)")
          .font(.scaledFootnote)
          .foregroundStyle(Color.secondary)

        // First parameter is the number for the plural
        // Second parameter is the formatted string to show
        Text(
          "account.label.followers \(viewModel.account.followersCount ?? 0) \(viewModel.account.followersCount ?? 0, format: .number.notation(.compactName))"
        )
        .font(.scaledFootnote)

        if let field = viewModel.account.fields.filter({ $0.verifiedAt != nil }).first {
          HStack(spacing: 2) {
            Image(systemName: "checkmark.seal")
              .font(.scaledFootnote)
              .foregroundColor(.green)

            EmojiTextApp(field.value, emojis: viewModel.account.emojis)
              .font(.scaledFootnote)
              .emojiText.size(Font.scaledFootnoteFont.emojiSize)
              .emojiText.baselineOffset(Font.scaledFootnoteFont.emojiBaselineOffset)
              .environment(
                \.openURL,
                OpenURLAction { url in
                  routerPath.handle(url: url)
                })
          }
        }

        EmojiTextApp(viewModel.account.note, emojis: viewModel.account.emojis, lineLimit: 2)
          .font(.scaledCaption)
          .emojiText.size(Font.scaledFootnoteFont.emojiSize)
          .emojiText.baselineOffset(Font.scaledFootnoteFont.emojiBaselineOffset)
          .environment(
            \.openURL,
            OpenURLAction { url in
              routerPath.handle(url: url)
            })

        if isFollowRequest {
          FollowRequestButtons(
            account: viewModel.account,
            requestUpdated: requestUpdated)
        }
      }
      Spacer()
      if currentAccount.account?.id != viewModel.account.id,
        let relationShip = viewModel.relationShip
      {
        VStack(alignment: .center) {
          FollowButton(
            viewModel: .init(
              client: client,
              accountId: viewModel.account.id,
              relationship: relationShip,
              shouldDisplayNotify: false,
              relationshipUpdated: { _ in }))
        }
      }
    }
    .onAppear {
      viewModel.client = client
    }
    .contentShape(Rectangle())
    .onTapGesture {
      routerPath.navigate(to: .accountDetailWithAccount(account: viewModel.account))
    }
    #if canImport(_Translation_SwiftUI)
      .addTranslateView(isPresented: $showTranslateView, text: viewModel.account.note.asRawText)
    #endif
    .contextMenu {
      AccountDetailContextMenu(
        showBlockConfirmation: $showBlockConfirmation,
        showTranslateView: $showTranslateView,
        account: viewModel.account,
        relationship: .constant(viewModel.relationShip),
        isCurrentUser: false)
    } preview: {
      List {
        AccountDetailHeaderView(
          account: viewModel.account,
          relationship: viewModel.relationShip,
          fields: [],
          followButtonViewModel: .constant(nil),
          translation: .constant(nil),
          isLoadingTranslation: .constant(false),
          isCurrentUser: false,
          accountId: viewModel.account.id,
          scrollViewProxy: nil
        )
        .applyAccountDetailsRowStyle(theme: theme)
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(theme.primaryBackgroundColor)
      .environment(theme)
      .environment(currentAccount)
      .environment(client)
      .environment(quickLook)
      .environment(routerPath)
      .environment(watcher)
      .environment(appAccountsManager)
    }
  }
}

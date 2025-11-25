/*
 * FollowButton.swift
 * IceCubesApp - 关注按钮组件
 *
 * 文件功能：
 * 提供关注/取消关注按钮和相关交互功能，包括通知和转发控制。
 *
 * 核心职责：
 * - 显示关注状态按钮（关注/正在关注/已请求）
 * - 处理关注和取消关注操作
 * - 提供通知开关（接收该用户的通知）
 * - 提供转发开关（显示该用户的转发）
 * - iOS 26 适配（Liquid Glass 效果）
 *
 * 技术要点：
 * - @Observable 视图模型
 * - AsyncButton 异步操作按钮
 * - iOS 26 glassEffect 效果
 * - 关系状态管理
 * - 无障碍支持
 *
 * 使用场景：
 * - 账户详情页的关注按钮
 * - 账户列表行的关注按钮
 * - 搜索结果中的关注按钮
 *
 * 依赖关系：
 * - ButtonKit: AsyncButton 组件
 * - Models: Relationship
 * - NetworkClient: MastodonClient、Accounts 端点
 */

import ButtonKit
import Combine
import Foundation
import Models
import NetworkClient
import OSLog
import Observation
import SwiftUI

/// 关注按钮视图模型。
///
/// 管理关注状态和相关操作（关注、通知、转发）。
@MainActor
@Observable public class FollowButtonViewModel {
  /// Mastodon 客户端。
  let client: MastodonClient

  /// 目标账户 ID。
  public let accountId: String
  /// 是否显示通知开关。
  public let shouldDisplayNotify: Bool
  /// 关系更新回调。
  public let relationshipUpdated: (Relationship) -> Void
  /// 当前关系状态。
  public var relationship: Relationship

  /// 初始化方法。
  ///
  /// - Parameters:
  ///   - client: Mastodon 客户端。
  ///   - accountId: 目标账户 ID。
  ///   - relationship: 当前关系状态。
  ///   - shouldDisplayNotify: 是否显示通知开关。
  ///   - relationshipUpdated: 关系更新回调。
  public init(
    client: MastodonClient,
    accountId: String,
    relationship: Relationship,
    shouldDisplayNotify: Bool,
    relationshipUpdated: @escaping ((Relationship) -> Void)
  ) {
    self.client = client
    self.accountId = accountId
    self.relationship = relationship
    self.shouldDisplayNotify = shouldDisplayNotify
    self.relationshipUpdated = relationshipUpdated
  }

  /// 关注账户。
  func follow() async throws {
    do {
      let newRelationship: Relationship = try await client.post(
        endpoint: Accounts.follow(id: accountId, notify: false, reblogs: true))
      withAnimation(.bouncy) {
        relationship = newRelationship
      }
      relationshipUpdated(relationship)
    } catch {
      throw error
    }
  }

  /// 取消关注账户。
  func unfollow() async throws {
    do {
      let newRelationship: Relationship = try await client.post(
        endpoint: Accounts.unfollow(id: accountId))
      withAnimation(.bouncy) {
        relationship = newRelationship
      }
      relationshipUpdated(relationship)
    } catch {
      throw error
    }
  }

  /// 刷新关系状态。
  func refreshRelationship() async throws {
    let relationships: [Relationship] = try await client.get(
      endpoint: Accounts.relationships(ids: [accountId]))
    if let relationship = relationships.first {
      self.relationship = relationship
      relationshipUpdated(relationship)
    }
  }

  /// 切换通知状态（是否接收该用户的通知）。
  func toggleNotify() async throws {
    do {
      relationship = try await client.post(
        endpoint: Accounts.follow(
          id: accountId,
          notify: !relationship.notifying,
          reblogs: relationship.showingReblogs))
      relationshipUpdated(relationship)
    } catch {
      throw error
    }
  }

  /// 切换转发显示（是否显示该用户的转发）。
  func toggleReboosts() async throws {
    do {
      relationship = try await client.post(
        endpoint: Accounts.follow(
          id: accountId,
          notify: relationship.notifying,
          reblogs: !relationship.showingReblogs))
      relationshipUpdated(relationship)
    } catch {
      throw error
    }
  }
}

/// 关注按钮视图。
///
/// 显示关注状态并提供交互按钮。
public struct FollowButton: View {
  @Environment(MastodonClient.self) private var client
  /// 视图模型。
  @State private var viewModel: FollowButtonViewModel

  /// 初始化方法。
  ///
  /// - Parameter viewModel: 关注按钮视图模型。
  public init(viewModel: FollowButtonViewModel) {
    _viewModel = .init(initialValue: viewModel)
  }

  public var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        VStack(alignment: .trailing) {
          AsyncButton {
            if viewModel.relationship.following || viewModel.relationship.requested {
              try await viewModel.unfollow()
            } else {
              try await viewModel.follow()
            }
          } label: {
            if viewModel.relationship.requested == true {
              Text("account.follow.requested")
            } else {
              Text(
                viewModel.relationship.following
                  ? "account.follow.following" : "account.follow.follow"
              )
              .padding(.horizontal, 2)
              .accessibilityLabel("account.follow.following")
              .accessibilityValue(
                viewModel.relationship.following
                  ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off")
            }
          }
          .glassEffect(.regular.interactive())
          if viewModel.relationship.following,
            viewModel.shouldDisplayNotify
          {
            HStack {
              AsyncButton {
                try await viewModel.toggleNotify()
              } label: {
                Image(systemName: viewModel.relationship.notifying ? "bell.fill" : "bell")
              }
              .accessibilityLabel("accessibility.tabs.profile.user-notifications.label")
              .accessibilityValue(
                viewModel.relationship.notifying
                  ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off"
              )
              .glassEffect(.regular.interactive())
              AsyncButton {
                try await viewModel.toggleReboosts()
              } label: {
                Image(systemName: "arrow.2.squarepath")
                  .opacity(viewModel.relationship.showingReblogs ? 1 : 0.5)
              }
              .accessibilityLabel("accessibility.tabs.profile.user-reblogs.label")
              .accessibilityValue(
                viewModel.relationship.showingReblogs
                  ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off"
              )
              .glassEffect(.regular.interactive())
            }
            .asyncButtonStyle(.none)
            .disabledWhenLoading()
          }
        }
        .buttonStyle(.bordered)
      }
    } else {
      VStack(alignment: .trailing) {
        AsyncButton {
          if viewModel.relationship.following || viewModel.relationship.requested {
            try await viewModel.unfollow()
          } else {
            try await viewModel.follow()
          }
        } label: {
          if viewModel.relationship.requested == true {
            Text("account.follow.requested")
          } else {
            Text(
              viewModel.relationship.following
                ? "account.follow.following" : "account.follow.follow"
            )
            .padding(.horizontal, 2)
            .accessibilityLabel("account.follow.following")
            .accessibilityValue(
              viewModel.relationship.following
                ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off")
          }
        }
        if viewModel.relationship.following,
          viewModel.shouldDisplayNotify
        {
          HStack {
            AsyncButton {
              try await viewModel.toggleNotify()
            } label: {
              Image(systemName: viewModel.relationship.notifying ? "bell.fill" : "bell")
            }
            .accessibilityLabel("accessibility.tabs.profile.user-notifications.label")
            .accessibilityValue(
              viewModel.relationship.notifying
                ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off")
            AsyncButton {
              try await viewModel.toggleReboosts()
            } label: {
              Image(systemName: "arrow.2.squarepath")
                .opacity(viewModel.relationship.showingReblogs ? 1 : 0.5)
            }
            .accessibilityLabel("accessibility.tabs.profile.user-reblogs.label")
            .accessibilityValue(
              viewModel.relationship.showingReblogs
                ? "accessibility.general.toggle.on" : "accessibility.general.toggle.off")
          }
          .asyncButtonStyle(.none)
          .disabledWhenLoading()
        }
      }
      .buttonStyle(.bordered)
    }
  }
}

/*
 * FollowRequestButtons.swift
 * IceCubesApp - 关注请求按钮组件
 *
 * 文件功能：
 * 提供接受和拒绝关注请求的按钮组。
 *
 * 核心职责：
 * - 显示接受和拒绝按钮
 * - 处理关注请求的接受和拒绝操作
 * - 在处理过程中禁用按钮
 * - 通知父视图更新
 *
 * 技术要点：
 * - CurrentAccount 管理关注请求
 * - Task 异步处理请求
 * - 回调通知父视图
 * - 禁用状态管理
 *
 * 使用场景：
 * - 关注者列表中的待处理请求
 * - 通知列表中的关注请求通知
 *
 * 依赖关系：
 * - Env: CurrentAccount
 * - Models: Account
 * - SwiftUI: 按钮和布局
 */

import Env
import Models
import SwiftUI

/// 关注请求按钮组。
///
/// 提供接受和拒绝关注请求的操作按钮。
public struct FollowRequestButtons: View {
  /// 当前账户（用于处理关注请求）。
  @Environment(CurrentAccount.self) private var currentAccount

  /// 发起关注请求的账户。
  let account: Account
  /// 请求处理完成后的回调。
  let requestUpdated: (() -> Void)?

  /// 初始化方法。
  ///
  /// - Parameters:
  ///   - account: 发起关注请求的账户。
  ///   - requestUpdated: 可选的更新回调。
  public init(account: Account, requestUpdated: (() -> Void)? = nil) {
    self.account = account
    self.requestUpdated = requestUpdated
  }

  /// 视图主体。
  public var body: some View {
    HStack {
      Button {
        Task {
          await currentAccount.acceptFollowerRequest(id: account.id)
          requestUpdated?()
        }
      } label: {
        Text("account.follow-request.accept")
          .frame(maxWidth: .infinity)
      }
      Button {
        Task {
          await currentAccount.rejectFollowerRequest(id: account.id)
          requestUpdated?()
        }
      } label: {
        Text("account.follow-request.reject")
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.bordered)
    .disabled(currentAccount.updatingFollowRequestAccountIds.contains(account.id))
    .padding(.top, 4)
  }
}

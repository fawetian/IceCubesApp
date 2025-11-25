/*
 * TimelineUnreadStatusesObserver.swift
 * IceCubesApp - 时间线未读状态观察器
 *
 * 文件功能：
 * 管理时间线中未读帖子的提示，包括计数、状态跟踪和用户交互。
 *
 * 核心职责：
 * - 维护待读帖子 ID 列表并统计数量
 * - 在用户滚动时移除已读帖子
 * - 控制加载提示和动画效果
 * - 提供未读提示 UI 组件
 *
 * 技术要点：
 * - @Observable + @MainActor 保证 UI 线程安全
 * - didSet 监听属性变化并触发动画
 * - iOS 26 Liquid Glass 效果支持
 * - visionOS 平台适配
 * - 触觉反馈集成
 *
 * 使用场景：
 * - 时间线顶部的未读提示条
 * - 显示新帖子数量
 * - 点击后滚动到最新帖子
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: UserPreferences、HapticManager
 * - Models: Status
 */

import DesignSystem
import Env
import Foundation
import Models
import Observation
import SwiftUI

/// 时间线未读状态观察器。
///
/// 负责跟踪未读帖子并提供 UI 提示。
@MainActor
@Observable class TimelineUnreadStatusesObserver {
  /// 待读帖子数量（用于显示徽章）。
  var pendingStatusesCount: Int = 0

  /// 是否禁用状态更新（滚动期间临时禁用）。
  var disableUpdate: Bool = false

  /// 是否正在加载新帖子（显示加载指示器）。
  var isLoadingNewStatuses: Bool = false

  /// 待读帖子 ID 列表（按时间顺序）。
  var pendingStatuses: [String] = [] {
    didSet {
      withAnimation(.default) {
        pendingStatusesCount = pendingStatuses.count
      }
    }
  }

  /// 移除已读帖子（用户滚动到某条帖子时调用）。
  ///
  /// - Parameter status: 用户已读的帖子。
  func removeStatus(status: Status) {
    if !disableUpdate, let index = pendingStatuses.firstIndex(of: status.id) {
      pendingStatuses.removeSubrange(index...(pendingStatuses.count - 1))
      HapticManager.shared.fireHaptic(.timeline)
    }
  }

  init() {}
}

/// 时间线未读提示视图。
///
/// 显示未读帖子数量并提供点击跳转功能。
struct TimelineUnreadStatusesView: View {
  /// 用户偏好设置（控制提示位置）。
  @Environment(UserPreferences.self) private var preferences
  /// 主题设置（控制颜色和样式）。
  @Environment(Theme.self) private var theme

  /// 未读状态观察器。
  @State var observer: TimelineUnreadStatusesObserver
  /// 点击按钮时的回调（传入最后一条未读帖子 ID）。
  let onButtonTap: (String?) -> Void

  /// 视图主体（根据系统版本选择样式）。
  var body: some View {
    if #available(iOS 26, *) {
      buttonBody
        #if os(visionOS)
          .buttonStyle(.bordered)
          .tint(Material.ultraThick)
        #endif
        .padding(8)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: preferences.pendingLocation)
    } else {
      buttonBody
        #if os(visionOS)
          .buttonStyle(.bordered)
          .tint(Material.ultraThick)
        #else
          .buttonStyle(.bordered)
          .background(Material.ultraThick)
        #endif
        .cornerRadius(8)
        #if !os(visionOS)
          .foregroundStyle(.secondary)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(theme.tintColor, lineWidth: 1)
          )
        #endif
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: preferences.pendingLocation)
    }
  }

  /// 按钮内容（仅在有未读或加载时显示）。
  @ViewBuilder
  var buttonBody: some View {
    if observer.pendingStatusesCount > 0 || observer.isLoadingNewStatuses {
      Button {
        onButtonTap(observer.pendingStatuses.last)
      } label: {
        if #available(iOS 26, *) {
          label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(theme.tintColor.opacity(0.4)).interactive(), in: .capsule)
        } else {
          label
        }
      }
      .accessibilityLabel(
        "accessibility.tabs.timeline.unread-posts.label-\(observer.pendingStatusesCount)"
      )
      .accessibilityHint("accessibility.tabs.timeline.unread-posts.hint")
    }
  }

  /// 按钮标签（显示进度或数量）。
  var label: some View {
    HStack(spacing: 8) {
      if observer.isLoadingNewStatuses {
        ProgressView()
      }
      if observer.pendingStatusesCount > 0 {
        Text("\(observer.pendingStatusesCount)")
          .contentTransition(.numericText(value: Double(observer.pendingStatusesCount)))
          .frame(minWidth: 16, minHeight: 16)
          .font(.footnote.monospacedDigit())
          .fontWeight(.bold)
      }
    }
  }
}

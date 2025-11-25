/*
 * NotificationsListState.swift
 * IceCubesApp - 通知列表状态枚举
 *
 * 文件功能：
 * 定义通知列表视图的所有可能状态。
 *
 * 核心职责：
 * - 表示加载中、已加载、错误三种状态
 * - 包含分页状态（有无下一页）
 * - 携带通知数据和错误信息
 *
 * 技术要点：
 * - 简单的枚举状态机
 * - 关联值携带数据
 * - 分页状态嵌套枚举
 *
 * 使用场景：
 * - NotificationsListView 状态管理
 * - SwiftUI 视图状态驱动
 *
 * 依赖关系：
 * - Models: ConsolidatedNotification
 */

import Foundation
import Models

/// 通知列表状态枚举。
///
/// 表示通知列表视图的所有可能状态。
public enum NotificationsListState {
  /// 分页状态枚举。
  public enum PagingState {
    /// 无下一页。
    case none
    /// 有下一页。
    case hasNextPage
  }

  /// 加载中。
  case loading
  /// 已加载（通知列表、分页状态）。
  case display(notifications: [ConsolidatedNotification], nextPageState: PagingState)
  /// 加载错误。
  case error(error: Error)
}

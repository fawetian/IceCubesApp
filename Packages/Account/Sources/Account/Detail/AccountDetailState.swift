/*
 * AccountDetailState.swift
 * IceCubesApp - 账户详情状态枚举
 *
 * 文件功能：
 * 定义账户详情视图的所有可能状态。
 *
 * 核心职责：
 * - 表示加载中、已加载、错误三种状态
 * - 携带账户数据、特色标签、关系状态和自定义字段
 *
 * 技术要点：
 * - 简单的枚举状态机
 * - 关联值携带数据
 *
 * 使用场景：
 * - AccountDetailView 状态管理
 * - SwiftUI 视图状态驱动
 *
 * 依赖关系：
 * - Models: Account、FeaturedTag、Relationship
 */

import Foundation
import Models

/// 账户详情状态枚举。
///
/// 表示账户详情视图的所有可能状态。
enum AccountDetailState {
  /// 加载中。
  case loading
  /// 已加载（账户、特色标签、关系列表、自定义字段）。
  case display(
    account: Account,
    featuredTags: [FeaturedTag],
    relationships: [Relationship],
    fields: [Account.Field])
  /// 加载错误。
  case error(error: Error)
}

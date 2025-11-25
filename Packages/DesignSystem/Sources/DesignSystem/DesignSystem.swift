/*
 * DesignSystem.swift
 * IceCubesApp - 设计系统常量
 *
 * 文件功能：
 * 定义应用全局的布局常量和间距值。
 *
 * 核心职责：
 * - 提供统一的布局边距
 * - 定义组件间距和尺寸
 * - 支持紧凑布局模式切换
 *
 * 技术要点：
 * - CGFloat 扩展
 * - 静态常量
 * - 根据主题动态调整
 *
 * 依赖关系：
 * - Theme: 读取紧凑布局偏好
 */

import Foundation

/// CGFloat 布局常量扩展。
@MainActor
extension CGFloat {
  /// 布局内边距（根据紧凑模式切换：20 或 8）。
  public static var layoutPadding: CGFloat {
    Theme.shared.compactLayoutPadding ? 20 : 8
  }

  /// 分隔线内边距。
  public static let dividerPadding: CGFloat = 2
  /// 滚动定位视图高度。
  public static let scrollToViewHeight: CGFloat = 1
  /// 状态列间距。
  public static let statusColumnsSpacing: CGFloat = 8
  /// 状态组件间距。
  public static let statusComponentSpacing: CGFloat = 6
  /// 次要栏宽度（iPad 等）。
  public static let secondaryColumnWidth: CGFloat = 400
  /// 投票条高度。
  public static let pollBarHeight: CGFloat = 30
}

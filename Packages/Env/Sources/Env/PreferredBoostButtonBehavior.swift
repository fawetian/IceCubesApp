// 文件功能：转发按钮行为偏好枚举
//
// 核心职责：
// - 定义转发按钮的不同行为模式
// - 支持转发、引用或两者兼有
// - 提供本地化的显示标题
// - 作为用户偏好设置的一部分
//
// 技术要点：
// - 枚举类型：定义三种转发行为
// - Int 原始值：便于存储和序列化
// - CaseIterable：支持遍历所有选项
// - Codable：支持 JSON 编解码
// - LocalizedStringKey：支持多语言
//
// 使用场景：
// - 设置页面的转发按钮行为选项
// - 帖子视图中的转发按钮显示
// - 用户偏好的持久化存储
//
// 依赖关系：
// - 依赖：Foundation, SwiftUI
// - 被依赖：UserPreferences, 帖子视图

import Foundation
import SwiftUI

/// 转发按钮行为偏好
///
/// 定义转发按钮的不同行为模式。
///
/// 行为模式：
/// - **both**：同时支持转发和引用
/// - **boostOnly**：仅支持转发
/// - **quoteOnly**：仅支持引用
///
/// 使用方式：
/// ```swift
/// // 在设置中选择
/// Picker("转发按钮行为", selection: $preferences.boostButtonBehavior) {
///     ForEach(PreferredBoostButtonBehavior.allCases, id: \.self) { behavior in
///         Text(behavior.title).tag(behavior)
///     }
/// }
///
/// // 在帖子视图中使用
/// if preferences.boostButtonBehavior == .both {
///     // 显示转发和引用两个按钮
/// } else if preferences.boostButtonBehavior == .boostOnly {
///     // 只显示转发按钮
/// } else {
///     // 只显示引用按钮
/// }
/// ```
///
/// - Note: 这个设置影响帖子操作栏的按钮显示
public enum PreferredBoostButtonBehavior: Int, CaseIterable, Codable {
  /// 同时支持转发和引用
  ///
  /// 显示两个按钮，用户可以选择转发或引用。
  case both
  
  /// 仅支持转发
  ///
  /// 只显示转发按钮，不显示引用按钮。
  case boostOnly
  
  /// 仅支持引用
  ///
  /// 只显示引用按钮，不显示转发按钮。
  case quoteOnly

  /// 行为的显示标题
  ///
  /// 返回本地化的行为描述。
  ///
  /// 标题说明：
  /// - **both**："Boost & Quote"（转发和引用）
  /// - **boostOnly**："Boost Only"（仅转发）
  /// - **quoteOnly**："Quote Only"（仅引用）
  ///
  /// 使用场景：
  /// - 设置页面的选项显示
  /// - 帮助文本和说明
  public var title: LocalizedStringKey {
    switch self {
    case .both:
      "Boost & Quote"
    case .boostOnly:
      "Boost Only"
    case .quoteOnly:
      "Quote Only"
    }
  }
}

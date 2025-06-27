/*
 * Visibility.swift
 * IceCubesApp - 可见性扩展
 * 
 * 功能描述：
 * 为 Mastodon 状态可见性类型添加 UI 相关扩展功能
 * 提供默认支持的可见性选项、SF Symbols 图标和本地化标题
 *
 * 技术点：
 * 1. Extension 扩展 - 为现有枚举添加功能
 * 2. 静态属性 - supportDefault 提供默认选项
 * 3. 计算属性 - iconName 和 title 动态返回值
 * 4. Switch 模式匹配 - 根据枚举值返回不同结果
 * 5. LocalizedStringKey - SwiftUI 本地化字符串支持
 * 6. SF Symbols - 系统图标名称字符串
 * 7. 枚举扩展 - 为 Models.Visibility 添加 UI 功能
 * 8. 公共接口 - public 修饰符暴露外部使用
 * 9. 字符串字面量 - 图标名称和本地化键
 * 10. 函数式编程 - 纯函数计算属性
 *
 * 技术点详解：
 * - Extension：为 Models.Visibility 枚举添加 UI 相关功能
 * - 静态属性：supportDefault 定义默认支持的可见性选项数组
 * - 计算属性：iconName 和 title 根据枚举值动态计算结果
 * - Switch 表达式：为每个可见性类型匹配对应的图标和标题
 * - SF Symbols：使用系统内置的矢量图标，保证视觉一致性
 * - LocalizedStringKey：支持多语言本地化的字符串键
 * - 可见性级别：public（公开）、unlisted（不公开列表）、private（仅关注者）、direct（私信）
 * - 图标语义：globe（全球）、lock.open（半锁）、lock（锁定）、tray.full（收件箱）
 * - 本地化设计：使用语义化的本地化键，便于翻译管理
 * - 模块化设计：将 UI 相关功能与核心数据模型分离
 */

// 导入 Models 模块，提供 Visibility 枚举定义
import Models
// 导入 SwiftUI 框架，提供 LocalizedStringKey 支持
import SwiftUI

// 为可见性枚举添加 UI 相关功能的扩展
extension Models.Visibility {
  // 静态属性：返回默认支持的可见性选项数组
  public static var supportDefault: [Self] {
    // 包含公开、私有和不公开列表三种常用可见性
    [.pub, .priv, .unlisted]
  }

  // 计算属性：根据可见性类型返回对应的 SF Symbols 图标名称
  public var iconName: String {
    switch self {
    case .pub:
      // 公开状态：地球图标，表示全球可见
      "globe.americas"
    case .unlisted:
      // 不公开列表：开锁图标，表示可访问但不在时间线显示
      "lock.open"
    case .priv:
      // 仅关注者：锁定图标，表示仅关注者可见
      "lock"
    case .direct:
      // 私信：收件箱图标，表示直接消息
      "tray.full"
    }
  }

  // 计算属性：根据可见性类型返回对应的本地化标题
  public var title: LocalizedStringKey {
    switch self {
    case .pub:
      // 公开状态的本地化标题
      "status.visibility.public"
    case .unlisted:
      // 不公开列表的本地化标题
      "status.visibility.unlisted"
    case .priv:
      // 仅关注者的本地化标题
      "status.visibility.follower"
    case .direct:
      // 私信的本地化标题
      "status.visibility.direct"
    }
  }

  public var subtitle: LocalizedStringKey {
    switch self {
    case .pub:
      "Anyone can see this post"
    case .unlisted:
      "Hidden from algorithmic surfaces"
    case .priv:
      "Only visible to your followers"
    case .direct:
      "Only visible to people mentioned"
    }
  }
}

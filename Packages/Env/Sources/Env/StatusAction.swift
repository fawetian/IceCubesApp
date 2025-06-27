// 文件功能：状态操作动作枚举，定义帖子的各种交互操作，如回复、转发、收藏、书签等。
// 相关技术点：
// - 枚举操作：StatusAction 定义所有状态操作类型。
// - CaseIterable：自动生成所有案例的集合遍历。
// - Identifiable：为 SwiftUI 提供唯一标识符。
// - LocalizedStringKey：本地化字符串键支持多语言。
// - 状态判断：isReblogged、isFavorited 等状态标记。
// - 条件显示：根据操作状态显示不同文本和图标。
// - 主题色彩：支持主题色和特定操作色彩。
// - 私有转发：privateBoost 特殊转发模式。
//
// 技术点详解：
// 1. enum StatusAction：定义帖子的所有可能操作类型。
// 2. String, CaseIterable：原始值为字符串，可迭代所有案例。
// 3. Identifiable：提供 id 属性支持 SwiftUI 列表。
// 4. displayName 方法：根据当前状态返回本地化显示名称。
// 5. iconName 方法：根据操作类型和状态返回图标名称。
// 6. color 方法：根据主题设置和操作类型返回颜色。
// 7. LocalizedStringKey：支持系统自动本地化。
// 8. 条件操作符：三元运算符处理不同状态的显示逻辑。
// 导入 SwiftUI 框架，Color 和 LocalizedStringKey 支持
import SwiftUI

// 状态操作动作枚举，定义帖子的各种交互操作
public enum StatusAction: String, CaseIterable, Identifiable {
  // 实现 Identifiable 协议，提供唯一标识符
  public var id: String {
    "\(rawValue)"
  }

  // 定义所有支持的状态操作类型
  // 无操作、回复、转发、收藏、书签、引用
  case none, reply, boost, favorite, bookmark, quote

  // 根据当前状态返回本地化的显示名称
  public func displayName(
    isReblogged: Bool = false, isFavorited: Bool = false, isBookmarked: Bool = false,
    privateBoost: Bool = false
  ) -> LocalizedStringKey {
    switch self {
    case .none:
      // 无操作显示
      return "settings.swipeactions.status.action.none"
    case .reply:
      // 回复操作显示
      return "settings.swipeactions.status.action.reply"
    case .quote:
      // 引用操作显示
      return "settings.swipeactions.status.action.quote"
    case .boost:
      // 转发操作，根据私有转发和当前状态显示不同文本
      if privateBoost {
        return isReblogged ? "status.action.unboost" : "status.action.boost-to-followers"
      }

      return isReblogged ? "status.action.unboost" : "settings.swipeactions.status.action.boost"
    case .favorite:
      // 收藏操作，根据当前收藏状态显示不同文本
      return isFavorited
        ? "status.action.unfavorite" : "settings.swipeactions.status.action.favorite"
    case .bookmark:
      // 书签操作，根据当前书签状态显示不同文本
      return isBookmarked
        ? "status.action.unbookmark" : "settings.swipeactions.status.action.bookmark"
    }
  }

  // 根据操作类型和当前状态返回图标名称
  public func iconName(
    isReblogged: Bool = false, isFavorited: Bool = false, isBookmarked: Bool = false,
    privateBoost: Bool = false
  ) -> String {
    switch self {
    case .none:
      // 无操作使用斜杠圆圈图标
      return "slash.circle"
    case .reply:
      // 回复使用左转箭头图标
      return "arrowshape.turn.up.left"
    case .quote:
      // 引用使用引号气泡图标
      return "quote.bubble"
    case .boost:
      // 转发图标，根据私有转发和状态显示不同图标
      if privateBoost {
        return isReblogged ? "Rocket.Fill" : "lock.rotation"
      }

      return isReblogged ? "Rocket.Fill" : "Rocket"
    case .favorite:
      // 收藏图标，根据收藏状态显示实心或空心星星
      return isFavorited ? "star.fill" : "star"
    case .bookmark:
      // 书签图标，根据书签状态显示实心或空心书签
      return isBookmarked ? "bookmark.fill" : "bookmark"
    }
  }

  // 根据操作类型、主题设置返回对应的颜色
  public func color(themeTintColor: Color, useThemeColor: Bool, outside: Bool) -> Color {
    // 如果使用主题色彩
    if useThemeColor {
      return outside ? themeTintColor : .gray
    }

    // 根据操作类型返回特定颜色
    switch self {
    case .none:
      // 无操作使用灰色
      return .gray
    case .reply:
      // 回复操作使用灰色系
      return outside ? .gray : Color(white: 0.45)
    case .quote:
      // 引用操作使用灰色系
      return outside ? .gray : Color(white: 0.45)
    case .boost:
      // 转发使用主题色
      return themeTintColor
    case .favorite:
      // 收藏使用黄色
      return .yellow
    case .bookmark:
      // 书签使用粉色
      return .pink
    }
  }
}

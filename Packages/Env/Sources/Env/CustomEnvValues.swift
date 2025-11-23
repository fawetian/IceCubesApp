// 文件功能：自定义环境值扩展，为SwiftUI EnvironmentValues添加应用特定的环境变量，支持布局、状态管理等。
// 相关技术点：
// - EnvironmentValues扩展：为SwiftUI环境系统添加自定义值。
// - @Entry宏：Swift 5.9+的新宏，简化环境值定义。
// - 环境传递：父视图向子视图传递状态和配置。
// - 布局状态：isCompact、isSecondaryColumn等布局相关状态。
// - 平台适配：isCatalystWindow支持Mac Catalyst适配。
// - 媒体状态：isMediaCompact控制媒体显示模式。
// - 交互状态：isModal、isInCaptureMode等交互状态管理。
// - 层级结构：indentationLevel支持嵌套层级显示。
//
// 技术点详解：
// 1. extension EnvironmentValues：扩展SwiftUI环境值系统。
// 2. @Entry宏：自动生成环境值的getter/setter。
// 3. Bool状态值：布尔型的开关状态管理。
// 4. CGFloat数值：浮点数的布局参数。
// 5. UInt层级：无符号整数的嵌套层级计数。
// 6. Int标识符：整数的选项卡标识。
// 7. 默认值：为每个环境值提供合理的默认值。
// 8. 全局状态：通过环境值在视图树中传递状态。
// 导入基础库，基本数据类型
import Foundation
// 导入SwiftUI框架，EnvironmentValues和@Entry支持
import SwiftUI

// 为SwiftUI环境值系统添加自定义环境变量
extension EnvironmentValues {
  // 是否为次要列布局（iPad分栏模式）
  @Entry public var isSecondaryColumn: Bool = false
  // 额外的前导内边距
  @Entry public var extraLeadingInset: CGFloat = 0
  // 是否为紧凑布局模式
  @Entry public var isCompact: Bool = false
  // 媒体是否使用紧凑显示模式
  @Entry public var isMediaCompact: Bool = false
  // 是否为Mac Catalyst窗口
  @Entry public var isCatalystWindow: Bool = false
  // 是否为模态显示状态
  @Entry public var isModal: Bool = false
  // 是否处于捕获模式（截图等）
  @Entry public var isInCaptureMode: Bool = false
  // 是否为支持者用户
  @Entry public var isSupporter: Bool = false
  // 状态是否获得焦点
  @Entry public var isStatusFocused: Bool = false
  // 是否为主时间线
  @Entry public var isHomeTimeline: Bool = false
  // 缩进层级（用于回复嵌套）
  @Entry public var indentationLevel: UInt = 0
  // 选中标签页滚动到顶部的标识符
  @Entry public var selectedTabScrollToTop: Int = -1
  // Set to true when rendering inside the Notifications tab
  @Entry public var isNotificationsTab: Bool = false
}

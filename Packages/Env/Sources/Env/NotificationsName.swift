// 文件功能：通知名称扩展，定义应用内部使用的自定义通知名称常量，用于组件间的解耦通信。
// 相关技术点：
// - Foundation框架：Notification.Name系统通知机制。
// - 扩展语法：extension为现有类型添加新功能。
// - 静态常量：public static定义全局可访问的常量。
// - NotificationCenter：iOS观察者模式的实现。
// - 解耦通信：通过通知实现组件间的松散耦合。
// - 字符串标识：使用字符串作为通知的唯一标识符。
// - 时间线刷新：各种时间线的刷新通知事件。
// - 分享功能：分享表单关闭的通知机制。
//
// 技术点详解：
// 1. Notification.Name：系统通知名称的包装类型。
// 2. extension：为Notification.Name添加静态常量。
// 3. public static：全局访问的类型属性。
// 4. 字符串标识符：通知名称的字符串表示。
// 5. 观察者模式：NotificationCenter的发布-订阅机制。
// 6. 解耦设计：避免组件间的直接依赖关系。
// 7. 事件驱动：基于事件的响应式编程模式。
// 8. 全局通信：跨模块的消息传递机制。
// 导入Foundation框架，Notification.Name支持
import Foundation

// 为Notification.Name添加自定义通知名称常量
extension Notification.Name {
  // 分享表单关闭通知
  public static let shareSheetClose = Notification.Name("shareSheetClose")
  // 刷新时间线通知
  public static let refreshTimeline = Notification.Name("refreshTimeline")
  // 主时间线通知
  public static let homeTimeline = Notification.Name("homeTimeline")
  // 趋势时间线通知
  public static let trendingTimeline = Notification.Name("trendingTimeline")
  // 联邦时间线通知
  public static let federatedTimeline = Notification.Name("federatedTimeline")
  // 本地时间线通知
  public static let localTimeline = Notification.Name("localTimeline")
}

// 文件功能：偏好浏览器枚举，定义用户打开链接时的浏览器选择，支持应用内Safari和系统Safari。
// 相关技术点：
// - 枚举类型：PreferredBrowser定义浏览器选择选项。
// - Int原始值：整数原始值便于存储和比较。
// - CaseIterable：自动生成所有枚举案例的集合。
// - 浏览器选择：应用内浏览和系统浏览的用户偏好。
// - 用户体验：让用户选择链接打开方式。
// - Safari集成：利用iOS的Safari浏览器功能。
// - 设置系统：作为用户偏好设置的一部分。
// - 简洁设计：只提供两种主要的浏览器选项。
//
// 技术点详解：
// 1. enum PreferredBrowser：浏览器偏好的枚举类型。
// 2. Int原始值：使用整数便于UserDefaults存储。
// 3. CaseIterable：支持遍历所有浏览器选项。
// 4. inAppSafari：在应用内使用SFSafariViewController。
// 5. safari：打开系统Safari应用。
// 6. 用户选择：在设置中让用户选择偏好。
// 7. 简化选项：只提供最常用的两种浏览方式。
// 8. 平台集成：利用iOS系统的浏览器能力。
// 导入基础库，基本数据类型
import Foundation

// 偏好浏览器枚举，定义链接打开时的浏览器选择
public enum PreferredBrowser: Int, CaseIterable {
  // 应用内Safari浏览器
  case inAppSafari
  // 系统Safari浏览器
  case safari
}

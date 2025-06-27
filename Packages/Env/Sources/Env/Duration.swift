// 文件功能：时长枚举定义，提供标准化的时间段选项，用于静音、过滤器、投票等功能的时长设置。
// 相关技术点：
// - 枚举类型：Duration定义各种预设时间段。
// - Int原始值：以秒为单位的时间长度。
// - CaseIterable：自动生成所有枚举案例的集合。
// - LocalizedStringKey：支持多语言的本地化字符串。
// - 静态方法：提供不同场景的时长筛选。
// - 计算属性：description返回本地化描述。
// - 时间常量：预定义的常用时间段。
// - 功能分类：静音、过滤、投票的不同时长需求。
//
// 技术点详解：
// 1. enum Duration：定义时间段的枚举类型。
// 2. Int原始值：用秒数表示时间长度。
// 3. CaseIterable：支持遍历所有枚举值。
// 4. LocalizedStringKey：SwiftUI本地化支持。
// 5. 静态筛选方法：为不同功能提供合适的时长选项。
// 6. filter过滤：移除不适用的时长选项。
// 7. 常量定义：使用下划线分隔的大数字。
// 8. 自定义时长：custom选项支持用户自定义。
// 导入SwiftUI框架，LocalizedStringKey支持
import SwiftUI

// 时长枚举，定义各种预设的时间段选项
public enum Duration: Int, CaseIterable {
  // 无限期（0秒）
  case infinite = 0
  // 5分钟（300秒）
  case fiveMinutes = 300
  // 30分钟（1800秒）
  case thirtyMinutes = 1800
  // 1小时（3600秒）
  case oneHour = 3600
  // 6小时（21600秒）
  case sixHours = 21600
  // 12小时（43200秒）
  case twelveHours = 43200
  // 1天（86400秒）
  case oneDay = 86400
  // 3天（259200秒）
  case threeDays = 259_200
  // 7天（604800秒）
  case sevenDays = 604_800
  // 自定义时长（-1标识）
  case custom = -1

  // 计算属性：返回时长的本地化描述
  public var description: LocalizedStringKey {
    switch self {
    case .infinite:
      // 无限期描述
      "enum.durations.infinite"
    case .fiveMinutes:
      // 5分钟描述
      "enum.durations.fiveMinutes"
    case .thirtyMinutes:
      // 30分钟描述
      "enum.durations.thirtyMinutes"
    case .oneHour:
      // 1小时描述
      "enum.durations.oneHour"
    case .sixHours:
      // 6小时描述
      "enum.durations.sixHours"
    case .twelveHours:
      // 12小时描述
      "enum.durations.twelveHours"
    case .oneDay:
      // 1天描述
      "enum.durations.oneDay"
    case .threeDays:
      // 3天描述
      "enum.durations.threeDays"
    case .sevenDays:
      // 7天描述
      "enum.durations.sevenDays"
    case .custom:
      // 自定义描述
      "enum.durations.custom"
    }
  }

  // 静态方法：返回适用于静音功能的时长选项
  public static func mutingDurations() -> [Duration] {
    // 过滤掉自定义选项
    allCases.filter { $0 != .custom }
  }

  // 静态方法：返回适用于过滤器的时长选项
  public static func filterDurations() -> [Duration] {
    // 返回包含自定义选项的常用时长
    [.infinite, .thirtyMinutes, .oneHour, .sixHours, .twelveHours, .oneDay, .sevenDays, .custom]
  }

  // 静态方法：返回适用于投票的时长选项
  public static func pollDurations() -> [Duration] {
    // 投票时长不包括无限期和自定义
    [
      .fiveMinutes, .thirtyMinutes, .oneHour, .sixHours, .twelveHours, .oneDay, .threeDays,
      .sevenDays,
    ]
  }
}

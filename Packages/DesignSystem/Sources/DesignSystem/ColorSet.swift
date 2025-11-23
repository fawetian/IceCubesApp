// 文件功能说明：
// 该文件定义了应用的颜色主题系统，包含多套预定义的颜色方案（明亮/深色模式），每套主题都有完整的色调、背景色和标签色配置。

// 技术点：
// 1. 协议定义 —— ColorSet协议统一颜色方案接口
// 2. Sendable协议 —— 并发安全的数据传递
// 3. 枚举类型 —— ColorScheme和ColorSetName枚举
// 4. 结构体实现 —— 各种颜色主题的具体实现
// 5. 十六进制颜色 —— Color.init(hex:)构造器
// 6. RGB颜色值 —— Color.init(red:green:blue:)构造器
// 7. Identifiable协议 —— ColorSetCouple的唯一标识
// 8. 计算属性 —— 动态生成ID的计算属性
// 9. 数组集合 —— availableColorsSets全局可用主题列表
// 10. 公共API —— 所有类型和属性的public访问级别

// 技术点详解：
// 1. 协议定义：ColorSet协议定义了所有颜色主题必须实现的属性和方法
// 2. Sendable：Swift并发协议，确保类型可以安全地在不同线程间传递
// 3. 枚举类型：使用枚举定义有限的选项集，提供类型安全和可预测性
// 4. 结构体实现：使用轻量级结构体实现具体的颜色主题，性能优越
// 5. 十六进制颜色：支持Web标准的十六进制颜色码，便于设计师协作
// 6. RGB颜色值：使用0-1范围的RGB值创建精确的颜色定义
// 7. Identifiable：为颜色主题对提供唯一标识符，用于SwiftUI列表渲染
// 8. 计算属性：动态生成基于明暗主题名称组合的唯一ID
// 9. 数组集合：全局定义所有可用的颜色主题对，便于主题选择
// 10. 公共API：所有定义都是公共的，可以被其他模块访问和使用

// 导入SwiftUI框架，提供Color颜色类型
import SwiftUI

// 全局可用的颜色主题对数组，包含所有预定义的明暗主题配对
public let availableColorsSets: [ColorSetCouple] =
  [
    .init(light: IceCubeLight(), dark: IceCubeDark()),
    .init(light: IceCubeNeonLight(), dark: IceCubeNeonDark()),
    .init(light: DesertLight(), dark: DesertDark()),
    .init(light: NemesisLight(), dark: NemesisDark()),
    .init(light: MediumLight(), dark: MediumDark()),
    .init(light: ConstellationLight(), dark: ConstellationDark()),
    .init(light: ThreadsLight(), dark: ThreadsDark()),
  ]

public protocol ColorSet: Sendable {
  var name: ColorSetName { get }
  var scheme: ColorScheme { get }
  var tintColor: Color { get set }
  var primaryBackgroundColor: Color { get set }
  var secondaryBackgroundColor: Color { get set }
  var labelColor: Color { get set }
}

public enum ColorScheme: String, Sendable {
  case dark, light
}

public enum ColorSetName: String, Sendable {
  case iceCubeDark = "Ice Cube - Dark"
  case iceCubeLight = "Ice Cube - Light"
  case iceCubeNeonDark = "Ice Cube Neon - Dark"
  case iceCubeNeonLight = "Ice Cube Neon - Light"
  case desertDark = "Desert - Dark"
  case desertLight = "Desert - Light"
  case nemesisDark = "Nemesis - Dark"
  case nemesisLight = "Nemesis - Light"
  case mediumLight = "Medium - Light"
  case mediumDark = "Medium - Dark"
  case constellationLight = "Constellation - Light"
  case constellationDark = "Constellation - Dark"
  case threadsLight = "Threads - Light"
  case threadsDark = "Threads - Dark"
}

public struct ColorSetCouple: Identifiable, Sendable {
  public var id: String {
    dark.name.rawValue + light.name.rawValue
  }

  public let light: ColorSet
  public let dark: ColorSet
}

public struct IceCubeDark: ColorSet {
  public var name: ColorSetName = .iceCubeDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(red: 187 / 255, green: 59 / 255, blue: 226 / 255)
  public var primaryBackgroundColor: Color = .init(red: 16 / 255, green: 21 / 255, blue: 35 / 255)
  public var secondaryBackgroundColor: Color = .init(red: 30 / 255, green: 35 / 255, blue: 62 / 255)
  public var labelColor: Color = .white

  public init() {}
}

public struct IceCubeLight: ColorSet {
  public var name: ColorSetName = .iceCubeLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(red: 187 / 255, green: 59 / 255, blue: 226 / 255)
  public var primaryBackgroundColor: Color = .white
  public var secondaryBackgroundColor: Color = .init(hex: 0xF0F1F2)
  public var labelColor: Color = .black

  public init() {}
}

public struct IceCubeNeonDark: ColorSet {
  public var name: ColorSetName = .iceCubeNeonDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(red: 213 / 255, green: 46 / 255, blue: 245 / 255)
  public var primaryBackgroundColor: Color = .black
  public var secondaryBackgroundColor: Color = .init(red: 19 / 255, green: 0 / 255, blue: 32 / 255)
  public var labelColor: Color = .white

  public init() {}
}

public struct IceCubeNeonLight: ColorSet {
  public var name: ColorSetName = .iceCubeNeonLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(red: 213 / 255, green: 46 / 255, blue: 245 / 255)
  public var primaryBackgroundColor: Color = .white
  public var secondaryBackgroundColor: Color = .init(hex: 0xF0F1F2)
  public var labelColor: Color = .black

  public init() {}
}

public struct DesertDark: ColorSet {
  public var name: ColorSetName = .desertDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(hex: 0xDF915E)
  public var primaryBackgroundColor: Color = .init(hex: 0x433744)
  public var secondaryBackgroundColor: Color = .init(hex: 0x654868)
  public var labelColor: Color = .white

  public init() {}
}

public struct DesertLight: ColorSet {
  public var name: ColorSetName = .desertLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(hex: 0xDF915E)
  public var primaryBackgroundColor: Color = .init(hex: 0xFCF2EB)
  public var secondaryBackgroundColor: Color = .init(hex: 0xEEEDE7)
  public var labelColor: Color = .black

  public init() {}
}

public struct NemesisDark: ColorSet {
  public var name: ColorSetName = .nemesisDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(hex: 0x17A2F2)
  public var primaryBackgroundColor: Color = .init(hex: 0x000000)
  public var secondaryBackgroundColor: Color = .init(hex: 0x151E2B)
  public var labelColor: Color = .white

  public init() {}
}

public struct NemesisLight: ColorSet {
  public var name: ColorSetName = .nemesisLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(hex: 0x17A2F2)
  public var primaryBackgroundColor: Color = .init(hex: 0xFFFFFF)
  public var secondaryBackgroundColor: Color = .init(hex: 0xE8ECEF)
  public var labelColor: Color = .black

  public init() {}
}

public struct MediumDark: ColorSet {
  public var name: ColorSetName = .mediumDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(hex: 0x1A8917)
  public var primaryBackgroundColor: Color = .init(hex: 0x121212)
  public var secondaryBackgroundColor: Color = .init(hex: 0x191919)
  public var labelColor: Color = .white

  public init() {}
}

public struct MediumLight: ColorSet {
  public var name: ColorSetName = .mediumLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(hex: 0x1A8917)
  public var primaryBackgroundColor: Color = .init(hex: 0xFFFFFF)
  public var secondaryBackgroundColor: Color = .init(hex: 0xFAFAFA)
  public var labelColor: Color = .black

  public init() {}
}

public struct ConstellationDark: ColorSet {
  public var name: ColorSetName = .constellationDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(hex: 0xFFD966)
  public var primaryBackgroundColor: Color = .init(hex: 0x09192C)
  public var secondaryBackgroundColor: Color = .init(hex: 0x304C7A)
  public var labelColor: Color = .init(hex: 0xE2E4E2)

  public init() {}
}

public struct ConstellationLight: ColorSet {
  public var name: ColorSetName = .constellationLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(hex: 0xC82238)
  public var primaryBackgroundColor: Color = .init(hex: 0xF4F5F7)
  public var secondaryBackgroundColor: Color = .init(hex: 0xACC7E5)
  public var labelColor: Color = .black

  public init() {}
}

public struct ThreadsDark: ColorSet {
  public var name: ColorSetName = .threadsDark
  public var scheme: ColorScheme = .dark
  public var tintColor: Color = .init(hex: 0x0095F6)
  public var primaryBackgroundColor: Color = .init(hex: 0x101010)
  public var secondaryBackgroundColor: Color = .init(hex: 0x181818)
  public var labelColor: Color = .init(hex: 0xE2E4E2)

  public init() {}
}

public struct ThreadsLight: ColorSet {
  public var name: ColorSetName = .threadsLight
  public var scheme: ColorScheme = .light
  public var tintColor: Color = .init(hex: 0x0095F6)
  public var primaryBackgroundColor: Color = .init(hex: 0xFFFFFF)
  public var secondaryBackgroundColor: Color = .init(hex: 0xFFFFFF)
  public var labelColor: Color = .black

  public init() {}
}

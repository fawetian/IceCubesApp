// 文件功能：字体扩展，提供可缩放的自定义字体系统，支持不同平台的字体大小适配和表情符号处理。
// 相关技术点：
// - Extension：扩展 Font 和 UIFont 类型。
// - @MainActor：确保在主线程执行。
// - 条件编译：#if targetEnvironment(macCatalyst) 平台适配。
// - 私有静态属性：定义不同平台的字体大小常量。
// - 计算属性：提供动态字体大小计算。
// - UIFontMetrics：系统字体度量工具。
// - 自定义字体：支持用户选择的字体。
// - 圆角字体：withDesign(.rounded) 处理。
//
// 技术点详解：
// 1. targetEnvironment(macCatalyst)：检测 Mac Catalyst 环境。
// 2. TextStyle：文本样式枚举，用于动态类型。
// 3. UIFontMetrics.scaledValue：根据用户设置缩放字体。
// 4. fontDescriptor：字体描述符，用于修改字体属性。
// 5. capHeight：字体的大写字母高度。
// 6. emojiBaselineOffset：表情符号基线偏移计算。
// 7. .AppleSystemUIFontRounded：苹果系统圆角字体标识。
// 8. relativeTo：相对于系统文本样式的字体大小。
// 导入环境管理模块
import Env
// 导入 SwiftUI 框架
import SwiftUI

// 扩展 Font 类型，提供可缩放的自定义字体支持
@MainActor
extension Font {
  // See https://gist.github.com/zacwest/916d31da5d03405809c4 for iOS values
  // Custom values for Mac
  // 标题字体大小常量
  private static let title = 28.0
  #if targetEnvironment(macCatalyst)
    // Mac Catalyst 平台的字体大小
    private static let headline = 20.0
    private static let body = 19.0
    private static let callout = 17.0
    private static let subheadline = 16.0
    private static let footnote = 15.0
    private static let caption = 14.0
  #else
    // iOS 和其他平台的字体大小
    private static let headline = 17.0
    private static let body = 17.0
    private static let callout = 16.0
    private static let subheadline = 15.0
    private static let footnote = 13.0
    private static let caption = 12.0
  #endif

  // 创建自定义字体的私有方法
  private static func customFont(size: CGFloat, relativeTo textStyle: TextStyle) -> Font {
    // 检查是否有用户选择的字体
    if let chosenFont = Theme.shared.chosenFont {
      // 如果是苹果系统圆角字体
      if chosenFont.fontName == ".AppleSystemUIFontRounded-Regular" {
        return .system(size: size, design: .rounded)
      } else {
        // 使用自定义字体
        return .custom(chosenFont.fontName, size: size, relativeTo: textStyle)
      }
    }

    // 默认使用系统字体
    return .system(size: size, design: .default)
  }

  // 创建自定义 UIFont 的私有方法
  private static func customUIFont(size: CGFloat) -> UIFont {
    // 检查是否有用户选择的字体
    if let chosenFont = Theme.shared.chosenFont {
      return chosenFont.withSize(size)
    }
    // 默认使用系统字体
    return .systemFont(ofSize: size)
  }

  // 根据用户设置缩放字体大小
  private static func userScaledFontSize(baseSize: CGFloat) -> CGFloat {
    UIFontMetrics.default.scaledValue(for: baseSize * Theme.shared.fontSizeScale)
  }

  // 可缩放的标题字体
  public static var scaledTitle: Font {
    customFont(size: userScaledFontSize(baseSize: title), relativeTo: .title)
  }

  // 可缩放的标题字体（半粗体）
  public static var scaledHeadline: Font {
    customFont(size: userScaledFontSize(baseSize: headline), relativeTo: .headline).weight(
      .semibold)
  }

  // 可缩放的标题 UIFont
  public static var scaledHeadlineFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: headline))
  }

  // 可缩放的聚焦正文字体（稍大）
  public static var scaledBodyFocused: Font {
    customFont(size: userScaledFontSize(baseSize: body + 2), relativeTo: .body)
  }

  // 可缩放的聚焦正文 UIFont
  public static var scaledBodyFocusedFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: body + 2))
  }

  // 可缩放的正文字体
  public static var scaledBody: Font {
    customFont(size: userScaledFontSize(baseSize: body), relativeTo: .body)
  }

  // 可缩放的正文 UIFont
  public static var scaledBodyFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: body))
  }

  // 可缩放的正文 UIFont（别名）
  public static var scaledBodyUIFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: body))
  }

  // 可缩放的标注字体
  public static var scaledCallout: Font {
    customFont(size: userScaledFontSize(baseSize: callout), relativeTo: .callout)
  }

  // 可缩放的标注 UIFont
  public static var scaledCalloutFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: body))
  }

  // 可缩放的副标题字体
  public static var scaledSubheadline: Font {
    customFont(size: userScaledFontSize(baseSize: subheadline), relativeTo: .subheadline)
  }

  // 可缩放的副标题 UIFont
  public static var scaledSubheadlineFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: subheadline))
  }

  // 可缩放的脚注字体
  public static var scaledFootnote: Font {
    customFont(size: userScaledFontSize(baseSize: footnote), relativeTo: .footnote)
  }

  // 可缩放的脚注 UIFont
  public static var scaledFootnoteFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: footnote))
  }

  // 可缩放的说明文字字体
  public static var scaledCaption: Font {
    customFont(size: userScaledFontSize(baseSize: caption), relativeTo: .caption)
  }

  // 可缩放的说明文字 UIFont
  public static var scaledCaptionFont: UIFont {
    customUIFont(size: userScaledFontSize(baseSize: caption))
  }
}

// 扩展 UIFont 类型，添加圆角字体和表情符号处理功能
extension UIFont {
  // 将字体转换为圆角版本
  public func rounded() -> UIFont {
    // 尝试获取圆角设计的字体描述符
    guard let descriptor = fontDescriptor.withDesign(.rounded) else {
      return self
    }
    // 创建圆角字体
    return UIFont(descriptor: descriptor, size: pointSize)
  }

  // 表情符号字体大小（与字体大小相同）
  public var emojiSize: CGFloat {
    pointSize
  }

  // 表情符号基线偏移量，用于与文本对齐
  public var emojiBaselineOffset: CGFloat {
    // Center emoji with capital letter size of font
    // 计算表情符号相对于大写字母的基线偏移
    -(emojiSize - capHeight) / 2
  }
}

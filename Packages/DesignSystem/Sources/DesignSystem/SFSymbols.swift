// 文件功能：SF Symbols 扩展，为 Label 提供统一的系统图标和自定义图标处理机制。
// 相关技术点：
// - Extension：扩展现有类型的功能。
// - 泛型约束：where 子句限制泛型类型。
// - LocalizedStringKey：本地化字符串键。
// - 字符串判断：lowercased() 检查字符串格式。
// - 条件初始化：根据图标名称格式选择不同初始化方式。
//
// 技术点详解：
// 1. where Title == Text, Icon == Image：泛型约束，确保特定类型组合。
// 2. LocalizedStringKey：支持本地化的字符串键类型。
// 3. systemImage vs image：系统图标和自定义图标的区别。
// 4. lowercased()：将字符串转换为小写。
// 5. 命名约定：小写为系统图标，大写为自定义图标。
// 导入基础框架
import Foundation
// 导入 SwiftUI 框架
import SwiftUI

// Functions to cope with extending SF symbols
// images named in lower case are Apple's symbols
// images inamed in CamelCase are custom

// 扩展 Label 类型，添加根据图标名称自动选择图标类型的初始化器
extension Label where Title == Text, Icon == Image {
  // 公共初始化方法，根据图标名称格式自动选择系统图标或自定义图标
  public init(_ title: LocalizedStringKey, imageNamed: String) {
    // 如果图标名称全为小写，使用系统图标
    if imageNamed.lowercased() == imageNamed {
      self.init(title, systemImage: imageNamed)
    } else {
      // 否则使用自定义图标（通常为驼峰命名）
      self.init(title, image: imageNamed)
    }
  }
}

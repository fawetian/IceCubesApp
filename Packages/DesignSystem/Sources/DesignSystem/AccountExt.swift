// 文件功能说明：
// 该文件为Account模型提供扩展功能，主要处理用户显示名称的安全获取、表情符号清理等用户界面显示相关的便捷方法。

// 技术点：
// 1. Extension扩展 —— 为现有类型添加新功能
// 2. 嵌套类型定义 —— Part结构体作为私有辅助类型
// 3. Identifiable协议 —— 为列表和集合提供唯一标识
// 4. UUID生成 —— 创建唯一标识符
// 5. Substring类型 —— 字符串的子字符串表示
// 6. 计算属性 —— 基于现有属性动态计算的只读属性
// 7. 字符串处理 —— 替换、分割、连接等字符串操作
// 8. 空值安全 —— 可选值的安全解包和默认值处理
// 9. 正则表达式替换 —— 表情符号代码的模式匹配
// 10. 函数式编程 —— split、joined等高阶函数的使用

// 技术点详解：
// 1. Extension：Swift语言特性，允许为现有类型添加新方法、计算属性等功能
// 2. 嵌套类型：在类型内部定义的辅助类型，提供更好的命名空间管理
// 3. Identifiable：SwiftUI常用协议，要求类型有唯一标识符，用于列表渲染
// 4. UUID：全局唯一标识符，提供128位的随机标识符生成
// 5. Substring：String的子字符串类型，避免不必要的字符串复制，提高性能
// 6. 计算属性：不存储值，而是通过其他属性计算得出，提供动态的只读访问
// 7. 字符串处理：Swift字符串操作方法，用于文本清理和格式化
// 8. 空值安全：Swift的可选类型系统，防止空指针异常的安全编程模式
// 9. 模式匹配：通过特定格式识别和替换表情符号代码
// 10. 函数式编程：使用高阶函数处理字符串序列，代码更简洁和功能化

// 导入Foundation框架，提供基础数据类型和字符串处理
import Foundation
// 导入Models模块，提供Account等数据模型定义
import Models
// 导入NukeUI，提供图片加载相关功能
import NukeUI
// 导入SwiftUI框架，提供用户界面相关功能
import SwiftUI

// 扩展Account模型，添加显示相关的便捷方法
extension Account {
  // 私有嵌套结构体，表示字符串的一部分，遵循Identifiable协议
  private struct Part: Identifiable {
    // 唯一标识符，自动生成UUID字符串
    let id = UUID().uuidString
    // 存储字符串子串的值
    let value: Substring
  }

  // 公共计算属性：获取安全的显示名称
  public var safeDisplayName: String {
    // 检查是否有displayName且不为空
    if let displayName, !displayName.isEmpty {
      // 如果有displayName，返回displayName
      return displayName
    }
    // 否则返回带@符号的用户名作为默认显示名称
    return "@\(username)"
  }

  // 公共计算属性：获取移除表情符号后的显示名称
  public var displayNameWithoutEmojis: String {
    // 获取安全的显示名称作为基础
    var name = safeDisplayName
    // 遍历账户中的所有表情符号
    for emoji in emojis {
      // 将表情符号代码（:shortcode:格式）替换为空字符串
      name = name.replacingOccurrences(of: ":\(emoji.shortcode):", with: "")
    }
    // 将处理后的字符串按空格分割，移除空的子序列，然后重新用空格连接
    return name.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
  }
}

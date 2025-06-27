// 文件功能：翻译类型枚举，定义应用支持的不同翻译服务选项，包括服务器、DeepL、Apple翻译。
// 相关技术点：
// - 枚举类型：TranslationType定义翻译服务的选择。
// - CaseIterable：自动生成所有枚举案例的集合。
// - LocalizedStringKey：支持系统自动本地化的字符串键。
// - 计算属性：description提供每种翻译类型的显示名称。
// - 原始值：String类型的原始值用于存储和序列化。
// - 翻译服务：集成多种翻译API的策略模式。
// - 用户选择：让用户选择偏好的翻译服务提供商。
// - 设置系统：作为用户偏好设置的一部分。
//
// 技术点详解：
// 1. enum TranslationType：定义支持的翻译服务类型。
// 2. String, CaseIterable：字符串原始值和可迭代协议。
// 3. LocalizedStringKey：SwiftUI的本地化字符串支持。
// 4. computed property：description计算属性返回显示文本。
// 5. switch语句：根据枚举值返回对应的本地化键。
// 6. 服务器翻译：使用Mastodon实例提供的翻译服务。
// 7. DeepL翻译：集成第三方专业翻译API。
// 8. Apple翻译：使用iOS系统内置的翻译功能。
// 导入SwiftUI框架，LocalizedStringKey支持
import SwiftUI

// 翻译类型枚举，定义应用支持的不同翻译服务选项
public enum TranslationType: String, CaseIterable {
  // 优先使用服务器翻译（如果可用）
  case useServerIfPossible
  // 使用DeepL翻译服务
  case useDeepl
  // 使用Apple系统翻译
  case useApple

  // 计算属性：返回翻译类型的本地化显示名称
  public var description: LocalizedStringKey {
    switch self {
    case .useServerIfPossible:
      // 实例服务器翻译
      "Instance"
    case .useDeepl:
      // DeepL翻译服务
      "DeepL"
    case .useApple:
      // Apple翻译服务
      "Apple Translate"
    }
  }
}

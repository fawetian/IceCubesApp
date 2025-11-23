// 文件功能：分享按钮行为偏好枚举，定义分享帖子时的不同分享策略（仅链接或链接加文本）。
// 相关技术点：
// - 枚举类型：PreferredShareButtonBehavior定义分享行为选项。
// - Int原始值：整数原始值便于存储和序列化。
// - CaseIterable：自动生成所有枚举案例的集合。
// - Codable：支持JSON编解码的协议。
// - LocalizedStringKey：本地化字符串键支持多语言。
// - 计算属性：title提供每种行为的显示标题。
// - 分享策略：不同的内容分享方式选择。
// - 用户偏好：作为设置系统的一部分。
//
// 技术点详解：
// 1. enum PreferredShareButtonBehavior：定义分享行为类型。
// 2. Int, CaseIterable, Codable：整数原始值和协议遵循。
// 3. LocalizedStringKey：SwiftUI的本地化支持。
// 4. computed property：title计算属性返回显示文本。
// 5. switch语句：根据枚举值返回本地化键。
// 6. 仅链接分享：只分享帖子的URL链接。
// 7. 链接和文本：同时分享URL和帖子内容文本。
// 8. 用户体验：让用户选择偏好的分享方式。
// 导入基础库，基本数据类型
import Foundation
// 导入SwiftUI框架，LocalizedStringKey支持
import SwiftUI

// 分享按钮行为偏好枚举，定义帖子分享时的不同策略
public enum PreferredShareButtonBehavior: Int, CaseIterable, Codable {
  // 仅分享链接
  case linkOnly
  // 分享链接和文本内容
  case linkAndText

  // 计算属性：返回分享行为的本地化显示标题
  public var title: LocalizedStringKey {
    switch self {
    case .linkOnly:
      // 仅链接分享模式
      "settings.content.sharing.share-behavior.link-only"
    case .linkAndText:
      // 链接和文本分享模式
      "settings.content.sharing.share-behavior.link-and-text"
    }
  }
}

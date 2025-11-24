/*
 * ViewModeMode.swift
 * IceCubesApp - 编辑器视图模式
 *
 * 功能描述：
 * 定义状态编辑器的不同工作模式
 * 每种模式对应不同的使用场景和初始状态
 *
 * 核心模式：
 * 1. replyTo - 回复帖子模式
 * 2. new - 新建帖子模式
 * 3. edit - 编辑已发布帖子模式
 * 4. quote - 引用帖子模式
 * 5. quoteLink - 引用链接模式
 * 6. mention - 提及用户模式
 * 7. shareExtension - 分享扩展模式
 * 8. imageURL - 图片 URL 模式
 *
 * 技术点：
 * 1. 枚举关联值 - 携带不同类型的数据
 * 2. 计算属性 - 派生状态和信息
 * 3. 模式匹配 - switch 语句处理不同情况
 * 4. 本地化字符串 - LocalizedStringKey
 * 5. 可选值处理 - 安全解包
 * 6. 公共访问 - public 修饰符
 * 7. 扩展设计 - 为 ViewModel 添加嵌套类型
 * 8. 类型安全 - 编译时模式检查
 * 9. 语义清晰 - 每种模式有明确含义
 * 10. 可扩展性 - 易于添加新模式
 *
 * 模式详解：
 * - replyTo: 回复特定帖子，携带被回复的 Status
 * - new: 创建新帖子，可选初始文本和可见性
 * - edit: 编辑已发布的帖子，携带原 Status
 * - quote: 引用帖子，携带被引用的 Status
 * - quoteLink: 通过链接引用帖子
 * - mention: 提及特定用户，携带 Account 和可见性
 * - shareExtension: 从分享扩展启动，携带分享项
 * - imageURL: 分享图片 URL，携带 URL、标题、替代文本和可见性
 *
 * 计算属性：
 * - isInShareExtension: 是否在分享扩展中
 * - isEditing: 是否在编辑模式
 * - replyToStatus: 获取被回复的帖子（如果有）
 * - title: 编辑器标题，根据模式动态生成
 *
 * 使用场景：
 * - 从时间线回复帖子
 * - 创建新帖子
 * - 编辑已发布的帖子
 * - 引用其他帖子
 * - 从分享菜单分享内容
 * - 提及特定用户
 *
 * 依赖关系：
 * - Models: Status、Account、Visibility
 * - SwiftUI: LocalizedStringKey
 * - UIKit: NSItemProvider
 */

import Models
import SwiftUI
import UIKit

extension StatusEditor.ViewModel {
  /// 编辑器工作模式
  ///
  /// 定义编辑器的不同使用场景和初始状态。
  ///
  /// 模式说明：
  /// - **replyTo**: 回复特定帖子
  /// - **new**: 创建新帖子
  /// - **edit**: 编辑已发布的帖子
  /// - **quote**: 引用帖子
  /// - **quoteLink**: 通过链接引用帖子
  /// - **mention**: 提及特定用户
  /// - **shareExtension**: 从分享扩展启动
  /// - **imageURL**: 分享图片 URL
  ///
  /// 使用示例：
  /// ```swift
  /// // 回复帖子
  /// let mode = Mode.replyTo(status: someStatus)
  ///
  /// // 创建新帖子
  /// let mode = Mode.new(text: nil, visibility: .public)
  ///
  /// // 编辑帖子
  /// let mode = Mode.edit(status: someStatus)
  /// ```
  public enum Mode {
    /// 回复帖子模式
    case replyTo(status: Status)
    /// 新建帖子模式
    case new(text: String?, visibility: Models.Visibility)
    /// 编辑帖子模式
    case edit(status: Status)
    /// 引用帖子模式
    case quote(status: Status)
    /// 引用链接模式
    case quoteLink(link: URL)
    /// 提及用户模式
    case mention(account: Account, visibility: Models.Visibility)
    /// 分享扩展模式
    case shareExtension(items: [NSItemProvider])
    /// 图片 URL 模式
    case imageURL(urls: [URL], caption: String?, altTexts: [String]?, visibility: Models.Visibility)

    /// 是否在分享扩展中
    var isInShareExtension: Bool {
      switch self {
      case .shareExtension:
        true
      default:
        false
      }
    }

    /// 是否在编辑模式
    var isEditing: Bool {
      switch self {
      case .edit:
        true
      default:
        false
      }
    }

    /// 获取被回复的帖子（如果有）
    var replyToStatus: Status? {
      switch self {
      case .replyTo(let status):
        status
      default:
        nil
      }
    }

    /// 编辑器标题
    ///
    /// 根据当前模式动态生成标题文本。
    var title: LocalizedStringKey {
      switch self {
      case .new, .mention, .shareExtension, .quoteLink, .imageURL:
        "status.editor.mode.new"
      case .edit:
        "status.editor.mode.edit"
      case .replyTo(let status):
        "status.editor.mode.reply-\(status.reblog?.account.displayNameWithoutEmojis ?? status.account.displayNameWithoutEmojis)"
      case .quote(let status):
        "status.editor.mode.quote-\(status.reblog?.account.displayNameWithoutEmojis ?? status.account.displayNameWithoutEmojis)"
      }
    }
  }
}

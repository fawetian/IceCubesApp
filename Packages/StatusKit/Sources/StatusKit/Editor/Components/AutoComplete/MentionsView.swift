/*
 * MentionsView.swift
 * IceCubesApp - 提及建议视图
 *
 * 功能描述：
 * 显示用户提及（@）的自动完成建议
 * 当用户输入 @ 符号时显示匹配的用户列表
 *
 * 核心功能：
 * 1. 用户列表 - 显示匹配的用户账户
 * 2. 头像显示 - 显示用户头像
 * 3. 用户信息 - 显示用户名和账户名
 * 4. 表情支持 - 支持用户名中的自定义表情
 * 5. 快速选择 - 点击用户快速插入提及
 *
 * 视图层次：
 * - ForEach（用户列表）
 *   - Button（用户按钮）
 *     - HStack
 *       - AvatarView（头像）
 *       - VStack
 *         - EmojiTextApp（用户名 + 表情）
 *         - Text（账户名）
 *
 * 技术点：
 * 1. @Environment - 主题环境注入
 * 2. EmojiTextApp - 支持自定义表情的文本
 * 3. AvatarView - 头像视图
 * 4. ForEach - 列表渲染
 *
 * 使用场景：
 * - 用户输入 @ 符号
 * - 显示匹配的用户建议
 * - 快速提及其他用户
 *
 * 依赖关系：
 * - DesignSystem: 主题和 AvatarView
 * - EmojiText: 表情文本支持
 * - Models: 账户模型
 */

import DesignSystem
import EmojiText
import Foundation
import Models
import SwiftData
import SwiftUI

extension StatusEditor.AutoCompleteView {
  /// 提及建议视图
  ///
  /// 显示用户提及（@）的自动完成建议。
  ///
  /// 主要功能：
  /// - **用户列表**：显示匹配的用户账户
  /// - **头像显示**：显示用户头像
  /// - **表情支持**：支持用户名中的自定义表情
  /// - **快速选择**：点击用户快速插入提及
  ///
  /// 使用示例：
  /// ```swift
  /// MentionsView(viewModel: viewModel)
  /// ```
  ///
  /// - Note: 用户名支持自定义表情显示
  struct MentionsView: View {
    /// 主题环境
    @Environment(Theme.self) private var theme

    /// 编辑器 ViewModel
    var viewModel: StatusEditor.ViewModel

    var body: some View {
      // 遍历提及建议列表
      ForEach(viewModel.mentionsSuggestions) { account in
        Button {
          // 选择用户，插入提及
          viewModel.selectMentionSuggestion(account: account)
        } label: {
          HStack {
            // 用户头像（徽章尺寸）
            AvatarView(account.avatar, config: AvatarView.FrameConfig.badge)

            VStack(alignment: .leading) {
              // 用户显示名称（支持自定义表情）
              EmojiTextApp(
                .init(stringValue: account.safeDisplayName),
                emojis: account.emojis
              )
              .emojiText.size(Font.scaledFootnoteFont.emojiSize)
              .emojiText.baselineOffset(Font.scaledFootnoteFont.emojiBaselineOffset)
              .font(.scaledFootnote)
              .fontWeight(.bold)
              .foregroundColor(theme.labelColor)

              // 用户账户名（@username）
              Text("@\(account.acct)")
                .font(.scaledFootnote)
                .foregroundStyle(theme.tintColor)
            }
          }
        }
      }
    }
  }
}

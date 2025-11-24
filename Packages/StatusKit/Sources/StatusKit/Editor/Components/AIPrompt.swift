/*
 * AIPrompt.swift
 * IceCubesApp - AI 助手提示
 *
 * 功能描述：
 * 定义 AI 助手的各种提示类型和语气选项（iOS 26+）
 * 使用系统语言模型辅助用户写作社交媒体帖子
 *
 * 核心功能：
 * 1. 语气调整 - 专业、休闲、幽默、教育
 * 2. 语法纠正 - 修正拼写和语法错误
 * 3. 文本缩短 - 生成更短的版本
 * 4. 强调效果 - 使文本更吸引人
 * 5. 标签生成 - 自动生成相关标签
 * 6. 流式响应 - 实时显示 AI 生成的内容
 * 7. 模型预热 - 提前加载模型以提高响应速度
 * 8. 可用性检查 - 检查系统语言模型是否可用
 *
 * 技术点：
 * 1. @available(iOS 26.0, *) - iOS 26+ 专属功能
 * 2. @MainActor - 确保 UI 操作在主线程
 * 3. LanguageModelSession - 语言模型会话
 * 4. @Generable - 可生成的结构体
 * 5. @Guide - 生成指导
 * 6. ResponseStream - 流式响应
 * 7. async/await - 异步操作
 * 8. CaseIterable - 枚举可迭代
 * 9. Hashable - 枚举可哈希
 * 10. ViewBuilder - 视图构建器
 *
 * AI 提示类型：
 * - correct: 修正语法和拼写
 * - fit: 缩短文本以适应字符限制
 * - emphasize: 使文本更有趣和吸引人
 * - rewriteWithTone: 用指定语气重写
 *
 * 语气选项：
 * - professional: 专业正式
 * - casual: 休闲友好
 * - humorous: 幽默风趣
 * - educational: 教育性信息性
 *
 * 使用场景：
 * - 辅助用户写作社交媒体帖子
 * - 修正语法错误
 * - 调整文本语气
 * - 生成相关标签
 * - 缩短过长的文本
 *
 * 依赖关系：
 * - FoundationModels: 系统语言模型
 * - NetworkClient: 网络客户端
 */

import Foundation
import FoundationModels
import NetworkClient
import SwiftUI

extension StatusEditor {
  /// AI 助手（iOS 26+）
  ///
  /// 使用系统语言模型辅助用户写作。
  ///
  /// 主要功能：
  /// - **语气调整**：用不同语气重写文本
  /// - **语法纠正**：修正拼写和语法错误
  /// - **文本缩短**：生成更短的版本
  /// - **强调效果**：使文本更吸引人
  /// - **标签生成**：自动生成相关标签
  ///
  /// 使用示例：
  /// ```swift
  /// let assistant = Assistant()
  /// let tags = await assistant.generateTags(from: "Hello world")
  /// ```
  ///
  /// - Note: 仅在 iOS 26+ 可用
  /// - Important: 需要系统语言模型支持
  @available(iOS 26.0, *)
  @MainActor
  public struct Assistant {
    /// 语气枚举
    ///
    /// 定义文本重写的不同语气风格。
    enum Tone: String, CaseIterable {
      case professional = "Professional and formal"
      case casual = "Casual and friendly"
      case humorous = "Witty and humorous"
      case educational = "Educational and informative"

      @ViewBuilder
      var label: some View {
        switch self {
        case .professional:
          Label("Profesional", systemImage: "suitcase")
        case .casual:
          Label("Casual", systemImage: "face.smiling")
        case .humorous:
          Label("Humorous", systemImage: "party.popper")
        case .educational:
          Label("Educational", systemImage: "book.closed")
        }
      }
    }

    private static let model = SystemLanguageModel.default

    public static var isAvailable: Bool {
      return model.isAvailable
    }

    public static func prewarm() {
      session.prewarm()
    }

    @Generable
    struct Tags {
      @Guide(
        description: "The value of the hashtags, must be camelCased and prefixed with a # symbol.",
        .count(5))
      let values: [String]
    }

    private static let session = LanguageModelSession(model: .init(useCase: .general)) {
      """
      Your job is to assist the user in writting social media posts. 
      The users is writting for the Mastodon platforms, where posts are usually not longer than 500 characters.
      Don't return any context, only the requestesd content without quote mark.
      """
    }

    func generateTags(from message: String) async -> Tags {
      do {
        let response = try await Self.session.respond(
          to: "Generate a list of hashtags for this social media post: \(message).",
          generating: Tags.self)
        return response.content
      } catch {
        return .init(values: [])
      }
    }

    func correct(message: String) async -> LanguageModelSession.ResponseStream<String>? {
      Self.session.streamResponse(
        to: "Fix the spelling and grammar mistakes in the following text: \(message).",
        options: .init(temperature: 0.3))
    }

    func shorten(message: String) async -> LanguageModelSession.ResponseStream<String>? {
      Self.session.streamResponse(
        to: "Make a shorter version of this text: \(message).", options: .init(temperature: 0.3))
    }

    func emphasize(message: String) async -> LanguageModelSession.ResponseStream<String>? {
      Self.session.streamResponse(
        to: "Make this text catchy, more fun, be insane: \(message).",
        options: .init(temperature: 2.0))
    }

    func adjustTone(message: String, to tone: Tone) async -> LanguageModelSession.ResponseStream<
      String
    >? {
      Self.session.streamResponse(
        to:
          "Rewrite this text to be more \(tone.rawValue). Here is the message to rewrite: \(message)",
        options: .init(temperature: 0.8))
    }
  }

  @available(iOS 26.0, *)
  enum AIPrompt: CaseIterable, Hashable {
    static var allCases: [StatusEditor.AIPrompt] {
      [.rewriteWithTone(tone: .professional), .correct, .fit, .emphasize]
    }

    case correct, fit, emphasize
    case rewriteWithTone(tone: Assistant.Tone)

    @ViewBuilder
    var label: some View {
      switch self {
      case .correct:
        Label("status.editor.ai-prompt.correct", systemImage: "text.badge.checkmark")
      case .fit:
        Label("status.editor.ai-prompt.fit", systemImage: "text.badge.minus")
      case .emphasize:
        Label("status.editor.ai-prompt.emphasize", systemImage: "text.badge.star")
      case .rewriteWithTone:
        Label("Rewrite with tone", systemImage: "pencil.and.scribble")
      }
    }
  }
}

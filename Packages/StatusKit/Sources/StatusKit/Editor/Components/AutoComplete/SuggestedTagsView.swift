/*
 * SuggestedTagsView.swift
 * IceCubesApp - AI 建议标签视图（iOS 26+）
 *
 * 功能描述：
 * 使用 AI 助手生成标签建议
 * 根据帖子内容智能推荐相关标签
 *
 * 核心功能：
 * 1. AI 生成 - 使用系统语言模型生成标签
 * 2. 内容分析 - 分析帖子内容推荐相关标签
 * 3. 加载状态 - 显示加载进度
 * 4. 快速选择 - 点击标签快速插入
 * 5. 自动记录 - 记录到最近使用列表
 * 6. 格式处理 - 自动处理标签格式（移除 # 前缀）
 *
 * 视图状态：
 * - loading: 正在生成标签
 * - loaded: 标签生成完成
 * - error: 生成失败
 *
 * 视图层次：
 * - Switch（状态切换）
 *   - ProgressView（加载中）
 *   - ForEach（标签列表）
 *     - Button（标签按钮）
 *   - EmptyView（错误状态）
 *
 * 技术点：
 * 1. @available(iOS 26.0, *) - iOS 26+ 专属功能
 * 2. @Environment - 环境对象注入
 * 3. @Binding - 双向绑定展开状态
 * 4. @State - 视图状态管理
 * 5. @Query - SwiftData 查询最近标签
 * 6. .task - 异步任务
 * 7. StatusEditor.Assistant - AI 助手
 *
 * 使用场景：
 * - 用户输入 # 符号
 * - AI 分析帖子内容
 * - 智能推荐相关标签
 * - 提高标签使用效率
 *
 * 依赖关系：
 * - DesignSystem: 主题
 * - Models: 标签模型
 * - SwiftData: 数据持久化
 * - StatusEditor.Assistant: AI 助手
 */

import DesignSystem
import EmojiText
import Foundation
import Models
import SwiftData
import SwiftUI

extension StatusEditor.AutoCompleteView {
  /// AI 建议标签视图（iOS 26+）
  ///
  /// 使用 AI 助手生成标签建议。
  ///
  /// 主要功能：
  /// - **AI 生成**：使用系统语言模型生成标签
  /// - **内容分析**：分析帖子内容推荐相关标签
  /// - **加载状态**：显示加载进度
  /// - **快速选择**：点击标签快速插入
  ///
  /// 使用示例：
  /// ```swift
  /// if #available(iOS 26, *) {
  ///   SuggestedTagsView(
  ///     viewModel: viewModel,
  ///     isTagSuggestionExpanded: $isExpanded
  ///   )
  /// }
  /// ```
  ///
  /// - Note: 仅在 iOS 26+ 且 AI 助手可用时使用
  /// - Important: 需要系统语言模型支持
  @available(iOS 26.0, *)
  struct SuggestedTagsView: View {
    /// 视图状态枚举
    ///
    /// 定义 AI 标签生成的不同状态。
    enum ViewState {
      /// 正在加载（生成标签中）
      case loading

      /// 加载完成（标签已生成）
      case loaded(tags: [String])

      /// 加载失败
      case error
    }

    /// 模型上下文（SwiftData）
    @Environment(\.modelContext) private var context

    /// 主题环境
    @Environment(Theme.self) private var theme

    /// AI 助手实例
    private let assistant = StatusEditor.Assistant()

    /// 编辑器 ViewModel
    var viewModel: StatusEditor.ViewModel

    /// 展开状态绑定
    @Binding var isTagSuggestionExpanded: Bool

    /// 视图状态
    @State var viewState: ViewState = .loading

    /// 最近使用的标签查询
    ///
    /// 用于检查标签是否已在最近使用列表中。
    @Query(sort: \RecentTag.lastUse, order: .reverse) var recentTags: [RecentTag]

    var body: some View {
      // 根据视图状态显示不同内容
      switch viewState {
      case .loading:
        // 加载状态：显示进度指示器
        ProgressView()
          .task {
            // 异步生成标签
            viewState = .loaded(
              tags: await assistant.generateTags(from: viewModel.statusText.string).values)
          }

      case .loaded(let tags):
        // 加载完成：显示标签列表
        ForEach(tags, id: \.self) { tag in
          Button {
            withAnimation {
              // 收起展开视图
              isTagSuggestionExpanded = false
              // 插入标签到编辑器
              viewModel.selectHashtagSuggestion(tag: tag)
            }

            // 检查标签是否已在最近使用列表中
            if let index = recentTags.firstIndex(where: {
              $0.title.lowercased() == tag.lowercased()
            }) {
              // 更新已存在标签的使用时间
              recentTags[index].lastUse = Date()
            } else {
              // 处理标签格式（移除 # 前缀）
              var tag = tag
              if tag.first == "#" {
                tag.removeFirst()
              }
              // 添加新标签到最近使用列表
              context.insert(RecentTag(title: tag))
            }
          } label: {
            // 标签文本
            Text(tag)
              .font(.scaledFootnote)
              .fontWeight(.bold)
              .foregroundColor(theme.labelColor)
          }
        }

      case .error:
        // 错误状态：不显示任何内容
        EmptyView()
      }
    }
  }
}

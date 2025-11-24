/*
 * AutoCompleteView.swift
 * IceCubesApp - 自动完成视图
 *
 * 功能描述：
 * 在编辑器中提供自动完成建议
 * 支持提及（@）、标签（#）和最近使用的标签
 *
 * 核心功能：
 * 1. 提及建议 - 显示用户提及建议
 * 2. 标签建议 - 显示标签建议
 * 3. 最近标签 - 显示最近使用的标签
 * 4. AI 建议 - iOS 26+ 支持 AI 生成标签
 * 5. 展开视图 - 显示更多建议
 * 6. 滚动浏览 - 水平滚动查看建议
 *
 * 视图层次：
 * - 主容器（毛玻璃效果/iOS 26+）
 *   - 水平滚动视图
 *     - MentionsView（提及建议）
 *     - SuggestedTagsView（AI 标签建议/iOS 26+）
 *     - RecentTagsView（最近标签）
 *     - RemoteTagsView（远程标签）
 *   - 展开按钮
 *   - ExpandedView（展开视图）
 *
 * 技术点：
 * 1. @MainActor - 主线程操作
 * 2. @Environment - 环境对象注入
 * 3. @State - 展开状态管理
 * 4. @Query - SwiftData 查询
 * 5. @available - iOS 26 特性检测
 * 6. glassEffect - 液态玻璃效果（iOS 26+）
 * 7. LazyHStack - 延迟加载水平堆栈
 * 8. ScrollView - 滚动视图
 *
 * 使用场景：
 * - 输入 @ 时显示用户建议
 * - 输入 # 时显示标签建议
 * - 显示最近使用的标签
 * - AI 辅助生成标签（iOS 26+）
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Models: 数据模型
 * - SwiftData: 数据持久化
 */

import DesignSystem
import EmojiText
import Foundation
import Models
import SwiftData
import SwiftUI

extension StatusEditor {
  /// 自动完成视图
  ///
  /// 在编辑器中提供自动完成建议。
  ///
  /// 主要功能：
  /// - **提及建议**：显示用户提及建议
  /// - **标签建议**：显示标签建议
  /// - **最近标签**：显示最近使用的标签
  /// - **AI 建议**：iOS 26+ 支持 AI 生成标签
  ///
  /// 使用示例：
  /// ```swift
  /// AutoCompleteView(viewModel: viewModel)
  /// ```
  ///
  /// - Note: iOS 26+ 使用液态玻璃效果
  @MainActor
  struct AutoCompleteView: View {
    /// 模型上下文（SwiftData）
    @Environment(\.modelContext) var context

    /// 主题环境
    @Environment(Theme.self) var theme

    /// 编辑器 ViewModel
    var viewModel: ViewModel

    /// 标签建议展开状态
    @State private var isTagSuggestionExpanded: Bool = false

    /// 最近使用的标签查询
    ///
    /// 按最后使用时间倒序排列。
    @Query(sort: \RecentTag.lastUse, order: .reverse) var recentTags: [RecentTag]

    var body: some View {
      // iOS 26+ 使用液态玻璃效果
      if #available(iOS 26, *) {
        contentView
          .padding(.vertical, 8)
          .glassEffect(
            .regular.tint(theme.primaryBackgroundColor.opacity(0.2)),
            in: RoundedRectangle(cornerRadius: 8)
          )
          .padding(.horizontal, 16)
      } else {
        // iOS 25 及以下使用薄材质背景
        contentView
          .background(.thinMaterial)
      }
    }

    /// 内容视图
    ///
    /// 根据建议类型显示不同的视图。
    ///
    /// 显示优先级：
    /// 1. 提及建议（MentionsView）
    /// 2. AI 标签建议（SuggestedTagsView/iOS 26+）
    /// 3. 最近标签（RecentTagsView）
    /// 4. 远程标签（RemoteTagsView）
    @ViewBuilder
    var contentView: some View {
      // 只在有建议时显示
      if !viewModel.mentionsSuggestions.isEmpty || !viewModel.tagsSuggestions.isEmpty
        || viewModel.showRecentsTagsInline
      {
        VStack {
          HStack {
            // 水平滚动建议列表
            ScrollView(.horizontal, showsIndicators: false) {
              LazyHStack {
                // 优先显示提及建议
                if !viewModel.mentionsSuggestions.isEmpty {
                  Self.MentionsView(viewModel: viewModel)
                } else {
                  // iOS 26+ 且 AI 可用时显示 AI 建议
                  if #available(iOS 26, *), Assistant.isAvailable, viewModel.tagsSuggestions.isEmpty
                  {
                    Self.SuggestedTagsView(
                      viewModel: viewModel,
                      isTagSuggestionExpanded: $isTagSuggestionExpanded)
                  } else if viewModel.showRecentsTagsInline {
                    // 显示最近使用的标签
                    Self.RecentTagsView(
                      viewModel: viewModel, isTagSuggestionExpanded: $isTagSuggestionExpanded)
                  } else {
                    // 显示远程标签建议
                    Self.RemoteTagsView(
                      viewModel: viewModel, isTagSuggestionExpanded: $isTagSuggestionExpanded)
                  }
                }
              }
              .padding(.horizontal, .layoutPadding)
            }
            .scrollContentBackground(.hidden)

            // 展开/收起按钮（仅标签建议时显示）
            if viewModel.mentionsSuggestions.isEmpty {
              Spacer()
              Button {
                withAnimation {
                  isTagSuggestionExpanded.toggle()
                }
              } label: {
                Image(
                  systemName: isTagSuggestionExpanded ? "chevron.down.circle" : "chevron.up.circle"
                )
                .padding(.trailing, 8)
              }
            }
          }
          .frame(height: 40)

          // 展开视图（显示更多标签）
          if isTagSuggestionExpanded {
            Self.ExpandedView(
              viewModel: viewModel, isTagSuggestionExpanded: $isTagSuggestionExpanded)
          }
        }
      }
    }
  }
}

/*
 * PollView.swift
 * IceCubesApp - 投票视图组件
 *
 * 功能描述：
 * 在编辑器中创建和编辑投票选项
 * 支持添加、删除选项，设置投票频率和持续时间
 *
 * 核心功能：
 * 1. 选项管理 - 添加、删除投票选项
 * 2. 焦点管理 - 自动聚焦到新添加的选项
 * 3. 投票频率 - 设置单选或多选
 * 4. 持续时间 - 设置投票的有效期
 * 5. 动态限制 - 根据实例配置限制最大选项数
 * 6. iOS 26 适配 - 使用 Liquid Glass 效果
 * 7. 键盘提交 - 按回车添加新选项
 * 8. 自动关闭 - 删除到只剩一个选项时自动关闭
 *
 * 技术点：
 * 1. @MainActor - 确保 UI 操作在主线程
 * 2. @FocusState - 管理输入框焦点
 * 3. @State - 本地状态管理
 * 4. @Environment - 环境依赖注入
 * 5. @Binding - 双向数据绑定
 * 6. @Bindable - 绑定 ViewModel
 * 7. ForEach - 遍历选项
 * 8. Picker - 选择器组件
 * 9. 条件编译 - iOS 26+ 使用 glassEffect
 * 10. 动画 - withAnimation
 *
 * 视图层次：
 * - VStack（主容器）
 *   - ForEach（遍历选项）
 *     - HStack（选项行）
 *       - TextField（选项输入框）
 *       - Button（添加/删除按钮）
 *   - HStack（设置行）
 *     - Picker（投票频率）
 *     - Picker（持续时间）
 *
 * 焦点管理：
 * - 使用 FocusField 枚举标识不同的输入框
 * - 添加新选项时自动聚焦
 * - 使用 DispatchQueue 延迟聚焦以确保视图更新
 *
 * 选项限制：
 * - 最少 2 个选项
 * - 最多由实例配置决定（默认 4 个）
 * - 最后一个选项显示添加按钮
 * - 其他选项显示删除按钮
 *
 * 使用场景：
 * - 创建新投票
 * - 编辑投票选项
 * - 设置投票参数
 *
 * 依赖关系：
 * - DesignSystem: 主题和样式
 * - Env: 环境对象
 */

import DesignSystem
import Env
import SwiftUI

extension StatusEditor {
  /// 投票视图
  ///
  /// 在编辑器中创建和编辑投票。
  ///
  /// 主要功能：
  /// - **选项管理**：添加、删除投票选项
  /// - **焦点管理**：自动聚焦到新添加的选项
  /// - **投票设置**：设置投票频率和持续时间
  /// - **动态限制**：根据实例配置限制最大选项数
  ///
  /// 使用示例：
  /// ```swift
  /// PollView(
  ///     viewModel: viewModel,
  ///     showPoll: $showPoll
  /// )
  /// ```
  ///
  /// - Note: 所有 UI 操作必须在主线程执行（@MainActor）
  /// - Important: 最少需要 2 个选项，最多由实例配置决定
  @MainActor
  struct PollView: View {
    /// 焦点字段枚举
    ///
    /// 标识不同的输入框。
    enum FocusField: Hashable {
      /// 选项输入框（携带索引）
      case option(Int)
    }

    /// 当前聚焦的字段
    @FocusState var focused: FocusField?

    /// 当前焦点索引
    @State private var currentFocusIndex: Int = 0

    /// 主题设置
    @Environment(Theme.self) private var theme
    /// 当前实例信息
    @Environment(CurrentInstance.self) private var currentInstance

    /// 编辑器 ViewModel
    var viewModel: ViewModel

    /// 是否显示投票视图
    @Binding var showPoll: Bool

    var body: some View {
      if #available(iOS 26.0, *) {
        contentView
          .glassEffect(
            .regular.tint(theme.tintColor.opacity(0.1)),
            in: RoundedRectangle(cornerRadius: 6))
      } else {
        contentView
          .background(
            RoundedRectangle(cornerRadius: 6.0)
              .stroke(theme.secondaryBackgroundColor.opacity(0.6), lineWidth: 1)
              .background(theme.primaryBackgroundColor.opacity(0.3))
          )
      }
    }

    @ViewBuilder
    private var contentView: some View {
      @Bindable var viewModel = viewModel
      let count = viewModel.pollOptions.count
      VStack {
        ForEach(0..<count, id: \.self) { index in
          VStack {
            HStack(spacing: 16) {
              TextField("status.poll.option-n \(index + 1)", text: $viewModel.pollOptions[index])
                .textFieldStyle(.roundedBorder)
                .focused($focused, equals: .option(index))
                .onTapGesture {
                  if canAddMoreAt(index) {
                    currentFocusIndex = index
                  }
                }
                .onSubmit {
                  if canAddMoreAt(index) {
                    addChoice(at: index)
                  }
                }

              if canAddMoreAt(index) {
                Button {
                  addChoice(at: index)
                } label: {
                  Image(systemName: "plus.circle.fill")
                }
              } else {
                Button {
                  removeChoice(at: index)
                } label: {
                  Image(systemName: "minus.circle.fill")
                }
              }
            }
            .padding(.horizontal)
            .padding(.top)
          }
        }
        .onAppear {
          focused = .option(0)
        }

        HStack {
          Picker("status.poll.frequency", selection: $viewModel.pollVotingFrequency) {
            ForEach(PollVotingFrequency.allCases, id: \.rawValue) {
              Text($0.displayString)
                .tag($0)
            }
          }
          .layoutPriority(1.0)

          Spacer()

          Picker("status.poll.duration", selection: $viewModel.pollDuration) {
            ForEach(Duration.pollDurations(), id: \.rawValue) {
              Text($0.description)
                .tag($0)
            }
          }
        }
        .padding(.leading, 9)
        .padding(.trailing, 34)
        .padding(.vertical, 8)
      }
    }

    /// 添加选项
    ///
    /// 在指定索引后添加新的投票选项，并自动聚焦。
    ///
    /// - Parameter index: 当前选项的索引
    private func addChoice(at index: Int) {
      viewModel.pollOptions.append("")
      currentFocusIndex = index + 1
      moveFocus()
    }

    /// 删除选项
    ///
    /// 删除指定索引的投票选项。
    /// 如果只剩一个选项，自动关闭投票视图。
    ///
    /// - Parameter index: 要删除的选项索引
    private func removeChoice(at index: Int) {
      viewModel.pollOptions.remove(at: index)

      if viewModel.pollOptions.count == 1 {
        viewModel.resetPollDefaults()

        withAnimation {
          showPoll = false
        }
      }
    }

    /// 移动焦点
    ///
    /// 延迟移动焦点到指定的输入框，确保视图已更新。
    private func moveFocus() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        focused = .option(currentFocusIndex)
      }
    }

    /// 检查是否可以添加更多选项
    ///
    /// 判断指定索引是否是最后一个选项，且未达到最大选项数。
    ///
    /// - Parameter index: 选项索引
    /// - Returns: 如果可以添加更多选项返回 true
    private func canAddMoreAt(_ index: Int) -> Bool {
      let count = viewModel.pollOptions.count
      let maxEntries: Int = currentInstance.instance?.configuration?.polls.maxOptions ?? 4

      return index == count - 1 && count < maxEntries
    }
  }
}

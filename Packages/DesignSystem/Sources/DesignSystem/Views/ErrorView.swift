/*
 * ErrorView.swift
 * IceCubesApp - 错误展示视图组件
 *
 * 功能描述：
 * 提供一个标准化的错误信息展示界面，用于显示加载失败、网络错误等异常情况
 * 包含错误图标、标题、详细描述和重试按钮，提供统一的错误处理用户体验
 *
 * 技术点：
 * 1. 异步回调处理 - @escaping 异步闭包和 Task 包装
 * 2. SF Symbols 系统图标 - exclamationmark.triangle.fill 警告图标
 * 3. 可缩放字体系统 - .scaledTitle 和 .scaledSubheadline 字体
 * 4. SwiftUI 布局系统 - HStack、VStack、Spacer 的组合使用
 * 5. 按钮样式系统 - .bordered 系统按钮样式
 * 6. 本地化支持 - LocalizedStringKey 多语言字符串
 * 7. 颜色系统 - .secondary 语义化颜色
 * 8. 布局边距 - .layoutPadding 自适应边距
 * 9. #Preview 预览 - Xcode 15+ 的新预览语法
 *
 * 技术点详解：
 * - 异步回调处理：使用 @escaping 修饰异步闭包，通过 Task 包装确保在正确的上下文中执行
 * - SF Symbols：使用系统提供的警告图标，支持动态大小和主题适配
 * - 可缩放字体系统：使用自定义的可缩放字体，支持用户字体大小偏好设置
 * - SwiftUI 布局系统：通过 HStack 和 VStack 实现居中布局，Spacer 提供弹性空间
 * - 按钮样式系统：使用系统预定义的边框按钮样式，保持界面一致性
 * - 本地化支持：支持多语言界面，字符串可根据用户设备语言自动切换
 * - 颜色系统：使用语义化颜色，自动适应明暗主题
 * - 布局边距：使用系统定义的布局边距，确保在不同设备上的一致性
 * - #Preview：提供组件预览功能，便于开发时快速查看效果
 */

// 导入 SwiftUI 框架，提供视图构建和用户界面组件
import SwiftUI

// 定义公共的错误视图结构体，用于显示错误信息和重试功能
public struct ErrorView: View {
  // 存储错误标题的本地化字符串键
  public let title: LocalizedStringKey
  // 存储错误详细信息的本地化字符串键
  public let message: LocalizedStringKey
  // 存储按钮标题的本地化字符串键
  public let buttonTitle: LocalizedStringKey
  // 存储按钮点击时执行的异步回调闭包
  public let onButtonPress: () async -> Void

  // 公共初始化方法，创建错误视图实例
  public init(
    title: LocalizedStringKey, message: LocalizedStringKey, buttonTitle: LocalizedStringKey,
    onButtonPress: @escaping (() async -> Void)
  ) {
    // 设置错误标题
    self.title = title
    // 设置错误详细信息
    self.message = message
    // 设置按钮标题
    self.buttonTitle = buttonTitle
    // 设置按钮点击回调，使用 @escaping 允许闭包在函数返回后继续存在
    self.onButtonPress = onButtonPress
  }

  // 视图主体，定义错误展示的 UI 结构
  public var body: some View {
    // 水平布局容器，实现居中对齐
    HStack {
      // 左侧弹性空间
      Spacer()
      // 垂直布局容器，包含错误内容
      VStack {
        // 警告图标，使用 SF Symbols 系统图标
        Image(systemName: "exclamationmark.triangle.fill")
          // 设置为可调整大小
          .resizable()
          // 保持宽高比，适应内容
          .aspectRatio(contentMode: .fit)
          // 限制最大高度为 50 点
          .frame(maxHeight: 50)
        // 错误标题文本
        Text(title)
          // 使用可缩放的标题字体
          .font(.scaledTitle)
          // 添加顶部边距
          .padding(.top, 16)
        // 错误详细信息文本
        Text(message)
          // 使用可缩放的副标题字体
          .font(.scaledSubheadline)
          // 设置多行文本居中对齐
          .multilineTextAlignment(.center)
          // 设置为次要文本颜色
          .foregroundStyle(.secondary)
        // 重试按钮
        Button {
          // 创建 Task 来执行异步操作
          Task {
            // 调用异步回调闭包
            await onButtonPress()
          }
        } label: {
          // 按钮标题
          Text(buttonTitle)
        }
        // 应用边框按钮样式
        .buttonStyle(.bordered)
        // 添加顶部边距
        .padding(.top, 16)
      }
      // 添加顶部边距，将内容向下推移
      .padding(.top, 100)
      // 添加布局边距
      .padding(.layoutPadding)
      // 右侧弹性空间
      Spacer()
    }
  }
}

// 使用 Xcode 15+ 的新预览语法定义预览
#Preview {
  // 创建预览用的错误视图实例
  ErrorView(
    // 设置错误标题
    title: "Error",
    // 设置错误信息
    message: "Error loading. Please try again",
    // 设置按钮标题
    buttonTitle: "Retry"
  ) {
    // 空的异步回调，用于预览
  }
}

/*
 * PlaceholderView.swift
 * IceCubesApp - 占位符视图组件
 *
 * 功能描述：
 * 提供一个标准化的空状态展示视图，用于在没有内容、加载失败或数据为空时显示给用户
 * 使用 iOS 17+ 的 ContentUnavailableView 来创建符合系统设计规范的占位符界面
 *
 * 技术点：
 * 1. ContentUnavailableView - iOS 17+ 引入的系统级空状态视图组件
 * 2. LocalizedStringKey - SwiftUI 的本地化字符串键类型
 * 3. SF Symbols - 系统图标符号系统
 * 4. #Preview - Xcode 15+ 的新预览语法
 * 5. View 协议 - SwiftUI 视图协议
 * 6. 无障碍支持 - 系统自动处理语音朗读
 * 7. 自适应设计 - 支持不同屏幕尺寸和方向
 *
 * 技术点详解：
 * - ContentUnavailableView：iOS 17 引入的系统级空状态视图，提供标准化的无内容展示界面，包含图标、标题和描述文本
 * - LocalizedStringKey：SwiftUI 的本地化字符串类型，支持自动本地化和字符串插值，便于多语言支持
 * - SF Symbols：苹果的矢量图标系统，提供数千个可缩放的系统图标，支持多种样式和权重
 * - #Preview：Xcode 15 引入的新预览宏语法，替代了之前的 PreviewProvider 协议
 * - View 协议：SwiftUI 的核心视图协议，定义了可显示的 UI 组件
 * - 无障碍支持：ContentUnavailableView 自动支持 VoiceOver 等无障碍功能
 * - 自适应设计：视图自动适应不同设备和屏幕尺寸，支持 Dynamic Type 字体缩放
 */

// 导入 SwiftUI 框架，提供视图构建和用户界面组件
import SwiftUI

// 定义公共的占位符视图结构体，用于显示空状态或无内容状态
public struct PlaceholderView: View {
  // 存储要显示的 SF Symbols 图标名称
  public let iconName: String
  // 存储标题文本的本地化字符串键
  public let title: LocalizedStringKey
  // 存储描述信息的本地化字符串键
  public let message: LocalizedStringKey

  // 公共初始化方法，用于创建占位符视图实例
  public init(iconName: String, title: LocalizedStringKey, message: LocalizedStringKey) {
    // 设置图标名称
    self.iconName = iconName
    // 设置标题文本
    self.title = title
    // 设置描述消息
    self.message = message
  }

  // 视图主体，定义占位符的 UI 结构
  public var body: some View {
    // 使用 iOS 17+ 的 ContentUnavailableView 创建标准化的空状态视图
    ContentUnavailableView(
      // 设置标题文本
      title,
      // 设置系统图标
      systemImage: iconName,
      // 设置描述文本
      description: Text(message))
  }
}

// 使用 Xcode 15+ 的新预览语法定义预览
#Preview {
  // 创建预览用的占位符视图实例
  PlaceholderView(
    // 使用 SF Symbols 中的上传失败图标
    iconName: "square.and.arrow.up.trianglebadge.exclamationmark",
    // 设置标题为"Nothing to see"
    title: "Nothing to see",
    // 设置描述消息
    message: "This is a preview. Please try again.")
}

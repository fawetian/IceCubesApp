// 文件功能说明：
// 该文件定义了时间线头部视图的通用容器组件，为不同类型的时间线提供一致的头部样式和布局，支持多平台（iOS、visionOS）的不同视觉效果。
// 技术点：
// 1. SwiftUI 泛型视图（Generic View）—— 使用 Content: View 泛型参数，支持任意内容。
// 2. @Environment 属性包装器 —— 从环境中获取主题配置。
// 3. ViewBuilder 闭包 —— 支持 SwiftUI 声明式语法构建内容。
// 4. 条件编译（#if os(visionOS)）—— 为不同平台提供特定的视觉效果。
// 5. 列表行定制化 —— 自定义列表行的背景、分隔符、内边距等。
// 6. VStack 垂直布局 —— 使用 Spacer 创建垂直居中效果。
// 7. 平台特定设计 —— visionOS 使用圆角矩形和悬停效果。
// 8. 布局边距（layoutPadding）—— 使用系统定义的布局边距。
// 9. 列表样式定制 —— 隐藏分隔符，自定义内边距。
// 10. 主题系统集成 —— 根据当前主题设置背景色。
//
// 技术点详解：
// - SwiftUI 泛型视图：通过泛型参数 Content: View 实现组件的通用性，可以包装任意 SwiftUI 视图
// - @Environment 属性包装器：从环境对象中获取主题配置，实现主题的全局传递和更新
// - ViewBuilder 闭包：允许使用 SwiftUI 的声明式语法在闭包内构建视图层次结构
// - 条件编译：使用 #if os(visionOS) 为 Apple Vision Pro 提供特殊的视觉效果
// - 列表行定制化：通过修饰符自定义列表行的外观，包括背景、分隔符、内边距等
// - VStack 布局：使用 Spacer() 在上下添加可伸缩空间，实现内容的垂直居中
// - 平台特定设计：visionOS 使用圆角矩形背景和悬停效果，其他平台使用主题背景色
// - 布局边距：使用 .layoutPadding 获取系统推荐的布局边距值
// - 列表样式：隐藏列表分隔符，自定义内边距以符合设计要求

// 引入设计系统模块，包含主题和视觉组件
import DesignSystem
// 引入 SwiftUI 框架
import SwiftUI

// 定义时间线头部视图的通用容器组件
struct TimelineHeaderView<Content: View>: View {
  // 从环境中获取当前主题配置
  @Environment(Theme.self) private var theme

  // 内容构建闭包，支持任意 SwiftUI 视图
  var content: () -> Content

  // 视图主体
  var body: some View {
    // 垂直堆栈布局，左对齐
    VStack(alignment: .leading) {
      // 上方可伸缩空间，用于垂直居中
      Spacer()
      // 执行内容构建闭包，插入自定义内容
      content()
      // 下方可伸缩空间，用于垂直居中
      Spacer()
    }
    #if os(visionOS)
      // visionOS 平台特定样式：使用圆角矩形背景和悬停效果
      .listRowBackground(
        RoundedRectangle(cornerRadius: 8)
          .foregroundStyle(.background).hoverEffect()
      )
      // 禁用列表行的悬停效果（因为已经在背景上添加了）
      .listRowHoverEffectDisabled()
    #else
      // 其他平台：使用主题的次要背景色
      .listRowBackground(theme.secondaryBackgroundColor)
    #endif
    // 隐藏列表行分隔符
    .listRowSeparator(.hidden)
    // 设置列表行的内边距
    .listRowInsets(
      .init(
        top: 8,  // 上边距 8pt
        leading: .layoutPadding,  // 左边距使用系统布局边距
        bottom: 8,  // 下边距 8pt
        trailing: .layoutPadding)  // 右边距使用系统布局边距
    )
  }
}

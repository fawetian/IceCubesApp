// 文件功能：标签列表视图，展示趋势标签的列表界面，支持不同平台的样式适配。
// 相关技术点：
// - List + ForEach：列表渲染模式。
// - 平台条件编译：#if !os(visionOS) 针对不同平台优化。
// - @Environment：主题环境依赖。
// - NavigationTitle：导航标题配置。
// - ListStyle：列表样式定制。
// - 背景定制：scrollContentBackground + background 组合。
// - Padding：内边距调整。
// - 组件复用：TagRowView 单行组件。
//
// 技术点详解：
// 1. List：SwiftUI 列表容器组件。
// 2. ForEach：遍历数据源渲染视图。
// 3. 条件编译：#if !os(visionOS) 平台特定代码。
// 4. listRowBackground：列表行背景色设置。
// 5. scrollContentBackground(.hidden)：隐藏默认滚动背景。
// 6. listStyle：设置列表样式（plain vs grouped）。
// 7. navigationBarTitleDisplayMode：标题显示模式。
// 8. Environment 依赖：获取共享主题配置。
// 导入设计系统，主题配置等
import DesignSystem
// 导入数据模型，Tag 等类型
import Models
// 导入 SwiftUI 框架
import SwiftUI

// 标签列表视图，显示趋势标签的列表
public struct TagsListView: View {
  // 环境值：应用主题配置
  @Environment(Theme.self) private var theme

  // 要显示的标签数组
  let tags: [Tag]

  // 初始化标签列表视图
  public init(tags: [Tag]) {
    self.tags = tags
  }

  // 视图主体
  public var body: some View {
    // 列表容器
    List {
      // 遍历标签数组
      ForEach(tags) { tag in
        // 单个标签行视图
        TagRowView(tag: tag)
          // 非 visionOS 平台设置行背景
          #if !os(visionOS)
            .listRowBackground(theme.primaryBackgroundColor)
          #endif
          // 垂直内边距
          .padding(.vertical, 4)
      }
    }
    // 平台特定的列表样式配置
    #if !os(visionOS)
      // 隐藏默认滚动背景
      .scrollContentBackground(.hidden)
      // 设置自定义背景色
      .background(theme.primaryBackgroundColor)
      // 使用简洁列表样式
      .listStyle(.plain)
    #else
      // visionOS 使用分组样式
      .listStyle(.grouped)
    #endif
    // 导航标题
    .navigationTitle("explore.section.trending.tags")
    // 内联标题显示模式
    .navigationBarTitleDisplayMode(.inline)
  }
}

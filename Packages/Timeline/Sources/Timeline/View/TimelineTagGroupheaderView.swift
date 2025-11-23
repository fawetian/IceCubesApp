// 文件功能说明：
// 该文件定义了时间线标签组头部视图，用于显示标签组时间线的头部信息，包括标签列表的水平滚动展示和编辑按钮，支持标签导航和标签组编辑功能。
// 技术点：
// 1. SwiftUI 绑定（@Binding）—— 双向数据绑定，与父视图共享状态。
// 2. @Environment 环境对象 —— 获取路由路径对象用于页面导航。
// 3. 条件渲染（if let）—— 基于可选值的条件视图显示。
// 4. ScrollView 水平滚动 —— 标签列表的水平滚动展示。
// 5. ForEach 动态列表 —— 动态生成标签按钮列表。
// 6. Button 交互组件 —— 标签导航和编辑功能按钮。
// 7. HStack 水平布局 —— 水平排列标签和编辑按钮。
// 8. 字体缩放（scaledHeadline）—— 支持动态类型的字体。
// 9. 表单样式（.bordered）—— 使用边框按钮样式。
// 10. 模态表单（presentedSheet）—— 弹出编辑标签组的模态视图。
//
// 技术点详解：
// - SwiftUI 绑定：使用 @Binding 实现父子视图间的双向数据同步
// - @Environment 环境对象：从环境中获取 RouterPath 对象，用于统一的页面导航管理
// - 条件渲染：使用 if let 语法安全地处理可选值，只在有数据时显示内容
// - ScrollView 水平滚动：提供标签列表的水平滚动功能，适应不同屏幕尺寸
// - ForEach 动态列表：根据标签数组动态生成按钮，每个标签都有独立的点击事件
// - Button 交互：提供标签导航和编辑功能，使用不同的按钮样式
// - HStack 布局：水平排列标签滚动区域和编辑按钮
// - 字体缩放：使用 scaledHeadline 支持 iOS 的动态类型功能
// - 表单样式：使用 .bordered 样式为编辑按钮提供视觉边界
// - 模态表单：通过 presentedSheet 展示标签组编辑界面

// 引入环境配置模块，包含路由和状态管理
import Env
// 引入数据模型模块，包含标签组等数据结构
import Models
// 引入 SwiftUI 框架
import SwiftUI

// 定义时间线标签组头部视图
struct TimelineTagGroupheaderView: View {
  // 从环境中获取路由路径对象，用于页面导航
  @Environment(RouterPath.self) private var routerPath

  // 绑定标签组对象，与父视图双向同步
  @Binding var group: TagGroup?
  // 绑定时间线过滤器，用于更新时间线状态
  @Binding var timeline: TimelineFilter

  // 视图主体
  var body: some View {
    // 如果存在标签组数据
    if let group {
      // 使用时间线头部视图容器
      TimelineHeaderView {
        // 水平布局：标签列表和编辑按钮
        HStack {
          // 水平滚动视图，显示标签列表
          ScrollView(.horizontal) {
            // 水平堆栈布局，标签间距 4pt
            HStack(spacing: 4) {
              // 遍历标签组中的所有标签
              ForEach(group.tags, id: \.self) { tag in
                // 标签按钮，点击导航到标签页面
                Button {
                  // 导航到指定标签的时间线页面
                  routerPath.navigate(to: .hashTag(tag: tag, account: nil))
                } label: {
                  // 显示标签文本，使用 # 前缀
                  Text("#\(tag)")
                    .font(.scaledHeadline)  // 使用可缩放的标题字体
                }
                .buttonStyle(.plain)  // 使用简单按钮样式
              }
            }
          }
          // 隐藏滚动指示器
          .scrollIndicators(.hidden)

          // 编辑按钮，用于编辑标签组
          Button("status.action.edit") {
            // 弹出编辑标签组的模态视图
            routerPath.presentedSheet = .editTagGroup(
              tagGroup: group,
              onSaved: { group in
                // 保存回调：更新时间线过滤器为新的标签组
                timeline = .tagGroup(
                  title: group.title,
                  tags: group.tags,
                  symbolName: group.symbolName
                )
              }
            )
          }
          .buttonStyle(.bordered)  // 使用边框按钮样式
        }
      }
    }
  }
}

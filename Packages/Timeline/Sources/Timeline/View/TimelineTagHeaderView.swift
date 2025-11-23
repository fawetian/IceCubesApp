// 文件功能说明：
// 该文件定义了时间线标签头部视图，用于显示单个标签时间线的头部信息，包括标签图表、标签统计信息和关注/取消关注按钮，提供标签的详细展示和交互功能。
// 技术点：
// 1. SwiftUI 绑定（@Binding）—— 双向数据绑定标签对象。
// 2. @Environment 环境对象 —— 获取当前账户对象用于标签操作。
// 3. @State 状态管理 —— 管理加载状态。
// 4. 条件渲染（if let）—— 基于可选值的条件视图显示。
// 5. Task 异步任务 —— 处理标签关注/取消关注的异步操作。
// 6. TagChartView 自定义组件 —— 显示标签趋势图表。
// 7. VStack/HStack 布局 —— 垂直和水平布局组合。
// 8. 字体缩放系统 —— 支持动态类型的字体。
// 9. 辅助功能（accessibility）—— 支持 VoiceOver 等辅助功能。
// 10. 按钮状态管理 —— 根据操作状态禁用按钮。
//
// 技术点详解：
// - SwiftUI 绑定：使用 @Binding 与父视图共享标签数据状态
// - @Environment 环境对象：从环境中获取 CurrentAccount 对象，用于标签关注操作
// - @State 状态管理：使用本地状态管理加载状态，防止重复操作
// - 条件渲染：使用 if let 安全地处理可选的标签对象
// - Task 异步任务：使用 Swift 并发处理网络请求，支持 async/await
// - TagChartView 组件：显示标签的使用趋势图表，提供可视化数据
// - 布局系统：使用 VStack 和 HStack 组合实现复杂的布局结构
// - 字体缩放：使用 scaledHeadline 和 scaledFootnote 支持用户字体大小偏好
// - 辅助功能：使用 accessibilityElement 组合多个文本元素为单一的可访问元素
// - 按钮状态：根据加载状态禁用按钮，提供良好的用户体验

// 引入设计系统模块，包含标签图表组件
import DesignSystem
// 引入环境配置模块，包含当前账户状态
import Env
// 引入数据模型模块，包含标签数据结构
import Models
// 引入 SwiftUI 框架
import SwiftUI

// 定义时间线标签头部视图
struct TimelineTagHeaderView: View {
  // 从环境中获取当前账户对象，用于标签关注操作
  @Environment(CurrentAccount.self) private var account

  // 绑定标签对象，与父视图双向同步
  @Binding var tag: Tag?

  // 管理加载状态，防止重复操作
  @State var isLoading: Bool = false

  // 视图主体
  var body: some View {
    // 如果存在标签数据
    if let tag {
      // 使用时间线头部视图容器
      TimelineHeaderView {
        // 水平布局：图表、信息和关注按钮
        HStack {
          // 标签趋势图表组件
          TagChartView(tag: tag)
            .padding(.top, 12)  // 顶部内边距 12pt

          // 垂直布局：标签信息
          VStack(alignment: .leading, spacing: 4) {
            // 标签名称，使用 # 前缀
            Text("#\(tag.name)")
              .font(.scaledHeadline)  // 使用可缩放的标题字体

            // 标签统计信息：总使用次数和参与用户数
            Text("timeline.n-recent-from-n-participants \(tag.totalUses) \(tag.totalAccounts)")
              .font(.scaledFootnote)  // 使用可缩放的脚注字体
              .foregroundStyle(.secondary)  // 次要文字颜色
          }
          // 将标签名称和统计信息组合为单一的可访问元素
          .accessibilityElement(children: .combine)

          // 可伸缩空间，将关注按钮推到右侧
          Spacer()

          // 关注/取消关注按钮
          Button {
            // 异步任务处理标签关注操作
            Task {
              // 设置加载状态为 true
              isLoading = true

              // 根据当前关注状态执行相应操作
              if tag.following {
                // 如果已关注，则取消关注
                self.tag = await account.unfollowTag(id: tag.name)
              } else {
                // 如果未关注，则关注标签
                self.tag = await account.followTag(id: tag.name)
              }

              // 操作完成，恢复加载状态
              isLoading = false
            }
          } label: {
            // 根据关注状态显示不同的按钮文字
            Text(tag.following ? "account.follow.following" : "account.follow.follow")
          }
          .disabled(isLoading)  // 加载时禁用按钮
          .buttonStyle(.bordered)  // 使用边框按钮样式
        }
      }
    }
  }
}

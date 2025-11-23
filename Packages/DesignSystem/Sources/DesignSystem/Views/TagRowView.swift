// 文件功能说明：
// 该文件实现了标签行视图组件，用于在列表中显示单个Mastodon标签的信息，包括标签名称、使用统计和趋势图表，支持点击导航到标签详情页面。

// 技术点：
// 1. @Environment环境值 —— 获取路由路径管理器
// 2. 响应式布局 —— HStack和VStack组合布局
// 3. 可缩放字体 —— .scaledHeadline和.scaledFootnote
// 4. 语义化颜色 —— .secondary次要文本颜色
// 5. 字符串插值 —— 本地化字符串中的变量插入
// 6. Spacer弹性布局 —— 自动填充剩余空间
// 7. contentShape点击区域 —— 扩展整个行的点击区域
// 8. onTapGesture手势 —— 处理点击事件
// 9. RouterPath导航 —— 程序化页面导航
// 10. 组件组合 —— TagChartView图表组件集成

// 技术点详解：
// 1. @Environment：SwiftUI环境系统，用于访问应用级别的共享数据和服务
// 2. 响应式布局：使用HStack水平布局和VStack垂直布局创建灵活的界面结构
// 3. 可缩放字体：支持用户字体大小偏好设置的动态字体系统
// 4. 语义化颜色：使用系统定义的语义颜色，自动适应明暗主题
// 5. 字符串插值：在本地化字符串中插入动态数据，支持多语言格式化
// 6. Spacer：SwiftUI布局组件，自动占用可用空间实现元素间的对齐
// 7. contentShape：定义视图的点击区域形状，扩展到整个矩形区域
// 8. onTapGesture：SwiftUI手势识别器，处理用户的点击交互
// 9. RouterPath：应用的导航管理系统，控制页面跳转和路由状态
// 10. 组件组合：将多个子组件组合成复杂的UI，实现功能模块化

// 导入Env模块，提供路由和环境管理功能
import Env
// 导入Models模块，提供Tag数据模型定义
import Models
// 导入SwiftUI框架，提供视图构建功能
import SwiftUI

// 定义公共的标签行视图，用于在列表中显示标签信息
public struct TagRowView: View {
  // 从环境中获取路由路径管理器，用于页面导航
  @Environment(RouterPath.self) private var routerPath

  // 存储要显示的标签数据
  let tag: Tag

  // 公共初始化方法，创建标签行视图实例
  public init(tag: Tag) {
    // 设置标签数据
    self.tag = tag
  }

  // 视图主体，定义标签行的UI结构
  public var body: some View {
    // 水平布局容器，包含标签信息和图表
    HStack {
      // 垂直布局，左对齐显示标签文本信息
      VStack(alignment: .leading) {
        // 标签名称，带#号前缀
        Text("#\(tag.name)")
          // 使用可缩放的标题字体
          .font(.scaledHeadline)
        // 标签使用统计信息，显示总使用次数和参与用户数
        Text("design.tag.n-posts-from-n-participants \(tag.totalUses) \(tag.totalAccounts)")
          // 使用可缩放的脚注字体
          .font(.scaledFootnote)
          // 设置为次要文本颜色（较淡的灰色）
          .foregroundStyle(.secondary)
      }
      // 弹性空间，将标签信息推到左侧，图表推到右侧
      Spacer()
      // 标签趋势图表组件
      TagChartView(tag: tag)
    }
    // 设置内容形状为矩形，扩展点击区域到整行
    .contentShape(Rectangle())
    // 添加点击手势处理
    .onTapGesture {
      // 导航到标签详情页面，传入标签名称，不指定特定账户
      routerPath.navigate(to: .hashTag(tag: tag.name, account: nil))
    }
  }
}

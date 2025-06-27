// 文件功能说明：
// 该文件实现了关闭工具栏项组件，为导航栏提供图标化的关闭按钮，使用X圆圈图标提供直观的关闭操作界面。

// 技术点：
// 1. ToolbarContent协议 —— SwiftUI工具栏内容定义
// 2. @Environment环境值 —— 获取dismiss关闭函数
// 3. SF Symbols图标 —— xmark.circle系统图标
// 4. Button构造器 —— action和label分离的按钮构建
// 5. keyboardShortcut —— 键盘快捷键支持
// 6. Image系统图标 —— systemName图标引用
// 7. ToolbarItem位置 —— navigationBarLeading左侧放置
// 8. dismiss函数 —— SwiftUI模态视图关闭机制
// 9. .cancelAction —— 系统预定义的取消快捷键
// 10. 图标语义化 —— 使用通用的关闭符号

// 技术点详解：
// 1. ToolbarContent：SwiftUI协议，定义可放置在工具栏中的内容元素
// 2. @Environment(\.dismiss)：SwiftUI环境值，提供关闭当前呈现的视图的功能
// 3. SF Symbols：苹果的矢量图标系统，xmark.circle表示带圆圈的X关闭图标
// 4. Button构造器：使用action和label参数分别定义按钮行为和外观
// 5. keyboardShortcut：为按钮添加键盘快捷键，提升可访问性和用户体验
// 6. Image系统图标：通过systemName参数引用SF Symbols中的系统图标
// 7. ToolbarItem位置：指定工具栏项在导航栏左侧的具体位置
// 8. dismiss函数：SwiftUI提供的关闭机制，用于关闭模态呈现的视图
// 9. .cancelAction：系统预定义的取消快捷键（通常是Esc键）
// 10. 图标语义化：使用国际通用的X符号表示关闭操作，提供直观的用户体验

// 导入SwiftUI框架，提供工具栏、按钮和图标组件
import SwiftUI

// 定义公共的关闭工具栏项，提供图标化的关闭按钮功能
public struct CloseToolbarItem: ToolbarContent {
  // 从环境中获取dismiss函数，用于关闭当前视图
  @Environment(\.dismiss) private var dismiss

  // 公共初始化方法，创建关闭工具栏项实例
  public init() {}

  // ToolbarContent协议要求的主体属性，定义工具栏项内容
  public var body: some ToolbarContent {
    // 创建工具栏项，放置在导航栏左侧
    ToolbarItem(placement: .navigationBarLeading) {
      // 关闭按钮，使用action和label分离的构造方式
      Button(
        action: {
          // 按钮点击时执行dismiss关闭操作
          dismiss()
        },
        label: {
          // 按钮标签：使用带圆圈的X关闭图标
          Image(systemName: "xmark.circle")
        }
      )
      // 添加键盘快捷键支持，使用系统标准的取消快捷键（Esc）
      .keyboardShortcut(.cancelAction)
    }
  }
}

// 文件功能：条件修饰符扩展，为 View 添加条件性应用修饰符的便捷方法。
// 相关技术点：
// - Extension：扩展现有类型的功能。
// - @ViewBuilder：视图构建器，支持条件性视图构建。
// - 泛型约束：Content 必须遵循 View 协议。
// - 反引号标识符：使用关键字作为方法名。
// - 高阶函数：transform 参数是一个转换函数。
// - some View：不透明类型，隐藏具体返回类型。
//
// 技术点详解：
// 1. @ViewBuilder：允许在函数中使用 if-else 构建视图。
// 2. `if`：使用反引号允许关键字作为标识符。
// 3. (Self) -> Content：闭包类型，接受 Self 返回 Content。
// 4. some View：编译器推断的具体视图类型。
// 5. 条件修饰符：根据条件决定是否应用修饰符的模式。
// 导入 SwiftUI 框架
import SwiftUI

// 扩展 View 协议，添加条件性修饰符功能
extension View {
  // 条件修饰符方法，根据条件决定是否应用转换
  @ViewBuilder public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content)
    -> some View
  {
    // 如果条件为真，应用转换
    if condition {
      transform(self)
    } else {
      // 否则返回原视图
      self
    }
  }
}

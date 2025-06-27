/*
 * EditorFocusState.swift
 * IceCubesApp - 编辑器焦点状态
 *
 * 功能描述：
 * 定义状态编辑器中不同输入区域的焦点状态枚举
 * 配合 SwiftUI @FocusState 属性包装器管理键盘焦点和输入状态
 *
 * 技术点：
 * 1. Hashable 协议 - 枚举遵循哈希协议
 * 2. 关联值 - followUp 携带 UUID 参数
 * 3. SwiftUI @FocusState - 焦点状态管理
 * 4. 枚举嵌套 - 在命名空间中定义类型
 * 5. UUID 唯一标识 - 区分不同输入框
 * 6. 焦点管理 - 键盘显示和隐藏控制
 * 7. 状态区分 - 主输入框和后续输入框
 * 8. 类型安全 - 编译时焦点状态检查
 * 9. 扩展设计 - 为 StatusEditor 添加类型
 * 10. 现代SwiftUI - 使用最新的焦点管理API
 *
 * 技术点详解：
 * - Hashable：提供哈希值计算能力，支持快速查找和比较
 * - 关联值：枚举情况可以携带额外的数据，用于区分不同实例
 * - UUID：全局唯一标识符，确保每个后续帖子输入框有独特标识
 * - @FocusState：SwiftUI 的焦点管理系统，控制键盘显示和输入焦点
 * - 主输入框：编辑器的主要文本输入区域
 * - 后续输入框：线程（Thread）模式下的额外帖子输入区域
 * - 焦点切换：在不同输入框间切换键盘焦点
 * - 状态持久化：焦点状态可以被保存和恢复
 * - 用户体验：智能的焦点管理提升输入体验
 * - 响应式设计：焦点变化自动触发界面更新
 */

// 导入 SwiftUI 框架，提供 @FocusState 和 Hashable 支持
import SwiftUI

// StatusEditor 命名空间扩展
extension StatusEditor {
  // 编辑器焦点状态枚举，用于管理不同输入框的键盘焦点
  enum EditorFocusState: Hashable {
    // 主要输入框获得焦点
    case main
    // 后续帖子输入框获得焦点，使用 UUID 标识不同的输入框
    case followUp(index: UUID)
  }
}

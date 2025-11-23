/*
 * StatusActionButtonStyle.swift
 * IceCubesApp - 状态操作按钮样式
 * 
 * 功能描述：
 * 定义状态操作按钮的自定义样式，支持开关状态、颜色变化和按压动画
 * 提供统一的按钮交互体验，包括缩放效果和亮度调节
 *
 * 技术点：
 * 1. ButtonStyle 协议 - 自定义按钮样式
 * 2. Extension 扩展 - 为 ButtonStyle 添加便捷方法
 * 3. 静态工厂方法 - statusAction 创建样式实例
 * 4. 开关状态 - isOn 布尔属性控制外观
 * 5. 动画系统 - SwiftUI 动画和过渡效果
 * 6. 颜色系统 - 动态颜色和主题支持
 * 7. 缩放效果 - scaleEffect 按压反馈
 * 8. 亮度调节 - brightness 修饰符
 * 9. 条件渲染 - 基于状态的样式变化
 * 10. UIKit 桥接 - Color(UIColor) 系统颜色
 *
 * 技术点详解：
 * - ButtonStyle：SwiftUI 的按钮样式自定义协议
 * - 工厂方法：通过静态方法创建预配置的样式实例
 * - 状态管理：isOn 控制按钮的激活/非激活状态
 * - 颜色逻辑：激活时使用 tintColor，非激活时使用次要标签色
 * - 动画控制：使用 nil 禁用特定属性的动画
 * - 按压效果：configuration.isPressed 检测按钮按压状态
 * - 缩放动画：非激活按钮按压时缩放到 0.8 倍
 * - 亮度效果：根据按压和激活状态调整亮度
 * - 性能优化：避免不必要的动画触发
 * - 一致性设计：所有状态操作按钮使用相同的视觉语言
 */

// 导入 DesignSystem 模块，提供设计系统支持
import DesignSystem
// 导入 SwiftUI 框架，提供视图组件和动画系统
import SwiftUI
// 导入 UIKit 框架，提供系统颜色支持
import UIKit

// 为 ButtonStyle 添加便捷的工厂方法扩展
extension ButtonStyle where Self == StatusActionButtonStyle {
  // 静态工厂方法：创建状态操作按钮样式
  // isOn: 按钮是否处于激活状态
  // tintColor: 激活时的主题颜色
  static func statusAction(isOn: Bool = false, tintColor: Color? = nil) -> Self {
    StatusActionButtonStyle(isOn: isOn, tintColor: tintColor)
  }
}

/// 切换按钮样式：激活时轻微缩放并改变前景色为 tintColor
struct StatusActionButtonStyle: ButtonStyle {
  // 按钮是否处于激活状态
  var isOn: Bool
  // 激活状态的主题颜色
  var tintColor: Color?

  // 构建按钮样式的视图
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      // 根据激活状态设置前景色
      .foregroundColor(isOn ? tintColor : Color(UIColor.secondaryLabel))
      // 禁用 isOn 变化时的动画
      .animation(nil, value: isOn)
      // 根据配置调整亮度
      .brightness(brightness(configuration: configuration))
      // 控制亮度变化的动画
      .animation(configuration.isPressed ? nil : .default, value: isOn)
      // 非激活按钮按压时的缩放效果
      .scaleEffect(configuration.isPressed && !isOn ? 0.8 : 1.0)
  }

  // 计算按钮的亮度调节值
  func brightness(configuration: Configuration) -> Double {
    switch (configuration.isPressed, isOn) {
    case (true, true): 
      // 激活状态被按压：降低亮度到 60%
      0.6
    case (true, false): 
      // 非激活状态被按压：降低亮度到 20%
      0.2
    default: 
      // 默认状态：不调整亮度
      0
    }
  }
}

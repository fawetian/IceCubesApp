/*
 * ScrollToView.swift
 * IceCubesApp - 滚动定位视图组件
 *
 * 功能描述：
 * 提供一个不可见的锚点视图，用于在 ScrollView 或 List 中实现滚动到顶部等导航功能
 * 通过设置固定的 ID，可以被 ScrollViewReader 引用来实现程序化滚动定位
 *
 * 技术点：
 * 1. ScrollViewReader - SwiftUI 的滚动视图控制器
 * 2. View ID 系统 - SwiftUI 的视图标识符机制
 * 3. List 定制 - 列表行样式和间距控制
 * 4. 无障碍处理 - accessibilityHidden 隐藏辅助技术
 * 5. 布局优化 - EmptyView 和 HStack 的性能优化
 * 6. Constants 枚举 - 静态常量管理模式
 * 7. 公共 API 设计 - 可复用组件接口设计
 *
 * 技术点详解：
 * - ScrollViewReader：SwiftUI 的滚动控制组件，可以通过 ID 将滚动视图滚动到特定位置
 * - View ID 系统：SwiftUI 中每个视图都可以设置唯一标识符，用于动画、滚动定位等操作
 * - List 定制：通过 listRowBackground、listRowSeparator 等修饰符定制列表行的外观
 * - 无障碍处理：accessibilityHidden(true) 使视图对 VoiceOver 等辅助技术不可见
 * - 布局优化：使用 EmptyView 和 HStack 创建轻量级的不可见视图，减少渲染开销
 * - Constants 枚举：使用嵌套枚举来组织静态常量，提供命名空间和类型安全
 * - 公共 API 设计：简洁的初始化器和清晰的使用约定，便于在不同场景中复用
 */

// 导入 SwiftUI 框架，提供视图构建和滚动控制功能
import SwiftUI

/// Add to any `ScrollView` or `List` to enable scroll-to behaviour (e.g. useful for scroll-to-top).
///
/// This view is configured such that `.onAppear` and `.onDisappear` are called while remaining invisible to users on-screen.
// 定义公共的滚动定位视图，用作 ScrollView 或 List 中的不可见锚点
public struct ScrollToView: View {
  // 定义常量枚举，用于管理滚动定位相关的静态值
  public enum Constants {
    // 滚动到顶部的标识符常量
    public static let scrollToTop = "top"
  }

  // 公共初始化方法，创建滚动定位视图实例
  public init() {}

  // 视图主体，定义不可见锚点的 UI 结构
  public var body: some View {
    // 使用 HStack 包含 EmptyView 创建一个不可见的容器
    HStack { EmptyView() }
      // 设置列表行背景为透明
      .listRowBackground(Color.clear)
      // 隐藏列表行分隔线
      .listRowSeparator(.hidden)
      // 移除列表行的默认内边距
      .listRowInsets(.init())
      // 对无障碍技术隐藏此视图
      .accessibilityHidden(true)
      // 设置视图 ID 为 "top"，用于 ScrollViewReader 定位
      .id(Constants.scrollToTop)
  }
}

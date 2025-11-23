/*
 * NotificationsHeaderFilteredView.swift
 * IceCubesApp - 通知头部过滤视图
 * 
 * 功能描述：
 * 显示被过滤的通知摘要信息，当有待处理的通知请求时显示相应的提示和计数
 * 提供快速导航到通知请求页面的交互入口
 *
 * 技术点：
 * 1. SwiftUI 声明式视图 - 基于状态的 UI 渲染
 * 2. Environment 属性包装器 - 访问全局主题和路由
 * 3. 条件渲染 - 基于数据状态的视图显示
 * 4. HStack 水平布局 - 横向排列 UI 元素
 * 5. Label 标签组件 - 图标和文本组合
 * 6. 文本样式修饰符 - 字体、颜色、间距等
 * 7. 形状裁剪 - clipShape 圆形背景
 * 8. 手势响应 - onTapGesture 触摸处理
 * 9. 列表行定制 - listRowBackground/Insets
 * 10. 路由导航 - RouterPath 页面跳转
 *
 * 技术点详解：
 * - Environment：通过环境获取主题和路由器实例
 * - 条件渲染：只在有待处理通知时显示界面
 * - Label 组件：结合系统图标和本地化文本
 * - 文本样式：使用字体、颜色、间距等修饰符美化文本
 * - Circle 形状：创建圆形的计数徽章
 * - 手势处理：响应点击事件并导航到相应页面
 * - 列表定制：自定义列表行的背景色和内边距
 * - 布局设计：使用 Spacer 推开元素，创建合理的视觉层次
 * - 访问性：使用系统图标提供无障碍支持
 * - 导航设计：提供清晰的视觉指示和交互反馈
 */

// 导入 DesignSystem 模块，提供主题和设计系统
import DesignSystem
// 导入 Env 模块，提供路由器和环境管理
import Env
// 导入 Models 模块，提供通知政策数据模型
import Models
// 导入 SwiftUI 框架，提供 UI 组件和修饰符
import SwiftUI

// 通知头部过滤视图结构体
struct NotificationsHeaderFilteredView: View {
  // 从环境中获取主题配置
  @Environment(Theme.self) private var theme
  // 从环境中获取路由器路径
  @Environment(RouterPath.self) private var routerPath

  // 已过滤的通知摘要数据
  let filteredNotifications: NotificationsPolicy.Summary

  // 视图主体
  var body: some View {
    // 只在有待处理通知时显示
    if filteredNotifications.pendingNotificationsCount > 0 {
      // 水平布局容器
      HStack {
        // 左侧标签：显示归档图标和提示文本
        Label("notifications.content-filter.requests.title", systemImage: "archivebox")
          .foregroundStyle(.secondary)
        // 推开中间空间
        Spacer()
        // 通知计数徽章
        Text("\(filteredNotifications.pendingNotificationsCount)")
          .font(.footnote)
          .fontWeight(.semibold)
          .monospacedDigit()
          .foregroundStyle(theme.primaryBackgroundColor)
          .padding(8)
          .background(.secondary)
          .clipShape(Circle())
        // 右侧导航指示箭头
        Image(systemName: "chevron.right")
          .foregroundStyle(.secondary)
      }
      // 添加点击手势：导航到通知请求页面
      .onTapGesture {
        routerPath.navigate(to: .notificationsRequests)
      }
      // 自定义列表行背景色
      .listRowBackground(theme.secondaryBackgroundColor)
      // 自定义列表行内边距
      .listRowInsets(
        .init(
          top: 12,
          leading: .layoutPadding,
          bottom: 12,
          trailing: .layoutPadding))
    }
  }
}

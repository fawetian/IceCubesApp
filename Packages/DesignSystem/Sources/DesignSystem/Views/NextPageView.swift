/*
 * NextPageView.swift
 * IceCubesApp - 下一页加载视图组件
 *
 * 功能描述：
 * 提供一个分页加载的底部视图组件，用于在列表滚动到底部时自动加载更多内容
 * 支持加载状态显示、错误重试机制和符号动画效果，提供良好的分页加载用户体验
 *
 * 技术点：
 * 1. @MainActor 并发 - 确保 UI 更新在主线程执行
 * 2. @State 状态管理 - 加载状态和错误状态跟踪
 * 3. 异步闭包处理 - @escaping 和 throws 异步操作
 * 4. Task 生命周期 - .task 修饰符自动任务管理
 * 5. 错误处理机制 - do-catch 语句和重试逻辑
 * 6. SF Symbols 动画 - .symbolEffect 符号效果
 * 7. 条件视图渲染 - 基于状态的 UI 切换
 * 8. 列表样式定制 - .listRowSeparator 分隔线控制
 * 9. #Preview 预览 - Xcode 15+ 的预览功能
 *
 * 技术点详解：
 * - @MainActor：确保所有 UI 更新都在主线程执行，避免并发问题
 * - @State 状态管理：跟踪加载和错误状态，驱动 UI 更新
 * - 异步闭包处理：支持可能抛出错误的异步加载操作
 * - Task 生命周期：使用 .task 修饰符在视图出现时自动开始加载
 * - 错误处理机制：捕获加载错误并提供重试功能
 * - SF Symbols 动画：使用脉冲效果增强加载状态的视觉反馈
 * - 条件视图渲染：根据不同状态显示不同的 UI 组件
 * - 列表样式定制：隐藏分隔线以获得更好的视觉效果
 * - #Preview：提供组件预览，包含模拟的列表环境
 */

// 导入 SwiftUI 框架，提供视图构建和状态管理功能
import SwiftUI

// 使用 @MainActor 确保下一页视图在主线程上运行
@MainActor
// 定义公共的下一页视图结构体，用于分页加载功能
public struct NextPageView: View {
  // 跟踪是否正在加载下一页的状态
  @State private var isLoadingNextPage: Bool = false
  // 跟踪是否显示重试按钮的状态
  @State private var showRetry: Bool = false

  // 存储加载下一页数据的异步闭包
  let loadNextPage: () async throws -> Void

  // 公共初始化方法，创建下一页视图实例
  public init(loadNextPage: @escaping (() async throws -> Void)) {
    // 设置加载下一页的回调闭包
    self.loadNextPage = loadNextPage
  }

  // 视图主体，定义分页加载的 UI 结构
  public var body: some View {
    // 水平布局容器
    HStack {
      // 检查是否显示重试按钮
      if showRetry {
        // 显示重试按钮
        Button {
          // 创建 Task 执行重试操作
          Task {
            // 隐藏重试按钮
            showRetry = false
            // 执行加载任务
            await executeTask()
          }
        } label: {
          // 重试按钮标签，包含文本和图标
          Label("action.retry", systemImage: "arrow.clockwise")
        }
        // 应用边框按钮样式
        .buttonStyle(.bordered)
      } else {
        // 显示加载指示器
        Label("placeholder.loading.short", systemImage: "arrow.down")
          // 使用脚注字体
          .font(.footnote)
          // 设置为次要颜色
          .foregroundStyle(.secondary)
          // 应用脉冲符号效果，根据加载状态变化
          .symbolEffect(.pulse, value: isLoadingNextPage)
      }
    }
    // 设置最大宽度为无限，居中对齐
    .frame(maxWidth: .infinity, alignment: .center)
    // 视图出现时自动执行加载任务
    .task {
      // 执行加载任务
      await executeTask()
    }
    // 隐藏列表行分隔线
    .listRowSeparator(.hidden, edges: .all)
  }

  // 私有方法：执行加载任务的具体逻辑
  private func executeTask() async {
    // 隐藏重试按钮
    showRetry = false
    // 使用 defer 确保在函数结束时重置加载状态
    defer {
      // 重置加载状态
      isLoadingNextPage = false
    }
    // 防止重复加载
    guard !isLoadingNextPage else { return }
    // 设置正在加载状态
    isLoadingNextPage = true
    // 执行加载操作，处理可能的错误
    do {
      // 尝试执行加载下一页的异步操作
      try await loadNextPage()
    } catch {
      // 加载失败时显示重试按钮
      showRetry = true
    }
  }
}

// 使用 Xcode 15+ 的新预览语法定义预览
#Preview {
  // 创建包含下一页视图的列表预览
  List {
    // 示例列表项
    Text("Item 1")
    // 下一页加载视图，使用空闭包作为加载回调
    NextPageView {}
  }
  // 设置为简单列表样式
  .listStyle(.plain)
}

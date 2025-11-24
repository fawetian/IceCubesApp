// 文件功能：SwiftUI 预览环境扩展
//
// 核心职责：
// - 为 SwiftUI 预览提供完整的环境对象
// - 简化预览代码的编写
// - 确保预览中所有依赖都可用
// - 提供一致的预览环境配置
//
// 技术要点：
// - View 扩展：为所有视图添加预览方法
// - @MainActor：确保在主线程执行
// - Environment 注入：批量注入环境对象
// - 单例共享：使用 shared 实例
// - 链式调用：支持流畅的 API 调用
//
// 使用场景：
// - SwiftUI 预览
// - 开发时的视图测试
// - 快速原型开发
//
// 依赖关系：
// - 依赖：NetworkClient, SwiftUI, Env 包的所有环境对象
// - 被依赖：所有需要预览的视图

import NetworkClient
import SwiftUI

/// SwiftUI 视图的预览环境扩展
///
/// 为视图添加完整的环境对象，用于 SwiftUI 预览。
@MainActor
extension View {
  /// 添加预览环境
  ///
  /// 为视图注入所有必要的环境对象，使其可以在预览中正常工作。
  ///
  /// 注入的环境对象：
  /// - **RouterPath**：路由导航
  /// - **MastodonClient**：网络客户端（空服务器）
  /// - **CurrentAccount**：当前账户管理
  /// - **UserPreferences**：用户偏好设置
  /// - **CurrentInstance**：当前实例信息
  /// - **PushNotificationsService**：推送通知服务
  /// - **QuickLook**：快速查看管理
  ///
  /// 使用方式：
  /// ```swift
  /// struct ContentView_Previews: PreviewProvider {
  ///     static var previews: some View {
  ///         ContentView()
  ///             .withPreviewsEnv()
  ///     }
  /// }
  ///
  /// // 或者在 #Preview 宏中使用
  /// #Preview {
  ///     TimelineView()
  ///         .withPreviewsEnv()
  /// }
  /// ```
  ///
  /// 特点：
  /// - 一次调用注入所有环境对象
  /// - 使用真实的单例实例
  /// - 网络客户端使用空服务器（不会发送真实请求）
  /// - 支持链式调用
  ///
  /// - Note: 这个方法只应在预览中使用，不要在生产代码中使用
  /// - Important: 网络客户端使用空服务器，不会发送真实的网络请求
  public func withPreviewsEnv() -> some View {
    environment(RouterPath())
      .environment(MastodonClient(server: ""))
      .environment(CurrentAccount.shared)
      .environment(UserPreferences.shared)
      .environment(CurrentInstance.shared)
      .environment(PushNotificationsService.shared)
      .environment(QuickLook.shared)
  }
}

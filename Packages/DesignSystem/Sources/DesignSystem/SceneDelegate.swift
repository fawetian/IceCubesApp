// 文件功能说明：
// 该文件实现了场景代理类，负责管理UIKit场景生命周期、窗口尺寸监控、多平台窗口适配等功能，为SwiftUI应用提供底层窗口管理支持。

// 技术点：
// 1. @Observable宏 —— SwiftUI新的可观察对象架构
// 2. @MainActor修饰符 —— 确保UI操作在主线程执行
// 3. UIWindowSceneDelegate协议 —— 窗口场景生命周期管理
// 4. Sendable协议 —— 并发安全的数据传递
// 5. 条件编译 —— 多平台适配（visionOS、macCatalyst）
// 6. 静态观察者模式 —— 全局窗口尺寸监控系统
// 7. Task异步任务 —— 持续监控窗口尺寸变化
// 8. 延迟初始化 —— lazy static属性优化性能
// 9. Set集合管理 —— 多窗口实例跟踪
// 10. 窗口标题栏定制 —— macCatalyst平台特定UI调整

// 技术点详解：
// 1. @Observable：iOS 17+新特性，编译时生成观察代码，性能优于ObservableObject
// 2. @MainActor：Swift并发安全特性，确保所有UI更新在主线程执行
// 3. UIWindowSceneDelegate：UIKit场景代理，处理窗口创建、配置等生命周期事件
// 4. Sendable：Swift并发协议，确保类型可以安全地在并发环境中传递
// 5. 条件编译：#if指令根据平台提供不同的实现，支持iOS、macOS、visionOS
// 6. 静态观察者：使用静态集合和任务实现全局的窗口尺寸监控机制
// 7. Task异步任务：使用Swift并发语法创建长期运行的监控任务
// 8. lazy static：延迟初始化静态属性，只在首次访问时创建，优化启动性能
// 9. Set集合：使用集合跟踪多个场景代理实例，支持多窗口应用
// 10. 标题栏定制：针对macCatalyst平台隐藏标题栏，提供更原生的Mac体验

// 导入Combine框架，支持响应式编程
import Combine
// 导入UIKit框架，提供底层UI和窗口管理功能
import UIKit

// 场景代理类，管理UIKit场景和窗口生命周期
@Observable
@MainActor public class SceneDelegate: NSObject, UIWindowSceneDelegate, Sendable {
  // 当前窗口对象的可选引用
  public var window: UIWindow?

  // 根据平台条件编译定义窗口尺寸属性
  #if os(visionOS)
    // visionOS平台：窗口尺寸初始化为0，后续动态获取
    public private(set) var windowWidth: CGFloat = 0
    public private(set) var windowHeight: CGFloat = 0
  #else
    // 其他平台：使用屏幕主尺寸作为初始值
    public private(set) var windowWidth: CGFloat = UIScreen.main.bounds.size.width
    public private(set) var windowHeight: CGFloat = UIScreen.main.bounds.size.height
  #endif

  // UIWindowSceneDelegate协议方法，场景连接时调用
  public func scene(
    _ scene: UIScene,
    willConnectTo _: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) {
    // 确保场景是窗口场景类型
    guard let windowScene = scene as? UIWindowScene else { return }
    // 获取并存储关键窗口引用
    window = windowScene.keyWindow

    // macCatalyst平台特定配置
    #if targetEnvironment(macCatalyst)
      if let titlebar = windowScene.titlebar {
        // 隐藏窗口标题栏，提供更原生的Mac体验
        titlebar.titleVisibility = .hidden
        // 移除工具栏
        titlebar.toolbar = nil
      }
    #endif
  }

  // 公共初始化方法
  override public init() {
    // 调用父类初始化方法
    super.init()

    // 在主线程上异步执行设置
    Task { @MainActor in
      setup()
    }
  }

  // 私有设置方法，初始化窗口尺寸和观察者
  private func setup() {
    // 根据平台设置初始窗口尺寸
    #if os(visionOS)
      // visionOS：从窗口边界获取尺寸，默认为0
      windowWidth = window?.bounds.size.width ?? 0
      windowHeight = window?.bounds.size.height ?? 0
    #else
      // 其他平台：优先使用窗口尺寸，回退到屏幕尺寸
      windowWidth = window?.bounds.size.width ?? UIScreen.main.bounds.size.width
      windowHeight = window?.bounds.size.height ?? UIScreen.main.bounds.size.height
    #endif
    // 将当前实例添加到观察集合中
    Self.observedSceneDelegate.insert(self)
    // 触发延迟初始化的观察者任务（通过访问激活）
    _ = Self.observer  // 仅用于激活lazy static属性
  }

  // 静态集合，存储所有需要监控的场景代理实例
  private static var observedSceneDelegate: Set<SceneDelegate> = []

  // 静态观察者任务，持续监控所有窗口的尺寸变化
  private static let observer = Task { @MainActor in
    // 无限循环监控
    while true {
      // 每0.1秒检查一次窗口尺寸变化
      try? await Task.sleep(for: .seconds(0.1))
      // 遍历所有被观察的场景代理
      for delegate in observedSceneDelegate {
        // 根据平台获取新的窗口尺寸
        #if os(visionOS)
          // visionOS：从窗口边界获取新宽度
          let newWidth = delegate.window?.bounds.size.width ?? 0
          if delegate.windowWidth != newWidth {
            // 如果宽度发生变化，更新存储的值
            delegate.windowWidth = newWidth
          }
          // 获取新高度
          let newHeight = delegate.window?.bounds.size.height ?? 0
          if delegate.windowHeight != newHeight {
            // 如果高度发生变化，更新存储的值
            delegate.windowHeight = newHeight
          }
        #else
          // 其他平台：优先使用窗口尺寸，回退到屏幕尺寸
          let newWidth = delegate.window?.bounds.size.width ?? UIScreen.main.bounds.size.width
          if delegate.windowWidth != newWidth {
            // 如果宽度发生变化，更新存储的值
            delegate.windowWidth = newWidth
          }
          // 获取新高度
          let newHeight = delegate.window?.bounds.size.height ?? UIScreen.main.bounds.size.height
          if delegate.windowHeight != newHeight {
            // 如果高度发生变化，更新存储的值
            delegate.windowHeight = newHeight
          }
        #endif
      }
    }
  }
}

// 文件功能：触觉反馈管理器，为应用提供统一的触觉反馈体验，支持按钮点击、数据刷新、通知等不同类型的反馈。
// 相关技术点：
// - CoreHaptics：iOS 触觉引擎框架，检测设备触觉支持。
// - UIKit 反馈生成器：UISelectionFeedbackGenerator、UIImpactFeedbackGenerator、UINotificationFeedbackGenerator。
// - 平台条件编译：#if os(visionOS) 处理 visionOS 平台差异。
// - 单例模式：shared 实例全局访问触觉管理器。
// - 枚举关联值：HapticType 携带强度和类型参数。
// - 用户偏好集成：根据用户设置决定是否触发反馈。
// - 预准备机制：prepare() 预加载反馈生成器。
// - 硬件能力检测：supportsHaptics 检查设备支持。
//
// 技术点详解：
// 1. @MainActor：确保触觉操作在主线程执行。
// 2. UIFeedbackGenerator：iOS 触觉反馈的标准 API。
// 3. 条件编译：为不同平台提供不同的实现。
// 4. 枚举关联值：为不同反馈类型携带参数。
// 5. prepare()：预加载生成器，减少触发延迟。
// 6. CHHapticEngine：检查硬件触觉支持能力。
// 7. intensity 参数：控制冲击反馈的强度。
// 8. 用户偏好集成：尊重用户的触觉设置开关。
// 导入 CoreHaptics 框架，触觉引擎支持
import CoreHaptics
// 导入 UIKit 框架，触觉反馈生成器
import UIKit

// 触觉反馈管理器，统一管理应用的触觉体验
@MainActor
public class HapticManager {
  // 单例实例，全局访问
  public static let shared: HapticManager = .init()

  // visionOS 平台的反馈类型定义
  #if os(visionOS)
    public enum FeedbackType: Int {
      case success, warning, error
    }
  #endif

  // 触觉类型枚举，定义不同场景的反馈
  public enum HapticType {
    // 按钮点击反馈
    case buttonPress
    // 数据刷新反馈（带强度参数）
    case dataRefresh(intensity: CGFloat)
    // 通知反馈（根据平台使用不同类型）
    #if os(visionOS)
      case notification(_ type: FeedbackType)
    #else
      case notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    #endif
    // 标签选择反馈
    case tabSelection
    // 时间线操作反馈
    case timeline
  }

  // 非 visionOS 平台的反馈生成器
  #if !os(visionOS)
    // 选择反馈生成器
    private let selectionGenerator = UISelectionFeedbackGenerator()
    // 冲击反馈生成器（重度）
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    // 通知反馈生成器
    private let notificationGenerator = UINotificationFeedbackGenerator()
  #endif

  // 用户偏好设置
  private let userPreferences = UserPreferences.shared

  // 私有初始化器，预准备生成器
  private init() {
    #if !os(visionOS)
      // 预准备生成器以减少延迟
      selectionGenerator.prepare()
      impactGenerator.prepare()
    #endif
  }

  // 触发指定类型的触觉反馈
  @MainActor
  public func fireHaptic(_ type: HapticType) {
    #if !os(visionOS)
      // 检查设备是否支持触觉
      guard supportsHaptics else { return }

      switch type {
      case .buttonPress:
        // 按钮按压反馈
        if userPreferences.hapticButtonPressEnabled {
          impactGenerator.impactOccurred()
        }
      case let .dataRefresh(intensity):
        // 数据刷新反馈（可调强度）
        if userPreferences.hapticTimelineEnabled {
          impactGenerator.impactOccurred(intensity: intensity)
        }
      case let .notification(type):
        // 通知类型反馈
        if userPreferences.hapticButtonPressEnabled {
          notificationGenerator.notificationOccurred(type)
        }
      case .tabSelection:
        // 标签选择反馈
        if userPreferences.hapticTabSelectionEnabled {
          selectionGenerator.selectionChanged()
        }
      case .timeline:
        // 时间线操作反馈
        if userPreferences.hapticTimelineEnabled {
          selectionGenerator.selectionChanged()
        }
      }
    #endif
  }

  // 检查设备是否支持触觉反馈
  public var supportsHaptics: Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
  }
}

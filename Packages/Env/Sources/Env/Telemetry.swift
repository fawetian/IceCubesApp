// 文件功能：遥测数据管理器，集成TelemetryDeck服务收集应用使用统计和分析数据。
// 相关技术点：
// - TelemetryDeck集成：第三方分析服务的Swift SDK。
// - 静态方法：类级别的工具方法，无需实例化。
// - @MainActor：确保遥测操作在主线程执行。
// - 事件追踪：signal方法发送自定义事件和参数。
// - 隐私保护：TelemetryDeck符合隐私法规的分析服务。
// - 应用ID配置：唯一标识应用的TelemetryDeck项目ID。
// - 参数字典：[String: String]格式的事件附加数据。
// - 统计分析：收集用户行为和应用性能数据。
//
// 技术点详解：
// 1. TelemetryDeck.Config：配置分析服务的应用标识。
// 2. TelemetryDeck.initialize：初始化SDK并建立连接。
// 3. TelemetryDeck.signal：发送事件数据到分析平台。
// 4. 静态类设计：提供全局访问的工具类模式。
// 5. 事件参数：支持自定义键值对数据收集。
// 6. @MainActor：保证UI相关操作的线程安全。
// 7. 隐私合规：遵循GDPR等隐私保护法规。
// 8. 应用分析：用户留存、功能使用、性能监控等。
// 导入SwiftUI框架，@MainActor支持
import SwiftUI
// 导入TelemetryDeck SDK，分析服务框架
import TelemetryDeck

// 遥测数据管理器，处理应用使用统计和分析数据收集
@MainActor
public class Telemetry {
  // 设置和初始化TelemetryDeck分析服务
  public static func setup() {
    // 创建TelemetryDeck配置，使用应用的唯一ID
    let config = TelemetryDeck.Config(appID: "F04175D2-599A-4504-867E-CE870B991EB7")
    // 初始化TelemetryDeck SDK
    TelemetryDeck.initialize(config: config)
  }

  // 发送自定义事件信号到分析平台
  public static func signal(_ event: String, parameters: [String: String] = [:]) {
    // 调用TelemetryDeck API发送事件和参数数据
    TelemetryDeck.signal(event, parameters: parameters)
  }
}

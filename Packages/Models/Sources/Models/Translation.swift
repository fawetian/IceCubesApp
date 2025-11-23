// 文件功能：翻译数据模型，表示帖子内容的翻译结果，包含翻译内容、检测的源语言和提供商。
// 相关技术点：
// - Decodable：JSON 解码协议，从翻译 API 响应解析数据。
// - Sendable：并发安全协议，可在并发环境中传递。
// - HTMLString：HTML 字符串包装类型。
// - 自定义初始化器：提供便捷的构造方法。
// - Extension：为结构体添加协议遵循。
//
// 技术点详解：
// 1. Translation：翻译服务 API 返回的数据结构。
// 2. HTMLString：包装 HTML 内容的字符串类型。
// 3. detectedSourceLanguage：自动检测的源语言代码。
// 4. provider：翻译服务提供商标识。
// 5. 自定义 init：提供比默认初始化器更方便的构造方式。
// 6. .init(stringValue:)：HTMLString 的构造方法。
// 导入基础框架
import Foundation

// 翻译数据模型，表示文本翻译的结果
public struct Translation: Decodable {
  // 翻译后的 HTML 内容
  public let content: HTMLString
  // 检测到的源语言
  public let detectedSourceLanguage: String
  // 翻译服务提供商
  public let provider: String

  // 自定义初始化器，便于手动创建翻译对象
  public init(content: String, detectedSourceLanguage: String, provider: String) {
    // 将字符串内容包装为 HTMLString
    self.content = .init(stringValue: content)
    self.detectedSourceLanguage = detectedSourceLanguage
    self.provider = provider
  }
}

// 扩展 Translation 为 Sendable，支持并发环境
extension Translation: Sendable {}

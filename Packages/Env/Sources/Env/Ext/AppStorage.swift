// 文件功能：数组AppStorage扩展，为Codable数组类型添加RawRepresentable协议支持，使其可用于@AppStorage。
// 相关技术点：
// - 协议扩展：为Array添加RawRepresentable协议实现。
// - @retroactive：Swift 5.8+的回溯协议遵循。
// - 泛型约束：Element: Codable限制数组元素类型。
// - JSON编解码：使用JSONEncoder/JSONDecoder进行序列化。
// - UserDefaults兼容：通过String原始值支持持久化存储。
// - 错误处理：解码失败时的降级处理。
// - @AppStorage集成：让数组类型可用于SwiftUI的@AppStorage。
// - 数据持久化：复杂数据结构的本地存储方案。
//
// 技术点详解：
// 1. extension Array：为数组类型添加功能扩展。
// 2. @retroactive：为现有类型回溯添加协议遵循。
// 3. RawRepresentable：提供原始值和对象的双向转换。
// 4. where Element: Codable：泛型约束确保元素可编码。
// 5. JSONDecoder/JSONEncoder：标准JSON序列化工具。
// 6. String原始值：UserDefaults支持的字符串格式。
// 7. 失败初始化：init?()可失败的初始化器。
// 8. 错误降级：解码失败时返回空数组字符串。
// 导入基础库，JSON编解码支持
import Foundation

// 为Codable数组类型添加RawRepresentable协议支持，使其兼容@AppStorage
extension Array: @retroactive RawRepresentable where Element: Codable {
  // 可失败初始化器：从字符串原始值创建数组
  public init?(rawValue: String) {
    // 将字符串转换为UTF-8数据
    guard let data = rawValue.data(using: .utf8),
      // 使用JSON解码器解码数组
      let result = try? JSONDecoder().decode([Element].self, from: data)
    else {
      // 解码失败返回nil
      return nil
    }
    // 设置解码结果
    self = result
  }

  // 计算属性：将数组转换为字符串原始值
  public var rawValue: String {
    // 使用JSON编码器编码数组
    guard let data = try? JSONEncoder().encode(self),
      // 将数据转换为UTF-8字符串
      let result = String(data: data, encoding: .utf8)
    else {
      // 编码失败返回空数组JSON字符串
      return "[]"
    }
    return result
  }
}

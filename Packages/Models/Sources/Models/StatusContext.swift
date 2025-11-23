// 文件功能：状态上下文数据模型，表示帖子的祖先（回复链上层）和后代（回复链下层）帖子。
// 相关技术点：
// - Decodable：JSON 解码协议，从 API 响应解析数据。
// - Sendable：并发安全协议，可在并发环境中传递。
// - 静态工厂方法：empty() 创建空上下文。
// - 数组属性：ancestors 和 descendants 存储相关帖子。
// - Extension：为结构体添加协议遵循。
//
// 技术点详解：
// 1. StatusContext：Mastodon API 返回的帖子上下文结构。
// 2. ancestors：回复链中的祖先帖子（更早的帖子）。
// 3. descendants：回复链中的后代帖子（更晚的回复）。
// 4. Decodable：自动生成 JSON 解码功能。
// 5. 静态方法：类型方法，无需实例即可调用。
// 6. Sendable：标记类型可在并发环境中安全使用。
// 导入基础框架
import Foundation

// 状态上下文数据模型，包含帖子的上下文信息
public struct StatusContext: Decodable {
  // 祖先帖子列表（回复链上层帖子）
  public let ancestors: [Status]
  // 后代帖子列表（回复链下层帖子）
  public let descendants: [Status]

  // 静态工厂方法：创建空的上下文
  public static func empty() -> StatusContext {
    .init(ancestors: [], descendants: [])
  }
}

// 扩展 StatusContext 为 Sendable，支持并发环境
extension StatusContext: Sendable {}

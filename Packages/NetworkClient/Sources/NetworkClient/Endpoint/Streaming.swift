/*
 * Streaming.swift
 * IceCubesApp - 流式数据端点
 *
 * 功能描述：
 * 定义 Mastodon 流式数据相关的 API 端点，用于 WebSocket 实时连接
 * 提供实时更新的数据流服务基础路径
 *
 * 技术点：
 * 1. Endpoint 协议 - 实现统一的端点接口
 * 2. Enum 枚举 - 类型安全的端点定义
 * 3. WebSocket 连接 - 实时数据传输
 * 4. 流式协议 - 持续的数据流
 * 5. 实时更新 - 即时接收新内容
 * 6. 基础端点 - 流式服务的根路径
 * 7. 长连接 - 保持持久的网络连接
 * 8. 事件驱动 - 基于事件的数据推送
 * 9. 低延迟 - 快速的数据传输
 * 10. 双向通信 - 支持客户端和服务器交互
 *
 * 技术点详解：
 * - Endpoint：实现 Mastodon 流式 API 的统一接口
 * - WebSocket：建立持久连接进行实时数据交换
 * - 流式协议：支持时间线、通知等实时更新
 * - 基础路径：提供流式服务的入口点
 * - 无查询参数：流式连接的参数通常在连接时指定
 * - 无 JSON 体：WebSocket 连接不需要 HTTP 请求体
 * - 实时性：相比轮询大大减少延迟
 * - 连接管理：需要处理连接断开和重连
 * - 事件流：接收各种类型的实时事件
 * - 性能优化：减少不必要的网络请求
 */

// 导入 Foundation 框架，提供 URL 查询参数支持
import Foundation

// 流式数据相关端点枚举
public enum Streaming: Endpoint {
  // 流式连接端点
  case streaming

  // 实现 Endpoint 协议：返回 API 路径
  public func path() -> String {
    switch self {
    case .streaming:
      // 流式数据的基础 API 路径
      "streaming"
    }
  }

  // 实现 Endpoint 协议：返回查询参数（无需参数）
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    default:
      // 流式端点不需要查询参数
      nil
    }
  }
}

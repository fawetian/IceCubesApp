/*
 * Trends.swift
 * IceCubesApp - 趋势内容端点
 *
 * 功能描述：
 * 定义 Mastodon 趋势内容相关的 API 端点
 * 获取趋势标签、链接和状态等热门内容
 *
 * 技术点：
 * 1. Endpoint 协议 - 实现统一的端点接口
 * 2. Enum 枚举 - 类型安全的端点定义
 * 3. 模式匹配 - switch 语句处理不同端点
 * 4. 无参数端点 - 简单的 GET 请求
 * 5. 趋势算法 - 基于活跃度的内容排序
 * 6. 社交发现 - 帮助用户发现热门内容
 * 7. 数据聚合 - 服务器端趋势计算
 * 8. 实时更新 - 动态变化的趋势数据
 * 9. 内容分类 - 标签、链接、状态分类
 * 10. 热度排名 - 基于互动量的排序
 *
 * 技术点详解：
 * - Endpoint：实现 Mastodon 趋势 API 的统一接口
 * - 趋势标签：基于使用频率和增长率的热门标签
 * - 趋势链接：被频繁分享的外部链接
 * - 趋势状态：高互动量的热门帖子
 * - 无查询参数：这些端点通常不需要额外参数
 * - 无 JSON 体：GET 请求不需要请求体数据
 * - 服务器计算：趋势由服务器算法实时计算
 * - 社交推荐：帮助用户发现平台上的热门内容
 * - 时效性：趋势数据具有时间敏感性
 * - 算法透明：不同实例可能有不同的趋势算法
 */

// 导入 Foundation 框架，提供 URL 查询参数支持
import Foundation

// 趋势内容相关端点枚举
public enum Trends: Endpoint {
  // 趋势标签端点
  case tags
  // 趋势状态端点
  case statuses(offset: Int?)
  // 趋势链接端点
  case links(offset: Int?)

  // 实现 Endpoint 协议：返回 API 路径
  public func path() -> String {
    switch self {
    case .tags:
      // 趋势标签的 API 路径
      "trends/tags"
    case .statuses:
      // 趋势状态的 API 路径
      "trends/statuses"
    case .links:
      // 趋势链接的 API 路径
      "trends/links"
    }
  }

  // 实现 Endpoint 协议：返回查询参数
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case let .statuses(offset), let .links(offset):
      // 如果有偏移量参数，添加到查询参数中
      if let offset {
        return [.init(name: "offset", value: String(offset))]
      }
      // 没有偏移量时不添加查询参数
      return nil
    default:
      // 标签端点不需要查询参数
      return nil
    }
  }
}

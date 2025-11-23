/*
 * Tags.swift
 * IceCubesApp - 标签管理端点
 *
 * 功能描述：
 * 定义 Mastodon 标签相关的 API 端点，用于获取标签信息和管理标签关注
 * 提供标签查看、关注和取消关注的功能
 *
 * 技术点：
 * 1. Endpoint 协议 - 实现统一的端点接口
 * 2. Enum 枚举 - 类型安全的端点定义
 * 3. 关联值 - 枚举携带标签ID参数
 * 4. 模式匹配 - switch 语句处理不同端点
 * 5. 字符串插值 - 动态构建API路径
 * 6. 标签系统 - Mastodon 的话题分类机制
 * 7. 关注管理 - 用户对标签的订阅功能
 * 8. REST 操作 - GET/POST/DELETE 标准操作
 * 9. 社交发现 - 通过标签发现内容
 * 10. 个性化 - 定制用户感兴趣的话题
 *
 * 技术点详解：
 * - Endpoint：实现 Mastodon 标签 API 的统一接口
 * - 关联值：枚举携带标签ID，提供类型安全的参数传递
 * - 标签信息：获取特定标签的详细信息和统计数据
 * - 关注标签：用户可以订阅感兴趣的标签
 * - 取消关注：移除对标签的订阅
 * - 字符串插值：使用 \() 语法构建包含参数的 API 路径
 * - 无查询参数：这些端点通过路径参数传递信息
 * - 标签发现：帮助用户找到相关话题和内容
 * - 时间线整合：关注的标签会出现在用户时间线中
 * - 社区功能：连接有共同兴趣的用户
 */

// 导入 Foundation 框架，提供 URL 查询参数支持
import Foundation

// 标签管理相关端点枚举
public enum Tags: Endpoint {
  // 获取标签信息端点，需要标签ID
  case tag(id: String)
  // 关注标签端点，需要标签ID
  case follow(id: String)
  // 取消关注标签端点，需要标签ID
  case unfollow(id: String)

  // 实现 Endpoint 协议：返回 API 路径
  public func path() -> String {
    switch self {
    case let .tag(id):
      // 获取特定标签信息的 API 路径
      "tags/\(id)/"
    case let .follow(id):
      // 关注特定标签的 API 路径
      "tags/\(id)/follow"
    case let .unfollow(id):
      // 取消关注特定标签的 API 路径
      "tags/\(id)/unfollow"
    }
  }

  // 实现 Endpoint 协议：返回查询参数（无需参数）
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    default:
      // 标签操作不需要查询参数，通过路径参数传递
      nil
    }
  }
}

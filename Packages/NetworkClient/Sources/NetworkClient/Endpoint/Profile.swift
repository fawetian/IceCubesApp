/*
 * Profile.swift
 * IceCubesApp - 用户资料端点
 *
 * 功能描述：
 * 定义用户资料相关的 API 端点，主要用于删除头像和封面图片
 * 提供用户资料图片管理的基本功能
 *
 * 技术点：
 * 1. Endpoint 协议 - 实现统一的端点接口
 * 2. Enum 枚举 - 类型安全的端点定义
 * 3. 模式匹配 - switch 语句处理不同端点
 * 4. DELETE 操作 - 删除用户资料图片
 * 5. 资料管理 - 用户头像和封面管理
 * 6. 无参数端点 - 简单的删除操作
 * 7. 用户权限 - 仅限用户自己的资料
 * 8. 媒体清理 - 清除用户上传的图片
 * 9. 隐私保护 - 用户控制自己的形象
 * 10. 简化接口 - 专注于删除操作
 *
 * 技术点详解：
 * - Endpoint：实现 Mastodon 用户资料 API 的统一接口
 * - 删除头像：移除用户的个人头像图片
 * - 删除封面：移除用户的个人资料封面图片
 * - 无查询参数：删除操作通常不需要额外参数
 * - 无 JSON 体：DELETE 请求不需要请求体数据
 * - 权限控制：只能删除自己的资料图片
 * - 媒体管理：与文件上传系统配合使用
 * - 用户体验：提供简单的图片管理功能
 * - 安全性：防止恶意删除他人资料
 * - 还原机制：删除后可重新上传新图片
 */

// 导入 Foundation 框架，提供 URL 查询参数支持
import Foundation

// 用户资料相关端点枚举
public enum Profile: Endpoint {
  // 删除用户头像端点
  case deleteAvatar
  // 删除用户封面端点
  case deleteHeader

  // 实现 Endpoint 协议：返回 API 路径
  public func path() -> String {
    switch self {
    case .deleteAvatar:
      // 删除头像的 API 路径
      "profile/avatar"
    case .deleteHeader:
      // 删除封面的 API 路径
      "profile/header"
    }
  }

  // 实现 Endpoint 协议：返回查询参数（无需参数）
  public func queryItems() -> [URLQueryItem]? {
    switch self {
    case .deleteAvatar, .deleteHeader:
      // 删除操作不需要查询参数
      nil
    }
  }
}

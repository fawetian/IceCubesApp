/*
 * LinkHandler.swift
 * IceCubesApp - 链接处理器
 *
 * 功能描述：
 * 链接处理器，解析分页链接中的 max_id 参数，支持时间线分页加载功能
 * 使用正则表达式从 Mastodon API 的分页链接中提取分页参数
 *
 * 技术点：
 * 1. RegexBuilder - Swift 正则表达式构建器
 * 2. Regex 类型 - 正则表达式类型
 * 3. firstMatch 查找 - 查找第一个匹配项
 * 4. 字符串替换 - replacingOccurrences 方法
 * 5. Sendable 协议 - 并发安全协议
 * 6. 计算属性 - 动态解析 maxId
 * 7. 错误处理 - do-catch 捕获正则表达式异常
 * 8. 正则匹配 - 模式匹配和提取
 * 9. 字符串处理 - 文本解析和提取
 * 10. API 分页 - Mastodon 分页机制
 *
 * 技术点详解：
 * - RegexBuilder：Swift 5.7+ 的现代正则表达式 API
 * - Regex 类型：类型安全的正则表达式表示
 * - max_id 参数：Mastodon API 使用的分页参数
 * - firstMatch(of:)：在字符串中查找正则匹配
 * - output.first?.substring：获取匹配的子字符串
 * - Sendable：标记类型可在并发环境中安全传递
 * - 分页机制：支持时间线的无限滚动加载
 * - 正则模式：匹配 max_id=[0-9]+ 格式的参数
 * - 错误处理：优雅处理正则表达式创建失败
 * - 字符串解析：从复杂 URL 中提取特定参数
 */

// 导入 Foundation 框架，提供基础数据类型
import Foundation
// 导入 RegexBuilder 框架，提供正则表达式构建功能
import RegexBuilder

// 链接处理器，用于解析分页链接
public struct LinkHandler {
  // 原始链接字符串
  public let rawLink: String

  // 计算属性：从链接中提取 max_id 参数
  public var maxId: String? {
    do {
      // 创建正则表达式，匹配 max_id= 后跟数字的模式
      let regex = try Regex("max_id=[0-9]+")
      // 在原始链接中查找第一个匹配项
      if let match = rawLink.firstMatch(of: regex) {
        // 提取匹配的子字符串并移除 "max_id=" 前缀
        return match.output.first?.substring?.replacingOccurrences(of: "max_id=", with: "")
      }
    } catch {
      // 正则表达式创建失败时返回 nil
      return nil
    }
    // 没有找到匹配时返回 nil
    return nil
  }
}

// 扩展 LinkHandler 为 Sendable，支持并发环境
extension LinkHandler: Sendable {}

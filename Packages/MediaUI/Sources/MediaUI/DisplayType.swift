/*
 * DisplayType.swift
 * IceCubesApp - 媒体显示类型枚举
 *
 * 功能描述：
 * 定义媒体显示类型枚举，将 Mastodon 的媒体附件类型映射为两种基本显示类型
 * 简化复杂的媒体类型分类，为渲染策略提供清晰的类型区分
 *
 * 技术点：
 * 1. 枚举类型 - 定义媒体的显示分类
 * 2. 初始化器 - 从附件类型转换为显示类型
 * 3. Switch 模式匹配 - 根据输入类型选择输出类型
 * 4. 类型映射 - 多对少的类型转换策略
 * 5. 关联类型 - MediaAttachment.SupportedType 的引用
 * 6. 简化逻辑 - 将复杂的媒体类型简化为渲染策略
 * 7. 枚举构造 - 通过 init(from:) 提供便捷构造方式
 * 8. 媒体分类 - image 静态显示，av 动态播放
 * 9. 公共接口 - public 访问控制修饰符
 * 10. 类型安全 - 编译时类型检查
 *
 * 技术点详解：
 * - 枚举类型：Swift 的值类型，提供类型安全的选项集合
 * - 初始化器：自定义构造函数，实现类型间的转换逻辑
 * - Switch 语句：模式匹配机制，处理所有可能的枚举值
 * - 类型映射：将 4 种附件类型（image、video、gifv、audio）归类为 2 种显示类型
 * - 关联类型：引用其他模块的类型定义，保持类型一致性
 * - 简化逻辑：抽象复杂性，为上层提供简洁的接口
 * - 枚举构造：提供便捷的类型转换方法
 * - 媒体分类：基于渲染特性的分类，image 为静态，av 为动态媒体
 * - 公共接口：使枚举可以被其他模块访问和使用
 * - 类型安全：利用 Swift 的类型系统防止运行时错误
 */

// 导入 Models 模块，提供 MediaAttachment 等数据模型
import Models
// 导入 SwiftUI 框架，提供基础类型支持
import SwiftUI

// 媒体显示类型枚举，定义两种基本的媒体渲染方式
public enum DisplayType {
  // 静态图片类型
  case image
  // 音视频类型（包括视频、GIF、音频）
  case av

  // 从媒体附件类型转换为显示类型的初始化器
  public init(from attachmentType: MediaAttachment.SupportedType) {
    switch attachmentType {
    // 图片类型直接映射为图片显示
    case .image:
      self = .image
    // 视频、GIF 动图、音频统一映射为音视频显示
    case .video, .gifv, .audio:
      self = .av
    }
  }
}

/*
 * QuickLookToolbarItem.swift
 * IceCubesApp - 快速预览工具栏项组件
 *
 * 功能描述：
 * 定义快速预览工具栏项组件，为媒体查看器提供 QuickLook 预览功能
 * 支持在系统原生预览界面中查看图片和其他媒体文件，包括缓存管理和临时文件处理
 *
 * 技术点：
 * 1. ToolbarContent 协议 - SwiftUI 工具栏内容定义
 * 2. @unchecked Sendable - 并发安全标记
 * 3. @State 状态管理 - 管理本地路径和加载状态
 * 4. Task 异步任务 - 处理文件下载和缓存操作
 * 5. Nuke 图片缓存库 - 利用第三方库的缓存功能
 * 6. URLSession 网络请求 - 下载媒体文件数据
 * 7. FileManager 文件管理 - 创建临时目录和写入文件
 * 8. QuickLook 预览 - 使用系统原生预览功能
 * 9. 缓存目录管理 - 在系统缓存目录中管理临时文件
 * 10. 错误处理 - 使用 try? 的可选错误处理方式
 *
 * 技术点详解：
 * - ToolbarContent 协议：定义可以在 SwiftUI 工具栏中显示的内容
 * - @unchecked Sendable：标记结构体为并发安全，用于在 actor 间传递
 * - @State 状态管理：跟踪本地文件路径和加载状态的变化
 * - Task 异步任务：使用 Swift 并发处理耗时的文件操作
 * - Nuke 缓存：优先从 Nuke 图片缓存中获取数据，提高性能
 * - URLSession：作为备选方案直接从网络下载文件数据
 * - FileManager：管理临时文件的创建、删除和目录结构
 * - QuickLook：集成 iOS/macOS 系统的原生文件预览功能
 * - 缓存管理：在用户缓存目录中创建专门的 quicklook 子目录
 * - 错误处理：使用 try? 语法忽略非关键错误，保证功能的鲁棒性
 */

// 导入 Nuke 图片加载和缓存库
import Nuke
// 导入 NukeUI SwiftUI 集成库
import NukeUI
// 导入 SwiftUI 框架，提供工具栏和视图组件
import SwiftUI

// 快速预览工具栏项组件，提供 QuickLook 功能
struct QuickLookToolbarItem: ToolbarContent, @unchecked Sendable {
  // 要预览的媒体文件 URL
  let itemUrl: URL
  // 本地文件路径状态，用于 QuickLook 预览
  @State private var localPath: URL?
  // 加载状态，显示进度指示器
  @State private var isLoading = false

  // 工具栏内容主体
  var body: some ToolbarContent {
    // 在工具栏尾部放置按钮
    ToolbarItem(placement: .topBarTrailing) {
      // 预览按钮
      Button {
        // 异步任务处理文件下载和缓存
        Task {
          // 开始加载，显示进度指示器
          isLoading = true
          // 获取或创建本地文件路径
          localPath = await localPathFor(url: itemUrl)
          // 加载完成，隐藏进度指示器
          isLoading = false
        }
      } label: {
        // 根据加载状态显示不同的图标
        if isLoading {
          // 加载中显示进度指示器
          ProgressView()
        } else {
          // 未加载时显示信息图标
          Image(systemName: "info.circle")
        }
      }
      // 绑定 QuickLook 预览功能到本地路径
      .quickLookPreview($localPath)
    }
  }

  // 获取图片数据，优先从缓存获取
  private func imageData(_ url: URL) async -> Data? {
    // 首先尝试从 Nuke 缓存中获取数据
    var data = ImagePipeline.shared.cache.cachedData(for: .init(url: url))

    // 如果缓存中没有数据，则从网络下载
    if data == nil {
      data = try? await URLSession.shared.data(from: url).0
    }

    return data
  }

  // 为指定 URL 创建本地文件路径
  private func localPathFor(url: URL) async -> URL {
    // 清理现有的 quicklook 目录
    try? FileManager.default.removeItem(at: quickLookDir)
    // 创建新的 quicklook 目录
    try? FileManager.default.createDirectory(at: quickLookDir, withIntermediateDirectories: true)

    // 构建本地文件路径，保持原文件名
    let path = quickLookDir.appendingPathComponent(url.lastPathComponent)
    // 获取图片数据
    let data = await imageData(url)
    // 将数据写入本地文件
    try? data?.write(to: path)

    return path
  }

  // QuickLook 缓存目录路径
  private var quickLookDir: URL {
    // 获取用户缓存目录并添加 quicklook 子目录
    do {
      return try FileManager.default.url(
        for: .cachesDirectory,  // 使用系统缓存目录
        in: .userDomainMask,  // 用户域
        appropriateFor: nil,  // 不指定特定位置
        create: false  // 不自动创建
      )
      .appending(component: "quicklook")  // 添加 quicklook 子目录
    } catch {
      // 如果获取失败，使用临时目录作为备选
      return FileManager.default.temporaryDirectory.appending(component: "quicklook")
    }
  }
}

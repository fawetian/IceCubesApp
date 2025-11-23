/*
 * MediaUIAttachmentImageView.swift
 * IceCubesApp - 媒体图片附件视图
 *
 * 功能描述：
 * 提供媒体图片的显示和交互功能，支持缩放、拖拽、上下文菜单等操作
 * 集成 Nuke 图片加载库，提供懒加载、缓存和分享功能
 *
 * 技术点：
 * 1. LazyImage - Nuke 库的懒加载图片组件
 * 2. MediaUIZoomableContainer - 自定义缩放容器
 * 3. @GestureState - 手势状态管理
 * 4. draggable 修饰符 - 支持拖拽操作
 * 5. contextMenu - 上下文菜单功能
 * 6. Transferable 协议 - 数据传输支持
 * 7. UIPasteboard - 系统剪贴板操作
 * 8. Task 异步操作 - 异步数据处理
 * 9. 图片缩放和适配 - resizable、scaledToFit
 * 10. 圆角裁剪 - clipShape、RoundedRectangle
 *
 * 技术点详解：
 * - LazyImage：Nuke 库的核心组件，提供异步图片加载、缓存和状态管理
 * - MediaUIZoomableContainer：自定义缩放容器，支持手势缩放和双击操作
 * - @GestureState：专门用于手势状态管理的属性包装器
 * - draggable：iOS 16+ 引入的拖拽修饰符，支持跨应用数据传输
 * - contextMenu：长按显示的上下文菜单，提供快捷操作
 * - Transferable：现代数据传输协议，替代传统的拖拽 API
 * - UIPasteboard：系统剪贴板接口，支持图片和链接复制
 * - Task：Swift 并发模型中的异步任务执行单元
 * - 图片适配：使用 SwiftUI 的图片修饰符实现合适的显示效果
 * - 圆角裁剪：通过 clipShape 实现图片的圆角效果
 */

// 导入 Models 模块，提供数据模型定义
import Models
// 导入 NukeUI 模块，提供 SwiftUI 集成的图片加载组件
import NukeUI
// 导入 SwiftUI 框架，提供视图构建功能
import SwiftUI

// 定义公共的媒体图片附件视图结构体
public struct MediaUIAttachmentImageView: View {
  // 图片的 URL 地址
  public let url: URL

  // 手势状态，跟踪缩放级别
  @GestureState private var zoom = 1.0

  // 视图主体，定义图片显示和交互界面
  public var body: some View {
    // 使用自定义的缩放容器包装图片
    MediaUIZoomableContainer {
      // 使用 Nuke 的懒加载图片组件
      LazyImage(url: url) { state in
        // 如果图片加载成功
        if let image = state.image {
          image
            // 使图片可调整大小
            .resizable()
            // 应用圆角裁剪效果
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // 按比例缩放以适应容器
            .scaledToFit()
            // 设置水平内边距
            .padding(.horizontal, 8)
            // 设置顶部内边距，避免与导航栏重叠
            .padding(.top, 44)
            // 设置底部内边距，避免与工具栏重叠
            .padding(.bottom, 32)
            // 应用手势缩放效果
            .scaleEffect(zoom)
        } else if state.isLoading {
          // 如果正在加载，显示进度指示器
          ProgressView()
            // 使用圆形进度样式
            .progressViewStyle(.circular)
        }
      }
      // 使图片支持拖拽操作，传输可传输的图片对象
      .draggable(MediaUIImageTransferable(url: url))
      // 添加上下文菜单（长按菜单）
      .contextMenu {
        // 分享链接选项
        MediaUIShareLink(url: url, type: .image)
        // 复制图片到剪贴板选项
        Button {
          Task {
            // 创建可传输的图片对象
            let transferable = MediaUIImageTransferable(url: url)
            // 异步获取图片数据并复制到剪贴板
            UIPasteboard.general.image = UIImage(data: await transferable.fetchData())
          }
        } label: {
          // 复制图片标签和图标
          Label("status.media.contextmenu.copy", systemImage: "doc.on.doc")
        }
        // 复制链接到剪贴板选项
        Button {
          // 将图片 URL 复制到剪贴板
          UIPasteboard.general.url = url
        } label: {
          // 复制链接标签和图标
          Label("status.action.copy-link", systemImage: "link")
        }
      }
    }
  }
}

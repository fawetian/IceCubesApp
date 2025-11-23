/*
 * MediaUIZoomableContainer.swift
 * IceCubesApp - 可缩放媒体容器
 *
 * 功能描述：
 * 提供支持手势缩放和双击缩放的容器组件，包装任意 SwiftUI 视图使其具备缩放功能
 * 通过 UIScrollView 实现底层缩放逻辑，支持平滑缩放动画和边界控制
 *
 * 技术点：
 * 1. UIViewRepresentable - SwiftUI 与 UIKit 桥接
 * 2. UIScrollView - 底层滚动和缩放实现
 * 3. UIScrollViewDelegate - 缩放行为代理
 * 4. UIHostingController - SwiftUI 视图托管
 * 5. @ViewBuilder - 泛型视图构建器
 * 6. @State 状态管理 - 缩放和点击位置状态
 * 7. @Binding 数据绑定 - 状态双向绑定
 * 8. Coordinator 模式 - UIKit 与 SwiftUI 通信
 * 9. 手势识别 - 双击缩放手势
 * 10. 动画缩放 - setZoomScale、zoom 方法
 *
 * 技术点详解：
 * - UIViewRepresentable：SwiftUI 协议，允许在 SwiftUI 中使用 UIKit 组件
 * - UIScrollView：UIKit 的滚动视图，内置缩放和平移功能
 * - UIScrollViewDelegate：处理滚动视图的缩放、滚动等事件回调
 * - UIHostingController：将 SwiftUI 视图嵌入到 UIKit 层次结构中
 * - @ViewBuilder：函数构建器，允许声明式构建视图层次
 * - @State/@Binding：SwiftUI 状态管理，实现数据流和响应式更新
 * - Coordinator：设计模式，作为 UIKit 和 SwiftUI 之间的桥梁
 * - 手势识别：onTapGesture 双击检测，触发缩放行为
 * - 动画缩放：使用 UIScrollView 的内置动画实现平滑缩放效果
 * - 缩放计算：基于点击位置计算缩放区域的几何变换
 */

// 导入 SwiftUI 框架，提供视图构建功能
import SwiftUI
// 导入 UIKit 框架，提供 UIScrollView 等底层组件
import UIKit

// ref: https://stackoverflow.com/questions/74238414/is-there-an-easy-way-to-pinch-to-zoom-and-drag-any-view-in-swiftui

// 定义最大允许的缩放比例常量
private let maxAllowedScale = 4.0

// 使用 @MainActor 确保在主线程执行 UI 操作
@MainActor
// 可缩放容器结构体，包装任意内容使其支持缩放
struct MediaUIZoomableContainer<Content: View>: View {
  // 要显示的内容视图
  let content: Content
  // 当前缩放比例状态
  @State private var currentScale: CGFloat = 1.0
  // 双击位置状态，用于定位缩放中心
  @State private var tapLocation: CGPoint = .zero

  // 初始化方法，接收视图构建闭包
  init(@ViewBuilder content: () -> Content) {
    // 执行构建闭包创建内容视图
    self.content = content()
  }

  // 双击手势处理方法
  func doubleTapAction(location: CGPoint) {
    // 记录双击位置
    tapLocation = location
    // 切换缩放状态：如果当前是原始大小则放大到最大，否则回到原始大小
    currentScale = currentScale == 1.0 ? maxAllowedScale : 1.0
  }

  // 视图主体，定义缩放容器的 UI 结构
  var body: some View {
    // 使用可缩放滚动视图包装内容
    ZoomableScrollView(scale: $currentScale, tapLocation: $tapLocation) {
      content
    }
    // 添加双击手势识别
    .onTapGesture(count: 2, perform: doubleTapAction)
  }

  // 内部可缩放滚动视图结构体，实现 UIKit 桥接
  fileprivate struct ZoomableScrollView<ScollContent: View>: UIViewRepresentable {
    // 要显示的 SwiftUI 内容
    private var content: ScollContent
    // 当前缩放比例的绑定
    @Binding private var currentScale: CGFloat
    // 双击位置的绑定
    @Binding private var tapLocation: CGPoint

    // 初始化方法
    init(
      scale: Binding<CGFloat>, tapLocation: Binding<CGPoint>,
      @ViewBuilder content: () -> ScollContent
    ) {
      // 绑定缩放比例状态
      _currentScale = scale
      // 绑定双击位置状态
      _tapLocation = tapLocation
      // 创建内容视图
      self.content = content()
    }

    // 创建 UIScrollView 实例
    func makeUIView(context: Context) -> UIScrollView {
      // 创建滚动视图
      let scrollView = UIScrollView()
      // 设置透明背景
      scrollView.backgroundColor = .clear
      // 设置代理为协调器
      scrollView.delegate = context.coordinator
      // 设置最大缩放比例
      scrollView.maximumZoomScale = maxAllowedScale
      // 设置最小缩放比例
      scrollView.minimumZoomScale = 1
      // 启用缩放时的弹性效果
      scrollView.bouncesZoom = true
      // 隐藏水平滚动指示器
      scrollView.showsHorizontalScrollIndicator = false
      // 隐藏垂直滚动指示器
      scrollView.showsVerticalScrollIndicator = false
      // 禁用内容裁剪
      scrollView.clipsToBounds = false
      // 确保背景透明
      scrollView.backgroundColor = .clear

      // 获取托管控制器的视图
      let hostedView = context.coordinator.hostingController.view!
      // 启用自动调整大小
      hostedView.translatesAutoresizingMaskIntoConstraints = true
      // 设置自动调整掩码
      hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      // 设置视图框架
      hostedView.frame = scrollView.bounds
      // 设置透明背景
      hostedView.backgroundColor = .clear
      // 将托管视图添加到滚动视图
      scrollView.addSubview(hostedView)

      return scrollView
    }

    // 创建协调器实例
    func makeCoordinator() -> Coordinator {
      // 创建协调器，传入托管控制器和缩放比例绑定
      Coordinator(hostingController: UIHostingController(rootView: content), scale: $currentScale)
    }

    // 更新 UIScrollView
    func updateUIView(_ uiView: UIScrollView, context: Context) {
      // 更新托管控制器的根视图
      context.coordinator.hostingController.rootView = content

      // 如果当前缩放比例大于最小值（缩小操作）
      if uiView.zoomScale > uiView.minimumZoomScale {  // Scale out
        // 平滑缩放到指定比例
        uiView.setZoomScale(currentScale, animated: true)
      } else if tapLocation != .zero {  // 如果有双击位置（放大操作）
        // 缩放到指定位置
        uiView.zoom(
          to: zoomRect(for: uiView, scale: uiView.maximumZoomScale, center: tapLocation),
          animated: true)
        // 异步重置双击位置
        DispatchQueue.main.async { tapLocation = .zero }
      }
    }

    // 计算缩放区域矩形
    @MainActor func zoomRect(for scrollView: UIScrollView, scale: CGFloat, center: CGPoint)
      -> CGRect
    {
      // 获取滚动视图大小
      let scrollViewSize = scrollView.bounds.size

      // 计算缩放后的宽度和高度
      let width = scrollViewSize.width / scale
      let height = scrollViewSize.height / scale
      // 计算缩放区域的左上角坐标，以双击点为中心
      let originX = center.x - (width / 2.0)
      let originY = center.y - (height / 2.0)

      // 返回缩放区域矩形
      return CGRect(x: originX, y: originY, width: width, height: height)
    }

    // 协调器类，处理 UIScrollView 代理方法
    class Coordinator: NSObject, UIScrollViewDelegate {
      // SwiftUI 视图的托管控制器
      var hostingController: UIHostingController<ScollContent>
      // 当前缩放比例的绑定
      @Binding var currentScale: CGFloat

      // 初始化协调器
      init(hostingController: UIHostingController<ScollContent>, scale: Binding<CGFloat>) {
        // 保存托管控制器
        self.hostingController = hostingController
        // 绑定缩放比例
        _currentScale = scale
      }

      // 返回用于缩放的视图
      func viewForZooming(in _: UIScrollView) -> UIView? {
        // 返回托管控制器的视图
        hostingController.view
      }

      // 缩放结束时的回调
      func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale scale: CGFloat) {
        // 更新当前缩放比例状态
        currentScale = scale
      }
    }
  }
}

/*
 * CameraPickerView.swift
 * IceCubesApp - 相机选择器视图
 *
 * 功能描述：
 * 封装 UIImagePickerController 以在 SwiftUI 中使用相机
 * 允许用户拍摄照片并返回到编辑器
 *
 * 核心功能：
 * 1. 相机访问 - 打开系统相机
 * 2. 照片捕获 - 拍摄照片
 * 3. 图片返回 - 将拍摄的照片返回给编辑器
 * 4. 自动关闭 - 拍摄完成后自动关闭
 * 5. visionOS 适配 - visionOS 不支持相机
 *
 * 技术点：
 * 1. UIViewControllerRepresentable - UIKit 桥接
 * 2. @Binding - 双向数据绑定
 * 3. @Environment - 环境依赖注入
 * 4. Coordinator - 协调器模式
 * 5. UIImagePickerController - 系统图片选择器
 * 6. UIImagePickerControllerDelegate - 代理协议
 * 7. UINavigationControllerDelegate - 导航代理
 * 8. 条件编译 - visionOS 不支持相机
 *
 * 使用场景：
 * - 从编辑器附件视图打开相机
 * - 拍摄新照片添加到帖子
 * - 非 macCatalyst 平台
 *
 * 依赖关系：
 * - SwiftUI: UI 框架
 * - UIKit: UIImagePickerController
 */

import SwiftUI
import UIKit

extension StatusEditor {
  /// 相机选择器视图
  ///
  /// 封装 UIImagePickerController 以在 SwiftUI 中使用相机。
  ///
  /// 主要功能：
  /// - **相机访问**：打开系统相机
  /// - **照片捕获**：拍摄照片
  /// - **图片返回**：将拍摄的照片返回给编辑器
  ///
  /// 使用示例：
  /// ```swift
  /// CameraPickerView(selectedImage: $selectedImage)
  /// ```
  ///
  /// - Note: visionOS 不支持相机功能
  /// - Important: 需要在 Info.plist 中添加相机权限说明
  struct CameraPickerView: UIViewControllerRepresentable {
    /// 选中的图片
    @Binding var selectedImage: UIImage?
    /// 关闭视图的环境变量
    @Environment(\.dismiss) var dismiss

    /// 协调器
    ///
    /// 处理 UIImagePickerController 的代理回调。
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
      /// 相机选择器视图引用
      let picker: CameraPickerView

      /// 初始化协调器
      ///
      /// - Parameter picker: 相机选择器视图
      init(picker: CameraPickerView) {
        self.picker = picker
      }

      /// 图片选择完成回调
      ///
      /// 当用户拍摄照片后调用。
      ///
      /// - Parameters:
      ///   - picker: 图片选择器
      ///   - info: 包含选中图片的信息字典
      func imagePickerController(
        _: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        guard let selectedImage = info[.originalImage] as? UIImage else { return }
        // 将选中的图片传递给绑定变量
        picker.selectedImage = selectedImage
        // 关闭相机视图
        picker.dismiss()
      }
    }

    /// 创建 UIViewController
    ///
    /// 创建并配置 UIImagePickerController。
    ///
    /// - Parameter context: 上下文
    /// - Returns: 配置好的 UIImagePickerController
    func makeUIViewController(context: Context) -> UIImagePickerController {
      let imagePicker = UIImagePickerController()
      #if !os(visionOS)
        // visionOS 不支持相机
        imagePicker.sourceType = .camera
      #endif
      imagePicker.delegate = context.coordinator
      return imagePicker
    }

    /// 更新 UIViewController
    ///
    /// 此视图不需要更新。
    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    /// 创建协调器
    ///
    /// - Returns: 新的协调器实例
    func makeCoordinator() -> Coordinator {
      Coordinator(picker: self)
    }
  }
}

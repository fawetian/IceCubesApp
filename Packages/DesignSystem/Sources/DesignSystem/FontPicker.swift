// 文件功能说明：
// 该文件实现了字体选择器组件，将UIKit的UIFontPickerViewController包装为SwiftUI视图，允许用户选择自定义字体并应用到应用主题中。

// 技术点：
// 1. UIViewControllerRepresentable —— SwiftUI包装UIKit控制器的协议
// 2. Coordinator模式 —— 处理UIKit代理回调的协调器
// 3. UIFontPickerViewControllerDelegate —— 字体选择器代理协议
// 4. @Environment环境值 —— 获取dismiss关闭函数
// 5. DismissAction类型 —— SwiftUI提供的关闭动作类型
// 6. UIFont和FontDescriptor —— UIKit字体描述和对象
// 7. NSObject继承 —— Objective-C对象模型兼容
// 8. 代理模式 —— 处理用户交互事件的设计模式
// 9. 主题集成 —— 将选择的字体保存到全局主题
// 10. 生命周期方法 —— makeUIViewController和updateUIViewController

// 技术点详解：
// 1. UIViewControllerRepresentable：SwiftUI协议，用于将UIKit视图控制器集成到SwiftUI视图层次结构中
// 2. Coordinator模式：SwiftUI推荐的模式，用于处理UIKit组件的代理回调和状态管理
// 3. UIFontPickerViewControllerDelegate：UIKit代理协议，响应字体选择器的用户交互事件
// 4. @Environment：SwiftUI环境系统，访问由父视图提供的共享值和功能
// 5. DismissAction：SwiftUI提供的类型，用于关闭当前呈现的视图或模态
// 6. UIFont和FontDescriptor：UIKit的字体系统，描述字体的属性和创建字体对象
// 7. NSObject：Objective-C的根类，为Swift类提供Objective-C运行时兼容性
// 8. 代理模式：设计模式，允许对象通过代理响应事件而不直接处理
// 9. 主题集成：将用户选择的字体保存到全局主题管理器，影响整个应用
// 10. 生命周期方法：UIViewControllerRepresentable要求的方法，管理UIKit组件的创建和更新

// 导入Env模块，提供环境管理功能
import Env
// 导入SwiftUI框架，提供视图表示协议和环境系统
import SwiftUI

// 字体选择器视图，将UIKit的字体选择器包装为SwiftUI组件
public struct FontPicker: UIViewControllerRepresentable {
  // 从环境中获取dismiss函数，用于关闭字体选择器
  @Environment(\.dismiss) var dismiss

  // 协调器类，处理字体选择器的代理回调
  public class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
    // 存储关闭动作的私有属性
    private let dismiss: DismissAction

    // 协调器初始化方法，接受关闭动作
    public init(dismiss: DismissAction) {
      // 保存关闭动作引用
      self.dismiss = dismiss
    }

    // 代理方法：用户取消字体选择时调用
    public func fontPickerViewControllerDidCancel(_: UIFontPickerViewController) {
      // 关闭字体选择器
      dismiss()
    }

    // 代理方法：用户选择字体时调用
    public func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
      // 将选择的字体保存到全局主题，size为0表示使用默认大小
      Theme.shared.chosenFont = UIFont(descriptor: viewController.selectedFontDescriptor!, size: 0)
      // 关闭字体选择器
      dismiss()
    }
  }

  // 公共初始化方法
  public init() {}

  // UIViewControllerRepresentable要求的方法：创建协调器
  public func makeCoordinator() -> Coordinator {
    // 创建协调器，传入dismiss函数
    Coordinator(dismiss: dismiss)
  }

  // UIViewControllerRepresentable要求的方法：创建UIKit控制器
  public func makeUIViewController(context: Context) -> UIFontPickerViewController {
    // 创建字体选择器控制器
    let controller = UIFontPickerViewController()
    // 设置代理为协调器
    controller.delegate = context.coordinator
    // 返回配置好的控制器
    return controller
  }

  // UIViewControllerRepresentable要求的方法：更新UIKit控制器（此处为空实现）
  public func updateUIViewController(_: UIFontPickerViewController, context _: Context) {}
}

// 文件功能：翻译视图扩展，为SwiftUI View添加系统翻译功能支持，集成iOS 17.4+的Translation框架。
// 相关技术点：
// - 条件导入：#if canImport检查Translation框架可用性。
// - View扩展：为SwiftUI View添加翻译相关方法。
// - 平台适配：排除不支持翻译的平台（macCatalyst、visionOS）。
// - 版本检查：#available确保iOS版本兼容性。
// - 系统集成：使用iOS原生翻译UI和服务。
// - 条件编译：多层次的平台和版本条件判断。
// - Binding参数：响应式的翻译界面显示控制。
// - 降级处理：不支持的平台返回原始视图。
//
// 技术点详解：
// 1. #if canImport：编译时检查框架是否可用。
// 2. import Translation：导入iOS系统翻译框架。
// 3. extension View：为所有SwiftUI视图添加扩展方法。
// 4. #if targetEnvironment：检查目标运行环境。
// 5. #available：运行时版本可用性检查。
// 6. translationPresentation：系统翻译界面修饰符。
// 7. Binding<Bool>：双向绑定的界面显示状态。
// 8. 平台排除：macCatalyst和visionOS不支持翻译。
// 导入SwiftUI框架，View扩展支持
import SwiftUI

// 条件导入：仅在Translation框架可用时编译以下代码
#if canImport(_Translation_SwiftUI)
  // 导入iOS系统翻译框架
  import Translation

  // 为SwiftUI View添加翻译功能扩展
  extension View {
    // 添加系统翻译视图的方法
    public func addTranslateView(isPresented: Binding<Bool>, text: String) -> some View {
      // 排除不支持翻译的平台
      #if targetEnvironment(macCatalyst) || os(visionOS)
        // macCatalyst和visionOS不支持翻译，返回原视图
        return self
      #else
        // 检查iOS版本是否支持翻译功能
        if #available(iOS 17.4, *) {
          // iOS 17.4+使用系统翻译界面
          return self.translationPresentation(isPresented: isPresented, text: text)
        } else {
          // 旧版本iOS不支持，返回原视图
          return self
        }
      #endif
    }
  }
#endif

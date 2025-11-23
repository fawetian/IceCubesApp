// 文件功能：翻译设置页面，用户可配置翻译服务类型、DeepL API 密钥、自动检测语言等。
// 相关技术点：
// - SwiftUI 表单与分区：Form、Section 组织界面。
// - @Environment/@Bindable：环境注入与双向绑定。
// - @State：本地状态管理。
// - Picker/Toggle：选择器与开关控件。
// - SecureField：安全文本输入框，隐藏密钥。
// - 条件渲染：根据选择的翻译类型显示不同内容。
// - onChange/onAppear：生命周期监听。
// - 条件编译：适配不同平台与可用性检查。
//
// 技术点详解：
// 1. SecureField：安全文本输入，自动隐藏输入内容，适合密码/API 密钥。
// 2. @ViewBuilder：SwiftUI 视图构建器，支持条件渲染。
// 3. 条件编译：#if canImport/_available 检查 API 可用性。
// 4. textContentType：输入框内容类型提示，优化用户体验。
// 5. Link：超链接组件，跳转外部网页。
// 6. onChange：监听状态变化，执行副作用操作。
// 7. onAppear：视图出现时的生命周期回调。
import DesignSystem
// 导入设计系统，包含主题、控件等
import Env
// 导入环境依赖模块
import SwiftUI

// 导入 SwiftUI 框架

// 主线程下定义翻译设置视图
@MainActor
struct TranslationSettingsView: View {
  // 注入用户偏好设置
  @Environment(UserPreferences.self) private var preferences
  // 注入主题
  @Environment(Theme.self) private var theme

  // API 密钥输入状态
  @State private var apiKey: String = ""

  // 主体视图
  var body: some View {
    Form {
      translationSelector
      // 当选择 DeepL 翻译时显示 API 密钥设置
      if preferences.preferredTranslationType == .useDeepl {
        Section("settings.translation.user-api-key") {
          deepLPicker
          // 安全文本输入框，隐藏 API 密钥
          SecureField("settings.translation.user-api-key", text: $apiKey)
            .textContentType(.password)
        }
        #if !os(visionOS)
          // 设置分区背景色
          .listRowBackground(theme.primaryBackgroundColor)
        #endif

        // 当 API 密钥为空时，显示获取提示
        if apiKey.isEmpty {
          Section {
            // 跳转到 DeepL API 注册页面
            Link(destination: URL(string: "https://www.deepl.com/pro-api")!) {
              Text("settings.translation.needed-message")
                .foregroundColor(.red)
            }
          }
          #if !os(visionOS)
            // 设置分区背景色
            .listRowBackground(theme.primaryBackgroundColor)
          #endif
        }
      }
      backgroundAPIKey
      autoDetectSection
    }
    // 设置导航标题
    .navigationTitle("settings.translation.navigation-title")
    #if !os(visionOS)
      // 隐藏表单默认背景
      .scrollContentBackground(.hidden)
      // 设置整体背景色
      .background(theme.secondaryBackgroundColor)
    #endif
    // 监听 API 密钥变化，自动保存
    .onChange(of: apiKey) {
      writeNewValue()
    }
    // 页面出现时更新偏好设置
    .onAppear(perform: updatePrefs)
    // 页面出现时读取已保存的密钥
    .onAppear(perform: readValue)
  }

  // 翻译服务选择器
  @ViewBuilder
  private var translationSelector: some View {
    // 创建可绑定的偏好设置对象
    @Bindable var preferences = preferences
    Picker("Translation Service", selection: $preferences.preferredTranslationType) {
      // 遍历所有可用的翻译类型
      ForEach(allTTCases, id: \.self) { type in
        Text(type.description).tag(type)
      }
    }
    #if !os(visionOS)
      // 设置背景色
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  // 获取所有可用的翻译类型（过滤不支持的平台）
  var allTTCases: [TranslationType] {
    TranslationType.allCases.filter { type in
      if type != .useApple {
        return true
      }
      #if canImport(_Translation_SwiftUI)
        // 检查 iOS 17.4+ 才支持苹果翻译
        if #available(iOS 17.4, *) {
          return true
        } else {
          return false
        }
      #else
        return false
      #endif
    }
  }

  // DeepL API 类型选择器
  @ViewBuilder
  private var deepLPicker: some View {
    // 创建可绑定的偏好设置对象
    @Bindable var preferences = preferences
    Picker("settings.translation.api-key-type", selection: $preferences.userDeeplAPIFree) {
      Text("DeepL API Free").tag(true)
      Text("DeepL API Pro").tag(false)
    }
  }

  // 自动检测语言设置分区
  @ViewBuilder
  private var autoDetectSection: some View {
    // 创建可绑定的偏好设置对象
    @Bindable var preferences = preferences
    Section {
      // 自动检测帖子语言开关
      Toggle(isOn: $preferences.autoDetectPostLanguage) {
        Text("settings.translation.auto-detect-post-language")
      }
    } footer: {
      // 分区说明文字
      Text("settings.translation.auto-detect-post-language-footer")
    }
    #if !os(visionOS)
      // 设置分区背景色
      .listRowBackground(theme.primaryBackgroundColor)
    #endif
  }

  // 后台 API 密钥管理分区
  @ViewBuilder
  private var backgroundAPIKey: some View {
    // 当不使用 DeepL 但仍有密钥时显示
    if preferences.preferredTranslationType != .useDeepl,
      !apiKey.isEmpty
    {
      Section {
        // 提示仍有 DeepL API 密钥存储
        Text("The DeepL API Key is still stored!")
        // 如果设置为服务器优先，说明可作为备用
        if preferences.preferredTranslationType == .useServerIfPossible {
          Text(
            "It can however still be used as a fallback for your instance's translation service.")
        }
        // 删除密钥按钮
        Button(role: .destructive) {
          withAnimation {
            writeNewValue(value: "")
            readValue()
          }
        } label: {
          Text("action.delete")
        }
      }
      #if !os(visionOS)
        // 设置分区背景色
        .listRowBackground(theme.primaryBackgroundColor)
      #endif
    }
  }

  // 保存当前输入的密钥
  private func writeNewValue() {
    writeNewValue(value: apiKey)
  }

  // 保存指定的密钥值
  private func writeNewValue(value: String) {
    DeepLUserAPIHandler.write(value: value)
  }

  // 读取已保存的密钥
  private func readValue() {
    apiKey = DeepLUserAPIHandler.readKey()
  }

  // 更新偏好设置，如果没有密钥则自动禁用 DeepL
  private func updatePrefs() {
    DeepLUserAPIHandler.deactivateToggleIfNoKey()
  }
}

// SwiftUI 预览
struct TranslationSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    TranslationSettingsView()
      .environment(UserPreferences.shared)
  }
}

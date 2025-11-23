// 文件功能：DeepL用户API处理器，管理DeepL翻译服务的API密钥存储、读取和验证，支持安全的密钥管理。
// 相关技术点：
// - KeychainSwift：安全存储API密钥到iOS钥匙串。
// - 静态方法：提供全局访问的API密钥管理功能。
// - @MainActor：确保API操作在主线程执行。
// - 枚举工具：使用enum作为静态方法的命名空间。
// - 条件编译：针对不同环境的钥匙串配置。
// - 用户偏好集成：根据翻译偏好控制密钥访问。
// - 安全同步：synchronizable钥匙串跨设备同步。
// - 密钥验证：检查密钥有效性并自动降级。
//
// 技术点详解：
// 1. enum DeepLUserAPIHandler：作为静态方法容器的枚举。
// 2. KeychainSwift：第三方钥匙串访问库。
// 3. private static：私有静态属性和方法。
// 4. 条件编译：#if检查调试和模拟器环境。
// 5. App Groups：keychain.accessGroup跨target共享。
// 6. synchronizable：启用iCloud钥匙串同步。
// 7. 用户偏好检查：基于设置决定密钥可用性。
// 8. 自动降级：密钥无效时切换到服务器翻译。
// 导入基础库，基本数据类型
import Foundation
// 导入KeychainSwift，安全密钥存储
import KeychainSwift
// 导入数据模型，用户偏好相关
import Models
// 导入SwiftUI框架，@MainActor支持
import SwiftUI

// DeepL用户API处理器，主线程安全的密钥管理工具
@MainActor
public enum DeepLUserAPIHandler {
  // 钥匙串存储的密钥名称
  private static let key = "DeepL"

  // 计算属性：获取配置好的钥匙串实例
  private static var keychain: KeychainSwift {
    let keychain = KeychainSwift()
    // 非调试和非模拟器环境下使用App Groups
    #if !DEBUG && !targetEnvironment(simulator)
      keychain.accessGroup = AppInfo.keychainGroup
    #endif
    return keychain
  }

  // 写入DeepL API密钥到钥匙串
  public static func write(value: String) {
    // 启用钥匙串iCloud同步
    keychain.synchronizable = true
    if !value.isEmpty {
      // 非空值则存储密钥
      keychain.set(value, forKey: key)
    } else {
      // 空值则删除密钥
      keychain.delete(key)
    }
  }

  // 根据用户偏好读取API密钥（仅在允许时）
  public static func readKeyIfAllowed() -> String? {
    // 检查用户是否选择使用DeepL翻译
    guard UserPreferences.shared.preferredTranslationType == .useDeepl else { return nil }

    return readKeyInternal()
  }

  // 直接读取API密钥（不检查偏好）
  public static func readKey() -> String {
    return readKeyInternal() ?? ""
  }

  // 内部密钥读取方法
  private static func readKeyInternal() -> String? {
    // 启用钥匙串iCloud同步
    keychain.synchronizable = true
    // 从钥匙串获取密钥
    return keychain.get(key)
  }

  // 如果没有密钥则停用DeepL选项
  public static func deactivateToggleIfNoKey() {
    // 检查当前是否选择DeepL翻译
    if UserPreferences.shared.preferredTranslationType == .useDeepl {
      // 如果没有存储的密钥，则切换到服务器翻译
      if readKeyInternal() == nil {
        UserPreferences.shared.preferredTranslationType = .useServerIfPossible
      }
    }
  }

  // 计算属性：判断是否应该始终使用DeepL
  public static var shouldAlwaysUseDeepl: Bool {
    // 仅在有有效密钥时返回true
    readKeyIfAllowed() != nil
  }
}

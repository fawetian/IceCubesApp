// 文件功能：音效管理器，为应用提供统一的音效播放功能，支持拉取、刷新、发帖、选择等各种操作的音效反馈。
// 相关技术点：
// - AudioToolbox：iOS 音频工具框架，提供系统音效播放功能。
// - SystemSoundID：系统音效标识符类型。
// - AudioServicesCreateSystemSoundID：创建系统音效 ID。
// - AudioServicesPlaySystemSound：播放系统音效。
// - Bundle.main：应用主包，用于加载音效文件。
// - 枚举音效：SoundEffect 定义所有支持的音效类型。
// - 字典映射：systemSoundIDs 建立音效到 ID 的映射。
// - 用户偏好集成：根据用户设置决定是否播放音效。
//
// 技术点详解：
// 1. @MainActor：确保音效操作在主线程执行。
// 2. SystemSoundID：iOS 系统音效的唯一标识符。
// 3. CFURL：Core Foundation URL 类型。
// 4. CaseIterable：枚举自动生成所有案例的集合。
// 5. rawValue：枚举的原始值，用作文件名。
// 6. Bundle.main.url：从应用包中查找资源文件。
// 7. inout 参数：&soundId 传递可变引用。
// 8. 字典存储：建立音效类型到系统 ID 的映射关系。
// 导入 AVKit 框架，音视频播放工具
import AVKit
// 导入 AudioToolbox 框架，系统音效播放
import AudioToolbox
// 导入 CoreHaptics 框架，触觉反馈（未直接使用）
import CoreHaptics
// 导入 UIKit 框架，iOS 用户界面
import UIKit

// 音效管理器，统一管理应用的音效播放
@MainActor
public class SoundEffectManager {
  // 单例实例，全局访问
  public static let shared: SoundEffectManager = .init()

  // 音效类型枚举，定义所有支持的音效
  public enum SoundEffect: String, CaseIterable {
    case pull, refresh, tootSent, tabSelection, bookmark, boost, favorite, share
  }

  // 音效 ID 映射字典，存储音效类型到系统 ID 的对应关系
  private var systemSoundIDs: [SoundEffect: SystemSoundID] = [:]

  // 用户偏好设置引用
  private let userPreferences = UserPreferences.shared

  // 私有初始化器，注册所有音效
  private init() {
    registerSounds()
  }

  // 注册所有音效文件
  private func registerSounds() {
    SoundEffect.allCases.forEach { effect in
      // 查找对应的 WAV 音效文件
      guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
        return
      }
      // 注册单个音效
      register(url: url, for: effect)
    }
  }

  // 注册单个音效文件
  private func register(url: URL, for effect: SoundEffect) {
    // 创建系统音效 ID
    var soundId: SystemSoundID = .init()
    // 通过 URL 创建系统音效 ID
    AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
    // 存储音效 ID 映射
    systemSoundIDs[effect] = soundId
  }

  // 播放指定音效
  public func playSound(_ effect: SoundEffect) {
    // 检查用户是否启用音效且音效 ID 存在
    guard
      userPreferences.soundEffectEnabled,
      let soundId = systemSoundIDs[effect]
    else {
      return
    }

    // 播放系统音效
    AudioServicesPlaySystemSound(soundId)
  }
}

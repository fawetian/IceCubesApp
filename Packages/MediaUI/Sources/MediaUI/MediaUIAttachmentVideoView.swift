/*
 * MediaUIAttachmentVideoView.swift
 * IceCubesApp - 媒体视频附件视图
 *
 * 功能描述：
 * 提供视频媒体的播放和交互功能，支持自动播放、全屏播放、音频控制等操作
 * 包括视频播放器视图模型和视图组件，集成 AVKit 框架实现完整的视频播放体验
 *
 * 技术点：
 * 1. AVPlayer - AVKit 视频播放器核心
 * 2. AVAudioSession - 音频会话管理
 * 3. VideoPlayer - SwiftUI 视频播放器组件
 * 4. @Observable 宏 - 现代状态管理
 * 5. NotificationCenter - 播放完成通知
 * 6. Environment 依赖注入 - 多种环境值
 * 7. fullScreenCover - 全屏模态视图
 * 8. scenePhase 生命周期 - 应用状态监听
 * 9. 条件编译 - 平台差异化处理
 * 10. 音频焦点管理 - AVAudioSession 配置
 *
 * 技术点详解：
 * - AVPlayer：Apple 的视频播放引擎，支持流媒体和本地文件播放
 * - AVAudioSession：管理应用的音频行为，处理音频焦点和中断
 * - VideoPlayer：SwiftUI 内置的视频播放器组件，封装 AVPlayerViewController
 * - @Observable：iOS 17+ 的响应式状态管理，替代 ObservableObject
 * - NotificationCenter：监听播放完成事件，实现循环播放
 * - Environment：获取系统环境值，如窗口类型、场景状态等
 * - fullScreenCover：模态全屏展示，提供沉浸式播放体验
 * - scenePhase：监听应用前后台切换，管理播放状态
 * - 条件编译：针对 macCatalyst、visionOS 等平台的差异化处理
 * - 音频焦点：通过 AVAudioSession 管理音频播放优先级和混音
 */

// 导入 AVKit 框架，提供视频播放功能
import AVKit
// 导入 DesignSystem 模块，提供主题配置
import DesignSystem
// 导入 Env 模块，提供用户偏好设置
import Env
// 导入 Models 模块，提供媒体附件模型
import Models
// 导入 Observation 框架，提供现代状态管理
import Observation
// 导入 SwiftUI 框架，提供视图构建功能
import SwiftUI

// 使用 @MainActor 确保视频播放视图模型在主线程运行
@MainActor
// 使用 @Observable 宏实现响应式状态管理
@Observable public class MediaUIAttachmentVideoViewModel {
  // AVPlayer 实例，核心视频播放器
  var player: AVPlayer?
  // 视频文件的 URL
  let url: URL
  // 是否强制自动播放标识
  let forceAutoPlay: Bool
  // 当前播放状态
  var isPlaying: Bool = false

  // 公共初始化方法
  public init(url: URL, forceAutoPlay: Bool = false) {
    self.url = url
    self.forceAutoPlay = forceAutoPlay
  }

  // 准备播放器，配置播放参数
  func preparePlayer(autoPlay: Bool, isCompact: Bool) {
    // 创建 AVPlayer 实例
    player = .init(url: url)
    // 设置后台播放策略为暂停
    player?.audiovisualBackgroundPlaybackPolicy = .pauses
    // 在非 visionOS 平台设置屏幕休眠控制
    #if !os(visionOS)
      player?.preventsDisplaySleepDuringVideoPlayback = false
    #endif
    // 根据自动播放设置和紧凑模式决定是否开始播放
    if autoPlay || forceAutoPlay, !isCompact {
      // 开始播放
      player?.play()
      isPlaying = true
    } else {
      // 暂停播放
      player?.pause()
      isPlaying = false
    }
    // 确保播放器存在
    guard let player else { return }
    // 添加播放完成通知监听器
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: player.currentItem, queue: .main
    ) { _ in
      // 使用 MainActor 和弱引用避免循环引用
      Task { @MainActor [weak self] in
        // 如果是自动播放或强制播放，则重新开始播放
        if autoPlay || self?.forceAutoPlay == true {
          self?.play()
        }
      }
    }
  }

  // 设置静音状态
  func mute(_ mute: Bool) {
    player?.isMuted = mute
  }

  // 暂停播放
  func pause() {
    isPlaying = false
    player?.pause()
  }

  // 停止播放并清理资源
  func stop() {
    isPlaying = false
    player?.pause()
    player = nil
  }

  // 从头开始播放
  func play() {
    isPlaying = true
    // 跳转到视频开始位置
    player?.seek(to: CMTime.zero)
    player?.play()
  }

  // 恢复播放（从当前位置）
  func resume() {
    isPlaying = true
    player?.play()
  }

  // 设置是否阻止屏幕休眠
  func preventSleep(_ preventSleep: Bool) {
    // 在非 visionOS 平台设置屏幕休眠控制
    #if !os(visionOS)
      player?.preventsDisplaySleepDuringVideoPlayback = preventSleep
    #endif
  }

  // 析构函数，清理通知监听器
  deinit {
    NotificationCenter.default.removeObserver(
      self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
  }
}

// 使用 @MainActor 确保视频附件视图在主线程运行
@MainActor
// 定义公共的媒体视频附件视图结构体
public struct MediaUIAttachmentVideoView: View {
  // 从环境中获取打开窗口函数
  @Environment(\.openWindow) private var openWindow
  // 从环境中获取场景生命周期状态
  @Environment(\.scenePhase) private var scenePhase
  // 从环境中获取是否为 Catalyst 窗口标识
  @Environment(\.isCatalystWindow) private var isCatalystWindow
  // 从环境中获取是否为紧凑媒体模式标识
  @Environment(\.isMediaCompact) private var isCompact
  // 从环境中获取用户偏好设置
  @Environment(UserPreferences.self) private var preferences
  // 从环境中获取应用主题配置
  @Environment(Theme.self) private var theme

  // 视频播放视图模型状态
  @State var viewModel: MediaUIAttachmentVideoViewModel
  // 是否全屏显示状态
  @State var isFullScreen: Bool = false

  // 公共初始化方法，接收视图模型
  public init(viewModel: MediaUIAttachmentVideoViewModel) {
    _viewModel = .init(wrappedValue: viewModel)
  }

  // 视图主体，定义视频播放界面的 UI 结构
  public var body: some View {
    videoView
      // 添加覆盖层，处理点击交互
      .overlay(content: {
        // 如果是 Catalyst 窗口，不添加覆盖层
        if isCatalystWindow {
          EmptyView()
        } else {
          // 添加透明的可点击区域
          HStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
              // 如果不是自动播放且未播放，则开始播放
              if !preferences.autoPlayVideo && !viewModel.isPlaying {
                viewModel.play()
                return
              }
              // 根据平台进行不同的处理
              #if targetEnvironment(macCatalyst)
                // macCatalyst 环境下暂停并打开新窗口
                viewModel.pause()
                let attachement = MediaAttachment.videoWith(url: viewModel.url)
                openWindow(
                  value: WindowDestinationMedia.mediaViewer(
                    attachments: [attachement], selectedAttachment: attachement))
              #else
                // 其他平台切换全屏模式
                isFullScreen = true
              #endif
            }
        }
      })
      // 视图出现时的初始化
      .onAppear {
        // 准备播放器，设置自动播放状态
        viewModel.preparePlayer(
          autoPlay: isFullScreen ? true : preferences.autoPlayVideo,
          isCompact: isCompact)
        // 设置静音状态
        viewModel.mute(preferences.muteVideo)
      }
      // 视图消失时停止播放
      .onDisappear {
        viewModel.stop()
      }
      // 全屏模态视图
      .fullScreenCover(isPresented: $isFullScreen) {
        modalPreview
      }
      // 设置圆角
      .cornerRadius(4)
      // 监听场景状态变化
      .onChange(of: scenePhase) { _, newValue in
        switch newValue {
        case .background, .inactive:
          // 应用进入后台或非活跃状态时暂停播放
          viewModel.pause()
        case .active:
          // 应用激活时根据设置决定是否播放
          if (preferences.autoPlayVideo || viewModel.forceAutoPlay || isFullScreen) && !isCompact {
            viewModel.play()
          }
        default:
          break
        }
      }
  }

  // 全屏模态预览视图
  private var modalPreview: some View {
    NavigationStack {
      videoView
        // 配置工具栏
        .toolbar {
          // 关闭按钮
          ToolbarItem(placement: .topBarLeading) {
            Button {
              isFullScreen.toggle()
            } label: {
              Image(systemName: "xmark.circle")
            }
          }
          // 快速预览工具栏项
          QuickLookToolbarItem(itemUrl: viewModel.url)
        }
    }
    // 全屏视图出现时的音频会话配置
    .onAppear {
      // 在后台队列配置音频会话
      DispatchQueue.global().async {
        // 停用当前音频会话，通知其他应用
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // 设置播放类别，降低其他音频
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        // 激活音频会话
        try? AVAudioSession.sharedInstance().setActive(true)
      }
      // 阻止屏幕休眠
      viewModel.preventSleep(true)
      // 取消静音
      viewModel.mute(false)
      // 延迟启动播放
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        if isCompact || !preferences.autoPlayVideo {
          // 从头开始播放
          viewModel.play()
        } else {
          // 恢复播放
          viewModel.resume()
        }
      }
    }
    // 全屏视图消失时的清理
    .onDisappear {
      // 根据设置决定是否暂停
      if isCompact || !preferences.autoPlayVideo {
        viewModel.pause()
      }
      // 恢复屏幕休眠设置
      viewModel.preventSleep(false)
      // 恢复静音设置
      viewModel.mute(preferences.muteVideo)
      // 在后台队列恢复音频会话
      DispatchQueue.global().async {
        // 停用音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // 设置环境音频类别，允许混音
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        // 激活音频会话
        try? AVAudioSession.sharedInstance().setActive(true)
      }
    }
  }

  // 视频播放器视图
  private var videoView: some View {
    VideoPlayer(
      player: viewModel.player,
      videoOverlay: {
        // 在特定条件下显示播放按钮覆盖层
        if !preferences.autoPlayVideo,
          !viewModel.forceAutoPlay,
          !isFullScreen,
          !viewModel.isPlaying,
          !isCompact
        {
          Button(
            action: {
              // 开始播放
              viewModel.play()
            },
            label: {
              Image(systemName: "play.fill")
                // 根据紧凑模式设置字体大小
                .font(isCompact ? .body : .largeTitle)
                // 设置前景色为主题色
                .foregroundColor(theme.tintColor)
                // 设置内边距
                .padding(.all, isCompact ? 6 : nil)
                // 添加圆形背景
                .background(Circle().fill(.thinMaterial))
                // 根据显示样式设置外边距
                .padding(theme.statusDisplayStyle == .compact ? 0 : 10)
            })
        }
      }
    )
    // 添加媒体会话可访问性特征
    .accessibilityAddTraits(.startsMediaSession)
    // 忽略安全区域
    .ignoresSafeArea()
  }
}

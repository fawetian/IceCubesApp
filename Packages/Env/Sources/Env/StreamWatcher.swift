// 文件功能：实时流监听核心类
//
// 核心职责：
// - 通过 WebSocket 连接到 Mastodon 实时流 API
// - 监听时间线的实时更新（新帖子、通知、删除等）
// - 管理多个流的订阅（公共流、本地流、用户流等）
// - 处理连接断开和自动重连
// - 解析和分发流事件
//
// 技术要点：
// - @Observable：使用 Swift Observation 框架，支持 SwiftUI 响应式更新
// - @MainActor：确保所有 UI 相关操作在主线程执行
// - WebSocket：使用 URLSessionWebSocketTask 实现实时通信
// - 自动重连：连接失败时自动重试，延迟递增
// - 事件解析：将 JSON 流事件解析为强类型事件对象
//
// 流类型：
// - federated：联邦时间线（所有实例的公开帖子）
// - local：本地时间线（本实例的公开帖子）
// - user：用户时间线（关注的人的帖子和通知）
// - direct：私信流
//
// 事件类型：
// - update：新帖子
// - status.update：帖子编辑
// - delete：帖子删除
// - notification：新通知
// - conversation：新对话
//
// 依赖关系：
// - 依赖：Foundation, Models, NetworkClient, OSLog
// - 被依赖：时间线视图、通知视图等需要实时更新的组件

import Combine
import Foundation
import Models
import NetworkClient
import OSLog
import Observation

/// 实时流监听器
///
/// 通过 WebSocket 连接到 Mastodon 的实时流 API，监听时间线的实时更新。
///
/// 主要功能：
/// - **实时更新**：接收新帖子、通知、删除等事件
/// - **多流订阅**：同时监听多个流（公共、本地、用户等）
/// - **自动重连**：连接断开时自动重试
/// - **事件分发**：将流事件解析并分发给订阅者
/// - **未读计数**：跟踪未读通知数量
///
/// 使用方式：
/// ```swift
/// // 设置客户端
/// StreamWatcher.shared.setClient(
///     client: mastodonClient,
///     instanceStreamingURL: streamingURL
/// )
///
/// // 开始监听
/// StreamWatcher.shared.watch(streams: [.user, .local])
///
/// // 在视图中响应事件
/// struct TimelineView: View {
///     @Environment(StreamWatcher.self) private var watcher
///
///     var body: some View {
///         List {
///             // 显示时间线内容
///         }
///         .onChange(of: watcher.latestEvent) { _, event in
///             if let update = event as? StreamEventUpdate {
///                 // 处理新帖子
///                 handleNewStatus(update.status)
///             }
///         }
///     }
/// }
///
/// // 停止监听
/// StreamWatcher.shared.stopWatching()
/// ```
///
/// 工作流程：
/// 1. 设置客户端和流 URL
/// 2. 建立 WebSocket 连接
/// 3. 订阅指定的流
/// 4. 接收并解析流事件
/// 5. 更新事件列表和未读计数
/// 6. 连接断开时自动重连
///
/// 重连策略：
/// - 初始延迟：10 秒
/// - 每次失败后延迟增加 30 秒
/// - 自动重新订阅之前的流
///
/// - Note: 使用单例模式，通过 `StreamWatcher.shared` 访问
/// - Important: 所有操作都在主线程执行，确保 UI 安全
/// - SeeAlso: `StreamEvent` 定义了所有可能的流事件类型
@MainActor
@Observable public class StreamWatcher {
  /// Mastodon 客户端
  ///
  /// 用于创建 WebSocket 连接和认证。
  private var client: MastodonClient?
  
  /// WebSocket 任务
  ///
  /// 实际的 WebSocket 连接，用于接收实时事件。
  private var task: URLSessionWebSocketTask?
  
  /// 当前监听的流列表
  ///
  /// 保存已订阅的流，用于重连时重新订阅。
  private var watchedStreams: [Stream] = []
  
  /// 实例的流 URL
  ///
  /// 某些实例可能使用自定义的流服务器地址。
  private var instanceStreamingURL: URL?

  /// JSON 解码器
  ///
  /// 用于解析流事件的 JSON 数据。
  private let decoder = JSONDecoder()
  
  /// JSON 编码器
  ///
  /// 用于编码订阅消息。
  private let encoder = JSONEncoder()

  /// 重试延迟（秒）
  ///
  /// 连接失败后的重试延迟，每次失败后增加 30 秒。
  private var retryDelay: Int = 10

  /// 流类型枚举
  ///
  /// 定义了 Mastodon 支持的所有流类型。
  public enum Stream: String {
    /// 联邦时间线
    ///
    /// 所有已知实例的公开帖子。
    case federated = "public"
    
    /// 本地时间线
    ///
    /// 本实例的公开帖子。
    case local
    
    /// 用户流
    ///
    /// 当前用户的主时间线和通知。
    case user
    
    /// 私信流
    ///
    /// 私信对话。
    case direct
  }

  /// 所有接收到的事件
  ///
  /// 按时间顺序保存所有流事件。
  ///
  /// 使用场景：
  /// - 调试和日志
  /// - 事件历史查看
  /// - 批量处理事件
  public var events: [any StreamEvent] = []
  
  /// 未读通知数量
  ///
  /// 跟踪通过流接收到的未读通知数量。
  ///
  /// 特点：
  /// - 只计算非私信通知
  /// - 用于显示角标
  /// - 需要手动清零
  public var unreadNotificationsCount: Int = 0
  
  /// 最新事件
  ///
  /// 最近接收到的流事件。
  ///
  /// 使用场景：
  /// - 在视图中使用 onChange 监听
  /// - 触发 UI 更新
  /// - 显示实时提示
  ///
  /// 示例：
  /// ```swift
  /// .onChange(of: watcher.latestEvent) { _, event in
  ///     if let update = event as? StreamEventUpdate {
  ///         showNewPostBanner(update.status)
  ///     }
  /// }
  /// ```
  public var latestEvent: (any StreamEvent)?

  /// 日志记录器
  ///
  /// 用于记录流连接和事件的日志。
  private let logger = Logger(subsystem: "com.icecubesapp", category: "stream")

  /// 单例实例
  ///
  /// 全局共享的流监听器实例。
  public static let shared = StreamWatcher()

  /// 私有初始化方法
  ///
  /// 配置 JSON 解码器的键转换策略。
  private init() {
    // 将 snake_case 转换为 camelCase
    decoder.keyDecodingStrategy = .convertFromSnakeCase
  }

  /// 设置客户端
  ///
  /// 配置 Mastodon 客户端和流 URL，并建立连接。
  ///
  /// - Parameters:
  ///   - client: Mastodon 客户端
  ///   - instanceStreamingURL: 实例的流服务器 URL（可选）
  ///
  /// 执行流程：
  /// 1. 如果已有客户端，先停止监听
  /// 2. 设置新的客户端和流 URL
  /// 3. 建立 WebSocket 连接
  ///
  /// 使用场景：
  /// - 用户登录后
  /// - 切换账户时
  /// - 应用启动时
  ///
  /// 示例：
  /// ```swift
  /// let client = MastodonClient(server: "mastodon.social", oauthToken: token)
  /// StreamWatcher.shared.setClient(
  ///     client: client,
  ///     instanceStreamingURL: URL(string: "wss://streaming.mastodon.social")
  /// )
  /// ```
  public func setClient(client: MastodonClient, instanceStreamingURL: URL?) {
    if self.client != nil {
      stopWatching()
    }
    self.client = client
    self.instanceStreamingURL = instanceStreamingURL
    connect()
  }

  /// 建立 WebSocket 连接
  ///
  /// 创建并启动 WebSocket 任务，开始接收消息。
  ///
  /// 执行流程：
  /// 1. 使用客户端创建 WebSocket 任务
  /// 2. 启动任务
  /// 3. 开始接收消息
  ///
  /// - Note: 如果创建任务失败，会静默返回
  private func connect() {
    guard
      let task = try? client?.makeWebSocketTask(
        endpoint: Streaming.streaming,
        instanceStreamingURL: instanceStreamingURL
      )
    else {
      return
    }
    self.task = task
    self.task?.resume()
    receiveMessage()
  }

  /// 开始监听指定的流
  ///
  /// 订阅一个或多个流，开始接收实时事件。
  ///
  /// - Parameter streams: 要监听的流列表
  ///
  /// 执行流程：
  /// 1. 检查客户端是否已认证
  /// 2. 如果连接不存在，先建立连接
  /// 3. 保存监听的流列表
  /// 4. 向服务器发送订阅消息
  ///
  /// 使用场景：
  /// - 进入时间线页面时
  /// - 用户选择要监听的流
  /// - 应用进入前台时
  ///
  /// 示例：
  /// ```swift
  /// // 监听用户流和本地流
  /// StreamWatcher.shared.watch(streams: [.user, .local])
  ///
  /// // 只监听用户流
  /// StreamWatcher.shared.watch(streams: [.user])
  /// ```
  ///
  /// - Note: 如果客户端未认证，此方法不会执行任何操作
  public func watch(streams: [Stream]) {
    if client?.isAuth == false {
      return
    }
    if task == nil {
      connect()
    }
    watchedStreams = streams
    for stream in streams {
      sendMessage(message: StreamMessage(type: "subscribe", stream: stream.rawValue))
    }
  }

  /// 停止监听
  ///
  /// 取消 WebSocket 连接，停止接收事件。
  ///
  /// 使用场景：
  /// - 用户登出时
  /// - 切换账户时
  /// - 应用进入后台时
  /// - 离开时间线页面时
  ///
  /// 示例：
  /// ```swift
  /// // 在视图消失时停止监听
  /// .onDisappear {
  ///     StreamWatcher.shared.stopWatching()
  /// }
  /// ```
  public func stopWatching() {
    task?.cancel()
    task = nil
  }

  /// 发送消息到服务器
  ///
  /// 将订阅消息编码并通过 WebSocket 发送。
  ///
  /// - Parameter message: 要发送的流消息
  ///
  /// 消息格式：
  /// ```json
  /// {
  ///   "type": "subscribe",
  ///   "stream": "user"
  /// }
  /// ```
  ///
  /// - Note: 如果编码失败，会静默忽略
  private func sendMessage(message: StreamMessage) {
    if let encodedMessage = try? encoder.encode(message),
      let stringMessage = String(data: encodedMessage, encoding: .utf8)
    {
      task?.send(.string(stringMessage), completionHandler: { _ in })
    }
  }

  /// 接收消息
  ///
  /// 从 WebSocket 接收消息并处理。
  ///
  /// 处理流程：
  /// 1. 接收 WebSocket 消息
  /// 2. 成功时：
  ///    - 解析 JSON 字符串
  ///    - 转换为强类型事件
  ///    - 添加到事件列表
  ///    - 更新未读计数
  ///    - 继续接收下一条消息
  /// 3. 失败时：
  ///    - 等待重试延迟
  ///    - 增加延迟时间
  ///    - 重新连接
  ///    - 重新订阅流
  ///
  /// 事件处理：
  /// - update：新帖子发布
  /// - status.update：帖子被编辑
  /// - delete：帖子被删除
  /// - notification：新通知
  /// - conversation：新对话
  ///
  /// 重连策略：
  /// - 初始延迟：10 秒
  /// - 每次失败增加：30 秒
  /// - 自动重新订阅之前的流
  ///
  /// - Note: 使用递归调用持续接收消息
  private func receiveMessage() {
    task?.receive(completionHandler: { [weak self] result in
      guard let self else { return }
      switch result {
      case let .success(message):
        switch message {
        case let .string(string):
          do {
            guard let data = string.data(using: .utf8) else {
              logger.error("Error decoding streaming event string")
              return
            }
            let rawEvent = try decoder.decode(RawStreamEvent.self, from: data)
            logger.info("Stream update: \(rawEvent.event)")
            Task { @MainActor in
              if let event = self.rawEventToEvent(rawEvent: rawEvent) {
                // 添加到事件列表
                self.events.append(event)
                self.latestEvent = event
                // 更新未读通知计数（排除私信）
                if let event = event as? StreamEventNotification,
                  event.notification.status?.visibility != .direct
                {
                  self.unreadNotificationsCount += 1
                }
              }
            }
          } catch {
            logger.error("Error decoding streaming event: \(error.localizedDescription)")
          }

        default:
          break
        }

        // 继续接收下一条消息
        Task { @MainActor in
          self.receiveMessage()
        }

      case .failure:
        // 连接失败，自动重连
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(self.retryDelay))
          self.retryDelay += 30
          self.stopWatching()
          self.connect()
          self.watch(streams: self.watchedStreams)
        }
      }
    })
  }

  /// 将原始事件转换为强类型事件
  ///
  /// 根据事件类型解析 JSON payload 并创建对应的事件对象。
  ///
  /// - Parameter rawEvent: 原始流事件
  /// - Returns: 强类型的流事件，如果解析失败返回 nil
  ///
  /// 支持的事件类型：
  /// - **update**：新帖子发布
  ///   - Payload：Status 对象
  ///   - 返回：StreamEventUpdate
  ///
  /// - **status.update**：帖子被编辑
  ///   - Payload：更新后的 Status 对象
  ///   - 返回：StreamEventStatusUpdate
  ///
  /// - **delete**：帖子被删除
  ///   - Payload：帖子 ID 字符串
  ///   - 返回：StreamEventDelete
  ///
  /// - **notification**：新通知
  ///   - Payload：Notification 对象
  ///   - 返回：StreamEventNotification
  ///
  /// - **conversation**：新对话
  ///   - Payload：Conversation 对象
  ///   - 返回：StreamEventConversation
  ///
  /// 错误处理：
  /// - 如果 payload 无法转换为 UTF-8，返回 nil
  /// - 如果 JSON 解析失败，记录错误并返回 nil
  /// - 如果事件类型未知，返回 nil
  ///
  /// - Note: 解析失败时会记录详细的错误日志
  private func rawEventToEvent(rawEvent: RawStreamEvent) -> (any StreamEvent)? {
    guard let payloadData = rawEvent.payload.data(using: .utf8) else {
      return nil
    }
    do {
      switch rawEvent.event {
      case "update":
        let status = try decoder.decode(Status.self, from: payloadData)
        return StreamEventUpdate(status: status)
      case "status.update":
        let status = try decoder.decode(Status.self, from: payloadData)
        return StreamEventStatusUpdate(status: status)
      case "delete":
        return StreamEventDelete(status: rawEvent.payload)
      case "notification":
        let notification = try decoder.decode(Notification.self, from: payloadData)
        return StreamEventNotification(notification: notification)
      case "conversation":
        let conversation = try decoder.decode(Conversation.self, from: payloadData)
        return StreamEventConversation(conversation: conversation)
      default:
        return nil
      }
    } catch {
      logger.error("Error decoding streaming event to final event: \(error.localizedDescription)")
      logger.error("Raw data: \(rawEvent.payload)")
      return nil
    }
  }

  /// 手动触发删除事件
  ///
  /// 当本地删除帖子时，手动创建删除事件以更新 UI。
  ///
  /// - Parameter status: 被删除的帖子 ID
  ///
  /// 使用场景：
  /// - 用户删除自己的帖子
  /// - 需要立即更新 UI，不等待流事件
  ///
  /// 示例：
  /// ```swift
  /// // 删除帖子后立即触发事件
  /// try await client.delete(endpoint: Statuses.status(id: statusId))
  /// StreamWatcher.shared.emmitDeleteEvent(for: statusId)
  /// ```
  public func emmitDeleteEvent(for status: String) {
    let event = StreamEventDelete(status: status)
    events.append(event)
    latestEvent = event
  }

  /// 手动触发编辑事件
  ///
  /// 当本地编辑帖子时，手动创建编辑事件以更新 UI。
  ///
  /// - Parameter status: 编辑后的帖子对象
  ///
  /// 使用场景：
  /// - 用户编辑自己的帖子
  /// - 需要立即更新 UI，不等待流事件
  ///
  /// 示例：
  /// ```swift
  /// // 编辑帖子后立即触发事件
  /// let updatedStatus = try await client.put(endpoint: Statuses.editStatus(...))
  /// StreamWatcher.shared.emmitEditEvent(for: updatedStatus)
  /// ```
  public func emmitEditEvent(for status: Status) {
    let event = StreamEventStatusUpdate(status: status)
    events.append(event)
    latestEvent = event
  }

  /// 手动触发发帖事件
  ///
  /// 当本地发布新帖子时，手动创建发帖事件以更新 UI。
  ///
  /// - Parameter status: 新发布的帖子对象
  ///
  /// 使用场景：
  /// - 用户发布新帖子
  /// - 需要立即在时间线中显示，不等待流事件
  ///
  /// 示例：
  /// ```swift
  /// // 发布帖子后立即触发事件
  /// let newStatus = try await client.post(endpoint: Statuses.postStatus(...))
  /// StreamWatcher.shared.emmitPostEvent(for: newStatus)
  /// ```
  public func emmitPostEvent(for status: Status) {
    let event = StreamEventUpdate(status: status)
    events.append(event)
    latestEvent = event
  }
}

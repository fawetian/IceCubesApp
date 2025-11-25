/*
 * EditAccountViewModel.swift
 * IceCubesApp - 编辑账户资料视图模型
 *
 * 文件功能：
 * 管理账户资料编辑的所有状态和逻辑。
 *
 * 核心职责：
 * - 加载当前账户资料
 * - 管理编辑表单状态（显示名称、简介、自定义字段等）
 * - 处理头像和横幅图片上传
 * - 保存资料修改到服务器
 * - 图片压缩和尺寸限制
 *
 * 技术要点：
 * - @Observable 管理状态
 * - PhotosPicker 集成
 * - 图片压缩（2MB 限制）
 * - 异步上传和保存
 * - FieldEditViewModel 嵌套模型
 *
 * 使用场景：
 * - EditAccountView 的数据管理
 * - 账户资料编辑
 * - 头像/横幅上传
 *
 * 依赖关系：
 * - Models: Account、Visibility
 * - NetworkClient: Accounts、Profile 端点
 * - StatusKit: 图片压缩器
 * - PhotosUI: PhotosPicker
 */

import Models
import NetworkClient
import Observation
import PhotosUI
import StatusKit
import SwiftUI

/// 编辑账户资料视图模型。
///
/// 管理资料编辑的所有状态和操作。
@MainActor
@Observable class EditAccountViewModel {
  /// 自定义字段编辑模型。
  @Observable class FieldEditViewModel: Identifiable {
    /// 唯一标识符。
    let id = UUID().uuidString
    /// 字段名称。
    var name: String = ""
    /// 字段值。
    var value: String = ""

    /// 初始化方法。
    init(name: String, value: String) {
      self.name = name
      self.value = value
    }
  }

  /// Mastodon 客户端。
  public var client: MastodonClient?

  /// 显示名称。
  var displayName: String = ""
  /// 个人简介。
  var note: String = ""
  /// 默认帖子可见性。
  var postPrivacy = Models.Visibility.pub
  /// 默认标记为敏感内容。
  var isSensitive: Bool = false
  /// 是否为机器人账户。
  var isBot: Bool = false
  /// 是否锁定账户（需要批准关注请求）。
  var isLocked: Bool = false
  /// 是否可被发现（允许出现在推荐中）。
  var isDiscoverable: Bool = false
  /// 自定义字段列表。
  var fields: [FieldEditViewModel] = []
  /// 头像 URL。
  var avatar: URL?
  /// 横幅 URL。
  var header: URL?

  /// 是否显示图片选择器。
  var isPhotoPickerPresented: Bool = false {
    didSet {
      if !isPhotoPickerPresented, mediaPickers.isEmpty {
        isChangingAvatar = false
        isChangingHeader = false
      }
    }
  }

  /// 是否正在更改头像。
  var isChangingAvatar: Bool = false
  /// 是否正在更改横幅。
  var isChangingHeader: Bool = false

  /// 是否正在加载账户数据。
  var isLoading: Bool = true
  /// 是否正在保存修改。
  var isSaving: Bool = false
  /// 是否保存失败。
  var saveError: Bool = false

  /// 图片选择器选中的项目。
  var mediaPickers: [PhotosPickerItem] = [] {
    didSet {
      if let item = mediaPickers.first {
        Task {
          if isChangingAvatar {
            if let data = await getItemImageData(item: item, for: .avatar) {
              _ = await uploadAvatar(data: data)
            }
            isChangingAvatar = false
          } else if isChangingHeader {
            if let data = await getItemImageData(item: item, for: .header) {
              _ = await uploadHeader(data: data)
            }
            isChangingHeader = false
          }
          await fetchAccount()
          mediaPickers = []
        }
      }
    }
  }

  /// 初始化方法。
  init() {}

  /// 拉取当前账户资料。
  ///
  /// 加载账户的所有可编辑字段。
  func fetchAccount() async {
    guard let client else { return }
    do {
      let account: Account = try await client.get(endpoint: Accounts.verifyCredentials)
      displayName = account.displayName ?? ""
      note = account.source?.note ?? ""
      postPrivacy = account.source?.privacy ?? .pub
      isSensitive = account.source?.sensitive ?? false
      isBot = account.bot
      isLocked = account.locked
      isDiscoverable = account.discoverable ?? false
      avatar = account.haveAvatar ? account.avatar : nil
      header = account.haveHeader ? account.header : nil
      fields = account.source?.fields.map { .init(name: $0.name, value: $0.value.asRawText) } ?? []
      withAnimation {
        isLoading = false
      }
    } catch {}
  }

  /// 保存账户资料修改。
  ///
  /// 将所有编辑后的字段提交到服务器。
  func save() async {
    isSaving = true
    do {
      let data = UpdateCredentialsData(
        displayName: displayName,
        note: note,
        source: .init(privacy: postPrivacy, sensitive: isSensitive),
        bot: isBot,
        locked: isLocked,
        discoverable: isDiscoverable,
        fieldsAttributes: fields.map { .init(name: $0.name, value: $0.value) })
      let response = try await client?.patch(endpoint: Accounts.updateCredentials(json: data))
      if response?.statusCode != 200 {
        saveError = true
      }
      isSaving = false
    } catch {
      isSaving = false
      saveError = true
    }
  }

  /// 删除头像。
  ///
  /// - Returns: 是否删除成功。
  func deleteAvatar() async -> Bool {
    guard let client else { return false }
    do {
      let response = try await client.delete(endpoint: Profile.deleteAvatar)
      avatar = nil
      return response?.statusCode == 200
    } catch {
      return false
    }
  }

  /// 删除横幅。
  ///
  /// - Returns: 是否删除成功。
  func deleteHeader() async -> Bool {
    guard let client else { return false }
    do {
      let response = try await client.delete(endpoint: Profile.deleteHeader)
      header = nil
      return response?.statusCode == 200
    } catch {
      return false
    }
  }

  /// 上传横幅图片。
  ///
  /// - Parameter data: 图片数据（JPEG 格式）。
  /// - Returns: 是否上传成功。
  private func uploadHeader(data: Data) async -> Bool {
    guard let client else { return false }
    do {
      let response = try await client.mediaUpload(
        endpoint: Accounts.updateCredentialsMedia,
        version: .v1,
        method: "PATCH",
        mimeType: "image/jpeg",
        filename: "header",
        data: data)
      return response?.statusCode == 200
    } catch {
      return false
    }
  }

  /// 上传头像图片。
  ///
  /// - Parameter data: 图片数据（JPEG 格式）。
  /// - Returns: 是否上传成功。
  private func uploadAvatar(data: Data) async -> Bool {
    guard let client else { return false }
    do {
      let response = try await client.mediaUpload(
        endpoint: Accounts.updateCredentialsMedia,
        version: .v1,
        method: "PATCH",
        mimeType: "image/jpeg",
        filename: "avatar",
        data: data)
      return response?.statusCode == 200
    } catch {
      return false
    }
  }

  /// 从 PhotosPickerItem 获取并压缩图片数据。
  ///
  /// - Parameters:
  ///   - item: 选择的图片项目。
  ///   - type: 图片类型（头像或横幅）。
  /// - Returns: 压缩后的图片数据（最大 2MB）。
  private func getItemImageData(item: PhotosPickerItem, for type: ItemType) async -> Data? {
    guard
      let imageFile = try? await item.loadTransferable(
        type: StatusEditor.ImageFileTranseferable.self)
    else { return nil }

    let compressor = StatusEditor.Compressor()

    guard let compressedData = await compressor.compressImageFrom(url: imageFile.url),
      let image = UIImage(data: compressedData),
      let uploadData = try? await compressor.compressImageForUpload(
        image,
        maxSize: 2 * 1024 * 1024,  // 2MB
        maxHeight: type.maxHeight,
        maxWidth: type.maxWidth
      )
    else {
      return nil
    }

    return uploadData
  }
}

extension EditAccountViewModel {
  /// 图片类型枚举。
  private enum ItemType {
    /// 头像（400x400）。
    case avatar
    /// 横幅（1500x500）。
    case header

    /// 最大高度。
    var maxHeight: CGFloat {
      switch self {
      case .avatar:
        400
      case .header:
        500
      }
    }

    /// 最大宽度。
    var maxWidth: CGFloat {
      switch self {
      case .avatar:
        400
      case .header:
        1500
      }
    }
  }
}

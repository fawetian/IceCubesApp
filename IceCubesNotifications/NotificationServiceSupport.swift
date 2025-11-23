// 文件功能说明：
// 该文件为通知服务提供加密解密支持功能，实现了 Web Push 协议的端到端加密机制。使用椭圆曲线加密和 AES-GCM 对称加密算法，确保推送通知内容在传输过程中的安全性和隐私保护。
// 技术点：
// 1. 椭圆曲线密钥协商 —— 使用 P256 椭圆曲线进行密钥交换。
// 2. HKDF 密钥派生 —— 基于 HMAC 的密钥派生函数。
// 3. AES-GCM 加密 —— 高级加密标准的 Galois/Counter 模式。
// 4. Web Push 协议 —— 遵循 RFC 8291 的 Web Push 加密标准。
// 5. CryptoKit 框架 —— 使用苹果的现代加密框架。
// 6. 数据填充处理 —— 处理加密数据的填充机制。
// 7. 密钥材料管理 —— 安全地处理各种密钥材料。
// 8. 内容编码 —— 支持 "aesgcm" 内容编码格式。
// 9. 随机数处理 —— 安全地处理加密随机数。
// 10. 二进制数据操作 —— 高效的二进制数据处理。
//
// 技术点详解：
// - P256 椭圆曲线：NIST 标准的椭圆曲线，提供 256 位安全级别
// - 密钥协商：ECDH 算法实现客户端和服务器间的安全密钥交换
// - HKDF：从共享密钥派生出用于加密和认证的具体密钥
// - AES-GCM：提供加密和认证的组合模式，确保数据完整性
// - Web Push 标准：确保与标准 Web Push 服务的兼容性
// - 内容编码：处理 HTTP 内容编码头，支持不同的加密格式
// - 填充移除：正确处理加密数据的填充，恢复原始内容
// - 安全编程：使用 guard 语句和可选绑定确保安全性
// - 内存安全：使用 withUnsafeBytes 进行高效的内存操作
// - 错误处理：完善的错误处理机制，确保解密过程的健壮性

// 引入 CryptoKit 框架，提供现代化的加密功能
import CryptoKit
// 引入 Foundation 框架，提供基础数据类型和操作
import Foundation

// 为 NotificationService 添加解密功能的扩展
extension NotificationService {
  // 解密推送通知负载的静态方法
  // 参数：payload - 加密的负载数据，salt - 盐值，auth - 认证密钥，privateKey - 客户端私钥，publicKey - 服务器公钥
  // 返回：解密后的明文数据，失败时返回 nil
  static func decrypt(
    payload: Data, salt: Data, auth: Data, privateKey: P256.KeyAgreement.PrivateKey,
    publicKey: P256.KeyAgreement.PublicKey
  ) -> Data? {
    // 使用椭圆曲线密钥协商算法生成共享密钥
    guard let sharedSecret = try? privateKey.sharedSecretFromKeyAgreement(with: publicKey) else {
      return nil
    }

    // 使用 HKDF 从共享密钥派生认证密钥材料
    let keyMaterial = sharedSecret.hkdfDerivedSymmetricKey(
      using: SHA256.self,                           // 使用 SHA256 哈希算法
      salt: auth,                                   // 认证密钥作为盐值
      sharedInfo: Data("Content-Encoding: auth\0".utf8), // 标准的信息字符串
      outputByteCount: 32)                          // 输出 32 字节密钥

    // 构建用于 AES 密钥派生的信息数据
    let keyInfo = info(
      type: "aesgcm",                               // 内容编码类型
      clientPublicKey: privateKey.publicKey.x963Representation, // 客户端公钥
      serverPublicKey: publicKey.x963Representation) // 服务器公钥
    
    // 使用 HKDF 派生 AES 加密密钥
    let key = HKDF<SHA256>.deriveKey(
      inputKeyMaterial: keyMaterial,                // 输入密钥材料
      salt: salt,                                   // 盐值
      info: keyInfo,                                // 信息数据
      outputByteCount: 16)                          // AES-128 需要 16 字节密钥

    // 构建用于随机数派生的信息数据
    let nonceInfo = info(
      type: "nonce",                                // 随机数类型
      clientPublicKey: privateKey.publicKey.x963Representation, // 客户端公钥
      serverPublicKey: publicKey.x963Representation) // 服务器公钥
    
    // 使用 HKDF 派生加密随机数
    let nonce = HKDF<SHA256>.deriveKey(
      inputKeyMaterial: keyMaterial,                // 输入密钥材料
      salt: salt,                                   // 盐值
      info: nonceInfo,                              // 信息数据
      outputByteCount: 12)                          // AES-GCM 需要 12 字节随机数

    // 将随机数转换为字节数组
    let nonceData = nonce.withUnsafeBytes(Array.init)

    // 构建 AES-GCM 密封盒子（包含随机数和加密数据）
    guard let sealedBox = try? AES.GCM.SealedBox(combined: nonceData + payload) else {
      return nil
    }

    // 尝试解密数据
    var plaintextData: Data?
    do {
      plaintextData = try AES.GCM.open(sealedBox, using: key)
    } catch {}
    
    // 检查解密是否成功
    guard let plaintext = plaintextData else {
      return nil
    }

    // 处理数据填充：前两个字节表示填充长度
    let paddingLength = Int(plaintext[0]) * 256 + Int(plaintext[1])
    
    // 验证数据长度是否足够
    guard plaintext.count >= 2 + paddingLength else {
      fatalError()
    }
    
    // 移除填充，获取真实的数据内容
    let unpadded = plaintext.suffix(from: paddingLength + 2)

    // 返回解密后的数据
    return Data(unpadded)
  }

  // 构建 HKDF 信息数据的私有方法
  // 参数：type - 编码类型，clientPublicKey - 客户端公钥，serverPublicKey - 服务器公钥
  // 返回：格式化的信息数据
  private static func info(type: String, clientPublicKey: Data, serverPublicKey: Data) -> Data {
    // 创建信息数据缓冲区
    var info = Data()

    // 添加内容编码前缀
    info.append("Content-Encoding: ".data(using: .utf8)!)
    // 添加编码类型
    info.append(type.data(using: .utf8)!)
    // 添加分隔符
    info.append(0)
    // 添加椭圆曲线标识
    info.append("P-256".data(using: .utf8)!)
    // 添加分隔符
    info.append(0)
    // 添加客户端公钥长度标识
    info.append(0)
    info.append(65)  // P-256 公钥为 65 字节
    // 添加客户端公钥数据
    info.append(clientPublicKey)
    // 添加分隔符
    info.append(0)
    // 添加服务器公钥长度标识
    info.append(65)  // P-256 公钥为 65 字节
    // 添加服务器公钥数据
    info.append(serverPublicKey)

    // 返回完整的信息数据
    return info
  }
}

#include <cstdint>
#include <jni.h>
#include <string>
#include <vector>

// 2026 Refactor: 核心安全解密层
// 理念：密钥派生自应用签名，解密逻辑在原生层执行，防御 FFI Hook

extern "C" {

// 简单的 XOR 解密，密钥将由签名动态派生
void xor_decrypt(uint8_t* data, size_t data_len, const uint8_t* key, size_t key_len) {
    for (size_t i = 0; i < data_len; i++) {
        data[i] ^= key[i % key_len];
    }
}

// 导出给 Dart FFI 使用
// 参数：加密数据，数据长度，签名哈希（由 Dart 传入或在此通过 JNI 获取）
JNIEXPORT void JNICALL
Java_com_example_address_MainActivity_decryptNative(JNIEnv* env, jobject thiz, jbyteArray data, jbyteArray sig_hash) {
    // 此函数仅作为 JNI 示例，实际 FFI 调用直接操作内存指针
}

// 2026 增强版：带容错的签名绑定解密
__attribute__((visibility("default"))) __attribute__((used))
void decrypt_with_signature(uint8_t* data, intptr_t data_len, uint8_t* sig_bytes, intptr_t sig_len) {
    if (data == nullptr || sig_bytes == nullptr || sig_len < 8) return;

    // 预设的合法签名特征（前8位），用于校验环境
    // Android 指纹: CB:8E:0E... (ci-debug.keystore)
    const uint8_t android_prefix[] = {0x43, 0x42, 0x3A, 0x38, 0x45, 0x3A, 0x30, 0x45}; 
    // iOS 指纹 (Binary Format): 7C:9F:B4:1E...
    const uint8_t ios_prefix[] = { 0x7C, 0x9F, 0xB4, 0x1E, 0xCC, 0x39, 0xBB, 0x98 };
    
    bool match = false;
    
    // Check Android (ASCII Match)
    if (sig_len >= 8) {
        bool android_match = true;
        for(int i = 0; i < 8; i++) {
            if(sig_bytes[i] != android_prefix[i]) {
                android_match = false;
                break;
            }
        }
        if (android_match) match = true;
    }

    // Check iOS (Binary Match)
    if (!match && sig_len >= 8) {
        bool ios_match = true;
        for(int i = 0; i < 8; i++) {
            if(sig_bytes[i] != ios_prefix[i]) {
                ios_match = false;
                break;
            }
        }
        if (ios_match) match = true;
    }

    if (!match) {
        // 安全加固：环境不匹配时，彻底摧毁内存数据，防止 Dart 层通过回退逻辑还原
        for (intptr_t i = 0; i < data_len; i++) {
            data[i] = 0xFF; // 填充无效数据
        }
        return;
    }

    // 环境匹配，执行深度解密
    std::vector<uint8_t> derived_key(sig_len);
    for (intptr_t i = 0; i < sig_len; i++) {
        derived_key[i] = sig_bytes[i] ^ 0xAA;
    }

    xor_decrypt(data, (size_t)data_len, derived_key.data(), derived_key.size());
}

}

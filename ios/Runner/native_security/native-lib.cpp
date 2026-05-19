#include <cstdint>
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

// 2026 增强版：带容错的签名绑定解密
// Updated to use intptr_t to match Dart FFI IntPtr (64-bit compatible)
__attribute__((visibility("default"))) __attribute__((used))
void decrypt_with_signature(uint8_t* data, intptr_t data_len, uint8_t* sig_bytes, intptr_t sig_len) {
    if (data == nullptr || sig_bytes == nullptr || sig_len < 8) return;

    // 预设的合法签名特征（前8位），用于校验环境
    // 当前指纹: 30:D6:18... -> 对应 ASCII: '3', '0', ':', 'D', '6', ':', '1', '8'
    const uint8_t expected_prefix[] = {0x33, 0x30, 0x3A, 0x44, 0x36, 0x3A, 0x31, 0x38}; 
    
    bool match = true;
    for(int i = 0; i < 8; i++) {
        if(sig_bytes[i] != expected_prefix[i]) {
            match = false;
            break;
        }
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

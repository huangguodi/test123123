#include <cstdint>
#include <jni.h>
#include <vector>

// 原生解密层：由 Dart 传入密钥材料，不再校验证书指纹前缀

extern "C" {

void xor_decrypt(uint8_t* data, size_t data_len, const uint8_t* key, size_t key_len) {
    for (size_t i = 0; i < data_len; i++) {
        data[i] ^= key[i % key_len];
    }
}

__attribute__((visibility("default"))) __attribute__((used))
void decrypt_with_signature(uint8_t* data, intptr_t data_len, uint8_t* sig_bytes, intptr_t sig_len) {
    if (data == nullptr || sig_bytes == nullptr || sig_len <= 0) return;

    std::vector<uint8_t> derived_key(sig_len);
    for (intptr_t i = 0; i < sig_len; i++) {
        derived_key[i] = sig_bytes[i] ^ 0xAA;
    }

    xor_decrypt(data, (size_t)data_len, derived_key.data(), derived_key.size());
}

}

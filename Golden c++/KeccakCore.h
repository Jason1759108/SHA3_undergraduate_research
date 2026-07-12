#ifndef KECCAK_CORE_H
#define KECCAK_CORE_H
#include <iostream>
using namespace std;

class KeccakCore {
private:
    uint64_t state[5][5]; // 5x5 的 64-bit 狀態陣列 (1600 bits)

    // Keccak-f 的 5 個內部步驟函數
    void theta();
    void rho_pi();
    void chi();
    void iota(int round);

    // 執行完整的 24 回合 Keccak-f[1600]
    void keccakF1600();

public:
    keccakCore();

    // Sponge 吸收階段
    void absorb(const uint8_t* data, size_t length, int rate);
    
    // 結尾 Padding 處理 (會依據 SHA3 或 SHAKE 傳入不同的 domain padding byte)
    void padAndAbsorb(uint8_t domain_padding, int rate);

    // Sponge 擠出階段
    void squeeze(uint8_t* output, size_t out_length, int rate);
    
    // 重設狀態
    void reset();
};


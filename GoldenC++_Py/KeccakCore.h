#ifndef KECCAK_CORE_H
#define KECCAK_CORE_H

#include <cstdint>
#include <cstddef>

class KeccakCore {
private:
    uint64_t state[5][5]; 
    size_t byte_number; // 💡 統一用這個變數來紀錄目前處理到第幾個 byte

    void theta();
    void rho_pi();
    void chi();
    void iota(int round);
    void keccakF1600();

public:
    KeccakCore(); 

    void absorb(const uint8_t* data, size_t length, int rate);
    void padAndAbsorb(uint8_t domain_padding, int rate);
    void squeeze(uint8_t* output, size_t out_length, int rate);
    void reset();
};

#endif
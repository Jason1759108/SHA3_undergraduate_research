#include "KeccakCore.h"

// 建構子
KeccakCore::KeccakCore() {
    reset();
}

// 重設狀態為全 0
void KeccakCore::reset(){
    for(int y = 0; y < 5; y++){
        for(int x = 0; x < 5; x++){
            state[y][x] = 0;
        }
    }
}

void KeccakCore::theta() {
    uint64_t C[5] = {0};
    uint64_t D[5] = {0};

    // C[x,z]=A[x, 0,z] ⊕ A[x, 1,z] ⊕ A[x, 2,z] ⊕ A[x, 3,z] ⊕ A[x, 4,z]. for  0≤x<5 and 0≤z<w
    for(int x = 0; x < 5; x++){
        C[x] = state[0][x] ^ state[1][x] ^ state[2][x] ^ state[3][x] ^ state[4][x];
    }

    // D[x,z]=C[(x-1) mod 5, z] ⊕ C[(x+1) mod 5, (z –1) mod w].             for  0≤x<5 and 0≤z<w
    for(int x = 0; x < 5; x++){
        uint64_t left = C[(x + 4) % 5];
        uint64_t right = C[(x + 1) % 5];
        right = (right << 1) | (right >> 63);
        D[x] = left ^ right;
    }
    // A′[x, y,z] = A[x, y,z] ⊕ D[x,z].                                     for  0≤x<5, 0≤y<5, and 0≤z<w
    for(int y = 0; y < 5; y++){
        for(int x = 0; x < 5; x++){
            state[y][x] = state[y][x] ^ D[x];
        }
    }
}

void KeccakCore::rho() {
    int x = 1, y = 0, tmp;
    static const int rho_offsets[5][5] = { // lookup table for b. below
        { 0,  1, 62, 28, 27 },
        { 36, 44,  6, 55, 20 },
        {  3, 10, 43, 25, 39 },
        { 41, 45, 15, 21,  8 },
        { 18,  2, 61, 56, 14 }
    };

    // For t from 0 to 23:
        // a. for all z such that 0≤z<w, let A′[x, y,z] = A[x, y, (z–(t+1)(t+2)/2) mod w];
        // b. let (x, y) = (y, (2x+3y) mod 5).
    for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
            int offset = rho_offsets[y][x];
            if (offset != 0) { // state[0][0] 的位移量是 0，不需要動
                state[y][x] = (state[y][x] << offset) | (state[y][x] >> (64 - offset));
            }
        }
    }
}
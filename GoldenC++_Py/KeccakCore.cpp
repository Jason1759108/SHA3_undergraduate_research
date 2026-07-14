#include "KeccakCore.h"
#include <cstring>  

KeccakCore::KeccakCore() {
    reset();
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

void KeccakCore::rho_pi() {
    uint64_t tmp[5][5];
    static const int shift_table[5][5] = { // lookup table for b. below
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
            int old_x = (x + 3 * y) % 5; // For all triples (x, y, z) such that 0≤x<5, 0≤y<5, and 0≤z<w, let
            int old_y = x;                       // A′[x, y, z]=A[(x + 3y) mod 5, x, z].
            int shift_val = shift_table[old_y][old_x]; 
            
            if (shift_val == 0) { // state[0][0] 的位移量是 0，不需要動
                tmp[y][x] = state[old_y][old_x];
            }else {
                tmp[y][x] = (state[old_y][old_x] << shift_val) | (state[old_y][old_x] >> (64ULL - shift_val));
                //tmp[y][x] = (state[old_y][old_x] << shift_val) | (state[old_y][old_x] >> (64 - shift_val));
            }
        }
    }

    memcpy(state, tmp, sizeof(tmp));
}

void KeccakCore::chi() {
    uint64_t tmp[5][5];

    // For all triples (x, y, z) such that 0≤x<5, 0≤y<5, and 0≤z<w, let
    //     A′[x, y,z] = A[x, y,z] ⊕ ((A[(x+1) mod 5, y, z] ⊕ 1) ⋅ A[(x+2) mod 5, y, z]).
    for(int y = 0; y < 5; y++){
        for(int x = 0; x < 5; x++){
            tmp[y][x] = state[y][x] ^ ((~state[y][(x + 1) % 5]) & state[y][(x + 2) % 5]);
        }
    }
    memcpy(state, tmp, sizeof(tmp));
}

void KeccakCore::iota(int round_idx) {
    // 24 輪對應的固定 Round Constants (RC)
    // For j from 0 to l, let RC[2j–1]=rc(j+7ir).
    static const uint64_t RC[24] = {
        0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL, 0x8000000080008000ULL,
        0x000000000000808BULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
        0x000000000000008AULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
        0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
        0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800AULL, 0x800000008000000AULL,
        0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
    };
    state[0][0] ^= RC[round_idx];
}
/* rc(t)
Input:
    integer t.
Output:
    bit rc(t).
Steps:
    1. If t mod 255 = 0, return 1.
    2. Let R = 10000000.
    3. For i from 1 to t mod 255, let:
        a. R = 0 || R;
        b. R[0] = R[0] ⊕ R[8];
        c. R[4] = R[4] ⊕ R[8];
        d. R[5] = R[5] ⊕ R[8];
        e. R[6] = R[6] ⊕ R[8];
        f. R =Trunc8[R].
        4. Return R[0].
*/

void KeccakCore::keccakF1600() {
    for(int ir = 0; ir < 24; ir++){
        theta();
        rho_pi();
        chi();
        iota(ir);
    }
}

void KeccakCore::padAndAbsorb(uint8_t domain_padding, int rate) {
    uint8_t* state_bytes = reinterpret_cast<uint8_t*>(state);

    // 1. Let P=N || pad(r, len(N)).
    state_bytes[byte_number] ^= domain_padding; 
    // ... 中間的 0 完全不用管它，因為任何數 XOR 0 都不會變 ...
    state_bytes[rate - 1] ^= 0x80; //(低)10000000(高)

    keccakF1600();
    byte_number = 0;
}

// 5. Let S=0^b
void KeccakCore::reset(){
    for(int y = 0; y < 5; y++){
        for(int x = 0; x < 5; x++){
            state[y][x] = 0;
        }
    }
    byte_number = 0;
}

void KeccakCore::absorb(const uint8_t* data, size_t length, int rate) {
    // 將 2D 狀態陣列看作平坦的 200 bytes 陣列
    uint8_t* state_bytes = reinterpret_cast<uint8_t*>(state);
    
    for(int idx = 0; idx < length; idx++){ 
        // 2. Let n=len(P)/r.
        // 3. Let c=b-r.
        // 4. Let P0, … , Pn-1 be the unique sequence of strings of length r such that P = P0 || … || Pn-1.
        state_bytes[byte_number] ^= data[idx]; // 6. For i from 0 to n1, let S=f (S ⊕ (Pi|| 0^c)).
        byte_number++;

        if(byte_number == rate){
            keccakF1600();
            byte_number = 0;
        }
    }
}

void KeccakCore::squeeze(uint8_t* output, size_t out_length, int rate) {
    uint8_t* state_bytes = reinterpret_cast<uint8_t*>(state);

    for(int idx = 0; idx < out_length; idx++){
        output[idx] = state_bytes[byte_number];
        byte_number++;

        if(byte_number == rate){
            keccakF1600();
            byte_number = 0;
        }
    }
}



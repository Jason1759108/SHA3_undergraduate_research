#ifndef SHA3_H
#define SHA3_H

#include "KeccakCore.h"
#include <cstdint>
#include <cstddef>

class SHA3 {
private:
    KeccakCore core; 
    
public:
    SHA3() {};

    void hash224(const uint8_t* message, size_t length, uint8_t* output);
    void hash256(const uint8_t* message, size_t length, uint8_t* output);
    void hash384(const uint8_t* message, size_t length, uint8_t* output);
    void hash512(const uint8_t* message, size_t length, uint8_t* output);
};

#endif
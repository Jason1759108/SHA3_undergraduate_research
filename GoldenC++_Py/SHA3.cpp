#include "SHA3.h"

void SHA3::hash224(const uint8_t* message, size_t length, uint8_t* output) {
    core.reset();
    core.absorb(message, length, 144);       // rate 
    core.padAndAbsorb(0x06, 144);            // domain padding, rate
    core.squeeze(output, 28, 144);           // bytes out, rate
}

void SHA3::hash256(const uint8_t* message, size_t length, uint8_t* output) {
    core.reset();
    core.absorb(message, length, 136);       // rate 
    core.padAndAbsorb(0x06, 136);            // domain padding, rate
    core.squeeze(output, 32, 136);           // bytes out, rate
}

void SHA3::hash384(const uint8_t* message, size_t length, uint8_t* output) {
    core.reset();
    core.absorb(message, length, 104);       // rate 
    core.padAndAbsorb(0x06, 104);            // domain padding, rate
    core.squeeze(output, 48, 104);           // bytes out, rate
}

void SHA3::hash512(const uint8_t* message, size_t length, uint8_t* output) {
    core.reset();
    core.absorb(message, length, 72);       // rate 
    core.padAndAbsorb(0x06, 72);            // domain padding, rate
    core.squeeze(output, 64, 72);           // bytes out, rate
}
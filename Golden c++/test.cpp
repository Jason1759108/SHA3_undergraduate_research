#include <iostream>
#include <string>
#include <iomanip>
#include "SHA3.h"
using namespace std;

int main(){
    string s = "";
    const uint8_t* msg = reinterpret_cast<const uint8_t*>(s.data());
    size_t msg_len = s.length();

    uint8_t output[32] = {0};
    
    SHA3 sha3;
    sha3.hash256(msg, msg_len, output);

    std::cout << "SHA3-256 output of \"" << s << "\": \n";
    for (int i = 0; i < 32; i++) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)output[i];
    }
    std::cout << std::endl;
    
    return 0;
    
}
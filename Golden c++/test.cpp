#include <iostream>
#include <vector>
using namespace std;

int main(){
    vector<vector<int>> table(5, vector<int>(5, 0));
    int x = 1, y = 0, tmp;
    for(int i = 0; i <= 23; i++){
        table[y][x] = ((i + 1) * (i + 2) / 2) % 64;
        tmp = 2*x + 3*y;
        x = y;
        y = tmp % 5;
    }

    for(y = 0; y < 5; y++){
        for(x = 0; x < 5; x++){
            cout << table[y][x] << ' ';
        }
        cout << endl;
    }
}
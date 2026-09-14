import hashlib
import time

def benchmark_sha3():
    s = b"" 
    
    start_time = time.perf_counter_ns()
    
    for _ in range(1000000):
        h = hashlib.sha3_256()
        h.update(s)
        output = h.digest() 
        
    end_time = time.perf_counter_ns()
    
    elapsed_ns = end_time - start_time
    
    print(f"SHA3-256 output of \"\": \n{h.hexdigest()}")
    print(f"running time: {elapsed_ns} ns")

if __name__ == "__main__":
    benchmark_sha3()
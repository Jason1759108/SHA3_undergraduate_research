import sha3_pkg::*;
module keccak_lane_parity (
    input state_t data_nxt, data_cur,
    input logic [24:0] lane_active,
    input logic check_valid, checkpoint_fault,
    input logic [24:0] predicted_parity,
    input logic inject_valid,
    input logic [4:0] inject_lane,
    input logic [63:0] inject_mask,
    output state_t data_wr,
    output logic [24:0] mismatch_mask,
    output logic fault_valid
);
    state_t received;
    always_comb begin
        received = data_nxt;
        mismatch_mask = '0;
        for (int y = 0; y < 5; y++) begin
            for (int x = 0; x < 5; x++) begin
                if (check_valid && lane_active[y*5+x]) begin
                    if (inject_valid && inject_lane == 5'(y*5+x))
                        received[x][y] ^= inject_mask;
                    mismatch_mask[y*5+x] = (^received[x][y]) ^ predicted_parity[y*5+x];
                end
            end
        end
    end
    assign fault_valid = checkpoint_fault || (|mismatch_mask);
    // Atomic whole-operation commit: no correction or partial row/column writes.
    always_comb begin
        data_wr = data_cur;
        for (int y = 0; y < 5; y++)
            for (int x = 0; x < 5; x++)
                if (lane_active[y*5+x] && !fault_valid)
                    data_wr[x][y] = received[x][y];
    end
endmodule

module xor_reg (
    input wire clk,
    input wire rst,
    input wire load_i,
    input wire [127:0] data_i,
    input wire [127:0] key_i,   // 사용하지 않아도 인터페이스 맞춤용
    output reg [127:0] data_o,
    output wire busy_o
);

    reg [127:0] reg_prev;
    reg busy_reg;

    assign busy_o = busy_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_prev <= 128'b0;
            data_o   <= 128'b0;
            busy_reg <= 1'b0;
        end else begin
            if (load_i) begin
                reg_prev <= data_i;     // 이전 값 저장
                data_o   <= data_i;     // 출력을 갱신 (혹은 XOR 등 연산 가능)
                busy_reg <= 1'b1;       // 1 사이클 동안 busy 활성화
            end else begin
                busy_reg <= 1'b0;
            end
        end
    end

endmodule
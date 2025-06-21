`include "clog2.v"

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

    reg [31:0] mem_in;
    wire [31:0] mem_out;
    reg wr_en;
    reg [6:0] address;

    reg [7:0] read_count;
    reg reading;




    mem_single #(.WIDTH(32), .DEPTH(128)
    ) mem (
        .clock(clk),
        .data(data_i[31:0]),
        .address(address),  // reg_prev의 하위 7비트를 주소로 사용
        .wr_en(wr_en),           // load_i가 활성화되면 메모리에 쓰기
        .q(mem_out)         // 메모리에서 읽은 값을 data_o에 저장
    );

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_prev <= 128'b0;
            busy_reg <= 1'b0;
        end else begin
            if (load_i) begin

                if (data_i[127] == 1'b1) begin
                    busy_reg <= 1'b1;
                    mem_in <= data_i[31:0];
                    address <= key_i[6:0];
                    wr_en <= 1'b1;
                    data_o <= {96'b0, data_i[31:0]};
                end else if (data_i == 128'b0) begin
                    busy_reg <= 1'b1;
                    read_count <= 1;
                    address <= 0;
                    data_o <= 128'b0;
                    reading <= 1'b1;
                end

            end
            else if (reading) begin
                address <= read_count;
                if (read_count == 1) begin
                    data_o <= 128'b0;
                end
                else begin
                    data_o <= {96'b0, mem_out};
                end
                read_count <= read_count + 1;
                wr_en <= 1'b0;

                if (read_count == 129) begin
                    reading <= 1'b0;
                end

            end else begin
                wr_en <= 1'b0;
                busy_reg <= 1'b0;
            end
        end
    end

endmodule
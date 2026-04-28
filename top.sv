module top (
    input  logic        clk, reset,
    output logic [31:0] WriteData, DataAdr,
    output logic        MemWrite
);
    logic [31:0] ReadData, result;

    riscv rv (
        .clk(clk), .reset(reset),
        .adr(DataAdr), .writedata(WriteData),
        .memwrite(MemWrite), .readdata(ReadData),
        .result(result)
    );

    memory mem (
        .clk(clk), .we(MemWrite),
        .a(DataAdr), .wd(WriteData),
        .rd(ReadData)
    );
endmodule

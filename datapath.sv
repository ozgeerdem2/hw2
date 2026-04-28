module datapath (
    input  logic        clk, reset, pcwrite, adrsrc, irwrite, regwrite,
    input  logic [1:0]  resultsrc, alusrca, alusrcb, immsrc,
    input  logic [2:0]  alucontrol,
    output logic [6:0]  op,
    output logic [2:0]  funct3,
    output logic        funct7b5, zero,
    output logic [31:0] adr, writedata,
    input  logic [31:0] readdata,
    output logic [31:0] result
);
    logic [31:0] pc, oldpc, instr, data, a, b, aluresult, aluout, immext, rd1, rd2, srca, srcb;

    assign op = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7b5 = instr[30];

    flopenr #(32) pcreg(clk, reset, pcwrite, result, pc);
    mux2    #(32) adrmux(pc, aluout, adrsrc, adr);

    flopenr #(32) ir(clk, reset, irwrite, readdata, instr);
    flopenr #(32) oldpcreg(clk, reset, irwrite, pc, oldpc); 
    flopr   #(32) datareg(clk, reset, readdata, data);

    regfile rf(clk, regwrite, instr[19:15], instr[24:20], instr[11:7], result, rd1, rd2);
    flopr   #(32) areg(clk, reset, rd1, a);
    flopr   #(32) breg(clk, reset, rd2, b);

    assign writedata = b;

    extend ext(instr, immsrc, immext);

    mux3 #(32) srcamux(pc, oldpc, a, alusrca, srca);
    mux3 #(32) srcbmux(b, immext, 32'd4, alusrcb, srcb);

    alu alu_unit(srca, srcb, alucontrol, aluresult, zero);
    flopr #(32) aluoutreg(clk, reset, aluresult, aluout);

    mux3 #(32) resmux(aluout, data, aluresult, resultsrc, result);
endmodule

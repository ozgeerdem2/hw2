module controller (
    input  logic       clk, reset,
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic       funct7b5, zero,
    output logic [1:0] immsrc,
    output logic [1:0] alusrca, alusrcb,
    output logic [1:0] resultsrc,
    output logic       adrsrc,
    output logic [2:0] alucontrol,
    output logic       irwrite, pcwrite, regwrite, memwrite
);
    // internal signals for logic 
    logic [1:0] alu_op_sig;
    logic       branch_sig, pc_update_sig;

    // connecting sub-modules 
    maindec mdec_inst (
        .clk(clk), .reset(reset), .op(op),
        .aluop(alu_op_sig), .resultsrc(resultsrc), .alusrca(alusrca), .alusrcb(alusrcb),
        .adrsrc(adrsrc), .irwrite(irwrite), .pcupdate(pc_update_sig), 
        .branch(branch_sig), .regwrite(regwrite), .memwrite(memwrite)
    );

    aludec adec_inst (
        .opb5(op[5]), .funct3(funct3), .funct7b5(funct7b5), 
        .aluop(alu_op_sig), .alucontrol(alucontrol)
    );

    instrdec idec_inst (
        .op(op), .immsrc(immsrc)
    );

    // pc write enable logic based on fig 1 
    assign pcwrite = pc_update_sig | (branch_sig & zero);

endmodule

module maindec (
    input  logic       clk, reset,
    input  logic [6:0] op,
    output logic [1:0] aluop, resultsrc, alusrca, alusrcb,
    output logic       adrsrc, irwrite, pcupdate, branch, regwrite, memwrite
);
    // fsm states 
    typedef enum logic [3:0] {
        S0_FETCH    = 4'd0, 
        S1_DECODE   = 4'd1, 
        S2_MEMADR   = 4'd2, 
        S3_MEMREAD  = 4'd3, 
        S4_MEMWB    = 4'd4, 
        S5_MEMWRITE = 4'd5, 
        S6_EXECUTER = 4'd6, 
        S7_ALUWB    = 4'd7, 
        S8_EXECUTEI = 4'd8, 
        S9_JAL      = 4'd9, 
        S10_BEQ     = 4'd10
    } statetype;

    statetype current_state, next_state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) current_state <= S0_FETCH;
        else       current_state <= next_state;
    end

    always_comb begin
        case (current_state)
            S0_FETCH:  next_state = S1_DECODE; 
            S1_DECODE: begin
                if (op == 7'b0000011 || op == 7'b0100011) next_state = S2_MEMADR;
                else if (op == 7'b0110011) next_state = S6_EXECUTER;
                else if (op == 7'b0010011) next_state = S8_EXECUTEI;
                else if (op == 7'b1101111) next_state = S9_JAL;
                else if (op == 7'b1100011) next_state = S10_BEQ;
                else next_state = S0_FETCH;
            end
            S2_MEMADR: begin
                if (op == 7'b0000011) next_state = S3_MEMREAD;
                else next_state = S5_MEMWRITE;
            end
            S3_MEMREAD: next_state = S4_MEMWB;
            S6_EXECUTER, S8_EXECUTEI, S9_JAL: next_state = S7_ALUWB; 
            default:   next_state = S0_FETCH; 
        endcase
    end

    always_comb begin
        {aluop, resultsrc, alusrca, alusrcb, adrsrc, irwrite, pcupdate, branch, regwrite, memwrite} = 15'b0;
        case (current_state)
            S0_FETCH:    begin adrsrc=0; irwrite=1; alusrca=2'b00; alusrcb=2'b10; aluop=2'b00; resultsrc=2'b10; pcupdate=1; end
            S1_DECODE:   begin alusrca=2'b01; alusrcb=2'b01; aluop=2'b00; end
            S2_MEMADR:   begin alusrca=2'b10; alusrcb=2'b01; aluop=2'b00; end
            S3_MEMREAD:  begin resultsrc=2'b00; adrsrc=1; end
            S4_MEMWB:    begin resultsrc=2'b01; regwrite=1; end
            S5_MEMWRITE: begin resultsrc=2'b00; adrsrc=1; memwrite=1; end
            S6_EXECUTER: begin alusrca=2'b10; alusrcb=2'b00; aluop=2'b10; end
            S8_EXECUTEI: begin alusrca=2'b10; alusrcb=2'b01; aluop=2'b10; end
            S7_ALUWB:    begin resultsrc=2'b00; regwrite=1; end
            S10_BEQ:     begin alusrca=2'b10; alusrcb=2'b00; aluop=2'b01; resultsrc=2'b00; branch=1; end
            S9_JAL:      begin alusrca=2'b01; alusrcb=2'b10; aluop=2'b00; resultsrc=2'b00; pcupdate=1; end
        endcase
    end
endmodule

module aludec (
    input  logic       opb5,
    input  logic [2:0] funct3,
    input  logic       funct7b5,
    input  logic [1:0] aluop,
    output logic [2:0] alucontrol
);
    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5; // Subtraction condition for R-type

    always_comb begin
        case (aluop)
            2'b00: alucontrol = 3'b000; // ADD (lw, sw, fetch PC+4)
            2'b01: alucontrol = 3'b001; // SUB (beq)
            2'b10: begin // R-type or I-type
                case (funct3)
                    3'b000:  alucontrol = RtypeSub ? 3'b001 : 3'b000; // sub : add
                    3'b010:  alucontrol = 3'b101; // slt
                    3'b110:  alucontrol = 3'b011; // or
                    3'b111:  alucontrol = 3'b010; // and
                    default: alucontrol = 3'bxxx;
                endcase
            end
            default: alucontrol = 3'bxxx;
        endcase
    end
endmodule

module instrdec (
    input  logic [6:0] op,
    output logic [1:0] immsrc
);
    always_comb begin
        case (op)
            7'b0110011:             immsrc = 2'bxx; // R-type (Hata buradayd?, X yapt?k)
            7'b0010011, 7'b0000011: immsrc = 2'b00; // I-type & lw
            7'b0100011:             immsrc = 2'b01; // sw
            7'b1100011:             immsrc = 2'b10; // beq
            7'b1101111:             immsrc = 2'b11; // jal
            default:                immsrc = 2'b00; 
        endcase
    end
endmodule
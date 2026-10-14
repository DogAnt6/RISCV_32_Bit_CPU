module RISCVCPU (
    input logic clock,
    input logic reset,
    output logic [5:0] debug_x3    
);
    //Instruction opcodes 
    localparam logic [6:0]
    RTYPE = 7'b0110011,
    ITYPE  = 7'b0010011,
    LW    = 7'b0000011,
    SW    = 7'b0100011,
    BEQ   = 7'b1100011;

    //Program Counter
    logic [31:0] PC;
    logic [31:0] PCTarget, PCNext;
    
    //Register file and Register file outputs
    logic [31:0] Regs[0:31], A, B;
    logic [4:0] rs1, rs2, rd;

    //Opcode
    logic [6:0] opcode;

    //Immediate
    logic [31:0] ImmGen;

    //ALU
    logic [31:0] ALUResult, ALUBin;
    logic Zero;
    logic [3:0] ALUCtl;

    //Memory
    logic [31:0] ReadData, WriteData, Result;

    //Control
    logic RegWrite, MemWrite, MemRead, MemtoReg, ALUSrc, Branch, PCSrc;
    logic [1:0] ALUOp;

    //Instruction/data memories
    logic [31:0] Instr;

    instruction_memory imem ( //ROM (Flash memory)
        .program_counter(PC),
        .instruction(Instr)
    );
    
    data_memory dmem ( //RAM
        .clock(clock),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(ALUResult),
        .write_data(WriteData),
        .read_data(ReadData)
    );

    //Flips the LED outputs
    assign debug_x3 = ~Regs[3][5:0];

    assign opcode = Instr[6:0];
    assign rs1 = Instr[19:15];
    assign rs2 = Instr[24:20];
    assign rd  = Instr[11:7];

    assign A = (rs1 == 5'd0) ? 32'b0 : Regs[rs1];
    assign B = (rs2 == 5'd0) ? 32'b0 : Regs[rs2];

    //Writes to Data Memory
    assign WriteData = B;

    //ALU input MUX
    assign ALUBin = ALUSrc ? ImmGen : B;

    //Write back MUX
    assign Result = MemtoReg ? ReadData : ALUResult;

    //PC MUX and Branch Logic
    assign PCTarget = PC + ImmGen;
    assign PCSrc = Branch & Zero;
    assign PCNext = PCSrc ? PCTarget : (PC + 32'd4);

    //ALU and ALU Control 
    ALU alu (
    .A(A),
    .B(ALUBin),
    .ALUCtl(ALUCtl),
    .ALUResult(ALUResult),
    .Zero(Zero)
    );

    ALUControl aluControl (
    .ALUOp(ALUOp),
    .funct3(Instr[14:12]),
    .funct7(Instr[31:25]),
    .ALUCtl(ALUCtl)
    );

    //Main control unit
    always_comb begin

        // Defaults
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        MemRead  = 1'b0;
        MemtoReg = 1'b0;
        ALUSrc   = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;
        ImmGen   = 32'b0;

        case (opcode)

            RTYPE: begin      // R-type
                RegWrite = 1'b1;
                ALUSrc   = 1'b0;
                ALUOp    = 2'b10;
            end

            ITYPE: begin      // I-type arithmetic
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUOp    = 2'b11;
                ImmGen = {{20{Instr[31]}}, Instr[31:20]};
            end

            LW: begin      // LW
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                MemtoReg = 1'b1;
                ALUSrc   = 1'b1;
                ALUOp    = 2'b00;
                ImmGen = {{20{Instr[31]}}, Instr[31:20]};
            end

            SW: begin      // SW
                MemWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUOp    = 2'b00;
                ImmGen = {{20{Instr[31]}},
                      Instr[31:25],
                      Instr[11:7]};
            end

            BEQ: begin      // BEQ
                Branch = 1'b1;
                ALUSrc = 1'b0;
                ALUOp  = 2'b01;
                ImmGen = {{19{Instr[31]}},
                      Instr[31],
                      Instr[7],
                      Instr[30:25],
                      Instr[11:8],
                      1'b0};
            end

        endcase
    end

    integer i;
    //Sequential Logic for PC update and memory access
    always_ff @(posedge clock) begin
        if (reset) begin
            PC <= 32'b0;
            for (i = 0; i < 32; i = i + 1)
                Regs[i] <= 32'b0;
        end
        else begin
            PC <= PCNext;
        
        if (RegWrite && (rd != 5'd0))
            Regs[rd] <= Result;
        
        end
    end
endmodule

module instruction_memory #(
    parameter NUMBER_OF_INSTRUCTIONS = 64
)(
    input  logic [31:0] program_counter,
    output logic [31:0] instruction
);

    logic [31:0] instruction_data [0:NUMBER_OF_INSTRUCTIONS-1];

    assign instruction = instruction_data[program_counter >> 2];

    initial begin
        instruction_data[0] = 32'h00500093; // addi x1, x0, 5
        instruction_data[1] = 32'h00700113; // addi x2, x0, 7
        instruction_data[2] = 32'h002081B3; // add x3, x1, x2
        instruction_data[3] = 32'h00000013; // nop

        for (int i = 4; i < NUMBER_OF_INSTRUCTIONS; i++)
            instruction_data[i] = 32'h00000013;
    end

endmodule

module data_memory #(
    parameter NUMBER_OF_WORDS = 1024
)(
    input  logic        clock,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);

    logic [31:0] data [0:NUMBER_OF_WORDS-1];

    assign read_data =
        MemRead ? data[address >> 2] : 32'b0;

    always_ff @(posedge clock) begin
        if (MemWrite)
            data[address >> 2] <= write_data;
    end

endmodule

module ALUControl (
    input  logic [1:0] ALUOp,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [3:0] ALUCtl
);

    always_comb begin
        case (ALUOp)

            2'b00: begin
                // LW / SW address calculation
                ALUCtl = 4'd2;   // ADD
            end

            2'b01: begin
                // Basic BEQ comparison
                ALUCtl = 4'd6;   // SUB
            end

            2'b10: begin
                // R-type
                case (funct3)
                    3'b000:
                        if (funct7[5])
                            ALUCtl = 4'd6;   // SUB
                        else
                            ALUCtl = 4'd2;   // ADD

                    3'b111: ALUCtl = 4'd0;   // AND
                    3'b110: ALUCtl = 4'd1;   // OR
                    3'b100: ALUCtl = 4'd3;   // XOR
                    3'b010: ALUCtl = 4'd7;   // SLT

                    default: ALUCtl = 4'd15;
                endcase
            end

            2'b11: begin
                // I-type arithmetic
                case (funct3)
                    3'b000: ALUCtl = 4'd2;   // ADDI
                    3'b111: ALUCtl = 4'd0;   // ANDI
                    3'b110: ALUCtl = 4'd1;   // ORI
                    3'b100: ALUCtl = 4'd3;   // XORI
                    3'b010: ALUCtl = 4'd7;   // SLTI

                    default: ALUCtl = 4'd15;
                endcase
            end

            default:
                ALUCtl = 4'd15;

        endcase
    end

endmodule

module ALU (
    input logic [31:0] A,
    input logic [31:0] B,
    input logic [3:0] ALUCtl,
    output logic [31:0] ALUResult,
    output logic Zero
);
    assign Zero = (ALUResult == 32'b0);

    always_comb begin
        case (ALUCtl)
            4'd0:  ALUResult = A & B; //AND
            4'd1:  ALUResult = A | B; //OR
            4'd2:  ALUResult = A + B; //ADD
            4'd3:  ALUResult = A ^ B; //XOR
            4'd6:  ALUResult = A - B; //SUB
            4'd7:  ALUResult = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; //SLT (signed less than)
            default: ALUResult = 32'b0;
        endcase
    end
endmodule
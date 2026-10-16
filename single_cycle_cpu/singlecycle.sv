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
        .reset(reset),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(ALUResult),
        .write_data(WriteData),
        .read_data(ReadData),
        .led_out(debug_x3)
    );

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

    //Sequential Logic for PC update and memory access
    always_ff @(posedge clock) begin
        if (reset) begin
            PC <= 32'b0;
            for (int i = 0; i < 32; i = i + 1)
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
        instruction_data[0] = 32'h00A00093;

        // addi x2, x0, 3
        instruction_data[1] = 32'h00300113;

        // R-TYPE TESTS

        // add x3, x1, x2
        // Expected: x3 = 13
        instruction_data[2] = 32'h002081B3;

        // Store x3 (13) to LED peripheral at 0x100
        instruction_data[3] = 32'h10300023;

        // sub x4, x1, x2
        // Expected: x4 = 7
        instruction_data[4] = 32'h40208233;

        // and x5, x1, x2
        // 10 & 3 = 2
        instruction_data[5] = 32'h0020F2B3;

        // or x6, x1, x2
        // 10 | 3 = 11
        instruction_data[6] = 32'h0020E333;

        // xor x7, x1, x2
        // 10 ^ 3 = 9
        instruction_data[7] = 32'h0020C3B3;

        // slt x8, x2, x1
        // 3 < 10 -> 1
        instruction_data[8] = 32'h00112433;

        // I-TYPE TESTS

        // addi x9, x1, 5
        // Expected: 15
        instruction_data[9] = 32'h00508493;

        // andi x10, x1, 6
        // 10 & 6 = 2
        instruction_data[10] = 32'h0060F513;

        // ori x11, x2, 8
        // 3 | 8 = 11
        instruction_data[11] = 32'h00816593;

        // xori x12, x1, 3
        // 10 ^ 3 = 9
        instruction_data[12] = 32'h0030C613;

        // slti x13, x2, 5
        // 3 < 5 -> 1
        instruction_data[13] = 32'h00512693;

        // MEMORY TEST

        // sw x3, 0(x0)
        // data[0] = 13
        instruction_data[14] = 32'h00302023;

        // lw x14, 0(x0)
        // Expected: x14 = 13
        instruction_data[15] = 32'h00002703;

        // BEQ TEST - TAKEN

        // beq x1, x1, +8
        //
        // Should skip instruction 16
        // and jump to instruction 17
        instruction_data[16] = 32'h00108463;

        // addi x15, x0, 99
        // SHOULD BE SKIPPED
        instruction_data[17] = 32'h06300793;

        // addi x15, x0, 42
        // Expected: x15 = 42
        instruction_data[18] = 32'h02A00793;

        // BEQ TEST - NOT TAKEN

        // beq x1, x2, +8
        //
        // x1 = 10
        // x2 = 3
        // NOT equal -> branch not taken
        instruction_data[19] = 32'h00208463;

        // addi x16, x0, 55
        // SHOULD execute
        instruction_data[20] = 32'h03700813;

        // Infinite loop
        instruction_data[21] = 32'h00000063;

        for (int i = 22; i < NUMBER_OF_INSTRUCTIONS; i++)
            instruction_data[i] = 32'h00000013;
    end

endmodule

module data_memory #(
    parameter NUMBER_OF_WORDS = 1024
)(
    input  logic        clock,
    input  logic        reset,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic [5:0]  led_out
);

    localparam logic [31:0] LED_ADDR = 32'h00000100;

    logic [31:0] data [0:NUMBER_OF_WORDS-1];
    logic [5:0] led_reg;

    // LEDs are active-low
    assign led_out = ~led_reg;

    // Memory-mapped reads
    always_comb begin
        read_data = 32'b0;

        if (MemRead) begin
            if (address == LED_ADDR)
                read_data = {26'b0, led_reg};
            else if (address[31:12] == 0)
                read_data = data[address[11:2]];
        end
    end

    // Memory-mapped writes
    always_ff @(posedge clock) begin
        if (reset) begin
            led_reg <= 6'b0;
        end
        else if (MemWrite) begin
            if (address == LED_ADDR)
                led_reg <= write_data[5:0];
            else if (address[31:12] == 0)
                data[address[11:2]] <= write_data;
        end
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
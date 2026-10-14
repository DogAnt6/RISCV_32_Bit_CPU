`timescale 1ns/1ps

module RISCVCPU_tb;

    logic clock;
    logic reset;

    // Instantiate CPU
    RISCVCPU dut (
        .clock(clock),
        .reset(reset)
    );

    // -----------------------------------------------------
    // CLOCK
    // 10 ns period = 100 MHz simulation clock
    // -----------------------------------------------------
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end


    // -----------------------------------------------------
    // TEST PROGRAM
    // -----------------------------------------------------
    initial begin

        // Start in reset
        reset = 1;

        // Allow instruction_memory's initial block to finish
        #1;


        // =====================================================
        // SET UP VALUES
        // =====================================================

        // addi x1, x0, 10
        dut.imem.instruction_data[0] = 32'h00A00093;

        // addi x2, x0, 3
        dut.imem.instruction_data[1] = 32'h00300113;


        // =====================================================
        // R-TYPE TESTS
        // =====================================================

        // add x3, x1, x2
        // Expected: x3 = 13
        dut.imem.instruction_data[2] = 32'h002081B3;

        // sub x4, x1, x2
        // Expected: x4 = 7
        dut.imem.instruction_data[3] = 32'h40208233;

        // and x5, x1, x2
        // 10 & 3 = 2
        dut.imem.instruction_data[4] = 32'h0020F2B3;

        // or x6, x1, x2
        // 10 | 3 = 11
        dut.imem.instruction_data[5] = 32'h0020E333;

        // xor x7, x1, x2
        // 10 ^ 3 = 9
        dut.imem.instruction_data[6] = 32'h0020C3B3;

        // slt x8, x2, x1
        // 3 < 10 -> 1
        dut.imem.instruction_data[7] = 32'h00112433;


        // =====================================================
        // I-TYPE TESTS
        // =====================================================

        // addi x9, x1, 5
        // Expected: 15
        dut.imem.instruction_data[8] = 32'h00508493;

        // andi x10, x1, 6
        // 10 & 6 = 2
        dut.imem.instruction_data[9] = 32'h0060F513;

        // ori x11, x2, 8
        // 3 | 8 = 11
        dut.imem.instruction_data[10] = 32'h00816593;

        // xori x12, x1, 3
        // 10 ^ 3 = 9
        dut.imem.instruction_data[11] = 32'h0030C613;

        // slti x13, x2, 5
        // 3 < 5 -> 1
        dut.imem.instruction_data[12] = 32'h00512693;


        // =====================================================
        // MEMORY TEST
        // =====================================================

        // sw x3, 0(x0)
        // data[0] = 13
        dut.imem.instruction_data[13] = 32'h00302023;

        // lw x14, 0(x0)
        // Expected: x14 = 13
        dut.imem.instruction_data[14] = 32'h00002703;


        // =====================================================
        // BEQ TEST - TAKEN
        // =====================================================

        // beq x1, x1, +8
        //
        // Should skip instruction 16
        // and jump to instruction 17
        dut.imem.instruction_data[15] = 32'h00108463;

        // addi x15, x0, 99
        // SHOULD BE SKIPPED
        dut.imem.instruction_data[16] = 32'h06300793;

        // addi x15, x0, 42
        // Expected: x15 = 42
        dut.imem.instruction_data[17] = 32'h02A00793;


        // =====================================================
        // BEQ TEST - NOT TAKEN
        // =====================================================

        // beq x1, x2, +8
        //
        // x1 = 10
        // x2 = 3
        // NOT equal -> branch not taken
        dut.imem.instruction_data[18] = 32'h00208463;

        // addi x16, x0, 55
        // SHOULD execute
        dut.imem.instruction_data[19] = 32'h03700813;


        // =====================================================
        // NOPS
        // =====================================================

        dut.imem.instruction_data[20] = 32'h00000013;
        dut.imem.instruction_data[21] = 32'h00000013;
        dut.imem.instruction_data[22] = 32'h00000013;


        // =====================================================
        // RELEASE RESET
        // =====================================================

        // We are currently at t = 1 ns.
        // Wait another 11 ns -> release at t = 12 ns.
        #11;
        reset = 0;


        // Allow CPU to execute program
        #230;


        // =====================================================
        // CHECK RESULTS
        // =====================================================

        $display("");
        $display("================================");
        $display("       RV32I CPU TEST");
        $display("================================");


        // -----------------------------------------------------
        // R-TYPE
        // -----------------------------------------------------

        if (dut.Regs[3] === 32'd13)
            $display("PASS: ADD");
        else
            $error("FAIL: ADD");

        if (dut.Regs[4] === 32'd7)
            $display("PASS: SUB");
        else
            $error("FAIL: SUB");

        if (dut.Regs[5] === 32'd2)
            $display("PASS: AND");
        else
            $error("FAIL: AND");

        if (dut.Regs[6] === 32'd11)
            $display("PASS: OR");
        else
            $error("FAIL: OR");

        if (dut.Regs[7] === 32'd9)
            $display("PASS: XOR");
        else
            $error("FAIL: XOR");

        if (dut.Regs[8] === 32'd1)
            $display("PASS: SLT");
        else
            $error("FAIL: SLT");


        // -----------------------------------------------------
        // I-TYPE
        // -----------------------------------------------------

        if (dut.Regs[9] === 32'd15)
            $display("PASS: ADDI");
        else
            $error("FAIL: ADDI");

        if (dut.Regs[10] === 32'd2)
            $display("PASS: ANDI");
        else
            $error("FAIL: ANDI");

        if (dut.Regs[11] === 32'd11)
            $display("PASS: ORI");
        else
            $error("FAIL: ORI");

        if (dut.Regs[12] === 32'd9)
            $display("PASS: XORI");
        else
            $error("FAIL: XORI");

        if (dut.Regs[13] === 32'd1)
            $display("PASS: SLTI");
        else
            $error("FAIL: SLTI");


        // -----------------------------------------------------
        // MEMORY
        // -----------------------------------------------------

        // Data memory is now inside dmem
        if (dut.dmem.data[0] === 32'd13)
            $display("PASS: SW");
        else
            $error("FAIL: SW");

        if (dut.Regs[14] === 32'd13)
            $display("PASS: LW");
        else
            $error("FAIL: LW");


        // -----------------------------------------------------
        // BEQ TAKEN
        // -----------------------------------------------------

        if (dut.Regs[15] === 32'd42)
            $display("PASS: BEQ taken");
        else
            $error("FAIL: BEQ taken");


        // -----------------------------------------------------
        // BEQ NOT TAKEN
        // -----------------------------------------------------

        if (dut.Regs[16] === 32'd55)
            $display("PASS: BEQ not taken");
        else
            $error("FAIL: BEQ not taken");


        $display("================================");
        $display("       TEST COMPLETE");
        $display("================================");
        $display("");

        $finish;

    end

endmodule
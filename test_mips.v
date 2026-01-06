module test_mips32;
    reg clock;
    mips32 mycpu(clock);
    

    initial begin
        clock = 1'b0;
    end

    always #5 clock = ~clock;

    initial begin
        mycpu.HALTED = 0;           // Initializing them with 0
        mycpu.TAKEN_BRANCH = 0;
        mycpu.PC = 0;

        // mycpu.Mem[0] = 32'h34C10000;    // LW R1, 0{R6}
        // mycpu.Mem[1] = 32'h18210800;    // MUL R1 R1 R1
        // // mycpu.Mem[1] = 32'h34C20001;    // LW R2, 1{120}
        // // mycpu.Mem[2] = 32'h3040002F;    // BNEQZ R2 48
        
        // // mycpu.Mem[4] = 32'h18210800;    // MUL R1 R1 R1
        // mycpu.Mem[2] = 32'hFC000000;    // HLT
        
        // // mycpu.Mem[50] = 32'h18210800;   // MUL R1 R1 R1
        // // mycpu.Mem[51] = 32'h0C420001;   // SUB R2 R2 1

        // // //mycpu.Mem[51] = 32'h0442FFFF;
        // // mycpu.Mem[52] = 32'h2C40FFCE;   // BEQZ R2
        // // mycpu.Mem[53] = 32'h3040FFFC;   // BNEQZ  R2

        // mycpu.Mem[120] = 32'h00000008;  // Base
        // mycpu.Mem[121] = 32'h00000001;  // Power

        // mycpu.Reg[6] =   32'h00000078;  // 120

        /*
        ADDI r1, r0, 5        ; r1 = 5
        ADDI r2, r0, 10       ; r2 = 10
        ADD  r3, r1, r2       ; r3 = 15
        SUB  r4, r3, r1       ; r4 = 10
        MUL  r3, r4, r1       ; r3 = 50
        SLTI r3, r3, 100      ; r3 = 1
        ADDI r5, r0, 0x20     ; base address = 0x20
        SW   r3, 0(r5)        ; store 1
        LW   r6, 0(r5)        ; load → load-use hazard
        ADD  r6, r6, r1       ; forwarding test
        BEQZ r6, +2           ; should NOT branch
        SUBI r6, r6, 6        ; r6 = 0
        BEQZ r6, +1           ; branch taken
        ADDI r1, r0, 99       ; skipped
        HLT
        */

        // mycpu.Mem[0] = 32'h04010005; //ADDI r1, r0, 5 
        // mycpu.Mem[1] = 32'h0402000A; // ADDI r2, r0, 10 
        // mycpu.Mem[2] = 32'h00221800; //ADD  r3, r1, r2 
        // mycpu.Mem[3] = 32'h08612000; //SUB  r4, r3, r1
        // mycpu.Mem[4] = 32'h18241800; //MUL  r3, r4, r1 
        // mycpu.Mem[5] = 32'h40630064; //SLTI r3, r3, 100
        // mycpu.Mem[6] = 32'h04050020; // ADDI r5, r0, 0x20
        // mycpu.Mem[7] = 32'h38A30000; // SW   r3, 0(r5)  
        // mycpu.Mem[8] = 32'h34A60000; // LW   r6, 0(r5) 
        // mycpu.Mem[9] = 32'h00C13000; // ADD  r6, r6, r1 
        // mycpu.Mem[10] = 32'h2CC00002; // BEQZ r6, +2 
        // mycpu.Mem[11] = 32'h0CC60006; // SUBI r6, r6, 6 
        // mycpu.Mem[12] = 32'h2CC00001; // BEQZ r6, +1   
        // mycpu.Mem[13] = 32'h04010063; // ADDI r1, r0, 99 
        // mycpu.Mem[14] = 32'hFC000000; // HLT

        mycpu.Mem[0] = 32'h04010005; //ADDI R1 R0 5
        mycpu.Mem[1] = 32'h38C10000; //SW R1 0{R6}
        mycpu.Mem[2] = 32'h34C20000; //LW R2 0{R6}
        mycpu.Mem[3] = 32'hFC000000; //HLT

        mycpu.Reg[6] = 32'h00000078;

    //    mycpu.Reg[1] = 12;

        
        #200 
        $display("R1 = %d", mycpu.Reg[1]);
        $display("R2 = %d", mycpu.Reg[2]);
        // $display("R3 = %d", mycpu.Reg[3]);
        // $display("R4 = %d", mycpu.Reg[4]);
        // $display("R5 = %d", mycpu.Reg[5]);
        // $display("R6 = %d", mycpu.Reg[6]);
        $display("Mem[32] = %d", mycpu.Mem[120]);


        // // $display("R2 = %d", mycpu.Reg[2]);
        // $display("A = %d", mycpu.A);
        // $display("B = %d", mycpu.B);
        // $display("C = %d", mycpu.C);
        // $display("D = %d", mycpu.D);


        // //$display("Reg[2] = %d", mycpu.Reg_2);
        // $display("Out = %d", mycpu.Out);
    end

    initial begin
        $dumpfile("mycpu.vcd");
        $dumpvars(0,test_mips32);
        #500 $finish;
    end

endmodule

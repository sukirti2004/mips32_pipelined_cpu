module test_pipe_MIPS32;
    reg clock_1, clock_2;
    pipeline_MIPS32 mycpu(clock_1, clock_2);

    initial begin
        clock_1 = 0;
        clock_2 = 0;
        repeat(20) begin                        // We need to create clock cycles which are completely independent of each other
            #5 clock_1 = 1; #5 clock_1 = 0;
            #5 clock_2 = 1; #5 clock_2 = 0;
        end
    end


    initial begin
        mycpu.HALTED = 0;           // Initializing them with 0
        mycpu.TAKEN_BRANCH = 0;
        mycpu.PC = 0;
        mycpu.Mem[0] = 32'h20C10000;
        mycpu.Mem[1] = 32'h20C20001;
        mycpu.Mem[2] = 32'h08000000;     // Stalling one cycle AND R0 R0 R0
        mycpu.Mem[3] = 32'h08000000;     // Stalling one cycle AND R0 R0 R0
        mycpu.Mem[4] = 32'h00221800;
        mycpu.Mem[5] = 32'h08000000;     // Stalling one cycle AND R0 R0 R0
        mycpu.Mem[6] = 32'h08000000;     // Stalling one cycle AND R0 R0 R0
        mycpu.Mem[7] = 32'h1CC30002;
        mycpu.Mem[8] = 32'h18000000;
        
        mycpu.Reg[6] = 32'h00000078;

        mycpu.Mem[120] = 32'h00000014;
        mycpu.Mem[121] = 32'h00000046;
        
        #200 
        $display("R1 = %d", mycpu.Reg[1]);
        $display("R2 = %d", mycpu.Reg[2]);
        $display("R3 = %d", mycpu.Reg[3]);
        $display("R6 = %d", mycpu.Reg[6]);
        $display("Mem[122] = %d", mycpu.Mem[122]);

    end

    initial begin
        $dumpfile("mycpu.vcd");
        $dumpvars(0,test_pipe_MIPS32);
        #220 $finish;
    end
endmodule
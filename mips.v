module mips32 (
    clock
);
    input clock;

    // Defining some parameters for instructions like add, sub, mul, div, branch, and, or, not, set less than, halt, load, store intotal 16 instruction 
    // Also remember that opcode is of 6 bits
    parameter ADD = 6'b000000, ADDI = 6'b000001, SUB = 6'b000010, SUBI = 6'b000011, MUL = 6'b000110, MULI = 6'b000111, AND = 6'b001000;
    parameter  OR = 6'b001001, BEQZ = 6'b001011, BNEQZ = 6'b001100, LW = 6'b001101, SW = 6'b001110, SLT = 6'b001111, SLTI = 6'b010000, HLT = 6'b111111;

    // These above instructions can be grouped to form (a type) Register-Register ALU, Register-Immediate ALU, Load, Store, Branch, Halt. Creating parameters for them
    parameter RR_ALU = 3'b000, RM_ALU = 3'b010, LOAD = 3'b011, STORE = 3'b100, BRANCH = 3'b101, NOP = 3'b110, HALT = 3'b111;

    //IF
    // requires PC, NPC, access memory, 

    reg [31:0] PC;              // Program counter - Used to fecth instruction from memory
    reg [31:0] Reg [0:31];      // 32 registers of size 32 bits
    reg [31:0] Mem [0:1023];    // 32 Memory cells of size 1024 bits  
    reg HALTED, TAKEN_BRANCH;   // These are flags for halt and branch taken  
    reg [31:0] IF_ID_NPC;       // Next Program Counter
    reg [31:0] IF_ID_IR;
    reg IF_ID_RegWrite, IF_ID_MemWrite;
    reg IF_ID_Write, PC_write;

    reg next_ID_EX_RegWrite, next_ID_EX_MemWrite;
    reg next_EX_MEM_RegWrite, next_EX_MEM_MemWrite;

    reg [31:0] next_ID_EX_IR, next_EX_MEM_IR;
    reg [4:0] next_ID_EX_WriteRegAdd, next_EX_MEM_WriteRegAdd;
    reg [2:0] next_ID_EX_TYPE, next_EX_MEM_TYPE;

    reg [31:0] A, B, C;


    //ID
    //Fetches register data from register bank and sign extension of immediate values
    
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;
    reg [2:0] ID_EX_TYPE;
    reg [31:0] id_rs_data, id_rt_data;
    reg [4:0] ID_EX_WriteRegAdd;
    reg ID_EX_RegWrite, ID_EX_MemWrite;
    reg ID_EX_Write;


    //EX
    // Does ALU operations on A, B, NPC, IMM, checks for jumps condition
    // Also forward IR and B(for Load, store instruction) 

    reg [31:0] EX_MEM_IR, EX_MEM_ALUOUT, EX_MEM_B;
    reg [4:0] EX_MEM_WriteRegAdd;
    reg [2:0] EX_MEM_TYPE;
    reg EX_MEM_RegWrite, EX_MEM_MemWrite, EX_MEM_COND;

    reg [31:0] ALU_IN_A, ALU_IN_B;


    //MEM
    // Only for loading and storing from registers into memory

    reg [31:0] MEM_WB_IR, MEM_WB_LMD, MEM_WB_ALUOUT;
    reg [4:0] MEM_WB_WriteRegAdd;
    reg [2:0] MEM_WB_TYPE;
    reg MEM_WB_RegWrite;

    reg [31:0] D, Out;

    //WB
    reg [31:0] WB_FWD_IR, WB_FWD_DATA;
    reg [4:0] WB_FWD_WriteRegAdd;
    reg WB_FWD_RegWrite;



    //IF
    always @(posedge clock) begin
        if(HALTED == 0) begin
            
            // I am adding branch condition here as we get condition about branch to be taken from EX stage itself, so we need to decide our NPC at this stage
            // For this we need to check that the instruction is of branch (by checking the EX-MEM latch) for opcode and that the condition is true.
            // If branch condition is true then we need to select the address of instruction from the ALU output of EX stage itself as it has calculated the jump address.
            if((EX_MEM_COND == 0 && EX_MEM_IR[31:26] == BNEQZ)||(EX_MEM_COND == 1 && EX_MEM_IR[31:26] == BEQZ)) begin

                PC              <= EX_MEM_ALUOUT + 1;
                TAKEN_BRANCH    <= 1'b1;
                IF_ID_IR        <= Mem[EX_MEM_ALUOUT];
                IF_ID_NPC       <= EX_MEM_ALUOUT + 1;
            end
            // Else, just fetch instruction from memory by using PC and update PC and NPC

            // We control PC updation using PC_write for stalling the instruction if necessary
            // We control the writing to pipeline registers IF_ID to stall the instruction in IF stage only
            // TAKEN_BRANCH needs to be reseted at this stage if taken previously.
            else begin
                if(PC_write == 1)  PC <= PC + 1;
                if(IF_ID_Write == 1) begin
                    IF_ID_IR  <= Mem[PC];
                    IF_ID_NPC <= PC + 1;
                end
                TAKEN_BRANCH <= 1'b0;
            end

            // This MemWrite and RegWrite is part of an instruction, this is required to controlling writing into memory and registers
            if(IF_ID_Write == 1) begin
                IF_ID_MemWrite <= 1'b1;
                IF_ID_RegWrite <= 1'b1;
            end
        end
    end
//Pipeline registers must be updated only on clock edges.
//Flush logic must affect the inputs to the registers, not the registers themselves. 
//So for this we need to create new variables for the pipeline registers which will be forwarded to further stages
//Flushing means turning off all control signals for the instruction like MemWrite and RegWrite. Also we reset IR = 0 and TYPE = NOP to prevent this instruction from doing anything
//Flushing happens when branch instruction enters the pipeline, Branch instruction is decoded at EX stage
// Which means that already two instructions have entered the pipeline and are in IF and ID stage which we need to flush before they start acting up
//
//Similarly if there is any Hazard detection (register being used before it has been loaded which cannot be fixed by forwarding) we need to stall the instruction in IF and ID stage
// For stalling instruction in ID stage we forward NOP instruction to EX stage and preserve ID_EX pipeline registers by disabling ID_EX write
// For stalling instruction in IF stage we simply disable PC_Write to prevent it from fetching next instruction and disabling IF_ID write.

    always @(*) begin
        next_ID_EX_MemWrite = ID_EX_MemWrite;
        next_ID_EX_RegWrite = ID_EX_RegWrite;
        next_EX_MEM_RegWrite = EX_MEM_RegWrite;
        next_EX_MEM_MemWrite = EX_MEM_MemWrite;
        
        next_ID_EX_IR = ID_EX_IR;
        next_ID_EX_WriteRegAdd = ID_EX_WriteRegAdd;
        next_ID_EX_TYPE = ID_EX_TYPE;
        next_EX_MEM_WriteRegAdd = EX_MEM_WriteRegAdd;
        next_EX_MEM_IR = EX_MEM_IR;
        next_EX_MEM_TYPE = EX_MEM_TYPE;

        if(TAKEN_BRANCH == 1) begin
            next_ID_EX_MemWrite  = 1'b0;
            next_ID_EX_RegWrite  = 1'b0;
            next_EX_MEM_MemWrite = 1'b0;
            next_EX_MEM_RegWrite = 1'b0;

            next_ID_EX_IR = 32'h00000000;
            next_ID_EX_WriteRegAdd = 5'b00000;
            next_ID_EX_TYPE = NOP;
            next_EX_MEM_WriteRegAdd = 5'b00000;
            next_EX_MEM_IR = 32'h00000000;
            next_EX_MEM_TYPE = NOP;
        end

        if((EX_MEM_TYPE == LOAD) && ((EX_MEM_IR[20:16] == ID_EX_IR[25:21]) || (EX_MEM_IR[20:16] == ID_EX_IR[20:16])))begin
            // Disable PC write
            // Insert NOP in ID/EX
            // Prevent IF/ID write

            PC_write = 1'b0;
            
            next_ID_EX_IR = 32'h00000000;
            next_ID_EX_WriteRegAdd = 5'b00000;
            next_ID_EX_MemWrite = 1'b0;
            next_ID_EX_RegWrite = 1'b0;
            next_ID_EX_TYPE = NOP;
            IF_ID_Write = 1'b0;
            ID_EX_Write = 1'b0;
        end

        else begin
            PC_write = 1'b1;
            ID_EX_Write = 1'b1;
            IF_ID_Write = 1'b1;
        end
    end

    // Reads should always happen combinationally and write should be sequential
    always @(*) begin
        if(IF_ID_IR[25:21] == 5'b00000) id_rs_data = 0;
        else id_rs_data = Reg[IF_ID_IR[25:21]];

        if(IF_ID_IR[20:16] == 5'b00000) id_rt_data = 0;
        else id_rt_data = Reg[IF_ID_IR[20:16]];
    end

    //ID
    always @(posedge clock) begin
        if(HALTED == 0) begin
            if(ID_EX_Write == 1) begin
                // At this stage we need to decode the instruction that we have fetched
                // IR has mainly 6 components :-
                //  - opcode    : contains the instruction to be performed
                //  - rs        : source register (For load, store : contains the shift from base address, For ALU : contains data on which operation is performed)  
                //  - rt        : source register (For load, store : contains the address of the register to be loaded into or stored from, For ALU : Same as rs)
                //  - rd        : Destination register (Where operation is finally stored into)
                //
                // Also we deduce the type of instruction it is at this stage
                // Also we fetch the data from registers as well

                //Fetching data from registers
                // While fetching data from registers, if register address is 0  we assign value 0
                // Also we need to forward IR, NPC

                // For register 'rs or A'
                ID_EX_A <= id_rs_data;

                // For register 'rt or B'
                ID_EX_B <= id_rt_data;

                // Sign extension of immediate value to 32 bits
                ID_EX_IMM <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};

                case (IF_ID_IR[31:26])
                    ADD, SUB, MUL, SLT, AND , OR : begin 
                                                     ID_EX_TYPE <= RR_ALU; 
                                                     ID_EX_WriteRegAdd <= IF_ID_IR[15:11];
                                                     ID_EX_MemWrite <= 1'b0;
                                                     ID_EX_RegWrite <= IF_ID_RegWrite;
                                                    end
                    ADDI, SUBI, MULI, SLTI       : begin
                                                     ID_EX_TYPE <= RM_ALU; 
                                                     ID_EX_WriteRegAdd <= IF_ID_IR[20:16]; 
                                                     ID_EX_MemWrite <= 1'b0;
                                                     ID_EX_RegWrite <= IF_ID_RegWrite;
                                                    end
                    LW                           : begin 
                                                     ID_EX_TYPE <= LOAD;
                                                     ID_EX_WriteRegAdd <= IF_ID_IR[20:16];
                                                     ID_EX_MemWrite <= 1'b0;
                                                     ID_EX_RegWrite <= IF_ID_RegWrite;
                                                    end
                    SW                           :  begin 
                                                     ID_EX_TYPE <= STORE;
                                                     ID_EX_MemWrite <= IF_ID_MemWrite;
                                                     ID_EX_RegWrite <= 1'b0;

                                                    end
                    BEQZ, BNEQZ                  : begin 
                                                     ID_EX_TYPE <= BRANCH;
                                                     ID_EX_MemWrite <= 1'b0;
                                                     ID_EX_RegWrite <= 1'b0;
                                                    end
                    HLT                          : ID_EX_TYPE <= HALT;
                    default                      : begin 
                                                     ID_EX_TYPE <= NOP; 
                                                     ID_EX_MemWrite <= 1'b0;
                                                     ID_EX_RegWrite <= 1'b0;
                                                    end
                endcase

                ID_EX_IR <= IF_ID_IR;
                ID_EX_NPC <= IF_ID_NPC;
                
                
            end
        end
    end


    always @(*) begin
        // Forwarding logic is always combinational. So it cannot be done at clock cycles. It is implemented using MUXs
        //
        //
        //Fixing Data Hazards
        // Data hazards needs to be fixed for both source registers which could happen due to two previous instructions (instructions which are one and two cycles ahead)
        //                                                                                                              (and current instruction is in EX stage)
        // First we check if data hazard is happening or not
        // forward the latches appropriately by checking whether the data being forwarded is legit or not by checking MemWrite and RegWrite (ONLY for ALU instructions) 
        // 
        // For load instructions we forward data from MEM stage as thats where it gets loaded into LMD register also we check RegWrite whether the data is legit or not

        // Also for forwarding we need to check for both A and B registers if they require forwarding at the same time
        // Like for example in ADD R1 R1 R1, we may need to forward to both A and B
        

        ALU_IN_A = ID_EX_A;
        ALU_IN_B = ID_EX_B;

        // Forwarding always has a priority EX > MEM > WB maintain this 
        // Manitain a WriteReg instead of this abomination and stop forwarding IR altogether (In some stages only)

        // Forwarding for A according to priority
        if((ID_EX_IR[25:21] == EX_MEM_WriteRegAdd) && (EX_MEM_RegWrite == 1)) ALU_IN_A = EX_MEM_ALUOUT;
        else if((ID_EX_IR[25:21] ==  MEM_WB_WriteRegAdd) && (MEM_WB_RegWrite == 1)) begin
            if(MEM_WB_TYPE == LOAD) ALU_IN_A = MEM_WB_LMD;
            else ALU_IN_A = MEM_WB_ALUOUT;
        end
        else if((ID_EX_IR[25:21] == WB_FWD_WriteRegAdd) && (WB_FWD_RegWrite == 1))  // This is required as two different stages are tryiong to access the same register file ID stage still fetches old data
            ALU_IN_A = WB_FWD_DATA;                                                 // This fixes that issue, same is done for B as well


        // Forwarding for B according to priority
        if((ID_EX_IR[20:16] == EX_MEM_WriteRegAdd) && (EX_MEM_RegWrite == 1)) begin
            ALU_IN_B = EX_MEM_ALUOUT;
        end
        else if((ID_EX_IR[20:16] == MEM_WB_WriteRegAdd) && (MEM_WB_RegWrite == 1)) begin
            if(MEM_WB_TYPE == LOAD) ALU_IN_B = MEM_WB_LMD;
            else ALU_IN_B = MEM_WB_ALUOUT;
        end
        else if((ID_EX_IR[20:16] == WB_FWD_WriteRegAdd) && (WB_FWD_RegWrite == 1))
            ALU_IN_B = WB_FWD_DATA;
    end

    //EX 

    always @(posedge clock) begin
        if(HALTED == 0) begin
            // In this stage first according to the type of instrcution we need to choose what operations we need to perform
            // For ALU type instructions            : We need to perform operation on A and B
            // For Load, store type instructions    : We need to calculate the address(from where to load or to store) by operation on A and IMM value
            // For Branch instructions              : We need to calculate the address (for the branch instruction) by operation on NPC and B value (A is used for condition checking only) 
            // For HALT instruction                 : It is set at the very last stage to ensure all other instructions have been completed
            EX_MEM_TYPE <= next_ID_EX_TYPE;
            EX_MEM_MemWrite <= next_ID_EX_MemWrite;
            EX_MEM_RegWrite <= next_ID_EX_RegWrite;
            EX_MEM_WriteRegAdd <= next_ID_EX_WriteRegAdd;
            EX_MEM_IR <= next_ID_EX_IR;
            // if(ID_EX_IR == 32'h08612000) begin
            //     A = Reg[1];
            //     B = ID_EX_B;
            //     //Out = ALU_IN_A - ID_EX_IMM;
            //     C = ALU_IN_B;
            //     Out = D;
            //     HALTED = 1'b1;
            // end

            case (next_ID_EX_TYPE)
                RR_ALU  : begin
                    case (next_ID_EX_IR[31:26])
                        ADD     : EX_MEM_ALUOUT <= ALU_IN_A + ALU_IN_B; 
                        SUB     : EX_MEM_ALUOUT <= ALU_IN_A - ALU_IN_B; 
                        MUL     : EX_MEM_ALUOUT <= ALU_IN_A * ALU_IN_B; 
                        AND     : EX_MEM_ALUOUT <= ALU_IN_A & ALU_IN_B; 
                        OR      : EX_MEM_ALUOUT <= ALU_IN_A | ALU_IN_B; 
                        SLT     : EX_MEM_ALUOUT <= ALU_IN_A < ALU_IN_B; 
                        default : EX_MEM_ALUOUT <= {32{1'bx}};
                    endcase
                end
                RM_ALU  : begin
                    case (next_ID_EX_IR[31:26])
                        ADDI     : EX_MEM_ALUOUT <= ALU_IN_A + ID_EX_IMM; 
                        SUBI     : EX_MEM_ALUOUT <= ALU_IN_A - ID_EX_IMM; 
                        MULI       : EX_MEM_ALUOUT <= ALU_IN_A * ID_EX_IMM; 
                        SLTI       : EX_MEM_ALUOUT <= ALU_IN_A < ID_EX_IMM; 
                        default    : EX_MEM_ALUOUT <= {32{1'bx}};
                    endcase
                end
                LOAD, STORE : begin
                    EX_MEM_ALUOUT <= ALU_IN_A + ID_EX_IMM;   // Calculating Address
                    EX_MEM_B      <= ALU_IN_B;               // We need to forward B as it as the address of register to be loaded into or stored from  
                end
                BRANCH      : begin
                    EX_MEM_ALUOUT <= ID_EX_NPC + ID_EX_IMM;
                    EX_MEM_COND   <= (ALU_IN_A == 0);
                end
            endcase    
        end
    end

    //MEM

    always @(posedge clock) begin
        if(HALTED == 0) begin
            //This stage is specifically for Load and store instructions only
            // If branch is been taken then we need to prevent write from happening
            // Also we need to forward ALUOUT as it is needed for write back stage (For ALU operations)
            // and type.
            // Use case here for different type of instruction

            MEM_WB_TYPE   <= next_EX_MEM_TYPE;
            MEM_WB_IR <= next_EX_MEM_IR;
            MEM_WB_RegWrite <= next_EX_MEM_RegWrite;
            MEM_WB_WriteRegAdd <= next_EX_MEM_WriteRegAdd;

            if(HALTED == 0) begin
                case(next_EX_MEM_TYPE) 
                    RR_ALU, RM_ALU : begin
                        MEM_WB_ALUOUT <= EX_MEM_ALUOUT;
                    end

                    LOAD : begin
                        MEM_WB_LMD <= Mem[EX_MEM_ALUOUT];
                    end
                    STORE : begin
                        if(EX_MEM_MemWrite == 1)               // Preventing writing into memory if branch is taken
                            Mem[EX_MEM_ALUOUT] <= EX_MEM_B;
                    end
                endcase
            end
        end
    end

    //WB

    always @(posedge clock) begin
        if(HALTED == 0) begin
            if(MEM_WB_RegWrite == 1) begin
                // In this stage we need to write data into registers which is required in ALU instructions and load instructions so we need to use case here
                // Also we need to prevent write if branch is taken
                case (MEM_WB_TYPE)
                    RR_ALU, RM_ALU : begin
                        if(MEM_WB_WriteRegAdd == 0) Reg[MEM_WB_WriteRegAdd] <= 0;
                        else Reg[MEM_WB_WriteRegAdd] <= MEM_WB_ALUOUT;
                    end 
                    LOAD   : begin
                        if(MEM_WB_WriteRegAdd == 0) Reg[MEM_WB_WriteRegAdd] <= 0;
                        else Reg[MEM_WB_WriteRegAdd] <= MEM_WB_LMD;
                    end 
                    HALT   : begin
                        HALTED <= 1'b1;     // HLT is done at last to let previous instructions to complete before HALTING the cpu
                    end
                endcase

                WB_FWD_DATA <= MEM_WB_ALUOUT;
                WB_FWD_IR <= MEM_WB_IR;
                WB_FWD_WriteRegAdd <= MEM_WB_WriteRegAdd;
                WB_FWD_RegWrite <= MEM_WB_RegWrite;
            end
        end
    end
endmodule


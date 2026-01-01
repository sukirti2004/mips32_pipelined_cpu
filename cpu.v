
// IF : Instruction Fetch
// ID : Instruction Decode
// EX : Execute
// MEM : Memory
// WB : Write Back
// IR : Instruction Read
// LMD : Load Memory Data
// ALUOUT : Output of ALU
// COND : Condition
// SLT  : Set on less than
// HLT  : Halt
// SW   : Store Word

module pipeline_MIPS32 (
    clock_1, clock_2
);
    input clock_1, clock_2;         // To prevent Race condition we use two different clocks

    reg [31:0] PC;                  // Program counter : Stores address of the Instructions

    reg [31:0] IF_ID_NPC, IF_ID_IR;                                             

    reg [31:0] ID_EX_A, ID_EX_B, ID_EX_IMM, ID_EX_NPC, ID_EX_IR;            // Register A - rs,  Register B - rt

    reg [31:0] EX_MEM_ALUOUT, EX_MEM_IR, EX_MEM_COND, EX_MEM_B;

    reg [31:0] MEM_WB_LMD, MEM_WB_IR, MEM_WB_ALUOUT;

    reg [31:0] Reg [0 : 31];    // 32 x 32 bits Register Bank
    reg [31:0] Mem [0:1023];    // 32 x 1024 bits Memory storage

    reg [2:0] ID_EX_TYPE, EX_MEM_TYPE, MEM_WB_TYPE;             // This stores the type of instruction

    reg HALTED, TAKEN_BRANCH;

    //Defining Parameters for easy understanding
    parameter  ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011, SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b000110, SW = 6'b000111;
    parameter  LW = 6'b001000, ADDI = 6'b001001, SUBI = 6'b001010, SLTI = 6'b001011, BNEQZ = 6'b001100, BEQZ = 6'b001101;   

    parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;


    // Instruction Fetch Stage
    // In this stage we fetch instruction by fecting it from memory using PC as address
    // We calculate the next program counter by adding + 1
    // If there is a branch condition triggered by previous instruction then NPC is updated to the jump address

    always @(posedge clock_1) begin
        if (HALTED == 0) begin
            if ((EX_MEM_IR[31:26]== BEQZ && EX_MEM_COND == 1) || (EX_MEM_IR[31:26]== BNEQZ && EX_MEM_COND == 0)) begin
                IF_ID_IR    <= #2 Mem[EX_MEM_ALUOUT];   // fetching Instruction from address calculated from previous branch instruction
                TAKEN_BRANCH <= #2 1'b1;                // Flag for branch is taken
                IF_ID_NPC   <= #2 EX_MEM_ALUOUT + 1;    // Forwarding NPC 
                PC          <= #2 EX_MEM_ALUOUT + 1;    // Updating PC to next
            end

            else begin
                IF_ID_IR <= #2 Mem[PC];                 // Fetching instruction from address stored in PC
                IF_ID_NPC <= #2 PC + 1;                 // Forwarding NPC 
                PC        <= #2 PC + 1;                 // Updating PC to next
            end
        end
    end

    // Instruction Decode Stage

    // In this stage we decode the instruction we fecthed in IF stage
    // Instruction is of 32 bits which contains 
    //      - Opcode : operational code
    //      - Rs and Rt    : Source register(A and B in our case)
    //      - Rd        : Destination register
    //      - shamt     : Shift Amount
    //      - funct     : Function
    //      - Imm       : Immediate Value
    // NPC and IR are forwarded as they are used in further stages

    always @(posedge clock_2) begin
        if (HALTED == 0) begin
            if(IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= 0;               // If register address is zero assigning zero - ST(1)
            else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];                    // Fetching value from register location - ST(2)

            if(IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= 0;               // ST(1)
            else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]];                    // ST(2)

            ID_EX_NPC   <= #2 IF_ID_NPC;
            ID_EX_IR    <= #2 IF_ID_IR;
            ID_EX_IMM   <= #2 { {16{IF_ID_IR[15]}},IF_ID_IR[15:0]};       // 16{ID_EX_IR[15]} - Repeats ID_EX_IR[15] 16 times to make it 32 bits

            case(IF_ID_IR[31:26])
                ADD, SUB, AND, OR, MUL, SLT : ID_EX_TYPE <= #2 RR_ALU;  // register-register alu instruction
                ADDI, SUBI, SLTI            : ID_EX_TYPE <= #2 RM_ALU;  // register-immediate alu instruction
                BNEQZ, BEQZ                 : ID_EX_TYPE <= #2 BRANCH;  // Branch instruction
                HLT                         : ID_EX_TYPE <= #2 HALT;    // Halt instruction
                LW                          : ID_EX_TYPE <= #2 LOAD;    // Load Instruction
                SW                          : ID_EX_TYPE <= #2 STORE;   // Store instruction
                default                     : ID_EX_TYPE <= #2 HALT;    // Invalid Instruction
            endcase
        end
    end

    //Execution Stage 
    // This Stage is responsible for execution of -
    //      - ALU operations
    //      - Caluclating address for LOAD, STORE and Branch address 

    always @(posedge clock_1) begin
        if(HALTED == 0) begin
            EX_MEM_IR  <= #2 ID_EX_IR;      
            //EX_MEM_NPC <= #2 ID_EX_NPC;   // EX stage does not require NPC as we have already calculated branch address in this stage
            //EX_MEM_B   <= #2 ID_EX_B;     // You Need not to always pass B as it is required only in case of Load and Store Instruction
            EX_MEM_TYPE <= #2 ID_EX_TYPE;   // Forwarding the type of instruction to next stage  
            TAKEN_BRANCH <= #2 1'b0;        // This needs to be set to 0 at every cycle to prevent errors as once branch if taken needs to be set to 0                           

            case (ID_EX_TYPE)
                RR_ALU : begin                                              // Register Register ALU
                    case (ID_EX_IR[31:26])                                  //opcode
                        ADD : EX_MEM_ALUOUT <= #2 ID_EX_A   +   ID_EX_B;
                        SUB : EX_MEM_ALUOUT <= #2 ID_EX_A   -   ID_EX_B;
                        MUL : EX_MEM_ALUOUT <= #2 ID_EX_A   *   ID_EX_B;
                        AND : EX_MEM_ALUOUT <= #2 ID_EX_A   &   ID_EX_B;
                        OR  : EX_MEM_ALUOUT <= #2 ID_EX_A   |   ID_EX_B;
                        SLT : EX_MEM_ALUOUT <= #2 ID_EX_A   <   ID_EX_B;
                        default: EX_MEM_ALUOUT  <= {32{1'bx}};
                    endcase
                end   
                RM_ALU : begin                                              // Register - Immediate ALU
                    case (ID_EX_IR[31:26])
                        ADDI : EX_MEM_ALUOUT <= #2 ID_EX_A  + ID_EX_IMM;
                        SUBI : EX_MEM_ALUOUT <= #2 ID_EX_A  - ID_EX_IMM;
                        SLTI : EX_MEM_ALUOUT <= #2 ID_EX_A  < ID_EX_IMM;
                        default : EX_MEM_ALUOUT <= {32{1'bx}};
                    endcase
                end  
                LOAD, STORE : begin
                    EX_MEM_ALUOUT <= #2 ID_EX_A +   ID_EX_IMM;              // This Calculates the actual address from where to load and store
                    EX_MEM_B      <= #2 ID_EX_B;                            // This contains the value to be stored
                end
                BRANCH : begin                                              // We are computing Branch in EX stage But deciding Branch at IF stage so there is # cycle penalty
                    EX_MEM_ALUOUT <= #2 ID_EX_NPC + ID_EX_IMM;              // IF -> ID -> EX are wasted
                    EX_MEM_COND   <= #2 (ID_EX_A == 0);
                end
            endcase

        end
    end

    // Memory Stage

    always @(posedge clock_2) begin
        if(HALTED == 0) begin
            MEM_WB_TYPE <= #2 EX_MEM_TYPE;                  // MEM stage requires this
            MEM_WB_IR   <= #2 EX_MEM_IR;

            case(EX_MEM_TYPE)
                RR_ALU, RM_ALU : begin
                    MEM_WB_ALUOUT <= #2 EX_MEM_ALUOUT;      // ALU instructions do not require memory write or read
                end
                LOAD : begin
                    MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOUT];    // Loading from Memory
                end
                STORE : begin
                    if(TAKEN_BRANCH == 0)                   // When Branch instruction, no write is allowed
                        Mem[EX_MEM_ALUOUT] <= #2 EX_MEM_B;  // Loading into Memory from register
                end
            endcase
        end
    end

    // Write-Back Stage

    always @(posedge clock_2) begin
        if (HALTED == 0) begin
            if(TAKEN_BRANCH == 0) begin                                 // Disable Write if Branch Instruction
                case(MEM_WB_TYPE)
                    RR_ALU : Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOUT; // 'rd'
                    RM_ALU : Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOUT; // 'rt'
                    LOAD   : Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;    // 'rt'
                    HALT   : HALTED <= #2 1'b1;
                    // By waiting until WB, we ensure:
                    //All prior instructions have completed safely.
                    //The architectural state (registers, memory) is fully committed.
                    //No partial execution remains.
                endcase
            end
        end
    end

endmodule
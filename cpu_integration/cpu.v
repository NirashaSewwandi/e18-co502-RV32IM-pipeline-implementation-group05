`include "../mux/mux2x1.v"
`include "../mux/mux4x1.v"
`include "../register/register_32bit.v"
`include "../adder/adder.v"
`include "../instruction cache/instruction_cache.v"
`include "../register file/register_file.v"
`include "../control unit/controlUnit.v"
`include "../sign extend unit/signExtend.v"
`include "../alu/alu.v"
`include "../branchLogic/branchLogic.v"
`include "../data cache/data_cache.v"
`include "../pipeline_registers/ex_mem_pipeline_register.v"
`include "../pipeline_registers/id_ex_pipeline_register.v"
`include "../pipeline_registers/if_id_pipeline_register.v"
`include "../pipeline_registers/mem_wb_pipeline_register.v"
`include "../forwarding unit/forwarding_unit.v"


module cpu (RESET, CLK, INST_MEM_READDATA, DATA_MEM_READDATA, DATA_MEM_WRITEDATA, INST_MEM_READ, DATA_MEM_BUSYWAIT, DATA_MEM_READ, DATA_MEM_WRITE, INST_MEM_ADDRESS, DATA_MEM_ADDRESS, INST_MEM_BUSYWAIT);

input RESET, CLK, INST_MEM_BUSYWAIT, DATA_MEM_BUSYWAIT;
input [127:0] INST_MEM_READDATA, DATA_MEM_READDATA;
output [127:0] DATA_MEM_WRITEDATA;
output INST_MEM_READ, DATA_MEM_READ, DATA_MEM_WRITE;
output [27:0] INST_MEM_ADDRESS, DATA_MEM_ADDRESS;

wire [31:0] PC_4_OUT, ALU_OUT, PC_SEL_MUX_OUT, PC_OUT, INSTRUCTION, INSTRUCTION_ID, PC_OUT_ID, WB_MUX_OUT, REG_FILE_OUT1, REG_FILE_OUT2, IMM_GEN_OUT, PC_OUT_EX, REG_FILE_OUT1_EX, REG_FILE_OUT2_EX, IMM_GEN_OUT_EX, OPERAND1, OPERAND2, PC_OUT_MEM, ALU_OUT_MEM, REG_FILE_OUT2_MEM, IMM_GEN_OUT_MEM, PC_4_WB_OUT, READDATA, PC_4_WB_OUT_WB, ALU_OUT_WB, IMM_GEN_OUT_WB,  READDATA_WB;

wire PC_SEL, DATA_BUSYWAIT, INST_BUSYWAIT, REG_WRITE_EN_WB, WRITE_ENABLE, BUSYWAIT,OP1SEL, OP2SEL, REG_WRITE_EN, OP1SEL_EX,  OP2SEL_EX, REG_WRITE_EN_EX, REG_WRITE_EN_MEM;
wire [4:0] WRITE_ADDRESS_WB, WRITE_ADDRESS_EX, WRITE_ADDRESS_MEM;
wire [2:0] IMM_SEL, BRANCH_JUMP, BRANCH_JUMP_EX;
wire [1:0] WB_SEL, WB_SEL_EX, WB_SEL_MEM, WB_SEL_WB;
wire [4:0] ALUOP, ALUOP_EX;
wire [3:0] READ_WRITE, READ_WRITE_EX, READ_WRITE_MEM;

assign BUSYWAIT = (DATA_BUSYWAIT | INST_BUSYWAIT);
assign WRITE_ENABLE = (REG_WRITE_EN_WB & !BUSYWAIT);

// Instruction fetch stage
mux2x1 pc_sel_mux(PC_4_OUT, ALU_OUT, PC_SEL_MUX_OUT, PC_SEL);
register_32bit program_counter(PC_SEL_MUX_OUT, PC_OUT, RESET, CLK, BUSYWAIT);
instruction_cache inst_cache(CLK, RESET, PC_OUT, INSTRUCTION, INST_BUSYWAIT, INST_MEM_ADDRESS, INST_MEM_READ, INST_MEM_READDATA, INST_MEM_BUSYWAIT);
adder pc_4_adder(PC_OUT, PC_4_OUT);

if_id_pipeline_register if_id_reg(INSTRUCTION, PC_OUT, INSTRUCTION_ID, PC_OUT_ID, CLK, (RESET | (CLK & PC_SEL)), BUSYWAIT);

// Instruction decode stage

reg_file register_file(WB_MUX_OUT, REG_FILE_OUT1, REG_FILE_OUT2, WRITE_ADDRESS_WB, INSTRUCTION_ID[19:15], INSTRUCTION_ID[24:20], WRITE_ENABLE, CLK, RESET);
signExtend imm_gen(INSTRUCTION_ID[31:7], IMM_GEN_OUT, IMM_SEL);
controlUnit ctrl_unit(INSTRUCTION_ID[6:0], INSTRUCTION_ID[14:12], INSTRUCTION_ID[31:25], OP1SEL, OP2SEL, REG_WRITE_EN, WB_SEL, ALUOP, BRANCH_JUMP, IMM_SEL, READ_WRITE);


wire DATA1IDSEL, DATA2IDSEL, DATAMEMSEL, DATAMEMSEL_EX , DATAMEMSEL_MEM;
wire [1:0] DATA1ALUSEL, DATA2ALUSEL, DATA1BJSEL, DATA2BJSEL;
wire [1:0] DATA1ALUSEL_EX, DATA2ALUSEL_EX, DATA1BJSEL_EX, DATA2BJSEL_EX;

forwarding_unit fwd_unit (
    INSTRUCTION_ID[19:15], INSTRUCTION_ID[24:20], WRITE_ADDRESS_WB, WRITE_ADDRESS_MEM, WRITE_ADDRESS_EX, OP1SEL, OP2SEL, INSTRUCTION_ID[6:0],
    DATA1IDSEL, DATA2IDSEL, DATA1ALUSEL, DATA2ALUSEL, DATA1BJSEL, DATA2BJSEL, DATAMEMSEL
);

wire [31:0] DATA1_ID, DATA2_ID;

mux2x1 mux_id_1(REG_FILE_OUT1, WB_MUX_OUT, DATA1_ID, DATA1IDSEL);
mux2x1 mux_id_2(REG_FILE_OUT2, WB_MUX_OUT, DATA2_ID, DATA2IDSEL);

id_ex_pipeline_register id_ex_reg(INSTRUCTION_ID[11:7], PC_OUT_ID, DATA1_ID, DATA2_ID, IMM_GEN_OUT, DATA1ALUSEL, DATA2ALUSEL, DATA1BJSEL, DATA2BJSEL, ALUOP, BRANCH_JUMP, DATAMEMSEL, READ_WRITE, WB_SEL, REG_WRITE_EN, WRITE_ADDRESS_EX, PC_OUT_EX, REG_FILE_OUT1_EX, REG_FILE_OUT2_EX, IMM_GEN_OUT_EX, DATA1ALUSEL_EX, DATA2ALUSEL_EX, DATA1BJSEL_EX, DATA2BJSEL_EX, ALUOP_EX, BRANCH_JUMP_EX, DATAMEMSEL_EX, READ_WRITE_EX, WB_SEL_EX, REG_WRITE_EN_EX, CLK,  (RESET | (CLK & PC_SEL)), BUSYWAIT);

// Instruction execution stage
// mux_2x1_32bit operand1_mux(REG_FILE_OUT1_EX, PC_OUT_EX, OPERAND1, OP1SEL_EX);
// mux_2x1_32bit operand2_mux(REG_FILE_OUT2_EX, IMM_GEN_OUT_EX, OPERAND2, OP2SEL_EX);

mux4x1 mux_ex_alu_1(REG_FILE_OUT1_EX, PC_OUT_EX, WB_MUX_OUT, ALU_OUT_MEM, OPERAND1, DATA1ALUSEL_EX);
mux4x1 mux_ex_alu_2(REG_FILE_OUT2_EX, IMM_GEN_OUT_EX, WB_MUX_OUT, ALU_OUT_MEM, OPERAND2, DATA2ALUSEL_EX);

alu alu_unit(OPERAND1, OPERAND2, ALU_OUT,ALUOP_EX);

wire [31:0] MUX_EX_BJ1_OUT, MUX_EX_BJ2_OUT;

mux4x1 mux_ex_bj_1(REG_FILE_OUT1_EX, REG_FILE_OUT1_EX, WB_MUX_OUT, ALU_OUT_MEM, MUX_EX_BJ1_OUT, DATA1BJSEL_EX);
mux4x1 mux_ex_bj_2(REG_FILE_OUT2_EX, REG_FILE_OUT2_EX, WB_MUX_OUT, ALU_OUT_MEM, MUX_EX_BJ2_OUT, DATA2BJSEL_EX);

wire [31:0] MUX_EX_OUT, MUX_EX_OUT_MEM;
mux4x1 mux_ex(REG_FILE_OUT2_EX, REG_FILE_OUT2_EX, WB_MUX_OUT, ALU_OUT_MEM, MUX_EX_OUT, DATA2BJSEL_EX);

branchLogic bj_unit(BRANCH_JUMP_EX, MUX_EX_BJ1_OUT, MUX_EX_BJ2_OUT, PC_SEL);

ex_mem_pipeline_register ex_mem_reg(WRITE_ADDRESS_EX, PC_OUT_EX, ALU_OUT, MUX_EX_OUT, IMM_GEN_OUT_EX, DATAMEMSEL_EX, READ_WRITE_EX, WB_SEL_EX, REG_WRITE_EN_EX, WRITE_ADDRESS_MEM, PC_OUT_MEM, ALU_OUT_MEM, MUX_EX_OUT_MEM, IMM_GEN_OUT_MEM, DATAMEMSEL_MEM, READ_WRITE_MEM, WB_SEL_MEM, REG_WRITE_EN_MEM, CLK,  RESET, BUSYWAIT);

// Memory stage
adder pc_4_adder_wb(PC_OUT_MEM, PC_4_WB_OUT);

wire [31:0] MUX_MEM_OUT;
mux2x1 mux_mem(MUX_EX_OUT_MEM, WB_MUX_OUT, MUX_MEM_OUT, DATAMEMSEL_MEM);

data_cache d_cache(CLK, RESET, DATA_BUSYWAIT, READ_WRITE_MEM, MUX_MEM_OUT, READDATA, ALU_OUT_MEM, DATA_MEM_BUSYWAIT, DATA_MEM_READ, DATA_MEM_WRITE, DATA_MEM_READDATA, DATA_MEM_WRITEDATA, DATA_MEM_ADDRESS);

mem_wb_pipeline_register mem_wb_reg(WRITE_ADDRESS_MEM, PC_4_WB_OUT, ALU_OUT_MEM,  IMM_GEN_OUT_MEM, READDATA, WB_SEL_MEM, REG_WRITE_EN_MEM, WRITE_ADDRESS_WB, PC_4_WB_OUT_WB, ALU_OUT_WB, IMM_GEN_OUT_WB,  READDATA_WB, WB_SEL_WB, REG_WRITE_EN_WB, CLK,  RESET, BUSYWAIT);

// Writeback stage
mux4x1 wb_mux(ALU_OUT_WB, READDATA_WB, IMM_GEN_OUT_WB, PC_4_WB_OUT_WB, WB_MUX_OUT, WB_SEL_WB);

endmodule
`default_nettype none
module processor( input         clk, reset,
                  output [31:0] PC,
                  input  [31:0] instruction,
                  output        WE,
                  output [31:0] address_to_mem,
                  output [31:0] data_to_mem,
                  input  [31:0] data_from_mem
                );
    //... write your code here ...
	assign address_to_mem = aluOut;
	assign data_to_mem = writeData;
	assign PC = programCount;
	reg [31:0] programCount;
	wire [31:0] PC_cable;
	
	always @(posedge clk) begin
		programCount <= PC_cable;
		if (reset)
			programCount <= {32{1'b0}}; 	
	end

	wire [31:0]rs1;
	wire [31:0]aluOut;
	wire [31:0]immOp; 
	wire zero;
	wire [31:0]writeData;
	wire [31:0]readData = data_from_mem;
	wire [31:0]branchTarget;
	wire [31:0]memToRegRes;
    wire [31:0]aluSrcOut;
    wire [31:0]pcPlusFour;
    wire [31:0]branchJalReturnAddr;
    wire [31:0]branchJalrMuxIn;
    wire [31:0]srcACable;

	wire [3:0]aluControl;
   	wire [2:0]immControl;
	wire memWrite;
	assign WE = memWrite;
	wire regWrite;
	wire aluSrc;
	wire memToReg;
	wire branchBeq;
	wire branchJal;
	wire branchJalr;
	wire branchBlt;

	cu cu (
		instruction,
		aluControl,
		immControl,
		memWrite,
		regWrite,
		aluSrc,
		memToReg,
		branchBeq,
		branchJal,
		branchJalr,
		branchBlt
	);
	alu32 alu32 (srcACable, aluSrcOut, aluControl, zero, aluOut);
    immDecode immDecode (instruction[31:7]/*from instr mem*/, immControl/*from cu*/, immOp/*output to aluSrcMux and dataMemory*/);
	reg32 registerSet(instruction[19:15]/*a1*/, instruction[24:20]/*a2*/, instruction[11:7]/*a3*/, memToRegRes/*memToRegMux result*/, clk, regWrite/*from cu*/, rs1/*wire*/, writeData/*goes to aluSrcMux and dataMemory*/); 	
	assign branchJalrMuxIn = immOp + programCount; //branch adder
	wire branchBx = (branchBeq & zero);  
	assign pcPlusFour = programCount + 3'b100;
	wire branchJalx = branchJal | branchJalr;
	wire branchOutcome = branchBx | branchJalx;
	mux32 aluSrcMux(writeData, immOp, aluSrc, aluSrcOut);
	mux32 branchOutcomeMux(pcPlusFour, branchTarget, branchOutcome, PC_cable);
	mux32 branchJalrMux(branchJalrMuxIn, aluOut, branchJalr, branchTarget); 	
	mux32 branchJalJalrMux(aluOut, pcPlusFour, branchJalx, branchJalReturnAddr); 
	mux32 memToRegMux(branchJalReturnAddr, readData, memToReg, memToRegRes); 

endmodule

//... add new Verilog modules here ...

module mux32(
	input [31:0]a,
   	input [31:0]b,
	input select,
	output [31:0]y 	
); 

	assign y = (a & ~select) | (b & select); 
endmodule

module reg32(
	input [4:0]a1, 
	input [4:0]a2, 
	input [4:0]a3,
   	input [31:0]wd3,
	input we3,	
	input clk,
	output [31:0]rd1, 	
	output [31:0]rd2
);

	reg [31:0] rf [31:0];

	initial begin
		rf[0] = 32'b0;
	end

	assign rd1 = rf[a1];
	assign rd2 = rf[a2];

	always @(posedge clk) begin
		if (we3 && a3 != 5'b0) begin
			rf[a3] <= wd3;
		end
	end 	
endmodule

module alu32(
	input signed [31:0]srcA,  
	input signed [31:0]srcB,
  	input [3:0]aluControl,
	output reg zero,
	output reg [31:0]aluResult 	
); 
`ifndef CLOG2_FUNCTION
`define CLOG2_FUNCTION

function integer clog2;
    input integer value;
          integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1) begin
            temp = temp >> 1;
        end
    end
endfunction
`endif

	integer tmp;
	always @(*) begin
		case (aluControl)
			   4'b0000: aluResult = srcA + srcB; 	
			   4'b0001: aluResult = srcA - srcB; 	
			   4'b0010: aluResult = srcA & srcB; 	
			   4'b0011: aluResult = srcA < srcB ? 1 : 0; 	
			   4'b0100: aluResult = srcA / srcB; 	
			   4'b0101: aluResult = srcA % srcB; 	
			   4'b0110: aluResult = srcB; 	
			   4'b0111: aluResult = srcA | srcB; 	
			   4'b1001: aluResult = srcA >> srcB; //srl
	    endcase
	zero = aluResult == 0 ? 1 : 0;
   	end
endmodule


module cu(
	input [31:0]instruction,
   	output reg [3:0]aluControl,	
	output reg [2:0]immControl,
	output reg branchBeq,
	output reg branchJal,
	output reg branchJalr,
	output reg branchBlt,
   	output reg regWrite,	
	output reg memToReg,
   	output reg memWrite,	
   	output reg aluSrc
);

	wire [6:0]opcode = instruction[6:0];
  	wire [14:12]function3 = instruction[14:12];
	wire [31:25]function7 = instruction[31:25];  	

	always @(*)begin
		case (opcode)
			7'b0110011: begin
				case (function3)
					3'b000: begin
						case (function7)
							7'b0000000: begin //add
								immControl = 3'b000;
								aluControl = 4'b0000;
								memWrite = 0;
								regWrite = 1;
								aluSrc = 0;
								memToReg = 0;
								branchBeq = 0;
								branchJal = 0;
								branchBlt = 0;
								branchJalr = 0;
							end
							7'b0100000: begin //sub
								immControl = 3'b000;
								aluControl = 4'b0001;
								memWrite = 0;
								regWrite = 1;
								aluSrc = 0;
								memToReg = 0;
								branchBeq = 0;
								branchJal = 0;
								branchBlt = 0;
								branchJalr = 0;
							end	
						endcase	
					end
					3'b111: begin
						case (function7)
							7'b0000000: begin //and
								immControl = 3'b000;
								aluControl = 4'b0010;
								memWrite = 0;
								regWrite = 1;
								aluSrc = 0;
								memToReg = 0;
								branchBeq = 0;
								branchJal = 0;
								branchBlt = 0;
								branchJalr = 0;
							end	
						endcase
					end
					3'b101: begin
						case (function7)
							7'b0000000: begin //srl
								immControl = 3'b000;
								aluControl = 4'b1001;
								memWrite = 0;
								regWrite = 1;
								aluSrc = 0;
								memToReg = 0;
								branchBeq = 0;
								branchJal = 0;
								branchBlt = 0;
								branchJalr = 0;
							end
						endcase	
					end	
				endcase	
			end
			7'b0000011: begin
				case (function3)
					3'b010: begin // lw
						immControl = 3'b001;
					   	aluControl = 4'b0000;
						memWrite = 0;
						regWrite = 1;
						aluSrc = 1;
						memToReg = 1;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 0;	
					end		
				endcase	
			end
			7'b0100011: begin
				case (function3)
					3'b010: begin //sw
						immControl = 3'b010;
						aluControl = 4'b0000;
						memWrite = 1;
						regWrite = 0;
						aluSrc = 1;
						memToReg = 1;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 0;
					end
				endcase	
			end
			7'b1101111: begin //jal
					immControl = 3'b101;
					aluControl = 4'b0000;
					memWrite = 0;
					regWrite = 1;
					aluSrc = 0;
					memToReg = 0;
					branchBeq = 0;
					branchJal = 1;
					branchBlt = 0;
					branchJalr = 0;
			end
			7'b1100111: begin
				case (function3)
					3'b000: begin //jalr
						immControl = 3'b101;
						aluControl = 4'b0000;
						memWrite = 0;
						regWrite = 1;
						aluSrc = 1;
						memToReg = 0;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr =1;
					end	
				endcase
			end
			7'b0010011: begin
				case (function3)
					3'b000: begin //addi
						immControl = 3'b001;
						aluControl = 4'b0000;
						memWrite = 0;
						regWrite = 1;
						aluSrc = 1;
						memToReg = 0;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 0;
					end	
				endcase	
			end
			7'b1100011: begin
				case (function3)
					3'b000: begin //beq
						immControl = 3'b011;
						aluControl = 4'b0001;
						memWrite = 0;
						regWrite = 0;
						aluSrc = 0;
						memToReg = 0;
						branchBeq = 1;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 0;
					end	
					3'b100: begin //blt
						immControl = 3'b011;
						aluControl = 4'b0011;
						memWrite = 0;
						regWrite = 0;
						aluSrc = 0;
						memToReg = 0;
						branchBeq = 1;
						branchJal = 0;
						branchBlt = 1;
						branchJalr = 0;
					end	
				endcase	
			end
			7'b0110111: begin //lui
					immControl = 3'b100;
					aluControl = 4'b0110;
					memWrite = 0;
					regWrite = 1;
					aluSrc = 1;
					memToReg = 0;
					branchBeq = 1;
					branchJal = 0;
					branchBlt = 1;
					branchJalr = 0;
			end
			7'b0001011: begin //floor_log
				case (function3)
					3'b000: begin
						immControl = 3'b000; 
						aluControl = 4'b1010;
						memWrite = 0;
						regWrite = 1;
						aluSrc = 0;
						memToReg = 0;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 0;
					end
			endcase
			end	
		endcase
	end	
endmodule

module immDecode(
	input [31:7]instruction,
   	input [2:0]immControl,
	output reg [31:0]immOut 	
);

always @(*) begin
	case (immControl)
		3'b000: //I-type Imm
			immOut = {{20{instruction[31]}}, instruction[31:20]}; 	
		3'b001: //S-type Imm
			immOut = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
		3'b010: //B-type Imm
			immOut = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0}; 	
		3'b011: //U-type Imm
			immOut = {instruction[31:12], 12'b0}; 
		3'b100: //J-type Imm
			immOut = {{11{instruction[31]}}, instruction[31], instruction[119:12], instruction[20], instruction[30:21], 1'b0};
   		default:
			immOut = 32'b0; 	
	endcase		
end
endmodule

`default_nettype wire

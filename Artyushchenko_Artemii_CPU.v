`default_nettype none
module processor( input         clk, reset,
                  output [31:0] PC,
                  input  [31:0] instruction,
                  output        WE,
                  output [31:0] address_to_mem,
                  output [31:0] data_to_mem,
                  input  [31:0] data_from_mem
                );

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

	//Cables(wires)

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

    //CU signals

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

	//Constructors

	cu cu (
		instruction,
		immControl,
		aluControl,
		memWrite,
		regWrite,
		aluSrc,
		memToReg,
		branchBeq,
		branchJal,
		branchJalr,
		branchBlt
	);


	alu32 alu32 (
		.srcA      (rs1),
		.srcB      (aluSrcOut),
		.aluControl(aluControl),
		.aluResult (aluOut),
		.zero      (zero)
	);
    

    immDecode immDecode(
    	.immControl (immControl),
    	.instruction(instruction[31:7]),
    	.immOut     (immOp)
    );
	
	
	reg32 registerSet(
		.a1 (instruction[19:15]),
		.a2 (instruction[24:20]),
		.a3 (instruction[11:7]),
		.wd3(memToRegRes),
		.clk(clk),
		.we3(regWrite),
		.rd1(rs1),
		.rd2(writeData)
	);

	mux32 aluSrcMux(
		.select(aluSrc),
		.d0    (writeData),
		.d1    (immOp),
		.y     (aluSrcOut)
	);


	mux32 branchOutcomeMux(
		.select(branchOutcome),
		.d0    (pcPlusFour),
		.d1    (branchTarget),
		.y     (PC_cable)
	);


	mux32 branchJalrMux(
		.select(branchJalr),
		.d0    (branchJalrMuxIn),
		.d1    (aluOut),
		.y     (branchTarget)
	);


	mux32 branchJalJalrMux(
		.select(branchJalx),
		.d0    (aluOut),
		.d1    (pcPlusFour),
		.y     (branchJalReturnAddr)
	);
	

	mux32 memToRegMux(
		.select(memToReg),
		.d0    (branchJalReturnAddr),
		.d1    (readData),
		.y     (memToRegRes)
	);

	//Additional elements

	wire branchJalx = branchJal | branchJalr;
	
	assign branchJalrMuxIn = immOp + programCount;
	
	wire branchBx = (branchBeq & zero);  
	
	assign pcPlusFour = programCount + 3'b100;
	
	wire branchOutcome = branchBx | branchJalx;

endmodule

module mux32(
	input select,
	input [31:0]d0,
   	input [31:0]d1,
	output [31:0]y 	
); 

	assign y = select ? d1 : d0;
endmodule

module reg32(
	input [4:0]a1, 
	input [4:0]a2, 
	input [4:0]a3,
   	input [31:0]wd3,
	input clk,	
	input we3,
	output [31:0]rd1, 	
	output [31:0]rd2
);

	reg [31:0] registers [31:0];

    assign rd1 = a1 == 0 ? 0 : registers[a1];
    assign rd2 = a2 == 0 ? 0 : registers[a2];

    always @ ( posedge clk )
        if ( we3 && a3 != 0 )
            registers[a3] <= wd3;

endmodule

module alu32(
	input signed [31:0]srcA,  
	input signed [31:0]srcB,
  	input [3:0]aluControl,
  	output reg [31:0]aluResult,
	output reg zero 	
); 

	reg [7:0]exponent;
	reg [31:0]log2_result;

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
			   4'b1010: begin //floor_log
					exponent = srcA[30:23];
					log2_result = exponent - 8'b01111111;
					// aluResult = $signed(log2_result);
					aluResult = log2_result;
			   end
			   default: aluResult = 32'b0;
	    endcase
	zero = (aluResult == 0) ? 1 : 0;
   	end
endmodule


module cu(
	input [31:0]instruction,
	output reg [2:0]immControl,
   	output reg [3:0]aluControl,
   	output reg memWrite,
   	output reg regWrite,
   	output reg aluSrc,
   	output reg memToReg,
	output reg branchBeq,
	output reg branchJal,
	output reg branchJalr,
	output reg branchBlt	
);

	wire [6:0]opcode = instruction[6:0];
  	wire [14:12]function3 = instruction[14:12];
	wire [31:25]function7 = instruction[31:25];  	

	always @(*)begin
		case (opcode)
			7'b0001011: begin //floor_log
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
						immControl = 3'b001;
						aluControl = 4'b0000;
						memWrite = 0;
						regWrite = 1;
						aluSrc = 1;
						memToReg = 0;
						branchBeq = 0;
						branchJal = 0;
						branchBlt = 0;
						branchJalr = 1;
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
						branchBeq = 0;
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
					branchBeq = 0;
					branchJal = 0;
					branchBlt = 0;
					branchJalr = 0;
			end
		endcase
	end	
endmodule

module immDecode(
	input [2:0]immControl,
	input [31:7]instruction,
	output reg [31:0]immOut 	
);

always @(*) begin
	case (immControl)
		3'b001: begin
                immOut[11:0] = instruction[31:20]; // I-type
                immOut[31:12] = { 20 { instruction[31] } }; // sign extension
            end 	
		3'b010: begin // S-type
                immOut[11:5] = instruction[31:25]; 
                immOut[4:0] = instruction[11:7];
                immOut[31:12] = { 20 { instruction[31] } }; // sign extension
            end
		3'b011: begin // B-type
                immOut[12] = instruction[31];
                immOut[10:5] = instruction[30:25];
                immOut[11] = instruction[7];
                immOut[4:1] = instruction[11:8];
                immOut[0] = 0;
                immOut[31:13] = { 19 { instruction[31] } }; // sign extension
            end 	
		3'b100: begin // U-type
                immOut[31:12] = instruction[31:12]; 
                immOut[11:0] = { 12 { 1'b0 } };
            end
		3'b101: begin // J-type
                    immOut[31:21] = { 11 { instruction[31] } }; // sign extension
                    immOut[20] = instruction[31];
                    immOut[10:1] = instruction[30:21];
                    immOut[11] = instruction[20];
                    immOut[19:12] = instruction[19:12];
                    immOut[0] = 0;
            end
   		default:
			immOut = 32'b0; 	
	endcase		
end
endmodule

`default_nettype wire

/*
acts as a layer, wrapper around inner_core
with grid_layout and communication. does not
handle packets

*/
typedef enum {
	IDLE,
	TO_SEND_Y,
	TRANSMIT_Y,
	RECV,
	DAISY_CHAIN,
	RECV_FIRST,
	DAISY_FIRST,
	SWITCH
} Corestate;
module outer_core#(
	parameter dim_in=2,
	parameter dim_out=2,
	parameter bitw=16,
	parameter fracw=8,
	parameter layer=0,
	parameter unsigned id=0
)
(
	input reset,
	input clk,
	input x_ready,
	input save_w,
	input [bitw-1:0] x [0:dim_in-1],
	input [bitw-1:0] w_in [0:dim_in-1],
	
	input in_left_ready, in_right_ready,
	input [$clog2(dim_out)-1:0] in_left_id, in_right_id,
	input [bitw-1:0] in_left, in_right,
	
	output reg out_left_ready, out_right_ready,
	output reg [$clog2(dim_out)-1:0] out_left_id, out_right_id,
	output reg [bitw-1:0] out_left, out_right,
	
	output layer_out_ready,
	output [bitw-1:0] layer_out [0:dim_out-1]
);

	wire [bitw-1:0] y;
	reg [0:dim_out-1] nodes_ready;
	reg [bitw-1:0] node_outs [0:dim_out-1];
	reg [1+($size(in_left_id))+($size(in_left))-1:0] in_left_cache, in_right_cache;
	
	Corestate state = IDLE;

	inner_core #(
		.dim(dim_in),
		.bitw(bitw),
		.fracw(fracw)
	) core (
		.x(x),
		.w_in(w_in),
		.save_w(save_w),
		.out(y)
	);
	
	always_ff @(posedge clk, posedge reset) begin
		if (reset) begin
			state <= IDLE;
		end else begin
			$display("Core %d.%d state %s, nodes_ready: %b", layer, $unsigned(id), state.name(), nodes_ready);
			
			case (state)
				IDLE: begin
					if (in_left_ready || in_right_ready) begin
						state <= RECV_FIRST;
						$display(" -> RECV_FIRST");
					end else if (x_ready) begin
						state <= TO_SEND_Y;
						$display(" -> TO_SEND_Y");
					end
				end
				TO_SEND_Y: begin
					if (in_left_ready || in_right_ready) begin
						state <= RECV_FIRST;
						$display(" -> RECV_FIRST");
					end
					state <= TRANSMIT_Y;
					$display(" -> TRANSMIT_Y");
				end
				TRANSMIT_Y: begin
					$display(" ins:  (%d)-> L  R<-(%d)   | %b_%b_%b  %b_%b_%b", in_left_id, in_right_id, in_left_ready, in_left_id, in_left, in_right_ready, in_right_id, in_right);
					$display(" outs: L<-(%d)   (%d)->R   | %b_%b_%b  %b_%b_%b", out_left_id, out_right_id, out_left_ready, out_left_id, out_left, out_right_ready, out_right_id, out_right);
					if (in_left_ready || in_right_ready) begin
						state <= RECV;
						$display(" -> RECV");
					end
				end
				RECV: begin
					if (!in_left_ready && !in_right_ready) begin
						state <= DAISY_CHAIN;
						$display(" -> DAISY_CHAIN");
					end
				end
				DAISY_CHAIN: begin
					$display(" ins:  (%d)-> L  R<-(%d)   | %b_%b_%b  %b_%b_%b", in_left_id, in_right_id, in_left_ready, in_left_id, in_left, in_right_ready, in_right_id, in_right);
					$display(" outs: L<-(%d)   (%d)->R   | %b_%b_%b  %b_%b_%b", out_left_id, out_right_id, out_left_ready, out_left_id, out_left, out_right_ready, out_right_id, out_right);
					if (in_left_ready || in_right_ready) begin
						state <= RECV;
						$display(" -> RECV");
					end
				end
				RECV_FIRST: begin
					if (!in_left_ready && !in_right_ready) begin
						state <= DAISY_FIRST;
						$display(" -> DAISY_FIRST");
					end
				end
				DAISY_FIRST: begin
					if (!in_left_ready && !in_right_ready) begin
						state <= SWITCH;
						$display(" -> SWITCH");
					end else begin
						state <= RECV_FIRST;
						$display(" -> RECV_FIRST");
					end
				end
				SWITCH: begin
					if (!in_left_ready && in_right_ready) begin
						state <= TRANSMIT_Y;
						$display(" -> TRANSMIT_Y");
					end else begin
						state <= RECV_FIRST;
						$display(" -> RECV_FIRST");
					end
				end
			endcase
		end
	end
	
	always_comb begin
		
		case (state)
			IDLE: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
				in_left_cache = 0;
				in_right_cache = 0;
				nodes_ready = 0;
			end
			TO_SEND_Y: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
				nodes_ready[id] = 1'b1;
				node_outs[id] = y;
			end
			TRANSMIT_Y: begin
				{out_left_ready, out_left_id, out_left} = {1'b1, id, y};
				{out_right_ready, out_right_id, out_right} = {1'b1, id, y};
				//$display("out_left_ready %b out_left_id %b out_left %b", out_left_ready, out_left_id, out_left);
				
			end
			RECV: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
			end
			DAISY_CHAIN: begin
				//$display("id %b rc %b lc %b", id, in_right_cache, in_left_cache);
				{out_left_ready, out_left_id, out_left} = in_right_cache;
				{out_right_ready, out_right_id, out_right} = in_left_cache;
				in_right_cache=0;
				in_left_cache=0;
			end
			RECV_FIRST: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
			end
			DAISY_FIRST: begin
				{out_left_ready, out_left_id, out_left} = in_right_cache;
				{out_right_ready, out_right_id, out_right} = in_left_cache;
			end
			SWITCH: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
				if (x_ready) begin
					nodes_ready[id] = 1'b1;
					node_outs[id] = y;
				end
			end
			default: begin
				{out_left_ready, out_left_id, out_left} = 0;
				{out_right_ready, out_right_id, out_right} = 0;
			end
		endcase
		
		if (in_left_ready) begin
			in_left_cache = {1'b1, in_left_id, in_left};
			nodes_ready[in_left_id] = 1'b1;
			node_outs[in_left_id] = in_left;
		end
		
		if (in_right_ready) begin
			in_right_cache = {1'b1, in_right_id, in_right};
			nodes_ready[in_right_id] = 1'b1;
			node_outs[in_right_id] = in_right;
		end
		
	end
	
	
	assign layer_out_ready = &nodes_ready;
	assign layer_out = node_outs;
	
endmodule 


module outer_tb;

	// manual
	reg x_ready;
	reg [15:0] W [0:1][0:1];
	reg [15:0] X [0:1];
	wire [1+1+15:0] ins [0:2];	// in_ready, in_id, in
	wire [1+1+15:0] outs [0:2];
	wire [0:1] l_rdy;
	wire [15:0] layer_out [0:1][0:1];
	
	// 4x4 grid
	reg clk;
	reg reset;
	reg save_w;
	reg [15:0] Wg [0:3][0:3][0:3];
	wire [1+2+15:0] netg [0:3][-1:4][0:1];		// in order to daisy chain, we need two parallel buses
	reg [0:3] x_readyg [0:4];
	reg [15:0] layer_outg [-1:3][0:3][0:3];	// index by row, col to get layer output (4 arr of 16 fixp)
															// index -1 is the input to the network
															
	// assign edge wires
	assign ins[0] = 0;
	assign ins[2] = 0;
	assign netg[0][-1][1] = 0;
	assign netg[1][-1][1] = 0;
	assign netg[2][-1][1] = 0;
	assign netg[3][-1][1] = 0;
	assign netg[0][4][0] = 0;
	assign netg[1][4][0] = 0;
	assign netg[2][4][0] = 0;
	assign netg[3][4][0] = 0;
															
	// manual
	outer_core #(
		.id(1'b0)
	) core1 (
		.reset(reset),
		.clk(clk),
		.x_ready(x_ready),
		.x(X),
		.w_in(W[0]),
		.save_w(save_w),
		
		.in_left_ready(ins[0][17]),
		.in_left_id(ins[0][16]),
		.in_left(ins[0][15:0]),
		.in_right_ready(ins[1][17]),
		.in_right_id(ins[1][16]),
		.in_right(ins[1][15:0]),
		
		.out_left_ready(outs[0][17]),
		.out_left_id(outs[0][16]),
		.out_left(outs[0][15:0]),
		.out_right_ready(outs[1][17]),
		.out_right_id(outs[1][16]),
		.out_right(outs[1][15:0]),
		
		.layer_out_ready(l_rdy[0]),
		.layer_out(layer_out[0])
	);

	
	outer_core #(
		.id(1'b1)
	) core2 (
		.reset(reset),
		.clk(clk),
		.x_ready(x_ready),
		.x(X),
		.w_in(W[1]),
		.save_w(save_w),
		
		.in_left_ready(outs[1][17]),
		.in_left_id(outs[1][16]),
		.in_left(outs[1][15:0]),
		.in_right_ready(ins[2][17]),
		.in_right_id(ins[2][16]),
		.in_right(ins[2][15:0]),
		
		.out_left_ready(ins[1][17]),
		.out_left_id(ins[1][16]),
		.out_left(ins[1][15:0]),
		.out_right_ready(outs[2][17]),
		.out_right_id(outs[2][16]),
		.out_right(outs[2][15:0]),
		
		.layer_out_ready(l_rdy[1]),
		.layer_out(layer_out[1])
	);
	
	// grid
	generate
		genvar i, j;
		
		for (i=0; i<4; i++) begin	: rows
			for (j=0; j<4; j++) begin	: cols
				outer_core #(
					.dim_in(4),
					.dim_out(4),
					.layer(i),
					.id(2'(j))
				) t (
					.reset(reset),
					.clk(clk),
					.x_ready(x_readyg[i][j]),
					.save_w(save_w),
					.w_in(Wg[i][j]),
					.x(layer_outg[i-1][j]),		// take previous layer's output as input
					
					.in_left_ready	( netg[i][j-1][1][18] ),
					.in_left_id		( netg[i][j-1][1][17:16] ),
					.in_left			( netg[i][j-1][1][15:0] ),
					.in_right_ready( netg[i][j+1][0][18] ),
					.in_right_id	( netg[i][j+1][0][17:16] ),
					.in_right		( netg[i][j+1][0][15:0] ),
					
					.out_left_ready	( netg[i][j][0][18] ),
					.out_left_id		( netg[i][j][0][17:16] ),
					.out_left			( netg[i][j][0][15:0] ),
					.out_right_ready	( netg[i][j][1][18] ),
					.out_right_id		( netg[i][j][1][17:16] ),
					.out_right			( netg[i][j][1][15:0] ),
					
					.layer_out_ready( x_readyg[i+1][j] ),
					.layer_out( layer_outg[i][j] )
				);
			end
		end
	endgenerate
	
	always #10 clk <= ~clk;
	
	initial begin
		clk = 0;
		reset = 0;
		
		// These tests pass
		/*
		x_ready = 0;
		save_w = 0;
		
		W = '{ '{{8'd2, 8'b0}, {8'd1, 8'b0}}, '{{8'd4, 8'b0}, {8'd3, 8'b0}} };		// Transposed
		X = '{{8'd1, 8'b0}, {8'd2, 8'b0}};
		
		#5 save_w = ~save_w; #1 x_ready=~x_ready;
		
		#150;
		assert (layer_out[0][0] == {8'd4, 8'b0}) $display("layer_out[0][0] correct");
		assert (layer_out[0][1] == {8'd10, 8'b0}) $display("layer_out[0][1] correct");
		assert (layer_out[1][0] == layer_out[0][0]
					&& layer_out[1][1] == layer_out[0][1]) $display("layer_out self-consistent passed");
		
		/* Compute
		W =
		 -1.00101, 2.1101		(-1.15625, 2.8125)
		 0.010111, -3.00011	(0.359375, -3.09375)
		X = 2.01, -0.011		(2.25, -0.375)
		X@W = out =  11111101_01000011, 00000111_01111101 (-2.73632812 , 7.48828125)
		
		
		#1 reset=1; #1 reset=0;
		W = '{ '{-{8'd1, 8'b0010_1000}, {8'd0, 8'b0101_1100}},
				 '{{8'd2, 8'b1101_0000}, -{8'd3, 8'b0001_1000}} };		// Transposed
				 
		X = '{{8'd2, 8'b0100_0000}, -{8'b0, 8'b0110_0000}};
		
		#5 save_w = ~save_w; #1 x_ready=~x_ready;
		#5 save_w = ~save_w; #1 x_ready=~x_ready;
		
		#150;
		
		assert (layer_out[0][0] == 16'b11111101_01000011) $display("layer_out[0][0] correct");
		assert (layer_out[0][1] == 16'b00000111_01111101) $display("layer_out[0][1] correct");
		assert (layer_out[1][0] == layer_out[0][0]
					&& layer_out[1][1] == layer_out[0][1]) $display("layer_out self-consistent passed");
					
		#10;/**/
		//////// GRID TESTING
		x_readyg[0] = 4'b0;
		save_w = 0;
		#1 reset = 1;
		#1 reset = 0;
		
		// equiv to [[[0.46875, -0.48046875, -1.17578125, -0.87890625], [-0.77734375, 1.42578125, 0.4921875, -0.9296875], [1.23828125, -1.53515625, 1.78125, -1.2421875], [-0.953125, -0.4140625, 0.31640625, 0.83984375]], [[-1.1875, -1.71484375, -0.46484375, 0.35546875], [0.359375, -1.37890625, 0.71484375, 1.96875], [1.55859375, 1.62109375, -0.703125, -0.6171875], [-0.15234375, -0.05859375, -0.91796875, -1.5078125]], [[-0.7734375, 0.23046875, 1.30859375, 1.51953125], [-1.55859375, -1.95703125, 1.1640625, -1.265625], [-0.3203125, 1.7734375, 1.7109375, 1.91796875], [-1.46484375, -0.53125, 0.84375, -0.74609375]], [[1.5390625, 1.9453125, 0.234375, -1.2109375], [1.0390625, 1.13671875, -1.19140625, 1.11328125], [-1.3203125, -1.9921875, -1.16796875, 1.41796875], [-1.67578125, 0.05078125, 0.07421875, -1.4140625]]]
		Wg = '{ '{ 	'{ 16'b0000000001111000, 16'b1111111110000101, 16'b1111111011010011, 16'b1111111100011111},
						'{ 16'b1111111100111001, 16'b0000000101101101, 16'b0000000001111110, 16'b1111111100010010},
						'{ 16'b0000000100111101, 16'b1111111001110111, 16'b0000000111001000, 16'b1111111011000010},
						'{ 16'b1111111100001100, 16'b1111111110010110, 16'b0000000001010001, 16'b0000000011010111}},
					'{ '{ 16'b1111111011010000, 16'b1111111001001001, 16'b1111111110001001, 16'b0000000001011011},
						'{ 16'b0000000001011100, 16'b1111111010011111, 16'b0000000010110111, 16'b0000000111111000},
						'{ 16'b0000000110001111, 16'b0000000110011111, 16'b1111111101001100, 16'b1111111101100010},
						'{ 16'b1111111111011001, 16'b1111111111110001, 16'b1111111100010101, 16'b1111111001111110}},
					'{ '{ 16'b1111111100111010, 16'b0000000000111011, 16'b0000000101001111, 16'b0000000110000101},
						'{ 16'b1111111001110001, 16'b1111111000001011, 16'b0000000100101010, 16'b1111111010111100},
						'{ 16'b1111111110101110, 16'b0000000111000110, 16'b0000000110110110, 16'b0000000111101011},
						'{ 16'b1111111010001001, 16'b1111111101111000, 16'b0000000011011000, 16'b1111111101000001}},
					'{ '{ 16'b0000000110001010, 16'b0000000111110010, 16'b0000000000111100, 16'b1111111011001010},
						'{ 16'b0000000100001010, 16'b0000000100100011, 16'b1111111011001111, 16'b0000000100011101},
						'{ 16'b1111111010101110, 16'b1111111000000010, 16'b1111111011010101, 16'b0000000101101011},
						'{ 16'b1111111001010011, 16'b0000000000001101, 16'b0000000000010011, 16'b1111111010010110}}};
		layer_outg[-1][0] = '{ 	16'b0000000010011101,
										16'b0000000110101010,
										16'b0000000100100000,
										16'b1111111010000000};	//[0.61328125, 1.6640625, 1.125, -1.5]
		layer_outg[-1][1] = layer_outg[-1][0];
		layer_outg[-1][2] = layer_outg[-1][0];
		layer_outg[-1][3] = layer_outg[-1][0];
		#1 save_w = 1; #1 save_w = 0;
		#1 x_readyg[0] = 4'b1111;
		// out = 0011110001000100 0100100100100110 1100100110111101 1101000011001001
		//     = [60.265625, 73.1484375, -54.26171875, -47.21484375]
		//     ~ [[ 60.27084479] [ 73.13607888] [-54.28061154] [-47.23108389]]
		
		#500;
		
		
					
	end

endmodule 
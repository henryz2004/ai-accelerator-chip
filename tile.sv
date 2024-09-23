/*
it's the tile!
*/
module tile#(
	parameter dim_in=2,
	parameter dim_out=2,
	parameter bitw=16,
	parameter fracw=8,
	parameter layer=0,
	parameter unsigned id=0
)
(


/* outer core
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
	output [bitw-1:0] layer_out [0:dim_out-1]*/
	
	input reset,
	input clk,
	input save_w,
	input [bitw-1:0] w[0:dim_in-1],
	
	input [7:0] in_top, in_left, in_right,
	output [7:0] out_left, out_right, out_bottom
);

	reg sync_clk;
	
	reg [7:0] data_top[0:2*dim_in];
	reg [7:0] data_left[0:3];
	reg [7:0] data_right[0:3];
	logic [2:0] in_stable;
	
	wire [7:0] out_left_pkt[0:3];
	wire [7:0] out_right_pkt[0:3];
	reg [7:0] out_bottom_pkt[0:2*dim_out];
	logic [2:0] out_ready;
	
	wire x_ready;
	reg [bitw-1:0] x [0:dim_in-1];
	wire in_left_ready, in_right_ready;
	wire [$clog2(dim_out)-1:0] in_left_id, in_right_id;
	wire [bitw-1:0] in_left_unp, in_right_unp;	// unpacked
	
	wire out_left_ready, out_right_ready;
	wire [$clog2(dim_out)-1:0] out_left_id, out_right_id;
	wire [bitw-1:0] out_left_unp, out_right_unp;	// unpacked
	
	wire layer_out_ready;
	wire [bitw-1:0] layer_out [0:dim_out-1];
	
	
	assign x_ready = data_top[0][0];
	assign in_left_ready = data_left[0][0];
	assign in_left_id = data_left[1][$clog2(dim_out)-1:0];
	assign in_left_unp = {data_left[2], data_left[3]};
	
	assign in_right_ready = data_right[0][0];
	assign in_right_id = data_right[1][$clog2(dim_out)-1:0];
	assign in_right_unp = {data_right[2], data_right[3]};
	
	assign out_left_pkt[0] = out_left_ready;
	assign out_left_pkt[1] = out_left_id;
	assign {out_left_pkt[2], out_left_pkt[3]} = out_left_unp;
	
	assign out_right_pkt[0] = out_right_ready;
	assign out_right_pkt[1] = out_right_id;
	assign {out_right_pkt[2], out_right_pkt[3]} = out_right_unp;
	
	assign sync_clk = clk && (&out_ready) && (&in_stable);
	
	
	always_comb begin
		for (int i=0; i<dim_in; i++) begin
			x[i] = {data_top[2*i+1], data_top[2*i+2]};
		end
		
		out_bottom_pkt[0] = layer_out_ready;
		for (int i=0; i<dim_out; i++) begin
			{out_bottom_pkt[2*i+1], out_bottom_pkt[2*i+2]} = layer_out[i];
		end
	end
	
	bitstream_in#(
		.max_data_bytes(2*dim_in+1)
	) stin_top (
		.clk(clk),
		.reset(reset),
		.din(in_top),
		.dout(data_top),
		.stable(in_stable[0])
		//.len() throw away the length because we know it
	);
	
	bitstream_in#(
		.max_data_bytes(4)
	) stin_left (
		.clk(clk),
		.reset(reset),
		.din(in_left),
		.dout(data_left),
		.stable(in_stable[1])
	);
	
	bitstream_in#(
		.max_data_bytes(4)
	) stin_right (
		.clk(clk),
		.reset(reset),
		.din(in_right),
		.dout(data_right),
		.stable(in_stable[2])
	);
	
	bitstream_out#(
		.max_data_bytes(4)
	) stout_left (
		.clk(clk),
		.reset(reset),
		.wr_en(out_left_ready),
		.len(3'd4),
		.din(out_left_pkt),
		.dout(out_left),
		.ready(out_ready[0])
	);
	
	bitstream_out#(
		.max_data_bytes(4)
	) stout_right (
		.clk(clk),
		.reset(reset),
		.wr_en(out_right_ready),
		.len(3'd4),
		.din(out_right_pkt),
		.dout(out_right),
		.ready(out_ready[1])
	);
	
	bitstream_out#(
		.max_data_bytes(2*dim_out+1)
	) stout_bottom (
		.clk(clk),
		.reset(reset),
		.wr_en(layer_out_ready),
		.len(2*dim_out+1),
		.din(out_bottom_pkt),
		.dout(out_bottom),
		.ready(out_ready[2])
	);

	outer_core#(
		.dim_in(dim_in),
		.dim_out(dim_out),
		.bitw(bitw),
		.fracw(fracw),
		.layer(layer),
		.id(id)
	) core (
		.reset(reset),
		.clk(sync_clk),
		.w_in(w),
		.save_w(save_w),
		
		.x_ready(x_ready),
		.x(x),
		
		.in_left_ready(in_left_ready),
		.in_left_id(in_left_id),
		.in_left(in_left_unp),
		.in_right_ready(in_right_ready),
		.in_right_id(in_right_id),
		.in_right(in_right_unp),
		
		.out_left_ready(out_left_ready),
		.out_left_id(out_left_id),
		.out_left(out_left_unp),
		.out_right_ready(out_right_ready),
		.out_right_id(out_right_id),
		.out_right(out_right_unp),
		
		.layer_out_ready(layer_out_ready),
		.layer_out(layer_out)
	);
	
	initial begin
		$monitor("[%0t] id: %d out_ready: %b in_stable: %b", $time, id, out_ready, in_stable);
	end

endmodule


module tile_tb;

	reg reset;
	reg clk;
	reg save_w;
	reg [15:0] W[0:1][0:1];
	reg [15:0] X[0:1];
	reg x_ready;
	reg x_sent;
	
	wire [7:0] fin[0:4];
	wire [7:0] x_out;
	wire [7:0] y_in;
	reg [7:0] fout[0:4];
	
	reg y_ready;
	reg y_sent;
	reg [15:0] y[0:1];
	wire [7:0] in_top;
	wire [7:0] ins [0:2];
	wire [7:0] outs[0:2];
	wire [7:0] out_bottom;
	
	assign ins[0] = 0;
	assign ins[2] = 0;
	
	assign fin[0] = x_ready;
	assign {fin[1], fin[2]} = X[0];
	assign {fin[3], fin[4]} = X[1];
	
	assign y_ready = fout[0][0];
	assign y[0] = {fout[1], fout[2]};
	assign y[1] = {fout[3], fout[4]};
	
	bitstream_out#(.max_data_bytes(5)) x_gen (
		.clk(clk),
		.reset(reset),
		.wr_en(x_ready),
		.din(fin),
		.len(5),
		.dout(x_out),
		.ready(x_sent)
	);
	
	bitstream_in#(.max_data_bytes(5)) y_recv (
		.clk(clk),
		.reset(reset),
		.din(y_in),
		.dout(fout),
		.stable(y_sent)
	);
	
	tile #(
		.id(1'b0)
	) tile1 (
		.reset(reset),
		.clk(clk),
		.save_w(save_w),
		.w(W[0]),

		.in_top(x_out), 
		.in_left(ins[0]),
		.in_right(ins[1]),
		.out_left(outs[0]),
		.out_right(outs[1]),
		.out_bottom(y_in)
	);
	
	tile #(
		.id(1'b1)
	) tile2 (
		.reset(reset),
		.clk(clk),
		.save_w(save_w),
		.w(W[1]),

		.in_top(x_out), 
		.in_left(outs[1]),
		.in_right(ins[2]),
		.out_left(ins[1]),
		.out_right(outs[2])
		//.out_bottom(y_in)
	);
	
	always #5 clk<=~clk;
	
	initial begin
		clk = 0;
		reset = 0;
		
		// Same tests as outer core
		
		x_ready = 0;
		save_w = 0;
		
		// swapped rows
		// special bytes are only a problem when 1 is transmitting extra
		/*
		W = '{ '{{8'd2, 8'b0}, {8'd1, 8'b0}}, '{{8'd4, 8'b0}, {8'd3, 8'b0}} };		// Transposed
		X = '{{8'd1, 8'b0}, {8'd2, 8'b0}};
		
		#5 save_w = 1; #1 x_ready=1;
		
		
		#300;
		
		assert (y[0] == {8'd4, 8'b0}) $display("y[0] correct");
		assert (y[1] == {8'd10, 8'b0}) $display("y[1] correct");
		
		// something is wrong with this test case
		
		/* Compute
		W =
		 -1.00101, 2.1101		(-1.15625, 2.8125)
		 0.010111, -3.00011	(0.359375, -3.09375)
		X = 2.01, -0.011		(2.25, -0.375)
		X@W = out =  11111101_01000011, 00000111_01111101 (-2.73632812 , 7.48828125)*/
		
		#10 save_w = 0; x_ready=0;
		//#10 reset=1; #30 reset=0;
		W = '{ '{-{8'd1, 8'b0010_1000}, {8'd0, 8'b0101_1100}},
				 '{{8'd2, 8'b1101_0000}, -{8'd3, 8'b0001_1000}} };		// Transposed
				 
		X = '{{8'd2, 8'b0100_0000}, -{8'b0, 8'b0110_0000}};
		#10 save_w = 1; #1 x_ready=1;
		
		#300;
		assert (y[0] == 16'b11111101_01000011) $display("y[0] correct");
		assert (y[1] == 16'b00000111_01111101) $display("y[1] correct");
					
		#10;/**/
	end
endmodule

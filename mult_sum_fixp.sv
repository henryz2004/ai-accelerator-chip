/*
fixed point multiply-then-accumulate module.
Takes in weights and inputs as inputs, outputs
dot product. Input dimension and resolution customizable

By default, operates on s7.8 fixpoint and inputs of size 2
*/
module mult_sum_fixp#(
	parameter dim=2,
	parameter bitw=16,
	parameter fracw=8
)
(
	input [bitw-1:0] weights [0:dim-1],
	input [bitw-1:0] x [0:dim-1],
	output reg [bitw-1:0] out
);

	reg [bitw+fracw-1:0] z;

	always @(*) begin
		z = 0;
		for (int i=0; i<dim; i++) begin
			z = z + {{fracw{weights[i][bitw-1]}}, weights[i]} * {{fracw{x[i][bitw-1]}}, x[i]};
		end
		out = z[bitw+fracw-1:fracw];
	end


endmodule


/*
Test bench for the mult_sum_fixp module

Test the dot product functionality
Test cases:
 - [2 1.25] [5 -4] -> 15
 - [-0.125 7] [-5 8.5] -> 57.[1101]
*/

module msf_tb ();

	reg [15:0] weights [0:1];
	reg [15:0] x [0:1];
	reg [15:0] out;

	mult_sum_fixp dut (
		weights,
		x,
		out
	);
	
	initial begin
		weights = '{ {8'd2, 8'b0}, {8'd1, 8'b01000000} };
		x = '{ {8'd5, 8'b0}, {8'd4, 8'b0} };
				
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %b", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %b", x[i]);
		end
		#10 $display("Result of dot product of s7.8: %s%d.%b", (out[15] ? "-" : "+"), out[14:8], out[7:0]);
		
		weights = '{ {-8'd0, 8'b00100000}, {8'd7, 8'b0} };
		x = '{ {-8'd0, 8'b10000000}, {8'd8, 8'b1000000} };
		
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %b", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %b", x[i]);
		end
		#10 $display("Result of dot product of s7.8: %s%d.%b", (out[15] ? "-" : "+"), out[14:8], out[7:0]);
		
		///// Test basic fixed point multiplication calculation
		
		weights 	= '{ -{8'd1, 8'b0010_1000}, 0 };	// -1.15625
		x			= '{ {8'd2, 8'b0100_0000}, 0 };	// [2.25, 0]. expected: -1.15625 * 2.25 = -2.6015625 = 11111101 01100110
		#10 assert (out == 16'b11111101_01100110) $display("Basic fixed point multiplication passed");	  //11111101 01100110
		
		weights = '{ 0, {8'd0, 8'b0101_1100} };		// 0.359375
		x		  = '{ 0,  -{8'b0, 8'b0110_0000} };		// -0.375. expected = 0.359375 * -0.375 = -0.134765625 = 11111111 11011101
		#10 assert (out == 16'b11111111_11011101) $display("Basic fixed point multiplication passed");
		
		///// Test full circuit
		weights = '{-{8'd1, 8'b0010_1000}, {8'd0, 8'b0101_1100}};		// (-1.15625, 0.359375)
		x		  = '{{8'd2, 8'b0100_0000}, -{8'b0, 8'b0110_0000}};		// [2.25, -0.375] = -1.15625 * 2.25 + 0.359375 * -0.375 = -2.73632812 = 11111101_01000011
		#10 assert (out == 16'b11111101_01000011) $display("Full fixed point multiplication passed");
		
		weights = '{ {8'd2, 8'b1101_0000}, -{8'd3, 8'b0001_1000}};		// [2.8125, -3.09375]
																							// out = 2.8125 * 2.25 + -3.09375*-0.375 = 7.48828125 = 00000111_01111101
		#10 assert (out == 16'b00000111_01111101) $display("Full fixed point multiplication passed");
		
		#100;
	end

endmodule 
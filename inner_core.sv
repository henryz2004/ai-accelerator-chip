/*

wrapper around mult_sum_fixp to save weights
acts as a singular neuron
*/

module inner_core#(
	parameter dim=2,
	parameter bitw=16,
	parameter fracw=8
)
(
	input [bitw-1:0] x [0:dim-1],
	input [bitw-1:0] w_in [0:dim-1],
	input save_w,
	output reg [bitw-1:0] out
);

	reg [bitw-1:0] weights [0:dim-1];
	
	mult_sum_fixp #(
		.dim(dim),
		.bitw(bitw),
		.fracw(fracw)
	) comp (
		.x(x),
		.weights(weights),
		.out(out)
	);
	
	always @(posedge save_w)
		weights <= w_in;

endmodule


/*

tests loading the weight and computing the product

*/
module ic_tb();
	
	reg [15:0] weights [0:1];
	reg [15:0] x [0:1];
	reg save_w = 0;
	reg [15:0] out;
	reg [15:0] expected;

	inner_core dut (
		x,
		weights,
		save_w,
		out
	);
	
	initial begin
		weights = '{ {8'd2, 8'b0}, {8'd1, 8'b01000000} };	// [2.0, 1.25]
		x = '{ {8'd5, 8'b0}, -{8'd4, 8'b0} };	// [5.0, -4]
		save_w = 1; #10 save_w=0;
		
		// expected:
		// 10 - 5 = 5
		#10 expected = {8'd5, 8'b0};
		assert (out == expected) $display("Testcase passed");
			else begin
				$display("weights:");
				foreach (weights[i]) begin
					$display(" %b", weights[i]);
				end
				
				$display("x:");
				foreach (x[i]) begin
					$display(" %b", x[i]);
				end
				$error("Testcase failed. Expected: %b, Actual: %b", expected, out);
			end;
		
		x = '{ -{8'd0, 8'b1000_0000}, {8'd8, 8'b1000_0000} };	// [-0.5, 8.5]
		// expected:
		// -1 + 10.625 = 9.625 = 00001001_10100000
		#10 expected = 16'b00001001_10100000;
		assert (out == expected) $display("Testcase passed");
			else begin
				$display("weights:");
				foreach (weights[i]) begin
					$display(" %b", weights[i]);
				end
				
				$display("x:");
				foreach (x[i]) begin
					$display(" %b", x[i]);
				end
				$error("Testcase failed. Expected: %b, Actual: %b", expected, out);
			end;
		
		weights = '{ -{8'd0, 8'b00100000}, {8'd7, 8'b0} };	// [-0.125, 7]
		save_w = 1; #10 save_w=0;
		
		x = '{ {8'd5, 8'b0}, -{8'd4, 8'b0} }; 	// [5.0, -4]
		// expected:
		// -0.625 - 28 = -28.625 = -00011100_10100000 = 11100011_01100000
		#10 expected = 16'b11100011_01100000;
		assert (out == expected) $display("Testcase passed");
			else begin
				$display("weights:");
				foreach (weights[i]) begin
					$display(" %b", weights[i]);
				end
				
				$display("x:");
				foreach (x[i]) begin
					$display(" %b", x[i]);
				end
				$error("Testcase failed. Expected: %b, Actual: %b", expected, out);
			end;
		
		x = '{ -{8'd0, 8'b10000000}, {8'd8, 8'b10000000} };	// [-0.5, 8.5]
		// expected:
		// 0.0625 + 59.5 = 59.5625 = 00111011_10010000
		#10 expected = 16'b00111011_10010000;
		assert (out == expected) $display("Testcase passed");
			else begin
				$display("weights:");
				foreach (weights[i]) begin
					$display(" %b", weights[i]);
				end
				
				$display("x:");
				foreach (x[i]) begin
					$display(" %b", x[i]);
				end
				$error("Testcase failed. Expected: %b, Actual: %b", expected, out);
			end;
		
		#100;
	end
	
endmodule 
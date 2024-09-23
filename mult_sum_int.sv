/*
Integer multiply-then-accumulate module.
Takes in weights and inputs as inputs, outputs
dot product
Input dimension and resolution customizable

By default, operates on 8-bit integers and inputs of size 2
*/
module mult_sum_int#(
	parameter dim=2,
	parameter bitw=8
)
(
	input [bitw-1:0] weights [0:dim-1],
	input [bitw-1:0] x [0:dim-1],
	output reg [bitw-1:0] out
);

	always @(*) begin
		out = 0;
		for (int i=0; i<dim; i++) begin
			out = out + weights[i] * x[i];
		end
	end


endmodule


/*
Test bench for the mult_sum_int module

Test the dot product functionality
Test cases:
 - [1 1] [2 6] -> 8
 - [3 4] [1 1] -> 7
*/

module msi_tb ();

	reg [7:0] weights [0:1];
	reg [7:0] x [0:1];
	reg [7:0] out;

	mult_sum_int dut (
		weights,
		x,
		out
	);
	
	initial begin
		weights = '{ 8'd1, 8'd1 };
		x = '{ 8'd2, 8'd6 };
		
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %d", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %d", x[i]);
		end
		#10 $display("dot product result: %d", out);
		
		weights = '{ -8'd4, 8'd10 };
		x = '{ -8'd6, -8'd4 };
		
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %d", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %d", x[i]);
		end
		#10 $display("dot product result: %d", out);
		
		weights = '{ 8'd1, 8'd1 };
		x = '{ 8'd2, 8'd6 };
		
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %d", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %d", x[i]);
		end
		#10 $display("dot product result: %d", out);
		
		weights = '{ 8'b1000000, 8'd90 };
		x = '{ 8'b1000000, 8'd6 };
		
		$display("weights:");
		foreach (weights[i]) begin
			$display(" %d", weights[i]);
		end
		$display("x:");
		foreach (x[i]) begin
			$display(" %d", x[i]);
		end
		#10 $display("dot product result: %d", out);
		
		#100;
	end

endmodule 
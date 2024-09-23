typedef enum {
	IN,
	OUT,
	SPECIAL
} Inputstate;

module bitstream_in #(
	parameter max_data_bytes=8
) (
	input clk,
	input reset,
	input [7:0] din,
	output reg [7:0] dout[0:max_data_bytes-1],
	output reg [$clog2(max_data_bytes):0] len,
	output reg stable
);
	
	Inputstate state = OUT;
	wire [7:0] orig;
	reg [7:0] buff[0:max_data_bytes-1];
	reg [$clog2(max_data_bytes)+1:0] i;
	
	always_ff @(posedge clk, posedge reset) begin
		if (reset) begin
			state <= OUT;
			stable <= 1;
			len <= 0;
			dout <= '{default: '0};
		end else begin
			case (state)
				OUT: begin
					i <= 0;
					
					if (din == 8'h7E) begin
						state <= IN;
						stable <= 0;
					end
				end
				IN: begin
					case (din)
						8'h7D:
							state <= SPECIAL;
						8'h7E: begin
							state <= OUT;
							stable <= 1;
							dout <= buff;
							len <= i;
						end
						default: begin
							buff[i] <= din;
							i <= i + 1;
						end
					endcase
				end
				SPECIAL: begin
					buff[i] <= orig;
					i <= i + 1;
					state <= IN;
				end
			endcase
		end
	end
	
	assign orig = din ^ 8'h20;

endmodule

typedef enum {
	IDLE,
	STREAMING,
	DELIMIT,
	FINISH
} Outstate;
module bitstream_out #(
	parameter max_data_bytes=8
)
(
	input clk,
	input reset,
	input wr_en,
	input reg [$clog2(max_data_bytes):0] len,
	input reg [7:0] din[0:max_data_bytes-1],
	output reg [7:0] dout,
	output ready
);

	Outstate state = IDLE;
	reg [$clog2(max_data_bytes)+1:0] i;
	
	always_ff @(posedge clk, posedge reset, negedge wr_en) begin
		if (reset) begin
			state <= IDLE;
			i <= 0;
		end else begin
			case (state)
				IDLE: begin
					i <= 0;
					if (wr_en) begin
						dout <= 8'h7E;
						state <= STREAMING;
					end
				end
				STREAMING: begin
					if (i >= len) begin
						$display("[%0t] stopping output  wr_en: %b", $time, wr_en);
						dout <= 8'h7E;
						state <= FINISH;
					end else begin
						$display("[%0t] i: %d din[i]: %h  wr_en: %b", $time, i, din[i], wr_en);
						case (din[i])
							8'h7E: begin
								dout <= 8'h7D;
								state <= DELIMIT;
							end
							8'h7D: begin
								dout <= 8'h7D;
								state <= DELIMIT;
							end
							default: begin
								dout <= din[i];
								i <= i+1;
							end
						endcase
					end
				end
					
				DELIMIT: begin
					$display("[%0t] i: %d ^din[i]: %h  wr_en: %b", $time, i, din[i] ^ 8'h20, wr_en);
					dout <= din[i] ^ 8'h20;
					i <= i+1;
					state <= STREAMING;
				end
				FINISH: begin
					dout <= 0;
					if (!wr_en) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
	
	assign ready = (state == IDLE || state == FINISH);

endmodule

module bitstream_tb();

  reg clk;
  reg reset; 
  reg wr_en;
  reg [3:0] in_len;
  reg [7:0] din[0:7];
  reg [3:0] echo_len;
  reg [7:0] echo[0:7];
  
  wire [7:0] dout;
  
  wire ready;
  wire stable;
  
  // Test stimuli generator
  initial begin
    clk = 0;
    reset = 0;
    #1 reset = 1; #1 reset = 0;
	 
	 din = '{8'd1, 8'd2, 8'd3, 0, 0, 0, 0, 0};
	 in_len = 4'd8;
	 
	 wr_en = 1;
	 
	 #20;
	 @(posedge ready);
	 #60;	//wait for echo
	 assert (echo == din) $display("echo matches input!");
	 
	 wr_en = 0;
	 #1 reset = 1; #10 reset = 0;
	 #20;
	 din = '{8'h7E, 8'h7D, 8'h7D, 8'hFF, 8'h20, 0, 8'h7E, 0};
	 in_len = 4'd8;
	 #20;
	 wr_en=1;
	 
	 #200;
	 assert (echo == din) $display("echo matches input!");
	 
  end

  // Clock generator
  always begin
    #5 clk = ~clk;
  end
  
  // System under test
  bitstream_in bi(.clk(clk), .reset(reset), .din(dout), .dout(echo), .len(echo_len), .stable(stable));
  bitstream_out bo(.clk(clk), .reset(reset), .wr_en(wr_en), .len(in_len), .din(din), .dout(dout), .ready(ready));

endmodule

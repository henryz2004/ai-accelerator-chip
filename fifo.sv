/*

Synchronous fifo module for communication, adapted from chipverify

*/
module fifo #(
	parameter depth=8,
	parameter bitw=16
)
(
	input resetn,
			wr_clk,
			rd_clk,
			wr_en,
			rd_en,
	input [bitw-1:0] din,
	output reg [bitw-1:0] dout,
	output	empty,
				full
);

	reg [$clog2(depth)-1:0] wptr;
	reg [$clog2(depth)-1:0] rptr;
	
	reg [bitw-1:0]  arr[depth];
	
	always @(posedge wr_clk, negedge resetn) begin
		if (!resetn) begin
			wptr <= 0;
		end else begin
			if (wr_en & !full) begin
				arr[wptr] <= din;
				wptr <= wptr + 1;
			end
		end
	end
	
	initial begin
		$monitor("[%0t] [FIFO] wr_en=%0b din=0x%0h rd_en=%0b dout=0x%0h empty=%0b full=%0b",
					$time, wr_en, din, rd_en, dout, empty, full);
	end
	
	always @(posedge rd_clk, negedge resetn) begin
		if (!resetn) begin
			rptr <= 0;
		end else begin
			if (rd_en & !empty) begin
				dout <= arr[rptr];
				rptr <= rptr + 1;
			end
		end
	end
	
	assign full = (wptr + 1) == rptr;
	assign empty = wptr == rptr;

endmodule 



module fifo_tb();

	reg	wr_clk;
	wire	rd_clk;
	reg	[15:0]	din;
	wire	[15:0]	dout;
	reg	[15:0]	rdata;
	reg	empty;
	reg	rd_en;
	reg	wr_en;
	wire	full;
	reg	resetn;
	reg	stop;
	
	fifo dut (
		.resetn(resetn),
		.wr_en(wr_en),
		.rd_en(rd_en),
		.wr_clk(wr_clk),
		.rd_clk(rd_clk),
		.din(din),
		.dout(dout),
		.empty(empty),
		.full(full)
	);
	
	always #10 wr_clk <= ~wr_clk;
	
	assign rd_clk = wr_clk;
	
	initial begin
		wr_clk <= 0;
		resetn <= 0;
		wr_en <= 0;
		rd_en <= 0;
		stop <= 0;
		
		#50 resetn <= 1;
	end
	
	initial begin
		@(posedge wr_clk);
		
		for (int i=0; i<50; i=i+1) begin
			while (full) begin
				@(posedge wr_clk);
				$display("[%0t] FIFO is full, wait for reads to happen", $time);
				
			end
			
			wr_en <= $random;
			din	<= $random;
			$display("[%0t] wr_clk i=%0d wr_en=%0d din=0x%0h", $time, i, wr_en, din);
			
			@(posedge wr_clk);
		end
		
		stop = 1;
	end
	
	initial begin
		@(posedge rd_clk);
		
		while (!stop) begin
			while (empty) begin
				rd_en <= 0;
				$display("[%0t] FIFO is empty, wait for writes to happen", $time);
				@(posedge rd_clk);
			end
			
			rd_en <= $random;
			@(posedge rd_clk);
			rdata <= dout;
			$display("[%0t] rd_clk rd_en=%0d rdata=0x%0h", $time, rd_en, rdata);
		end
	end

endmodule 
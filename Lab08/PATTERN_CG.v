/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: SA
// FILE NAME: PATTERN_CG.v
// VERSRION: 1.0
// DATE: Nov 06, 2024
// AUTHOR: Yen-Ning Tung, NYCU AIG
// CODE TYPE: RTL or Behavioral Level (Verilog)
// DESCRIPTION: 2024 Fall IC Lab / Exersise Lab08 / PATTERN_CG
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
`define CYCLE_TIME 50
`define PATTERN_NUMBER 30
`define RANDOM_SEED 42
// `define SHOW_PROCESS

module PATTERN(
    // Output signals
    clk,
    rst_n,
    cg_en,
    in_valid,
    T,
    in_data,
    w_Q,
    w_K,
    w_V,

    // Input signals
    out_valid,
    out_data
);

output reg clk;
output reg rst_n;
output reg cg_en;
output reg in_valid;
output reg [3:0] T;
output reg signed [7:0] in_data;
output reg signed [7:0] w_Q;
output reg signed [7:0] w_K;
output reg signed [7:0] w_V;

input out_valid;
input signed [63:0] out_data;

//================================================================
// Clock
//================================================================
real CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk;
initial	clk = 0;


//================================================================
// parameters & integer
//================================================================
integer seed;
integer i_pat;
parameter patnum = `PATTERN_NUMBER;
integer total_latency, latency;
integer t, td;


//================================================================
// Wire & Reg Declaration
//================================================================
logic signed [7:0] data[7:0][7:0];
logic signed [7:0] WQ[7:0][7:0], WK[7:0][7:0], WV[7:0][7:0];
logic signed [63:0] Q[7:0][7:0], K[7:0][7:0], V[7:0][7:0];
logic signed [63:0] QK_T[7:0][7:0];
logic signed [63:0] Scaled[7:0][7:0];
logic signed [63:0] S[7:0][7:0];
logic signed [63:0] golden_out[7:0][7:0];
logic signed [63:0] design_out[7:0][7:0];

always @* begin
	if (in_valid === 1'b1 && out_valid === 1'b1) begin
		FAIL_in_out_overlap_task;
	end
end

initial begin
	reset_task;
	for (i_pat = 0; i_pat < patnum; i_pat = i_pat + 1) begin
		test_one_pattern_task;
	end
	PASS_task;
end

task reset_task; begin
	total_latency = 0;
	rst_n = 1'b1;
	in_valid = 1'b0;
    cg_en = 1'b0;
	T = 'bx;
	in_data = 'bx;
	w_Q = 'bx;
	w_K = 'bx;
	w_V = 'bx;
	force clk = 0;
	#(20); rst_n = 1'b0;
	#(10); rst_n = 1'b1;
	#(90);
	if (out_valid !== 'b0 || out_data !== 'b0) begin
		FAIL_no_reset_task;
	end
	#(20); release clk;
end endtask

task test_one_pattern_task; begin
	// generate pattern
	if (i_pat < 10) t = 1;
	else if (i_pat < 20) t = 4;
	else t = 8;
	td = t * 8;
	for (int i = 0; i < t; i = i+1) begin
		for (int j = 0; j < 8; j = j+1) begin
			data[i][j] = $random(seed);
		end
	end
	for (int i = 0; i < 8; i = i+1) begin
		for (int j = 0; j < 8; j = j+1) begin
			WQ[i][j] = $random(seed);
			WK[i][j] = $random(seed);
			WV[i][j] = $random(seed);
		end
	end
	`ifdef SHOW_PROCESS
	// show data and weight
	$display("Pattern No.%04d | t = %1d", i_pat, t);
	$display("Matrix data:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%4d ", data[i][j]);
		end
		$display("");
	end
	$display("Matrix WQ:");
	for (int i = 0; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%4d ", WQ[i][j]);
		end
		$display("");
	end
	$display("Matrix WK:");
	for (int i = 0; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%4d ", WK[i][j]);
		end
		$display("");
	end
	$display("Matrix WV:");
	for (int i = 0; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%4d ", WV[i][j]);
		end
		$display("");
	end
	`endif
	// generate golden output
	`ifdef SHOW_PROCESS
	$display("Matrix Q:");
	`endif
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			Q[i][j] = 0;
			K[i][j] = 0;
			V[i][j] = 0;
			for (int k = 0; k < 8; k = k + 1) begin
				Q[i][j] = Q[i][j] + data[i][k] * WQ[k][j];
				K[i][j] = K[i][j] + data[i][k] * WK[k][j];
				V[i][j] = V[i][j] + data[i][k] * WV[k][j];
			end
			`ifdef SHOW_PROCESS
			$write("%8d ", Q[i][j]);
			`endif
		end
		`ifdef SHOW_PROCESS
		$display("");
		`endif
	end

	`ifdef SHOW_PROCESS
	$display("Matrix K:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%8d ", K[i][j]);
		end
		$display("");
	end

	$display("Matrix V:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%8d ", V[i][j]);
		end
		$display("");
	end

	$display("Matrix QK_T:");
	`endif
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < t; j = j + 1) begin
			QK_T[i][j] = 0;
			for (int k = 0; k < 8; k = k + 1) begin
				QK_T[i][j] = QK_T[i][j] + Q[i][k] * K[j][k];
			end
			`ifdef SHOW_PROCESS
			$write("%14d ", QK_T[i][j]);
			`endif
			Scaled[i][j] = QK_T[i][j] / 3;
			S[i][j] = (Scaled[i][j] > 0) ? Scaled[i][j] : 0;
		end
		`ifdef SHOW_PROCESS
		$display("");
		`endif
	end

	`ifdef SHOW_PROCESS
	$display("Matrix Scaled:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < t; j = j + 1) begin
			$write("%14d ", Scaled[i][j]);
		end
		$display("");
	end
	$display("Matrix S:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < t; j = j + 1) begin
			$write("%14d ", S[i][j]);
		end
		$display("");
	end
	`endif

	`ifdef SHOW_PROCESS
	$display("Matrix golden_out:");
	`endif
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			golden_out[i][j] = 0;
			for (int k = 0; k < t; k = k + 1) begin
				golden_out[i][j] = golden_out[i][j] + S[i][k] * V[k][j];
			end
			`ifdef SHOW_PROCESS
			$write("%20d ", golden_out[i][j]);
			`endif
		end
		`ifdef SHOW_PROCESS
		$display("");
		`endif
	end
	// output pattern
	repeat ($urandom_range(2, 5)) @(negedge clk);
	in_valid = 'b1;
    cg_en = 'b1;
	T = t;
	in_data = data[0][0];
	w_Q = WQ[0][0];
	@(negedge clk);
	T = 'bx;
	for (int i = 1; i < 8; i = i + 1) begin
		in_data = data[0][i];
		w_Q = WQ[0][i];
		@(negedge clk);
	end
	for (int i = 1; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			in_data = data[i][j];
			w_Q = WQ[i][j];
			@(negedge clk);
		end
	end
	in_data = 'bx;
	for (int i = t; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			w_Q = WQ[i][j];
			@(negedge clk);
		end
	end
	w_Q = 'bx;
	for (int i = 0; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			w_K = WK[i][j];
			@(negedge clk);
		end
	end
	w_K = 'bx;
	for (int i = 0; i < 8; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			w_V = WV[i][j];
			@(negedge clk);
		end
	end
	w_V = 'bx;
    in_valid = 'b0;
    cg_en = 'b0;
    wait_out_valid_task;
    check_ans_task;
end endtask

task wait_out_valid_task; begin
    latency = 1;
    while (out_valid !== 1'b1) begin
        latency = latency + 1;
        if (latency > 2000) begin
            FAIL_exceed_latency_task;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end endtask

task check_ans_task; 
begin

	// get output
	`ifdef SHOW_PROCESS
	$display("Matrix design_out:");
	`endif
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			if (out_valid !== 1'b1) begin
				FAIL_output_cycle_task;
			end
			design_out[i][j] = out_data;
			`ifdef SHOW_PROCESS
			$write("%4d ", design_out[i][j]);
			`endif
			@(negedge clk);
		end
		`ifdef SHOW_PROCESS
		$display("");
		`endif
	end
	if (out_valid !== 1'b0) FAIL_output_cycle_task;
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			if (design_out[i][j] !== golden_out[i][j]) begin
				FAIL_wrong_output_task;
			end
		end
	end
    $display("\033[1;34mPASS PATTERN NO.%04d | latency = %4d clk\033[0m", i_pat, latency);
end endtask

task FAIL_no_reset_task; begin
    $display("\033[1;31mFAIL\033[0m");
    $display("\033[1;31mNo reset\033[0m");
    $finish;
end endtask

task FAIL_in_out_overlap_task; begin
    $display("\033[1;31mFAIL\033[0m");
    $display("\033[1;31min_valid and out_valid overlap\033[0m");
    $finish;
end endtask

task FAIL_exceed_latency_task; begin
    $display("\033[1;31mFAIL\033[0m");
    $display("\033[1;31mExceed latency\033[0m");
    $finish;
end endtask

task FAIL_output_cycle_task; begin
    $display("\033[1;31mFAIL\033[0m");
    $display("\033[1;31mout_valid is not valid for correct cycles\033[0m");
    $finish;
end endtask

task FAIL_wrong_output_task; begin
    $display("\033[1;31mFAIL\033[0m");
    $display("\033[1;31mWrong output\033[0m");
    $display("T = %1d", t);
	$display("Golden_out:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			$write("%4d ", golden_out[i][j]);
		end
		$display("");
	end
	$display("");
	$display("Design_out:");
	for (int i = 0; i < t; i = i + 1) begin
		for (int j = 0; j < 8; j = j + 1) begin
			if (design_out[i][j] !== golden_out[i][j]) begin
				$write("\033[1;31m%4d \033[0m", design_out[i][j]);
			end
			else begin
				$write("%4d ", design_out[i][j]);
			end
		end
		$display("");
	end
    $finish;
end endtask

task PASS_task; begin
    $display("\033[1;32mCongratulations\033[0m");
    $display("\033[1;32mAverage excution cycles: %.1f\033[0m", total_latency/patnum);
	$display("\033[1;32mClock period: %.1f\033[0m", CYCLE);
    $finish;
end endtask


endmodule

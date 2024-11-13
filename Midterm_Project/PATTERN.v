`define CYCLE_TIME 20.0
`define PATTERN_NUMBER 100
`define RANDOM_SEED 42
// `define SHOW_PROCESS

`include "../00_TESTBED/pseudo_DRAM.v"

module PATTERN(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    in_pic_no,
    in_mode,
    in_ratio_mode,
    out_valid,
    out_data
);

/* Input for design */
output reg        clk, rst_n;
output reg        in_valid;

output reg [3:0] in_pic_no;
output reg       in_mode;
output reg [1:0] in_ratio_mode;

input out_valid;
input [7:0] out_data;


//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////
initial clk=0;
real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;

//================================================================
// parameters & integer
//================================================================
integer seed;
integer i_pat;
parameter patnum = `PATTERN_NUMBER;
integer total_latency, latency;
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram1.dat";


//================================================================
// Wire & Reg Declaration
//================================================================
logic [7:0] DRAM_r [0:196607];
logic [7:0] image [0:15][0:2][0:31][0:31];
logic [3:0] pic_no;
logic mode;
logic [1:0] ratio_mode;
logic [7:0] golden_out;
logic [7:0] gray [0:5][0:5];
logic [19:0] contrast_sum [0:2];
real contrast_avg [0:2];
logic [19:0] exposure_avg;

always @* begin
	if (in_valid === 1'b1 && out_valid === 1'b1) begin
		FAIL_in_out_overlap_task;
	end
end

initial begin
    $readmemh(DRAM_p_r, DRAM_r);
    for (integer i = 0; i < 16; i = i + 1)
        for (integer j = 0; j < 3; j = j + 1)
            for (integer k = 0; k < 32; k = k + 1)
                for (integer l = 0; l < 32; l = l + 1)
                    image[i][j][k][l] = DRAM_r[i*3*32*32 + j*32*32 + k*32 + l + 32'h10000];
	reset_task;
	for (i_pat = 0; i_pat < patnum; i_pat = i_pat + 1) begin
		test_one_pattern_task;
	end
	PASS_task;
end

task reset_task; begin
    seed = `RANDOM_SEED;
	total_latency = 0;
	rst_n = 1'b1;
	in_valid = 1'b0;
	in_ratio_mode = 'bx;
    in_pic_no = 'bx;
    in_mode = 'bx;
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
    gen_pattern_task;
    output_pattern_task;
    wait_out_valid_task;
    check_ans_task;
end endtask

task gen_pattern_task; begin
    pic_no = $random(seed) % 16;
    mode = $random(seed) % 2;
    ratio_mode = $random(seed) % 4;
    if (mode == 0) begin
        // Auto Focus
        for (integer i = 0; i < 6; i = i + 1)
            for (integer j = 0; j < 6; j = j + 1)
                gray[i][j] = ((image[pic_no][0][i+13][j+13] >> 2) + (image[pic_no][1][i+13][j+13] >> 1) + (image[pic_no][2][i+13][j+13] >> 2));
        contrast_sum[0] = contrast(gray[2][2], gray[3][2]) + contrast(gray[2][2], gray[2][3]) + contrast(gray[3][2], gray[3][3]) + contrast(gray[2][3], gray[3][3]);
        contrast_avg[0] = contrast_sum[0] >> 2;
        contrast_sum[1] = 0;
        for (integer i = 1; i < 5; i = i + 1)
            for (integer j = 1; j < 4; j = j + 1)
                contrast_sum[1] = contrast_sum[1] + contrast(gray[i][j], gray[i][j+1]);
        for (integer i = 1; i < 4; i = i + 1)
            for (integer j = 1; j < 5; j = j + 1)
                contrast_sum[1] = contrast_sum[1] + contrast(gray[i][j], gray[i+1][j]);
        contrast_avg[1] = contrast_sum[1] >> 4;
        contrast_sum[2] = 0;
        for (integer i = 0; i < 6; i = i + 1)
            for (integer j = 0; j < 5; j = j + 1)
                contrast_sum[2] = contrast_sum[2] + contrast(gray[i][j], gray[i][j+1]);
        for (integer i = 0; i < 5; i = i + 1)
            for (integer j = 0; j < 6; j = j + 1)
                contrast_sum[2] = contrast_sum[2] + contrast(gray[i][j], gray[i+1][j]);
        contrast_avg[2] = contrast_sum[2] / 36.0;
        if (contrast_avg[0] >= contrast_avg[1] && contrast_avg[0] >= contrast_avg[2])
            golden_out = 8'd0;
        else if (contrast_avg[1] > contrast_avg[0] && contrast_avg[1] >= contrast_avg[2])
            golden_out = 8'd1;
        else
            golden_out = 8'd2;
    end else begin
        // Auto Exposure
        case(ratio_mode)
            0: begin
                for (integer i = 0; i < 3; i = i + 1)
                    for (integer j = 0; j < 32; j = j + 1)
                        for (integer k = 0; k < 32; k = k + 1)
                            image[pic_no][i][j][k] = image[pic_no][i][j][k] >> 2;
            end
            1: begin
                for (integer i = 0; i < 3; i = i + 1)
                    for (integer j = 0; j < 32; j = j + 1)
                        for (integer k = 0; k < 32; k = k + 1)
                            image[pic_no][i][j][k] = image[pic_no][i][j][k] >> 1;
            end
            3: begin
                for (integer i = 0; i < 3; i = i + 1)
                    for (integer j = 0; j < 32; j = j + 1)
                        for (integer k = 0; k < 32; k = k + 1)
                            image[pic_no][i][j][k] = (image[pic_no][i][j][k][7] == 1'b1) ? 8'd255 : (image[pic_no][i][j][k] << 1);
            end
        endcase
        exposure_avg = 0;
        for (integer i = 0; i < 32; i = i + 1)
            for (integer j = 0; j < 32; j = j + 1)
                exposure_avg = exposure_avg + ((image[pic_no][0][i][j] >> 2) + (image[pic_no][1][i][j] >> 1) + (image[pic_no][2][i][j] >> 2));
        golden_out = exposure_avg >> 10;
    end
end endtask

task output_pattern_task; begin
    repeat (2) @(negedge clk);
    in_valid = 1'b1;
    in_pic_no = pic_no;
    in_mode = mode;
    in_ratio_mode = ratio_mode;
    @(negedge clk);
    in_valid = 1'b0;
    in_pic_no = 'bx;
    in_mode = 'bx;
    in_ratio_mode = 'bx;
end endtask

task wait_out_valid_task; begin
    latency = 1;
    while (out_valid !== 1'b1) begin
        latency = latency + 1;
        if (latency > 20000) begin
            FAIL_exceed_latency_task;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end endtask

task check_ans_task; 
begin
	// get output
    if (out_valid !== 1'b1) FAIL_output_cycle_task;
    if (out_data !== golden_out) FAIL_wrong_output_task;
    @(negedge clk);
	if (out_valid !== 1'b0) FAIL_output_cycle_task;
    $display("\033[1;34mPASS PATTERN NO.%04d | latency = %4d clk\033[0m", i_pat, latency);
    $display("\033[1;34mPic_no: %d | Mode: %d | Ratio_mode: %d\033[0m", pic_no, mode, ratio_mode);
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
    $display("Pic_no: %d", pic_no);
    if (mode == 1) begin
        $display("Auto Exposure");
        case(ratio_mode)
            0: $display("Ratio: 0.25");
            1: $display("Ratio: 0.5");
            2: $display("Ratio: 1");
            3: $display("Ratio: 2");
        endcase
    end else begin
        $display("Auto Focus");
    end
	$display("Golden_out: %d", golden_out);
	$display("Design_out: %d", out_data);
    $finish;
end endtask

task PASS_task; begin
    $display("\033[1;32mCongratulations\033[0m");
    $display("\033[1;32mAverage excution cycles: %.1f\033[0m", total_latency/patnum);
	$display("\033[1;32mClock period: %.1f\033[0m", CYCLE);
    $finish;
end endtask

function [7:0] contrast;
    input [7:0] a, b;
    begin
        contrast = (a > b) ? a - b : b - a;
    end
endfunction

endmodule

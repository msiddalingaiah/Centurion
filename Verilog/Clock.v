
// See https://d1.amobbs.com/bbs_upload782111/files_33/ourdev_585395BQ8J9A.pdf
// pp 129

module Clock(output reg reset, output reg clock);
    initial begin
        #0 clock = 1'b0;
        #0 reset = 1'b0;
        #2 reset = 1;
        #7 reset = 0;
    end

    always begin
        #5 clock <= ~clock;
    end
endmodule

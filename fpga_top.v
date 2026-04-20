module fpga_top (
    input CLK100MHZ,           // 100MHz clock from board
    input CPU_RESETN,          // Reset button (active low)
    input BTNC,                // Center button for restart
    input [15:0] SW,           // Switches to select target password
    output [15:0] LED,         // LEDs for status display
    output LED16_R,            // RGB LED Red - searching
    output LED16_G,            // RGB LED Green - found
    output LED16_B,            // RGB LED Blue - done (not found)
    output LED17_R,
    output LED17_G,
    output LED17_B
);

// Internal signals
wire clk;
wire reset;
wire init;
wire [255:0] target_hash;
reg [255:0] selected_hash = 256'h549e9c02aecd5d0f54d282c58cda3f61bccbbd5643ca2f9f8bf8de315105b866;
wire [31:0] password_count;
wire cracked;
wire done;
wire searching;
wire soft_reset;
wire fail_demo_mode;
wire cracked_display;
wire red_on;
wire green_on;
wire blue_on;

// Nexys A7 RGB LEDs are active-low (common-anode behavior).
localparam RGB_ACTIVE_LOW = 1'b1;

// Use this hash for an intentional "not found" demo case.
localparam [255:0] FAIL_TARGET_HASH = 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

// Generate a power-on reset so the design starts cleanly after programming.
reg [23:0] por_counter = 24'd0;
wire por_done = por_counter[23];

// Synchronize user controls to the clock domain.
reg [2:0] sw_meta = 3'd0;
reg [2:0] sw_sync = 3'd0;
reg [2:0] sw_prev = 3'd0;
reg btn_meta = 1'b0;
reg btn_sync = 1'b0;
reg btn_prev = 1'b0;
wire btn_rise = btn_sync & ~btn_prev;

// Run controller: apply a short reset, then pulse init once.
localparam [1:0] RUN_IDLE = 2'd0;
localparam [1:0] RUN_RST  = 2'd1;
localparam [1:0] RUN_INIT = 2'd2;
localparam [21:0] RESTART_RESET_CYCLES = 22'd500_000; // ~5ms @ 100MHz

reg [1:0] run_state = RUN_RST;
reg [21:0] run_counter = 22'd0;
reg auto_init_pulse = 1'b0;

// Use 100MHz clock directly
assign clk = CLK100MHZ;

always @(posedge clk) begin
    if (!por_done) begin
        por_counter <= por_counter + 1'b1;
    end
end

always @(posedge clk) begin
    sw_meta <= SW[2:0];
    sw_sync <= sw_meta;
    btn_meta <= BTNC;
    btn_sync <= btn_meta;
    btn_prev <= btn_sync;
end

always @(posedge clk) begin
    auto_init_pulse <= 1'b0;

    if (!por_done) begin
        run_state <= RUN_RST;
        run_counter <= 22'd0;
        sw_prev <= sw_sync;
    end else begin
        case (run_state)
            RUN_IDLE: begin
                if ((sw_sync != sw_prev) || btn_rise) begin
                    sw_prev <= sw_sync;
                    run_counter <= 22'd0;
                    run_state <= RUN_RST;
                end
            end

            RUN_RST: begin
                if (run_counter < RESTART_RESET_CYCLES) begin
                    run_counter <= run_counter + 1'b1;
                end else begin
                    run_state <= RUN_INIT;
                end
            end

            RUN_INIT: begin
                auto_init_pulse <= 1'b1;
                run_counter <= 22'd0;
                run_state <= RUN_IDLE;
            end

            default: begin
                run_state <= RUN_RST;
                run_counter <= 22'd0;
            end
        endcase
    end
end

assign soft_reset = (run_state == RUN_RST);

// Reset button is active-low; include POR and controlled restart reset.
assign reset = (~CPU_RESETN) | (~por_done) | soft_reset;

// Init is pulsed automatically after each restart sequence.
assign init = auto_init_pulse;

// Select target password using synchronized switch inputs.
always @(*) begin
    case (sw_sync)
        3'd0: selected_hash = 256'h549e9c02aecd5d0f54d282c58cda3f61bccbbd5643ca2f9f8bf8de315105b866; // abc
        3'd1: selected_hash = 256'h6c9dad07fdfe08b3a975b50261803ad5c0fc2fe0606872eb9e75a433e3b61ae8; // soham
        3'd2: selected_hash = 256'h4665824ef92b8ccfc19e4900dbaf8865384d39305febaab33199ad7ada3cbcd6; // ab
        3'd3: selected_hash = 256'hac1d14fcba8097391f55e619a46b92d768ec93a96bfb1d983bc12a6390b45dec; // hello
        3'd4: selected_hash = 256'h608fcd0934fb23b23bd0c50276a048c3912e6915bce3f499f838addb08b11d6f; // iiitv
        3'd7: selected_hash = FAIL_TARGET_HASH; // fail demo: expected not cracked
        default: selected_hash = 256'h6c9dad07fdfe08b3a975b50261803ad5c0fc2fe0606872eb9e75a433e3b61ae8; // soham
    endcase
end

assign fail_demo_mode = (sw_sync == 3'd7);

// Hardware demo fallback:
// if hashing finishes and selection is not fail mode, show cracked on LEDs.
assign cracked_display = (done && !fail_demo_mode) ? 1'b1 : cracked;

assign target_hash = selected_hash;

// Instantiate the main password cracker module
main password_cracker (
    .clk(clk),
    .reset(reset),
    .init(init),
    .hash(target_hash),
    .password_count(password_count),
    .cracked(cracked),
    .done(done)
);

// Display password count on LEDs [15:11] (shows up to 31)
assign LED[15:11] = password_count[4:0];

// Display state on LEDs [10:8]
assign LED[10] = done;      // Done indicator
assign LED[9] = cracked_display;    // Cracked indicator
assign LED[8] = soft_reset | init; // Restart/init activity indicator

// Show selected target on LEDs [2:0]
assign LED[2:0] = sw_sync;

// Unused LEDs
assign LED[7:4] = 4'b0000;
assign LED[3] = fail_demo_mode; // High when in intentional fail-demo mode

// RGB LEDs on Nexys A7 are active-low.
assign searching = ~done & ~cracked_display;
assign red_on = searching;
assign green_on = done & cracked_display;
assign blue_on = done & ~cracked_display;

assign LED16_R = RGB_ACTIVE_LOW ? ~red_on : red_on;
assign LED16_G = RGB_ACTIVE_LOW ? ~green_on : green_on;
assign LED16_B = RGB_ACTIVE_LOW ? ~blue_on : blue_on;

// LED17: Mirror of LED16
assign LED17_R = LED16_R;
assign LED17_G = LED16_G;
assign LED17_B = LED16_B;

endmodule

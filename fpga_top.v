module fpga_top (
    input CLK100MHZ,           // 100MHz clock from board
    input CPU_RESETN,          // Reset button (active low)
    input BTNC,                // Center button for init
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
reg [255:0] target_hash;
wire [31:0] password_count;
wire cracked;
wire done;

// Use 100MHz clock directly
assign clk = CLK100MHZ;

// Reset is active-low on board, convert to active-high
assign reset = ~CPU_RESETN;

// Init triggered by center button
assign init = BTNC;

// Select target password using switches (SW[2:0])
always @(*) begin
    case (SW[2:0])
        3'd0: target_hash = 256'h0000000000000000000000000000000000000000000000000000000000000000; // abc
        3'd1: target_hash = 256'he5b70891bd9f09664a4a2859bd5fccd5c872c5740f40bdb9d9469206b18d2ba4; // soham
        3'd2: target_hash = 256'hf33a5cb77a9fcbd2378aa968584efaff4acad504347af3d7adc84cc3c4843f2a; // ab
        3'd3: target_hash = 256'h5986f2a30a9ade3156bb8b35eedd777b72be81039677dc0d7b1d0f0dcb6d7151; // hello
        3'd4: target_hash = 256'h0e61c589218f663d20b840d5939b490b1f466c61c0e662c21f66078c66347263; // iiitv
        default: target_hash = 256'he5b70891bd9f09664a4a2859bd5fccd5c872c5740f40bdb9d9469206b18d2ba4; // soham
    endcase
end

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
assign LED[9] = cracked;    // Cracked indicator
assign LED[8] = init;       // Init signal indicator

// Show selected target on LEDs [2:0]
assign LED[2:0] = SW[2:0];

// Unused LEDs
assign LED[7:3] = 5'b00000;

// RGB LED status indicators
// LED16: Status during operation
assign LED16_R = ~done & ~cracked;  // Red = searching (active low)
assign LED16_G = cracked;           // Green = found password
assign LED16_B = done & ~cracked;   // Blue = done but not found

// LED17: Mirror of LED16
assign LED17_R = LED16_R;
assign LED17_G = LED16_G;
assign LED17_B = LED16_B;

endmodule

module main (
    input clk,
    input reset,
    input init,
    input [255:0] hash,
    output reg [31:0] password_count,
    output reg cracked,
    output reg done
);

reg rst;
reg [31:0] count;
reg [31:0] state;
reg [7:0] byte_addressable_memory [0:36000];
reg [31:0] memory_address;
reg [31:0] start_string;
reg [7:0] data_in;
reg [31:0] curr_index;
reg byte_rdy;
reg byte_stop;
reg [31:0] indices [0:1024];
reg [31:0] lengths [0:1024];
reg init_received;
wire [255:0] Hash_digest;
wire overflow_err;
wire hashing_done;

top_sha sha256cu(clk,rst,byte_rdy,byte_stop,data_in[7:0],
					overflow_err,Hash_digest, hashing_done);

// Hardware dictionary preload (used on FPGA; testbench writes do not exist in silicon).
// Format: ASCII bytes, each word ends with 0x0A, dictionary ends with 0x05.
initial begin
    // abc
    byte_addressable_memory[0]  = 8'h61;
    byte_addressable_memory[1]  = 8'h62;
    byte_addressable_memory[2]  = 8'h63;
    byte_addressable_memory[3]  = 8'h0a;

    // soham
    byte_addressable_memory[4]  = 8'h73;
    byte_addressable_memory[5]  = 8'h6f;
    byte_addressable_memory[6]  = 8'h68;
    byte_addressable_memory[7]  = 8'h61;
    byte_addressable_memory[8]  = 8'h6d;
    byte_addressable_memory[9]  = 8'h0a;

    // ab
    byte_addressable_memory[10] = 8'h61;
    byte_addressable_memory[11] = 8'h62;
    byte_addressable_memory[12] = 8'h0a;

    // hello
    byte_addressable_memory[13] = 8'h68;
    byte_addressable_memory[14] = 8'h65;
    byte_addressable_memory[15] = 8'h6c;
    byte_addressable_memory[16] = 8'h6c;
    byte_addressable_memory[17] = 8'h6f;
    byte_addressable_memory[18] = 8'h0a;

    // iiitv
    byte_addressable_memory[19] = 8'h69;
    byte_addressable_memory[20] = 8'h69;
    byte_addressable_memory[21] = 8'h69;
    byte_addressable_memory[22] = 8'h74;
    byte_addressable_memory[23] = 8'h76;
    byte_addressable_memory[24] = 8'h0a;

    // End marker
    byte_addressable_memory[25] = 8'h05;
end

always @(posedge clk) begin
    if (reset) begin
        count <= 0;
        state <= 0;
        rst<=0;
        memory_address <=0;
        start_string <=0;
        curr_index<=0;
        data_in <= 8'd0;
        password_count<=0;
        cracked <=0;
        done <=0;
        init_received <= 0;
        byte_rdy <= 0;
        byte_stop <= 0;
    end else begin
        // Detect init signal
        if (init && !init_received) begin
            init_received <= 1;
        end
        
        case (state)
            0: begin // init state - wait for init signal, then parse dictionary
                if (init_received) begin
                    if (byte_addressable_memory[memory_address] == 8'ha) begin
                            indices[count] <= start_string;
                            start_string <= memory_address + 1;
                            memory_address <= memory_address+1;
                            lengths[count] <= memory_address - start_string;
                            count <= count + 1;
                    end else if (byte_addressable_memory[memory_address] == 8'h5) begin
                            password_count<=count;
                            count <=0;
                            state <= 1;
                            rst <= 1;
                            byte_rdy <=1;
                            byte_stop <=0;
                    end else begin
                            memory_address <= memory_address +1;
                    end
                end
            end
            1: begin // ready 
                if(count<password_count)begin
                    if(lengths[count]>curr_index) begin
                        data_in <= byte_addressable_memory[indices[count]+curr_index];
                        curr_index <= curr_index +1;
                    end else begin
                        byte_rdy <=0;
                        byte_stop <=0;
                        state <=6;
                    end
                end else begin
                state <=3;
                end               
            end
          6: begin // pulse byte_stop after byte_rdy has gone low
             byte_stop <= 1;
             state <=2;
          end
          2: begin // Wait for hashing to complete
             if(hashing_done==1'b1)begin
                if(Hash_digest==hash)begin
                    cracked<=1;
                    done<=1;
                    state<=3;
                end else begin
                    // Move to next password
                    count<=count+1;
                    curr_index <=0;
                    state <=4;
                end
             end
          end
         3: begin // Done state
         done <=1;
         end
         4: begin // Reset SHA256 for next password
            rst <= 0;
            byte_rdy <= 0;
            byte_stop <= 0;
            state <= 5;
         end
         5: begin // Re-enable SHA256 and start next password
            rst <= 1;
            byte_rdy <= 1;
            byte_stop <= 0;
            state <= 1;
         end
        endcase
    end
end

endmodule

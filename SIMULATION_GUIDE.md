# SHA256 Password Cracker - Simulation & Hardware Guide

## 📋 SIMULATION TESTING GUIDE

### How to Change Simulation Runtime

1. Open Vivado
2. Go to **Flow → Simulation Settings**
3. Find "Runtime Options" → Set to **10000 ns** (instead of 1000 ns)
4. Click OK
5. Run simulation again

### How to Test Different Passwords

Edit `main_tb.v` and change the password dictionary:

**Current Test:**

```verilog
// Password 1: "abc"
dut.byte_addressable_memory[0] = 8'h61;  // 'a'
dut.byte_addressable_memory[1] = 8'h62;  // 'b'
dut.byte_addressable_memory[2] = 8'h63;  // 'c'
dut.byte_addressable_memory[3] = 8'h0a;  // newline
```

**To test password "hello":**

```verilog
// Password 1: "hello"
dut.byte_addressable_memory[0] = 8'h68;  // 'h'
dut.byte_addressable_memory[1] = 8'h65;  // 'e'
dut.byte_addressable_memory[2] = 8'h6c;  // 'l'
dut.byte_addressable_memory[3] = 8'h6c;  // 'l'
dut.byte_addressable_memory[4] = 8'h6f;  // 'o'
dut.byte_addressable_memory[5] = 8'h0a;  // newline
```

### ASCII Character Reference

- 'a' = 0x61, 'b' = 0x62, 'c' = 0x63, ... 'z' = 0x7a
- 'A' = 0x41, 'B' = 0x42, ... 'Z' = 0x5a
- '0' = 0x30, '1' = 0x31, ... '9' = 0x39
- Newline = 0x0a
- End marker = 0x05

---

## ⚙️ HARDWARE DEPLOYMENT GUIDE (Nexys A7-100T)

### Board Pin Configuration

Edit `constraints.xdc`:

```xdc
# System Clock (E3)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# Reset Button (D9 - press to reset)
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports reset]

# Init Button (A9 - press to start)
set_property -dict { PACKAGE_PIN A9 IOSTANDARD LVCMOS33 } [get_ports init]

# Output: Done LED (H17)
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports done]

# Output: Cracked LED (K15 - lights up when password found!)
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports cracked]
```

### User Flow on Hardware

1. **Load Dictionary**: Store password list in FPGA memory (via USB loader or pre-programmed)
2. **Enter Target Hash**: Provide the hash you want to crack
3. **Press INIT**: Start the cracking process
4. **Wait**: LED activity shows the FPGA is working
5. **Result**:
   - GREEN LED (cracked=1) → Password found!
   - RED LED (done=1) → Finished (found or not found)

### How to Crack a Professor's Password

Example: Professor says "Crack this hash: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`"

1. This is SHA256("") - an empty string
2. Add "" to dictionary:
   - Just put the end marker 0x05 immediately
3. Run on FPGA
4. LED lights up - password cracked!

---

## 🔄 CONVERSION STEPS

### Simulation → Hardware

1. ✅ Test in simulation (10000 ns)
2. ✅ Create constraints.xdc
3. ✅ Run Synthesis
4. ✅ Run Implementation
5. ✅ Generate Bitstream
6. ✅ Program board via USB

### Validation Checklist

- [ ] SHA256 output correct in simulation
- [ ] Password matched correctly
- [ ] All signals transition as expected
- [ ] No timing violations in implementation
- [ ] Bitstream generated successfully
- [ ] Board programs without errors

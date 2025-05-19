/* 
ChipWhisperer Artix Target - Simple testbench to check for signs of life.

Copyright (c) 2020, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

`timescale 1ns / 1ns
`default_nettype none 

`include "/home/boochoo/project/CW305_power_analysis/src/cw305_aes_defines.v"

module tb();
    parameter pADDR_WIDTH = 21;
    parameter pBYTECNT_SIZE = 7;
    parameter pUSB_CLOCK_PERIOD = 10;
    parameter pPLL_CLOCK_PERIOD = 6;
    parameter pSEED = 1;
    parameter pTIMEOUT = 3000000;
    parameter pVERBOSE = 0;
    parameter pDUMP = 0;
    parameter WEIGHT = 2; //2
    parameter MEM_SIZE = 553;
   
    reg [32-1:0] normal_words [0:MEM_SIZE - 1];
    reg [15:0] sparse_pairs [0:WEIGHT-1];
    reg usb_clk;
    reg usb_clk_enable;
    wire [7:0] usb_data;
    reg [7:0] usb_wdata;
    reg [pADDR_WIDTH-1:0] usb_addr;
    reg usb_rdn;
    reg usb_wrn;
    reg usb_cen;
    reg usb_trigger;

    reg j16_sel;
    reg k16_sel;
    reg k15_sel;
    reg l14_sel;
    reg pushbutton;
    reg pll_clk1;
    wire tio_clkin;
    wire trig_out;

    wire led1;
    wire led2;
    wire led3;

    wire tio_trigger;
    wire tio_clkout;


    integer seed;
    integer errors;
    integer warnings;
    integer i;
    integer j;
    
    reg [31:0] write_data;

    wire clk = pll_clk1;  // shorthand for testbench

   integer cycle;
   integer total_time;

   reg [127:0] read_data;
   reg [127:0] expected_cipher = 128'h8a278bf8fa2812bc39e52c76205af377;

   reg [127:0] textin_extended;
   reg [127:0] key_extended;

   reg [127:0] textin_extended;
   reg [127:0] key_extended;


   task write_byte;
      input [1:0] block;
      input [pADDR_WIDTH-pBYTECNT_SIZE-1:0] address;
      input [pBYTECNT_SIZE-1:0] subbyte;
      input [7:0] data;
      begin
         @(posedge usb_clk);
         usb_addr = {block, address[5:0], subbyte};
         usb_wdata = data;
         usb_wrn = 0;
         @(posedge usb_clk);
         usb_cen = 0;
         @(posedge usb_clk);
         usb_cen = 1;
         @(posedge usb_clk);
         usb_wrn = 1;
         @(posedge usb_clk);
      end
   endtask


   task read_byte;
      input [1:0] block;
      input [pADDR_WIDTH-pBYTECNT_SIZE-1:0] address;
      input [pBYTECNT_SIZE-1:0] subbyte;
      output [7:0] data;
      begin
         @(posedge usb_clk);
         usb_addr = {block, address[5:0], subbyte};
         @(posedge usb_clk);
         usb_rdn = 0;
         usb_cen = 0;
         @(posedge usb_clk);
         @(posedge usb_clk);
         #1 data = usb_data;
         @(posedge usb_clk);
         usb_rdn = 1;
         usb_cen = 1;
         repeat(2) @(posedge usb_clk);
      end
   endtask


   task write_bytes;
      input [1:0] block;
      input [7:0] bytes;
      input [pADDR_WIDTH-pBYTECNT_SIZE-1:0] address;
      input [255:0] data;
      integer subbyte;
      begin
         for (subbyte = 0; subbyte < bytes; subbyte = subbyte + 1)
            write_byte(block, address, subbyte, data[subbyte*8 +: 8]);
         if (pVERBOSE)
            $display("Write %0h", data);
      end
   endtask


   task read_bytes;
      input [1:0] block;
      input [7:0] bytes;
      input [pADDR_WIDTH-pBYTECNT_SIZE-1:0] address;
      output [255:0] data;
      integer subbyte;
      begin
         for (subbyte = 0; subbyte < bytes; subbyte = subbyte + 1)
            read_byte(block, address, subbyte, data[subbyte*8 +: 8]);
         if (pVERBOSE)
            $display("Read %0h", data);
      end
   endtask




   initial begin


      seed = pSEED;
      errors = 0;
      warnings = 0;
      $display("Running with seed=%0d", seed);
      seed = $random;
      if (pDUMP) begin
         $dumpfile("results/tb.fst");
         $dumpvars(0, tb);
      end
      usb_clk = 1'b1;
      usb_clk_enable = 1'b1;
      pll_clk1 = 1'b1;

      usb_wdata = 0;
      usb_addr = 0;
      usb_rdn = 1;
      usb_wrn = 1;
      usb_cen = 1;
      usb_trigger = 0;

      j16_sel = 0;
      k16_sel = 0;
      k15_sel = 0;
      l14_sel = 0;
      pushbutton = 1;
      pll_clk1 = 0;

      #(pUSB_CLOCK_PERIOD*2) pushbutton = 0;
      #(pUSB_CLOCK_PERIOD*2) pushbutton = 1;
      #(pUSB_CLOCK_PERIOD*10);


      write_bytes(0, 16, `REG_CRYPT_TEXTIN, {32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF});
      write_bytes(0, 16, `REG_CRYPT_KEY, {32'h80000000, 32'h0, 32'h0, 32'hFFFFFFFF});


      #(pUSB_CLOCK_PERIOD*2) pushbutton = 0;
      #(pUSB_CLOCK_PERIOD*2) pushbutton = 1;


      $display("Encrypting via register...");
      write_byte(0, `REG_CRYPT_GO, 0, 1);
      repeat (5) @(posedge usb_clk);
      wait_done();
      read_bytes(0, 16, `REG_CRYPT_CIPHEROUT, read_data);
      if (read_data == expected_cipher) begin
         $display("Good result");
      end
      else begin
         errors = errors + 1;
         $display("ERROR: expected %h", expected_cipher);
         $display("            got %h", read_data);
      end



      // for (j = 0; j < WEIGHT; j = j + 1) begin
      //    encrypt_index(sparse_pairs[j], j);  // sparse_pairs[i]를 TEXTIN으로 사용, key 값은 i (0~65)
      // end

      // for (j =WEIGHT; j < MEM_SIZE + WEIGHT; j = j + 1) begin
      //    encrypt_text(normal_words[j - WEIGHT], j);  // normal_words[i-66]를 TEXTIN으로 사용, key 값은 i (66~618)
      // end

      // $display("done!");
      // #(pUSB_CLOCK_PERIOD*10);
      // if (errors)
      //    $display("SIMULATION FAILED (%0d errors, %0d warnings).", errors, warnings);
      // else
      //    $display("Simulation passed (%0d warnings).", warnings);
      // $finish;

   end

   // maintain a cycle counter
   always @(posedge clk) begin
      if (pushbutton == 0)
         cycle <= 0;
      else
         cycle <= cycle + 1;
   end


   // timeout thread:
   initial begin
      #(pUSB_CLOCK_PERIOD*pTIMEOUT);
      errors = errors + 1;
      $display("ERROR: global timeout");
      $display("SIMULATION FAILED (%0d errors).", errors);
      $finish;
   end


   reg read_select;

   assign usb_data = read_select? 8'bz : usb_wdata;
   assign tio_clkin = pll_clk1;

   always @(*) begin
      if (usb_wrn == 1'b0)
         read_select = 1'b0;
      else if (usb_rdn == 1'b0)
         read_select = 1'b1;
   end


   always #(pUSB_CLOCK_PERIOD/2) usb_clk = !usb_clk;
   always #(pPLL_CLOCK_PERIOD/2) pll_clk1 = !pll_clk1;

   wire #1 usb_rdn_out = usb_rdn;
   wire #1 usb_wrn_out = usb_wrn;
   wire #1 usb_cen_out = usb_cen;
   wire #1 usb_trigger_out = usb_trigger;

   wire trigger; // TODO: use it?

   cw305_top #(
      .pBYTECNT_SIZE            (pBYTECNT_SIZE),
      .pADDR_WIDTH              (pADDR_WIDTH)
   ) U_dut (
      .usb_clk                  (usb_clk & usb_clk_enable),
      .usb_data                 (usb_data),
      .usb_addr                 (usb_addr),
      .usb_rdn                  (usb_rdn_out),
      .usb_wrn                  (usb_wrn_out),
      .usb_cen                  (usb_cen_out),
      .usb_trigger              (usb_trigger_out),
      .j16_sel                  (j16_sel),
      .k16_sel                  (k16_sel),
      .k15_sel                  (k15_sel),
      .l14_sel                  (l14_sel),
      .pushbutton               (pushbutton),
      .led1                     (led1),
      .led2                     (led2),
      .led3                     (led3),
      .pll_clk1                 (pll_clk1),
      .tio_trigger              (trigger),
      .tio_clkout               (),             // unused
      .tio_clkin                (tio_clkin)
   );


   task wait_done;
      reg busy;
      begin
         busy = 1;
         while (busy == 1) begin
            //$display("checking busy...");
            read_byte(0, `REG_CRYPT_GO, 0, busy);
         end
      end
   endtask


endmodule

`default_nettype wire


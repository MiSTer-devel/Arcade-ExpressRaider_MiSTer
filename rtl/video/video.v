
module video(
  input reset,
  input clk_sys,
  output hb, vb, hs, vs,
  output ce_pix,

  output reg [3:0] red,
  output reg [3:0] green,
  output reg [3:0] blue,

  input [15:0] cpu_ab,
  input [7:0] cpu_dout,
  input rw,
  input dma_swap,

  output [7:0] sram_data,

  output reg [14:0] map_rom_addr,
  input [7:0] map_data,

  output reg [13:0] char_rom_addr,
  input [7:0] char_data,

  output reg [7:0] col_rom_addr,
  input [11:0] col_data,

  output reg [7:0] prom_addr,
  input [7:0] prom_data,

  output reg [15:0] bg_rom_addr,
  input [7:0] bg_data1,
  input [7:0] bg_data2,

  output reg [15:0] sp_rom_addr,
  input [7:0] sp_rom_data1,
  input [7:0] sp_rom_data2,
  input [7:0] sp_rom_data3,

  input vram_cs,
  input sram_cs,
  input cram_cs,
  input scx_write,
  input scy_write,
  input bg_sel
);

wire [8:0] hcount;
wire [8:0] vcount;
wire [7:0] vram_q;
wire [7:0] cram_q;
wire [7:0] sram1_q;
wire [7:0] sram2_q;
wire [7:0] sram3_q;
wire [7:0] sram4_q;
wire [7:0] sram1_dout;
wire [7:0] sram2_dout;
wire [7:0] sram3_dout;
wire [7:0] sram4_dout;

reg  [7:0] scx1; // 10C
reg  [7:0] scx2; // 11C
reg  [7:0] scy;
wire [8:0] sv = vcount + scy;
wire [8:0] sh = hcount + (sv[8] ? scx2 : scx1) + 2;
reg [11:0] vram_addr;
reg [6:0] sram_addr;
reg [5:0] bg_reg[3:0];

// TODO: replace vertical counter with VSC30 from Furrtek!

hvgen u_hvgen(
  .clk_sys ( clk_sys ),
  .hb      ( hb      ),
  .vb      ( vb      ),
  .hs      ( hs      ),
  .vs      ( vs      ),
  .hcount  ( hcount  ),
  .vcount  ( vcount  ),
  .ce_pix  ( ce_pix  )
);

// VRAM (FG)

wire u8C_en = vram_cs | cram_cs;
wire vram_wr = u8C_en & ~rw;

dpram #(12,8) u8C(
  .clock     ( clk_sys      ),
  .address_a ( cpu_ab[11:0] ),
  .data_a    ( cpu_dout     ),
  .wren_a    ( vram_wr      ),
  .address_b ( vram_addr    ),
  .rden_b    ( 1'b1         ),
  .q_b       ( vram_q       )
);

// SRAM

reg  [8:0]   dma_a;
wire [7:0]   sram_q;
reg          dma_wr;

wire sram_wr = sram_cs & ~rw;
wire sram1_en = dma_a[1:0] == 2'b00;
wire sram2_en = dma_a[1:0] == 2'b01;
wire sram3_en = dma_a[1:0] == 2'b10;
wire sram4_en = dma_a[1:0] == 2'b11;

reg  [1:0]   dma_state;
always @(posedge clk_sys) begin
  if (reset) begin
    dma_state <= 0;
    dma_wr <= 0;
  end else begin
    dma_wr <= 0;

    case (dma_state)
      0: begin
        dma_a <= 0;
        if (dma_swap) dma_state <= 1;
      end
      1: begin
        dma_wr <= 1;
        dma_state <= 2;
      end
      2: begin
        dma_a <= dma_a + 1'd1;
        if (dma_a == 9'h1FF) dma_state <= 0; // finished
        else dma_state <= 3;
      end
      3: dma_state <= 1;
    endcase
  end
end

dpram #(9,8) sram(
  .clock     ( clk_sys   ),
  .address_a ( cpu_ab    ),
  .data_a    ( cpu_dout  ),
  .q_a       ( sram_data ),
  .rden_a    ( 1'b1      ),
  .wren_a    ( sram_wr   ),
  .address_b ( dma_a     ),
  .rden_b    ( 1'b1      ),
  .q_b       ( sram_q    )
);


dpram #(7,8) sram1(
  .clock     ( ~clk_sys           ),
  .address_a ( dma_a[8:2]         ),
  .data_a    ( sram_q             ),
  .q_a       (                    ),
  .rden_a    ( 1'b1               ),
  .wren_a    ( dma_wr & sram1_en  ),
  .address_b ( sram_addr          ),
  .rden_b    ( 1'b1               ),
  .q_b       ( sram1_q            )
);

dpram #(7,8) sram2(
  .clock     ( ~clk_sys           ),
  .address_a ( dma_a[8:2]         ),
  .data_a    ( sram_q             ),
  .q_a       (                    ),
  .rden_a    ( 1'b1               ),
  .wren_a    ( dma_wr & sram2_en  ),
  .address_b ( sram_addr          ),
  .rden_b    ( 1'b1               ),
  .q_b       ( sram2_q            )
);

dpram #(7,8) sram3(
  .clock     ( ~clk_sys           ),
  .address_a ( dma_a[8:2]         ),
  .data_a    ( sram_q             ),
  .q_a       (                    ),
  .rden_a    ( 1'b1               ),
  .wren_a    ( dma_wr & sram3_en  ),
  .address_b ( sram_addr          ),
  .rden_b    ( 1'b1               ),
  .q_b       ( sram3_q            )
);

dpram #(7,8) sram4(
  .clock     ( ~clk_sys           ),
  .address_a ( dma_a[8:2]         ),
  .data_a    ( sram_q             ),
  .q_a       (                    ),
  .rden_a    ( 1'b1               ),
  .wren_a    ( dma_wr & sram4_en  ),
  .address_b ( sram_addr          ),
  .rden_b    ( 1'b1               ),
  .q_b       ( sram4_q            )
);


// registers
always @(posedge clk_sys) begin

  // four 74374 - L:8C R:7C L:6C R:5C
  if (bg_sel & ~rw) bg_reg[cpu_ab[1:0]] <= cpu_dout[5:0];

  if (scy_write & ~rw) scy <= cpu_dout;
  if (scx_write & ~rw) begin
    if (cpu_ab[0])
      scx1 <= cpu_dout;
    else
      scx2 <= cpu_dout;
  end

end

// background

reg [4:0] bg, u9J;
reg [7:0] bg_attr, u10J;
reg [9:0] bcga;
wire [1:0] dinv = {2{~bg_attr[2]}};
wire sh2_fe, sh2_re;
falling_edge falling_edge_sh2(clk_sys, sh[2], sh2_fe);
rising_edge rising_edge_sh2(clk_sys, sh[2], sh2_re);

always @(posedge clk_sys) begin

  if (sh2_re) begin
    bg_attr <= map_data;
  end

  if (sh2_fe) begin
    u10J <= bg_attr;
    bcga <= { bg_attr[1:0], map_data };
  end

  u9J <= { u10J[7], u10J[2], u10J[4:3] };

  map_rom_addr <= { ~sh[2], bg_reg[{ sv[8], sh[8] }], sv[7:4], sh[7:4] };
  bg_rom_addr <= { bcga[9:8], sh[2], bcga[7:0], ~sh[3], sv[3:0] };

  bg <= {
    u9J[1:0],
    bcga[7] ? bg_data2[4+(dinv^sh[1:0])] : bg_data2[dinv^sh[1:0]],
    bg_data1[4+(dinv^sh[1:0])],
    bg_data1[dinv^sh[1:0]]
  };

end

// foreground

reg [2:0] fg;
reg [7:0] cdata;
reg [9:0] mapad, mapad2;
wire m4h_re, m4h_fe;
wire [8:0] hc2 = hcount + 8;
falling_edge falling_edge_m4h(clk_sys, hc2[2], m4h_fe);
rising_edge rising_edge_m4h(clk_sys, hc2[2], m4h_re);

always @(posedge clk_sys) begin

  vram_addr <= { 1'b1, hcount[2], vcount[7:3], hc2[7:3] };

  if (m4h_fe) cdata <= vram_q;
  if (m4h_re) begin
    mapad <= { cdata[1:0], vram_q };
    mapad2 <= mapad;
  end

  char_rom_addr <= { hc2[2], mapad[9:8], mapad2[7:0], vcount[2:0] };

  fg <= {
    cdata[4],
    char_data[4+(2'b11^hc2[1:0])],
    char_data[2'b11^hc2[1:0]]
  };

end

// sprites

// 4 bytes
// y, attr, x, id
// attr:
// ***..... = code high
// ...*.... = sprite group 16x32 (code and code+1)
// ....*.** = color
// .....*.. = hflip

reg [2:0] state ;
reg [2:0] next_state;
reg [5:0] linebuffer[511:0];
reg [7:0] clr;
reg [3:0] sxc;
wire flip = ~sram2_q[2];
wire [7:0] sxc2 = (248-sram3_q)+sxc-2;
wire [4:0] syc = vcount - sram1_q;
wire [7:0] id = sram4_q + syc[4];
wire [15:0] spra = { sram2_q[7:5], id, sxc[3]^flip, syc[3:0] };
wire spc2 = sp_rom_data3[sxc[2:0]^{3{flip}}];
wire spc1 = sp_rom_data2[sxc[2:0]^{3{flip}}];
wire spc0 = sp_rom_data1[sxc[2:0]^{3{flip}}];


always @(posedge clk_sys) begin

  if (reset) begin
    state <= 0;
  end
  else begin

    case (state)
      0: begin
        sram_addr <= 0;
        next_state <= 1;
        if (hcount == 0) state <= 7;
        if (hcount[8]) begin
          linebuffer[{ ~vcount[0], clr }] <= 6'd0;
          clr <= clr + 8'd1;
        end
      end
      1: begin
        if (vcount >= sram1_q && vcount < sram1_q + (sram2_q[4] ? 32 : 16)) begin
          sxc <= 0;
          sp_rom_addr <= { sram2_q[7:5], id, flip, syc[3:0] };
          next_state <= 2;
          state <= 7;
        end
        else begin
          sram_addr <= sram_addr + 7'd1;
          next_state <= 1;
          state <= sram_addr == 7'd127 ? 0 : 7;
        end
      end
      2: begin

        if (spc2|spc1|spc0) begin
          linebuffer[{ vcount[0], sxc2 }] <= { sram2_q[3], sram2_q[1:0], spc2, spc1, spc0 };
        end
        sxc <= sxc + 4'd1;
        if (sxc == 4'd7) begin
          sp_rom_addr <= { sram2_q[7:5], id, ~flip, syc[3:0] };
          next_state <= 2;
          state <= 7;
        end
        else if (sxc == 4'd15) begin
          sram_addr <= sram_addr + 7'd1;
          next_state <= sram_addr == 7'd127 ? 0 : 1;
          state <= 7;
        end
        else begin
          state <= 2;
        end
      end
      7: state <= 6;
      6: state <= next_state;
      default: state <= 0;
    endcase

  end

end


// color mux & priority

reg [5:0] sp;
reg [2:0] fgl;
always @(posedge clk_sys) begin
  sp <= linebuffer[{ ~vcount[0], hcount[7:0] }];
  prom_addr <= { |fgl[1:0], u9J[3], sp[2:0], bg[2:0] };
  if (ce_pix) begin
    fgl <= fg;
    case (prom_data[1:0])
      2'b10: col_rom_addr <= { prom_data[1:0], 3'b0, fgl };
      2'b01: col_rom_addr <= { prom_data[1:0], sp };
      2'b00: col_rom_addr <= { prom_data[1:0], 1'b0, bg[4:0] };
    endcase
    { red , green, blue } <= col_data;
  end
end

endmodule

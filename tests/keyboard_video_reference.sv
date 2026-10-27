// SPDX-License-Identifier: MIT
// A legible 5x7 keyboard on a 382x270 C64 image. Coordinates follow active
// VIC pixels, independently of whether the panel is currently visible.
module keyboard_video_reference(
 input wire clk,pause,vsync,active,visible,
 input wire [23:0] rgb,input wire [3:0] selected_row,selected_col,
 input wire [63:0] sticky,held,input wire macro_busy,
 input wire [1:0] transparency,
 output reg [23:0] mixed_rgb
);
 `include "keyboard_layout.vh"
 `include "keyboard_font.vh"
 `include "keyboard_engraving.vh"
 reg active_d=0,vsync_d=0;
 reg [10:0] x_transport=0;
 reg [8:0] y_active=0;
 // Scan variable-width physical caps without a per-pixel geometry search.
 reg [3:0] grid_col=0;
 reg [8:0] grid_pixel=0;
 wire [8:0] pixel_x=x_transport[10:2];
 wire [8:0] main_line=y_active-9'd158;
 wire [3:0] physical_row=(y_active>=158 && y_active<222) ? {2'b0,main_line[5:4]}:
                          (y_active>=223 && y_active<235) ? 4'd5:4'd6;
 wire [8:0] row_origin=physical_row==5 ? 9'd73:physical_row==6 ? 9'd17:9'd16;
 wire [8:0] row_end=physical_row==5 ? 9'd279:physical_row==6 ? 9'd367:
                    physical_row==0 ? 9'd320:physical_row==1 ? 9'd327:physical_row==2 ? 9'd331:9'd334;
 wire [8:0] cell_pitch=layout_pitch(physical_row,grid_col);
 always @(posedge clk) if(!pause) begin
  active_d<=active;vsync_d<=vsync;
  if(!active) begin x_transport<=0;grid_col<=0;grid_pixel<=0;end
  else begin
   x_transport<=x_transport+1'b1;
   // One update per four-sample VIC pixel; only simple counters are critical.
   if(x_transport[1:0]==3) begin
    if(pixel_x>=row_origin && pixel_x<row_end) begin
     if(grid_pixel==cell_pitch-1'b1) begin grid_pixel<=0;grid_col<=grid_col+1'b1;end
     else grid_pixel<=grid_pixel+1'b1;
    end else begin grid_col<=0;grid_pixel<=0;end
   end
  end
  if(vsync && !vsync_d) begin y_active<=0;grid_col<=0;grid_pixel<=0;end
  else if(active_d && !active) begin
   y_active<=y_active+1'b1;
  end
 end
 localparam [23:0] PANEL=24'hc8bfa5,EDGE=24'h8b8068,CREAM=24'hf3ead0,
  CAP=24'h4b4037,CAP_ALT=24'h7b6b58,CAP_EDGE=24'h9b8a70,
  SELECTED=24'hd8c999,LATCHED=24'hc9904f,INK=24'h3b3028,CASE_INK=24'h514637;
 function automatic [7:0] blend_channel(input [7:0] foreground,background,input [1:0] mode);
  reg [9:0] sum;
  begin
   case(mode)
    1:begin sum=({2'b0,foreground}<<1)+{2'b0,foreground}+{2'b0,background};blend_channel=sum[9:2];end
    2:begin sum={2'b0,foreground}+{2'b0,background};blend_channel=sum[8:1];end
    default:blend_channel=foreground;
   endcase
  end
 endfunction
 reg [47:0] label_text;
 reg [34:0] bitmap;
 reg [7:0] character;
 reg [6:0] key_id;
 reg key_selected,key_sticky,key_held,ink_pixel;
 reg [8:0] x,y,text_x,lx,key_width,text_left;
 reg [3:0] col,row,text_y;
 reg [5:0] character_column;
 reg [4:0] ly;
 reg [2:0] glyph_column,glyph_row,length;
 reg [5:0] bitmap_index;
 reg [4:0] key_height;
 reg key_region,stacked_label;
 reg [255:0] banner;
 reg [339:0] engraving_bits;
 reg [1:0] engraving_pixel;
 reg [7:0] engraving_x;
 reg [2:0] engraving_y;
 reg surface_pixel,opaque_ink,title_ink;
 always @* begin
  mixed_rgb=rgb;
  x=pixel_x;y=y_active;col=0;row=0;lx=0;ly=0;key_id=127;key_width=0;key_height=0;key_region=0;stacked_label=0;
  label_text=0;bitmap=0;character=0;key_selected=0;key_sticky=0;key_held=0;
  ink_pixel=0;text_x=0;text_y=0;character_column=0;glyph_column=0;glyph_row=0;length=0;banner=0;text_left=0;bitmap_index=0;
  engraving_bits=0;engraving_pixel=0;engraving_x=0;engraving_y=0;surface_pixel=0;opaque_ink=0;title_ink=0;
  if(visible && active && x>=8 && x<374 && y>=140 && y<270) begin
   surface_pixel=1;
   mixed_rgb=PANEL;
   if(x==8 || y==140) mixed_rgb=24'he9dfc3;
   if(x==373 || y==269) mixed_rgb=EDGE;
   // A classic badge and restrained rainbow on the moulded beige case.
   if(x>=16 && x<120 && y>=144 && y<154) mixed_rgb=24'h41372f;
   if(y>=146 && y<153 && x>=35 && x<150) begin
    banner="COMMODORE 64                    ";text_x=x-9'd35;text_y=y-9'd146;ink_pixel=1;title_ink=1;
   end else if(y>=146 && y<153 && x>=190 && x<370) begin
    banner=macro_busy ? "TYPING... B CANCEL              ":"A KEY X HOLD Y CLEAR B CLOSE    ";text_x=x-9'd190;text_y=y-9'd146;ink_pixel=1;
   end
   if(ink_pixel) begin
    character_column=text_x/9'd6;glyph_column=text_x%9'd6;glyph_row=text_y[2:0];
    character=banner[8'd255-{character_column[4:0],3'b0} -:8];bitmap=glyph(character);
    bitmap_index=6'd34-({3'b0,glyph_row}*6'd5)-{3'b0,glyph_column};
    if(glyph_column<5 && bitmap[bitmap_index]) begin mixed_rgb=title_ink ? CREAM:CASE_INK;opaque_ink=1;end
   end
   if(x>=18 && x<30 && y>=146 && y<152) begin
    if(x<21) mixed_rgb=24'hbc493b;
    else if(x<24) mixed_rgb=24'he0ab4e;
    else if(x<27) mixed_rgb=24'h649576;
    else mixed_rgb=24'h557eaa;
    opaque_ink=1;
   end
   if(y>=158 && y<222) begin
    ly={1'b0,main_line[3:0]};key_height=14;
    if(x>=16 && x<row_end) begin
     row=physical_row;col=grid_col;lx=grid_pixel;key_width=cell_pitch-2;key_region=1;
    end else if(x>=338 && x<366) begin
     row=4;col={2'b0,main_line[5:4]};lx=x-9'd338;key_width=28;key_region=1;
    end
   end else if(y>=223 && y<235 && x>=73 && x<279) begin
    row=5;col=0;lx=x-9'd73;ly=y-9'd223;key_width=206;key_height=12;key_region=1;
   end else if(y>=223 && y<235 && x>=286 && x<366) begin
    row=5;col=1;lx=x-9'd286;ly=y-9'd223;key_width=80;key_height=12;key_region=1;
   end else if(y>=239 && y<251 && x>=17 && x<367) begin
    row=6;col=grid_col;lx=grid_pixel;ly=y-9'd239;key_width=33;key_height=12;key_region=1;
   end
   if(key_region) begin
    key_id=layout_key(row,col);
    if(key_id!=127) begin
     key_selected=row==selected_row && col==selected_col;
     key_sticky=key_mask(key_id)!=0 && (key_mask(key_id)&sticky)==key_mask(key_id);
     key_held=key_mask(key_id)!=0 && (key_mask(key_id)&held)==key_mask(key_id);
     if(lx<key_width && ly<key_height) begin
      mixed_rgb=key_selected ? SELECTED:(key_sticky ? LATCHED:((key_id<10 || key_id>=60) ? CAP_ALT:CAP));
      opaque_ink=key_selected || key_sticky;
      if(ly==key_height-1'b1) mixed_rgb=24'h2f2721;
      if(lx==0 || lx==key_width-1'b1 || ly==0) mixed_rgb=key_selected ? 24'hfff4cc:CAP_EDGE;
      if(key_held && ly==key_height-2 && lx>=3 && lx<key_width-3) begin mixed_rgb=SELECTED;opaque_ink=1;end
      label_text=key_label(key_id);length=key_length(key_id);
      if(key_id==76)begin
       label_text=transparency==1 ? "TR 25%":transparency==2 ? "TR 50%":"TR OFF";
       length=6;
      end
      stacked_label=key_width<24 && length>3;
      text_left=stacked_label ? (key_width-12)>>1:(key_width-({6'b0,length}*9'd6)+1)>>1;
      text_x=lx-text_left;
      text_y=stacked_label ? (ly>=8 ? ly-8:ly-1):ly-((key_height-7)>>1);
      if(lx>=text_left && text_x<(stacked_label ? 9'd12:({6'b0,length}*9'd6)) &&
         (stacked_label ? ((ly>=1 && ly<6)||(ly>=8 && ly<13)):
          (ly>=((key_height-7)>>1) && ly<((key_height-7)>>1)+7))) begin
       character_column=text_x/9'd6;glyph_column=text_x%9'd6;glyph_row=text_y[2:0];
       if(stacked_label) begin
        if(ly>=8) character_column=character_column+2;
        case(text_y) 0:glyph_row=0;1:glyph_row=1;2:glyph_row=3;3:glyph_row=5;default:glyph_row=6;endcase
       end
       character=label_text[6'd47-{character_column[2:0],3'b0} -:8];bitmap=glyph(character);
       bitmap_index=6'd34-({3'b0,glyph_row}*6'd5)-{3'b0,glyph_column};
       if(glyph_column<5 && bitmap[bitmap_index]) begin
        mixed_rgb=(key_selected || key_sticky) ? INK:CREAM;opaque_ink=1;
       end
      end
     end
    end
   end
   if(y==155 && x>=17 && x<365) mixed_rgb=EDGE;
   // Original 4x6 mixed-case artwork, with a one-pixel recessed bevel.
   if(x>=106 && x<276 && y>=260 && y<267) begin
    engraving_x=x-9'd106;engraving_y=y-9'd260;
    engraving_bits=engraving_row(engraving_y);
    engraving_pixel=engraving_bits[9'd339-{engraving_x,1'b0} -:2];
    if(engraving_pixel!=0) begin
     mixed_rgb=engraving_pixel==1 ? 24'h8a795f:24'heee2c3;opaque_ink=1;
    end
   end
  end
  if(surface_pixel && !opaque_ink) begin
   mixed_rgb={blend_channel(mixed_rgb[23:16],rgb[23:16],transparency),
              blend_channel(mixed_rgb[15:8],rgb[15:8],transparency),
              blend_channel(mixed_rgb[7:0],rgb[7:0],transparency)};
  end
 end
endmodule

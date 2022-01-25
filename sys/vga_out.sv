/* Mike Simone 
Attempt to generate a YC source for S-Video and Composite

Y	0.299R' + 0.587G' + 0.114B'
U	0.492(B' - Y) = 504 (X 1024)
V	0.877(R' - Y) = 898 (X 1024)

 C = U * Sin(wt) + V * Cos(wt) ( sin / cos generated in 2 LUTs)

Chroma out requires a 1uF capacitor to lower the DC offset back to 0.

*/


module vga_out
(
	input         clk,
	input         clk50,		// Used to generate NTSC signal
	input         ypbpr_en,

	input         hsync,
	input         vsync,
	input         csync,

	input  [23:0] din,
	output [23:0] dout,

	output reg    hsync_o,
	output reg    vsync_o,
	output reg    csync_o
);


wire [7:0] red   = din[23:16];
wire [7:0] green = din[15:8];
wire [7:0] blue  = din[7:0];

reg [23:0] din1, din2;
reg [18:0] y_r, u_r, v_r;
reg [18:0] y_g, u_g, v_g;
reg [18:0] y_b, u_b, v_b;
(* preserve_for_debug *) reg signed [19:0] by, ry;
(* preserve_for_debug *) reg signed [19:0] u, v, c; 
(* preserve_for_debug *) reg signed [19:0] u_sin, v_cos, u_sin2, v_cos2;
(* preserve_for_debug *) reg signed [28:0] csin, ccos;
(* preserve_for_debug *) reg [18:0] y;
(* preserve_for_debug *) reg [7:0] Y, U, V, C;
reg [23:0] rgb; 
reg hsync2, vsync2, csync2;
reg hsync1, vsync1, csync1;

reg[8:0]  cburst_phase;    // colorburst counter 
reg signed [7:0]  vref = 'sd100;		// Voltage reference point (Used for Chroma)
reg[3:0]  chroma_LUT_count;     // colorburst counter

wire signed [9:0] chroma_sin_LUT[14] = '{
	10'b0000000100, 10'b0001110011, 10'b0011001011, 10'b0011111011, 
	10'b0011111000, 10'b0011000101, 10'b0001101010, 10'b1111111011, 
	10'b1110001100, 10'b1100110100, 10'b1100000101, 10'b1100001000, 
	10'b1100111100, 10'b1110010111
};

wire signed [9:0] chroma_cos_LUT[14] = '{
	10'b0100000000, 10'b0011100101, 10'b0010011100, 10'b0000110101, 
	10'b1111000010, 10'b1101011101, 10'b1100010111, 10'b1100000001, 
	10'b1100011100, 10'b1101100101, 10'b1111001101, 10'b0000111111, 
	10'b0010100101, 10'b0011101010
};

wire signed [9:0] colorburst_LUT[14] = '{
	10'b1100110001, 10'b1100000100, 10'b1100001001, 10'b1101000000, 
	10'b1110011101, 10'b0000001101, 10'b0001111011, 10'b0011010000, 
	10'b0011111100, 10'b0011110110, 10'b0010111111, 10'b0001100010, 
	10'b1111110001, 10'b1110000011
};


always_ff @(posedge clk50) 
begin


	// Calculate for U, V

	by <= $signed($signed({12'b0 ,(blue)}) - $signed({12'b0 ,y[17:10]}));
	ry <= $signed($signed({12'b0 ,(red)}) - $signed({12'b0 ,y[17:10]}));

	// Bit Shift Multiple by u = by * 1024 x 0.492 = 504, v = ry * 1024 x 0.877 = 898

	u <= $signed({by, 8'd0}) +  $signed({by, 7'd0}) + $signed({by, 6'd0})  + $signed({by, 5'd0}) + $signed({by, 4'd0})  + $signed({by, 3'd0}) ; 									
	v <= $signed({ry, 9'd0}) +  $signed({ry, 8'd0}) + $signed({ry, 7'd0})  + $signed({ry, 1'd0})   ;
	
	if (hsync) 
		begin
			cburst_phase <= 'd0; 	// Reset Colorburst counter during sync
			chroma_LUT_count <= 'd0; 	// Reset LUT counter during sync
			ccos <= 20'b0;	// Reset cos LUT value during sync
			csin <= 20'b0;  // Reset sin LUT value during sync
			C <= vref;
		end
	else 
		begin // Generate Colorburst for 9 cycles 
			if (cburst_phase >= 'd45 && cburst_phase <= 'd175) // Start the color burst signal at 45 samples or 0.9 us
				begin	// COLORBURST SIGNAL GENERATION (9 CYCLES ONLY or between count 45 - 175)
					csin <= $signed({colorburst_LUT[chroma_LUT_count],5'd0});
					ccos <= 29'b0;
				end
			else if (cburst_phase > 'd175) // Modulate U, V for chroma using a LUT for sin / cos
				begin  

					csin <= $signed(u>>>10) * $signed(chroma_sin_LUT[chroma_LUT_count]);
					ccos <= $signed(v>>>10) * $signed(chroma_cos_LUT[chroma_LUT_count]);

					end

			// Turn u * sin(wt) and v * cos(wt) into signed numbers
			u_sin <= $signed(csin[19:0]);
			v_cos <= $signed(ccos[19:0]);

			// Divide to to the correct amplitudes needed for chroma out.
			u_sin2 <= (u_sin>>>8);
			v_cos2 <= (v_cos>>>8);

			// Stop the colorburst timer as its only needed for the initial pulse
			if (cburst_phase <= 'd300)
				begin
					cburst_phase <= cburst_phase + 8'd1;
				end
			// Chroma sin / cos LUT counter (0-14 then reset back to 0)
			chroma_LUT_count <=chroma_LUT_count + 4'd1; 
			if (chroma_LUT_count == 4'd13)
				begin
					chroma_LUT_count <= 4'd0;
				end

			// Generate chorma
			c <= vref + u_sin2 + v_cos2;

		end

	// Set Chroma output
	C <= c[7:0];
end


always @(posedge clk) begin

	y_r <= {red, 8'd0} + {red, 5'd0}+ {red, 4'd0} + {red, 1'd0} ;
    y_g <= {green, 9'd0} + {green, 6'd0} + {green, 4'd0} + {green, 3'd0} + green;
	y_b <= {blue, 6'd0} + {blue, 5'd0} + {blue, 4'd0} + {blue, 2'd0} + blue;
	y <= y_r + y_g + y_b;

	
	Y <= y[17:10];
	V <= v[17:10];

		hsync_o <= hsync2; hsync2 <= hsync1; hsync1 <= hsync;
		vsync_o <= vsync2; vsync2 <= vsync1; vsync1 <= vsync;
		csync_o <= csync2; csync2 <= csync1; csync1 <= csync;

		rgb <= din2; din2 <= din1; din1 <= din;
end

assign dout = ypbpr_en ? {C, Y, V} : rgb;

endmodule

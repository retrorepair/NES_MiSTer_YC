/* Mike Simone 
Attempt to generate a YC source for S-Video and Composite

Y	0.299R' + 0.587G' + 0.114B'
U	0.492(B' - Y) = 504 (X 1024)
V	0.877(R' - Y) = 898 (X 1024)

 C = U * Sin(wt) + V * Cos(wt) ( sin / cos generated in 2 LUTs)

 A third LUT was created for the colorburst carrier wave or sin(wt ~ 180 degrees)

YPbPr is requred in the MiSTer ini file
A AC coupling 0.1uF capacitor was used on the Chroma output, but may not be required.

This is only a concept right now and there is still a lot of work to see how well this 
can be applied to more applications or even how the existing issues can be cleaned up.

*/


module vga_out
(
	input         clk,
	input         clk_50,		// Used to generate NTSC signal
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

reg [8:0]  cburst_phase;    // colorburst counter 
reg [7:0]  vref = 'd128;		// Voltage reference point (Used for Chroma)
reg [4:0]  chroma_LUT_count = 'd0;     // colorburst counter

/*
THe following LUT tables were calculated in Google Sheets with the following
Sampling rate = 14 * 3.579545 or 50,113,560 Hz
w = =2 * PI * (3.579545*10^6)
t = 1/sampling rate

Where: 
chroma_sin_LUT = sin(wt)
chroma_cos_LUT = cos(wt)
colorburst_LUT = sin(wt + 160.2)    or roughly 180 degrees out of phase from sin(wt)

*/


wire signed [10:0] chroma_sin_LUT[14] = '{
	11'b00000000000, 11'b00001101111, 11'b00011001000, 11'b00011111010,	11'b00011111010,
	11'b00011001000, 11'b00001101111, 11'b00000000000, 11'b11110010001, 11'b11100111000,
	11'b11100000110, 11'b11100000110, 11'b11100111000, 11'b11110010001
};


wire signed [10:0] chroma_cos_LUT[14] = '{
	11'b00100000000, 11'b00011100111, 11'b00010100000, 11'b00000111001, 11'b11111000111,
	11'b11101100000, 11'b11100011001, 11'b11100000000, 11'b11100011001, 11'b11101100000,
	11'b11111000111, 11'b00000111001, 11'b00010100000, 11'b00011100111
};
wire signed [10:0] colorburst_LUT[14] = '{
	11'b00000000101, 11'b11110010110, 11'b11100111011, 11'b11100001000, 11'b11100000101,
	11'b11100110101, 11'b11110001100, 11'b11111111011, 11'b00001101010, 11'b00011000101,
	11'b00011111000, 11'b00011111011, 11'b00011001011, 11'b00001110100
};

always_ff @(posedge clk_50) 
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
			//chroma_LUT_count <= 'd0; 	// Reset LUT counter during sync
			ccos <= 20'b0;	// Reset cos LUT value during sync
			csin <= 20'b0;  // Reset sin LUT value during sync
			c <= vref;
		end
	else 
		begin // Generate Colorburst for 9 cycles 
			if (cburst_phase >= 'd20 && cburst_phase <= 'd155) // Start the color burst signal at 45 samples or 0.9 us
				begin	// COLORBURST SIGNAL GENERATION (9 CYCLES ONLY or between count 45 - 175)
					csin <= $signed({colorburst_LUT[chroma_LUT_count],5'd0});
					ccos <= 29'b0;

					// Turn u * sin(wt) and v * cos(wt) into signed numbers
					u_sin <= $signed(csin[19:0]);
					v_cos <= $signed(ccos[19:0]);

					// Division to scale down the results to fit 8 bit.. signed numbers had to be handled a bit different. 
					// There are probably better methods here. but the standard >>> didnt work for multiple shifts.
					if (u_sin >= 0)
						begin
							u_sin2 <= u_sin[19:8]+ u_sin[19:9] ;      
						end
					else
						begin
							u_sin2 <= $signed(~(~u_sin[19:8])) + $signed(~(~u_sin[19:9]));
						end
					v_cos2 <= (v_cos>>>8);
				end
			else if (cburst_phase > 'd155) // Modulate U, V for chroma using a LUT for sin / cos
				begin  

					csin <= $signed(u>>>10) * $signed(chroma_sin_LUT[chroma_LUT_count]);
					ccos <= $signed(v>>>10) * $signed(chroma_cos_LUT[chroma_LUT_count]);

					// Turn u * sin(wt) and v * cos(wt) into signed numbers
					u_sin <= $signed(csin[19:0]);
					v_cos <= $signed(ccos[19:0]);

					// Divide U*sin(wt) and V*cos(wt) to fit results to 8 bit
					if (u_sin >= 0)
						begin
							u_sin2 <= u_sin[19:8]+ u_sin[19:9] + u_sin[19:11];       
						end
					else
						begin
							u_sin2 <= $signed(~(~u_sin[19:8])) + $signed(~(~u_sin[19:9]))+ $signed(~(~u_sin[19:11]));
						end
					if (v_cos >=0)
						begin
							v_cos2 <= v_cos[19:8] + v_cos[19:9]+ v_cos[19:11];
						end
					else
						begin
							v_cos2 <= $signed(~(~v_cos[19:8])) + $signed(~(~v_cos[19:9])) + $signed(~(~v_cos[19:11]));
						end
					end

			// Stop the colorburst timer as its only needed for the initial pulse
			if (cburst_phase <= 'd300)
				begin
					cburst_phase <= cburst_phase + 8'd1;
				end
			// Chroma sin / cos LUT counter (0-14 then reset back to 0)


			// Generate chorma
			c <= $signed(vref) + u_sin2 + v_cos2;

		end
		chroma_LUT_count <=chroma_LUT_count + 5'd1; 
		if (chroma_LUT_count == 5'd13)
			begin
				chroma_LUT_count <= 5'd0;
			end
	// Set Chroma output
	C <= c[7:0];
end


always @(posedge clk) begin

	// YUV standard for luma added
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

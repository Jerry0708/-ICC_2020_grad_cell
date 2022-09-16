module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output reg match;
output reg [4:0] match_index;
output reg valid;

//---def param---
parameter FAIL = 11;
parameter SUCCESS = 12;

//---def fsm reg---
reg [4:0]cur_state;
reg [4:0]next_state;

//---def reg---
integer i;
reg [7:0]str_r[0:31];
reg [7:0]pat_r[0:7];
reg sel[0:1];
reg [5:0]strlen;
reg [3:0]patlen;

reg [4:0]str_space[0:5];
reg [2:0]cnt_space;

reg [3:0]sel_state;
reg [4:0]a;
reg [2:0]b;
reg [4:0]addr;
reg [4:0]index;
reg [4:0]space_f[0:5];
reg [4:0]space_b[0:5];

reg [5:0]check_a;
reg [2:0]check_b;
reg [4:0]check_cnta;
reg [3:0]check_cntb;

//---FSM---
always@(posedge clk or posedge reset) begin
	if(reset)	cur_state <= 0;
	else 		cur_state <= next_state;
end

//---state transfer
always@(*) begin
	case(cur_state)
		0:
		begin
			if(ispattern && !isstring) 	next_state = 1;
			if(!ispattern && !isstring) next_state = 2;
			else 					   	next_state = 0;
		end
		1:
		begin
			if(!ispattern && !isstring) next_state = 2;
			else 			   		   	next_state = 1;
		end
		2:
		begin
			next_state = 3;
		end
		3:
		begin
			if(sel_state==FAIL)			next_state = 4;
			else if(sel_state==SUCCESS) next_state = 4;
			else 						next_state = 3; 
		end
		4:
		begin
			next_state = 0;
		end
	endcase
end

always@(posedge clk or posedge reset) begin
	if(reset) begin
		sel_state <= 4'd0;
		a <= 5'd0;
		b <= 3'd1;
		addr <= 5'd0;
		index <= 5'd0;
		for(i=0; i<=3'd5; i=i+1) space_f[i] <= 5'd0;
		for(i=0; i<=3'd5; i=i+1) space_b[i] <= 5'd0;
		check_a <= 6'd0;
		check_b <= 3'd0;
		check_cnta <= 5'd0;
		check_cntb <= 4'd0;
	end
	else begin
		if(cur_state==3) begin
			case(sel_state)
				0:
				begin
					for(i=0; i<=3'd5; i=i+1) begin
						if(i==0)	space_f[i] <= 0;
						else 		space_f[i] <= str_space[i-1]+1;
							
						if(i==cnt_space)	space_b[i] <= strlen-1;
						else 				space_b[i] <= str_space[i]-1;
					end
					
					case({sel[1],sel[0]})
						2'b00:	
						begin
							a <= 0;
							b <= 1;
							sel_state <= 1;
						end
						2'b01: //^
						begin
							a <= 0;
							b <= 2;
							sel_state <= 3;
						end
						2'b10: //$
						begin
							a <= 0;
							b <= 2;
							sel_state <= 5;
						end
						2'b11:
						begin
							a <= 0;
							b <= 2;
							sel_state <= 7;
						end
					endcase
				end
				1:	//00
				begin
					a <= a + 1'b1;
					b <= 1;
					if(a < strlen) begin
						if(str_r[a]==pat_r[0]) 		sel_state <= 2;
						else if(pat_r[0]==8'h2E) 	sel_state <= 2;
						else if(pat_r[0]==8'h2A) begin
							sel_state <= 9;
							check_a <= a;	
							check_b <= b+1;	
						end
						else 				   		sel_state <= 1;
					end
					else begin
						sel_state <= FAIL;
						index <= 0;
					end
				end
				2:
				begin
					b <= b + 1'b1;
					if(b < patlen) begin
						if(pat_r[b]==8'h2E && (b==patlen-1)) begin
							sel_state <= SUCCESS;
							index <= a-1;
						end
						else if((str_r[a+b-1]==pat_r[b]) && (b==patlen-1)) begin
							sel_state <= SUCCESS;
							index <= a-1;
						end
						else if(pat_r[b]==8'h2E)		sel_state <= 2;
						else if(str_r[a+b-1]==pat_r[b])	sel_state <= 2;
						else if(pat_r[b]==8'h2A) begin	
							sel_state <= 9;
							check_a <= a;	
							check_b <= b+1;	
						end
						else							sel_state <= 1;
					end
					else if(patlen==1) begin
						sel_state <= SUCCESS;
						index <= a-1;
					end
					else begin
						sel_state <= 1;
					end
				end
				3:	//01
				begin
					a <= a + 1'b1;
					b <= 2;
					addr <= space_f[a]+b-1;
					if(a <= cnt_space) begin
						if(str_r[space_f[a]]==pat_r[1]) sel_state <= 4;
						else if(pat_r[1]==8'h2E)		sel_state <= 4;
						else 							sel_state <= 3;
					end
					else begin
						sel_state <= FAIL;
						index <= 0;
					end
				end
				4:
				begin
					b <= b + 1'b1;
					addr <= addr + 1'b1;
					if(b < patlen) begin
						if(pat_r[b]==8'h2E && (b==patlen-1)) begin
							sel_state <= SUCCESS;
							index <= space_f[a-1];
						end
						else if(pat_r[b]==8'h2E) begin
							sel_state <= 4;
						end
						else if((str_r[addr]==pat_r[b]) && (b==patlen-1)) begin
							sel_state <= SUCCESS;
							index <= space_f[a-1];
						end
						else if(str_r[addr]==pat_r[b])	sel_state <= 4;
						else							sel_state <= 3;
					end
					else begin		
						sel_state <= 3;
					end
				end
				5:	
				begin
					a <= a + 1'b1;
					b <= 3;
					addr <= space_b[a]-1;	
					
					if(a <= cnt_space) begin
						if(str_r[space_b[a]]==pat_r[patlen-2]) sel_state <= 6;
						else if(pat_r[patlen-2]==8'h2E)		   sel_state <= 6;	
						else 		   						   sel_state <= 5;
					end
					else begin
						sel_state <= FAIL;
						index <= 0;
					end
				end
				6:
				begin
					b <= b + 1'b1;
					addr <= addr - 1'b1;
					
					if(b <= patlen) begin
						if(pat_r[patlen-b]==8'h2E && (b==patlen)) begin
							sel_state <= SUCCESS;
							index <= addr;
						end
						else if(pat_r[patlen-b]==8'h2E) 
							sel_state <= 6;
						else if((str_r[addr]==pat_r[patlen-b]) && (b==patlen)) begin
							sel_state <= SUCCESS;
							index <= addr;
						end
						else if(pat_r[patlen-b]==8'h2A) begin
							sel_state <= SUCCESS;
							index <= 17;
						end
						else if(str_r[addr]==pat_r[patlen-b])	sel_state <= 6;
						else									sel_state <= 5;
					end
					else begin
						sel_state <= 5;
					end
					
				end
				7:
				begin
					a <= a + 1'b1;
					b <= 2;
					addr <= space_f[a]+1;
					if(a <= cnt_space) begin
						if(str_r[space_f[a]]==pat_r[1]) sel_state <= 8;
						else if(pat_r[1]==8'h2E) 		sel_state <= 8;
						else 							sel_state <= 7;
					end
					else begin
						sel_state <= FAIL;
						index <= 0;
					end
				end
				8:
				begin
					b <= b + 1'b1;
					addr <= addr + 1'b1;
					
					if(pat_r[b]==8'h24 && str_r[addr]==8'h20) begin
						sel_state <= SUCCESS;
						index <= space_f[a-1];
					end
					else if(b < patlen) begin
						if(pat_r[b]==8'h2E) 			sel_state <= 8;
						else if(str_r[addr]==pat_r[b])	sel_state <= 8;
						else							sel_state <= 7;
					end
					else begin
						sel_state <= 7;
					end
				end
				9:
				begin
					if(check_a < strlen) begin
						check_a <= check_a + 1'b1;
						
						if(str_r[check_a] != pat_r[check_b]) begin
							sel_state <= 9;
						end
						else if(str_r[check_a]==pat_r[check_b] && check_b==patlen-1) begin
							sel_state <= SUCCESS;
							index <= a-1;
						end
						else begin
							sel_state <= 10;
							check_cnta <= check_a+1;
							check_cntb <= check_b+1;
						end
					end 
					else begin
						sel_state <= FAIL;
						index <= 0;
					end
				end
				10:
				begin
					if(check_cntb < patlen) begin
						check_cnta <= check_cnta + 1'b1;
						check_cntb <= check_cntb + 1'b1;
						
						if(str_r[check_cnta]==pat_r[check_cntb] && check_cntb==patlen-1) begin
							sel_state <= SUCCESS;
							index <= a-1;
						end
						else if(str_r[check_cnta] == pat_r[check_cntb])
							sel_state <= 10;
						else 
							sel_state <= 9;
					end
					else begin
						sel_state <= 9;
					end
				end
				FAIL:
				begin
					a <= 0;
					sel_state <= 0;
				end
				SUCCESS:
				begin 
					a <= 0;
					sel_state <= 0;
				end
			endcase
		end
	end
end


//---read data---
always@(posedge clk or posedge reset) begin
	if(reset) begin
		strlen <= 6'd0;
		patlen <= 4'd0;
		cnt_space <= 3'd0;
		sel[0] <= 1'd0; 
		sel[1] <= 1'd0;
		match <= 1'd0;
		match_index <= 5'd0;
		valid <= 1'd0;
		for(i=0; i<=3'd5; i=i+1) 	str_space[i] <= 5'd0;
		for(i=0; i<=5'd31; i=i+1) 	str_r[i] <= 8'd0;
		for(i=0; i<=3'd7; i=i+1) 	pat_r[i] <= 8'd0;
	end
	else begin
		case(cur_state)
			0,1:
			begin
				case({ispattern,isstring})
					2'b01:
					begin
						strlen <= strlen + 1'b1;
						str_r[strlen] <= chardata; 
						if(chardata==8'h20) begin
							cnt_space <= cnt_space + 1'b1;
							str_space[cnt_space] <= strlen;
						end
					end
					2'b10:
					begin
						patlen <= patlen + 1'b1;
						pat_r[patlen] <= chardata;
					end
				endcase
			end
			2:
			begin	//5E ^ , 24 $	
				if(pat_r[0]==8'h5E) 		sel[0] <= 1;
				else 						sel[0] <= 0;
				if(pat_r[patlen-1]==8'h24)  sel[1] <= 1;
				else 						sel[1] <= 0;
			end
			3:		//output signal
			begin
				if(sel_state==FAIL) begin
					match <= 0;
					valid <= 1;
					match_index <= 0;
				end
				else if(sel_state==SUCCESS) begin
					match <= 1;
					valid <= 1;
					match_index <= index;
				end
			end
			4:
			begin
				valid <= 0;
				case({ispattern,isstring})
					2'b01:
					begin
						cnt_space <= 0;
						strlen <= 1;
						patlen <= 0;
						str_r[0] <= chardata; 
					end
					2'b10:
					begin
						patlen <= 1;
						pat_r[0] <= chardata;
					end
				endcase
			end
		endcase
	end
end
endmodule

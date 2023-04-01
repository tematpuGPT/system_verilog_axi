


// ���� ���� �������� ������ datamover_in_2, ������� ��������� ������ � ������ �� ���� AXI stream ������ � ���������� �� � AXI memory mapped ����. 
// ������ ���������� �������� ������� ��� ���������� ����������� ������ � ������. 
// ������ ����� ��������� ������� tlast � tkeep ��� ����������� ����� �������� � �������������� ����� ������. 
// ������ �� �������� ������ � ������������ � tkeep, � ���������� ��� ��� ����� ��� �������� �������������� ������. 
// ������ ��� �������� �� ������ � ��������� � ������� ���-���� Bing.

module datamover_in_2
#(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)
(
  input clk,
  input rst_n,

  // AXI Stream input port
  input [DATA_WIDTH-1:0] axi_stream_in_tdata,
  input axi_stream_in_tvalid,
  output axi_stream_in_tready,
  input axi_stream_in_tlast,
  input [DATA_WIDTH/8-1:0] axi_stream_in_tkeep,

  // AXI Stream address port
  input [ADDR_WIDTH-1:0] axi_stream_addr_tdata,
  input axi_stream_addr_tvalid,
  output axi_stream_addr_tready,

  // AXI Memory Mapped output port
  output reg [ADDR_WIDTH-1:0] m_awaddr,
  output reg[7:0] m_awlen,
  output reg[2:0] m_awsize,
  output reg m_awvalid,
  input m_awready,

  output reg[DATA_WIDTH-1:0] m_wdata,
  output reg[DATA_WIDTH/8-1:0] m_wstrb,
  output reg m_wvalid,
  input m_wready

);



// Internal signals
logic [DATA_WIDTH-1:0] data;
logic [DATA_WIDTH/8-1:0] tkeep;
logic [ADDR_WIDTH-1:0] addr;
logic s_tready;
logic s_aready;

// State machine
typedef enum logic [2:0] {IDLE, READ, WAIT_READ, WRITE, WAIT} state_t;
state_t state;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    s_tready <= 'b0;
    s_aready <= 'b0;
    data <= 'b0;
    tkeep <= 'b0;
    addr <= 'b0;
    m_awaddr <= 'b0;
    m_awlen <= 'b0;
    m_awsize <= 'b0;
    m_awvalid <= 'b0;
    m_wdata <= 'b0;
    m_wstrb <= 'b0;
    m_wvalid <= 'b0;
  end else begin
    case (state)
      IDLE: begin
        s_tready = 'b0;
        s_aready = 'b1;
        if (axi_stream_addr_tvalid && axi_stream_addr_tready) begin
          addr <= axi_stream_addr_tdata;
          state <= READ;
        end else begin
          state <= IDLE;
        end
      end

      READ: begin
        if (axi_stream_in_tvalid) begin
          s_tready = 'b1;
          data <= axi_stream_in_tdata;
          tkeep <= axi_stream_in_tkeep;
          if (axi_stream_in_tlast) begin
            state <= WRITE;
          end else begin
            state <= WAIT_READ;
          end
        end else begin
          s_tready = 'b0;
        end
      end
	  
	  READ: 
	  begin 
		  if (axi_stream_in_tvalid) 
				begin 
					s_tready = 'b1; 
					data <= axi_stream_in_tdata; 
					tkeep <= axi_stream_in_tkeep; 
					state <= WRITE; // ��������� � ��������� WRITE ��� ������ ����� 
				end 
				else 
				begin 
					state <= WAIT_READ; 
				end 
	        
	  end
	  

      WAIT_READ: begin
        s_tready = 'b0;
        if (m_awready && m_wready) begin
          state <= READ;
        end else begin
          state <= WAIT_READ;
        end
      end

      // WRITE: begin
        // s_aready = 'b0;
        // m_awaddr = addr + DATA_WIDTH/8 - tkeep[$clog2(DATA_WIDTH/8)-1:0];
        // m_awlen = tkeep[$clog2(DATA_WIDTH/8)-1:0];
        // //m_awsize = $clog2(DATA_WIDTH/8);
		// m_awsize = int�(floor(log2(real�(DATA_WIDTH/8))));
		
        // m_awvalid = 'b1;

		// m_wdata = data; 
		// m_wstrb = tkeep;
		
		
		// m_wstrb = tkeep;
        // m_wvalid = 'b1;

        // if (m_awready && m_wready) begin
          // state <= WAIT;
        // end else begin
          // state <= WRITE;
        // end

      // end
	  
	  WRITE: 
	  begin 
		  s_aready = 0; 
		  s_tready = 0;
		  m_awaddr = addr + DATA_WIDTH/8 - tkeep[$clog2(DATA_WIDTH/8)-1:0]; 
		  //m_awlen = tkeep[$clog2(DATA_WIDTH/8)-1:0]; 
		  m_awlen = tkeep[$clog2(DATA_WIDTH/8)-1:0];
		  //m_awsize = int(floor($clog2(real(DATA_WIDTH/8)))); 
		  m_awsize = $clog2(DATA_WIDTH/8);
		  m_awvalid = 'b1;
		  m_wdata = data; m_wstrb = tkeep; m_wvalid = 'b1;
		  if (m_awready && m_wready) 
		  begin 
			  if (axi_stream_in_tlast) 
			  begin // ���� ��� ��������� �����, �� ��������� � ��������� WAIT 
				state <= WAIT; 
			  end 
			  else 
			  begin // ����� ��������� � ��������� READ ��� ���������� ����� 
				state <= READ; 
			  end 
			  
			end 
			  else 
			  begin 
				state <= WRITE; 
			  end
		
    end
	  
	  

      WAIT: 
	  begin
        s_aready = 'b1;

		   if (axi_stream_addr_tvalid && axi_stream_addr_tready) 
		   begin
			addr <= axi_stream_addr_tdata;
		   state <= READ;
		   end 
		   else 
		   begin
				  state <= WAIT;
			end
		end	
		endcase
end
end

// Assign output ports
assign axi_stream_in_tready = s_tready;
assign axi_stream_addr_tready = s_aready;

endmodule
// Это ip ядро на System Verilog. Входной порт axi steam для пакетов длиной 16 - 1600 байт с сигналом tkeep.
// Ширина данных задается параметром для ядра. пакеты приходящие в этот порт должны сохраняться в память через мастер порт AXI memory mapped c поддержкой Burst. 
//Адрес для сохранения пакета должен получаться через еще один входной порт AXI stream. 
//Где в каждом приходящем слове лежит адрес для сохранения пакетов. Если новых адресов в порте нет, то и первый axi stream порт должен переходить в состояние "не готов"


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
  outputreg m_awvalid,
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

      WAIT_READ: begin
        s_tready = 'b0;
        if (m_awready && m_wready) begin
          state <= READ;
        end else begin
          state <= WAIT_READ;
        end
      end

      WRITE: begin
        s_aready = 'b0;
        m_awaddr = addr + DATA_WIDTH/8 - tkeep[$clog2(DATA_WIDTH/8)-1:0];
        m_awlen = tkeep[$clog2(DATA_WIDTH/8)-1:0];
        m_awsize = $clog2(DATA_WIDTH/8);
        m_awvalid = 'b1;

		m_wdata = data >> {tkeep[$clog2(DATA_WIDTH/8)-1:0], {$clog2(DATA_WIDTH/8){'b0}}};
		m_wstrb = tkeep;
        m_wvalid = 'b1;

        if (m_awready && m_wready) begin
          state <= WAIT;
        end else begin
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
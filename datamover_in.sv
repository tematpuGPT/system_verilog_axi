// Это ip ядро на System Verilog. Входной порт axi steam для пакетов длиной 16 - 1600 байт с сигналом tkeep.
// Ширина данных задается параметром для ядра. пакеты приходящие в этот порт должны сохраняться в память через мастер порт AXI memory mapped c поддержкой Burst. 
//Адрес для сохранения пакета должен получаться через еще один входной порт AXI stream. 
//Где в каждом приходящем слове лежит адрес для сохранения пакетов. Если новых адресов в порте нет, то и первый axi stream порт должен переходить в состояние "не готов"

module datamover_in #(
    parameter DATA_WIDTH = 32
)(
    input clk,
    input reset_n,
    input [DATA_WIDTH-1:0] s_data,
    input [DATA_WIDTH/8-1:0] s_tkeep,
    input s_tvalid,
    input s_tlast,
    output reg s_tready,
    input [31:0] a_data,
    input a_tvalid,
    output reg a_tready,
    output reg [31:0] m_awaddr,
    output reg [7:0] m_awlen,
    output reg m_awvalid,
    input m_awready,
    output reg [DATA_WIDTH-1:0] m_wdata,
    output reg [DATA_WIDTH/8-1:0] m_wstrb,
    output reg m_wlast,
    output reg m_wvalid,
    input m_wready,
    input [1:0] m_bresp,
    input m_bvalid,
    output reg m_bready
);

localparam IDLE = 3'b000;
localparam READ = 3'b001;
localparam WAIT = 3'b010;
localparam WRITE = 3'b100;

reg [2:0] state;
reg [2:0] next_state;

reg [31:0] addr;
reg [7:0] len;

reg data_reg;

always @* begin
   
    next_state = state;
    
    s_tready = 1'b0;
    a_tready = 1'b0;
    
    m_awvalid = 1'b0;
    m_wvalid = 1'b0;
    
    case (state)
        IDLE: begin
            
            if (s_tvalid && a_tvalid) begin
                
                next_state = READ;
                
                s_tready = 1'b1;
                a_tready = 1'b1;
                
                addr = a_data;
                
                len = 8'h00;
                
            end
            
        end
        
        READ: begin
            
            if (s_tvalid) begin
                
                s_tready = 1'b1;
                
                len = s_tlast;
                m_awvalid = s_tvalid;
                m_wvalid = s_tvalid;
                
                if (len == 8'hFF || s_tkeep == {(DATA_WIDTH/8){1'b0}} || s_tlast == 1'b1) 
                begin
                    
                    next_state = WAIT;
                    
                    
                    
                end
                
                data_reg = s_data;
                
            end
            
        end
        
        WAIT: begin
            
            if (m_awready && m_wready) begin
                
                next_state = IDLE;
                
                s_tready = 1'b1;
                a_tready = 1'b1;
                
                addr = a_data;
                
            end else begin
                
                m_awvalid = 1'b0;
                m_wvalid = 1'b0;
                
            end
            
        end
        
    endcase
    
end

always @(posedge clk or negedge reset_n) begin
    
    if (!reset_n) begin
        
        state <= IDLE;
        
        m_awaddr <= 32'h0000_0000;
        m_awlen <= 8'h00;
        m_wdata <= {DATA_WIDTH{1'b0}};
        m_wstrb <= {DATA_WIDTH/8{1'b0}};
        m_wlast <= 1'b0;
        m_bready <= 1'b0;
        
    end else begin
        
        state <= next_state;
        
        case (state)
            IDLE: begin
                
                m_awaddr <= addr;
                m_awlen <= len - 8'h01;
                m_wdata <= data_reg;
                m_wstrb <= s_tkeep;
                m_wlast <= s_tlast;
                m_bready <= 1'b1;
                
            end
            
            READ: begin
                
                m_awaddr <= addr + DATA_WIDTH/8'h01;
                m_wdata <= data_reg;
                m_wstrb <= s_tkeep;
                m_wlast <= s_tlast;
                m_bready <= 1'b0;
                
            end
            
            WAIT: begin
                
                m_bready <= 1'b0;
                
            end
            
        endcase
        
    end
    
end

endmodule
				
				
				
				
				
				
				
				
				
				
				
				
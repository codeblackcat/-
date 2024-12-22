`include "defines.vh"  // 包含定义文件
module regfile(
    // 基本读写端口
    input wire clk,                    // 时钟信号
    input wire [4:0] raddr1,          // 读端口1地址(5位)
    output wire [31:0] rdata1,        // 读端口1数据(32位)
    input wire [4:0] raddr2,          // 读端口2地址(5位)
    output wire [31:0] rdata2,        // 读端口2数据(32位)

    // 数据前推总线
    input wire [37:0] ex_to_id_bus,   // 执行阶段到译码阶段的前推总线
    input wire [37:0] mem_to_id_bus,  // 访存阶段到译码阶段的前推总线
    input wire [37:0] wb_to_id_bus,   // 写回阶段到译码阶段的前推总线
    input wire [65:0] ex_to_id_2,     // HI/LO寄存器执行阶段前推
    input wire [65:0] mem_to_id_2,    // HI/LO寄存器访存阶段前推
    
    // 写端口信号
    input wire we,                     // 写使能信号
    input wire [4:0] waddr,           // 写地址(5位)
    input wire [31:0] wdata,          // 写数据(32位)
    
    // HI/LO寄存器控制信号
    input wire w_hi_we,               // HI寄存器写使能
    input wire w_lo_we,               // LO寄存器写使能
    input wire [31:0] hi_i,           // HI寄存器输入数据
    input wire [31:0] lo_i,           // LO寄存器输入数据
    input wire r_hi_we,               // HI寄存器读使能
    input wire r_lo_we,               // LO寄存器读使能
    output wire[31:0] hi_o,           // HI寄存器输出数据
    output wire[31:0] lo_o,           // LO寄存器输出数据
    
    // LSA指令相关信号
    input [31:0] inst,                // 指令
    input inst_lsa                    // LSA指令标识
);

    // 寄存器组定义
    reg [31:0] reg_array [31:0];      // 32个32位通用寄存器
    reg [31:0] hi;                    // HI寄存器
    reg [31:0] lo;                    // LO寄存器

    // 写入通用寄存器
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin  // $0寄存器不可写
            reg_array[waddr] <= wdata;
        end
    end

    // 写入HI/LO寄存器
    always @ (posedge clk) begin
        if (w_hi_we) begin
            hi <= hi_i;
        end
        if (w_lo_we) begin
            lo <= lo_i;
        end
    end

    // 解析执行阶段前推信号
    wire [31:0] ex_result;            // 执行结果
    wire ex_rf_we;                    // 执行阶段写使能
    wire [4:0] ex_rf_waddr;           // 执行阶段写地址
    assign {
        ex_rf_we,                     // 位37
        ex_rf_waddr,                  // 位36:32
        ex_result                     // 位31:0
    } = ex_to_id_bus;

    // 解析访存阶段前推信号
    wire [31:0] mem_rf_wdata;         // 访存数据
    wire mem_rf_we;                   // 访存阶段写使能
    wire [4:0] mem_rf_waddr;          // 访存阶段写地址
    wire [31:0] bbb;                  // 临时变量用于数据选择
    assign {
        mem_rf_we,                    // 位37
        mem_rf_waddr,                 // 位36:32
        mem_rf_wdata                  // 位31:0
    } = mem_to_id_bus;

    // 解析写回阶段前推信号
    wire [31:0] wb1_rf_wdata;         // 写回数据
    wire wb1_rf_we;                   // 写回阶段写使能
    wire [4:0] wb1_rf_waddr;          // 写回阶段写地址
    assign {
        wb1_rf_we,                    // 位37
        wb1_rf_waddr,                 // 位36:32
        wb1_rf_wdata                  // 位31:0
    } = wb_to_id_bus;
    
    // 解析HI/LO寄存器前推信号
    wire hi_ex_we, lo_ex_we;          // 执行阶段HI/LO写使能
    wire [31:0] hi_ex, lo_ex;         // 执行阶段HI/LO数据
    wire hi_mem_we, lo_mem_we;        // 访存阶段HI/LO写使能
    wire [31:0] hi_mem, lo_mem;       // 访存阶段HI/LO数据
    wire hi_wb_we, lo_wb_we;          // 写回阶段HI/LO写使能
    wire [31:0] hi_wb, lo_wb;         // 写回阶段HI/LO数据

    // 从总线解析HI/LO信号
    assign{
        hi_ex_we, lo_ex_we,           // HI/LO写使能
        hi_ex, lo_ex                  // HI/LO数据
    } = ex_to_id_2;
    
    assign{
        hi_mem_we, lo_mem_we,         // HI/LO写使能
        hi_mem, lo_mem                // HI/LO数据
    } = mem_to_id_2;
    
    // 读端口1数据选择(带前推)
    assign bbb = (raddr1 == 5'b0) ? 32'b0 : 
    ((raddr1 == ex_rf_waddr)&& ex_rf_we) ? ex_result : 
    ((raddr1 == mem_rf_waddr)&& mem_rf_we) ? mem_rf_wdata : 
    ((raddr1 == wb1_rf_waddr)&& wb1_rf_we) ? wb1_rf_wdata :
    reg_array[raddr1];
    
    // LSA指令的移位处理,单步定量左移，根据6-7位判断
    wire [31:0] aaa;                  // LSA结果临时变量
    assign aaa = inst[7:6] == 2'b11 ?  ({bbb[27:0],4'b0}):  // 左移4位
                 inst[7:6] == 2'b00 ?  ({bbb[30:0],1'b0}):  // 左移1位
                 inst[7:6] == 2'b01 ?  ({bbb[29:0],2'b0}):  // 左移2位
                 inst[7:6] == 2'b10 ?  ({bbb[28:0],3'b0}):  // 左移3位
                 32'b0;
    // 最终读端口1输出选择
    assign rdata1 = inst_lsa ? aaa : bbb;

    // 读端口2数据选择(带前推)
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : 
    ((raddr2 == ex_rf_waddr)&& ex_rf_we) ? ex_result :
    ((raddr2 == mem_rf_waddr)&& mem_rf_we) ? mem_rf_wdata : 
    ((raddr2 == wb1_rf_waddr)&& wb1_rf_we) ? wb1_rf_wdata : 
    reg_array[raddr2];
    
    // HI/LO寄存器输出选择(带前推)
    assign hi_o = hi_ex_we ? hi_ex :
                 hi_mem_we ? hi_mem :
                //  hi_wb_we ? hi_wb : 
                 hi;
    assign lo_o = lo_ex_we ? lo_ex :
                 lo_mem_we ? lo_mem :
                //  lo_wb_we ? lo_wb : 
                 lo;
     
endmodule
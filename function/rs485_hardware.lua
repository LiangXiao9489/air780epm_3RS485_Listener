--[[
@module  rs485_hardware
@summary RS485 底层收发模块（仅 UART2），基于 demo/hardware.lua 的 u2 参数
@version 1.1
@date    2026.11.17
@usage
require "function.rs485_hardware"  -- require 时自动初始化 UART2
本模块负责 UART2 的 uart.setup 初始化，并提供 send() 接口。
上层模块（如 listener）自行注册 receive 回调。
]]

local _M = {}

-- ============================================================
-- 配置区：UART2（RS485_2，EN 硬件自动翻转）
-- ============================================================
local uartid      = 2
local baudrate    = 9600
local databits    = 8
local stopbits    = 1
local parity      = uart.NONE
local order       = uart.LSB
local buf_size    = 1024
local en_pin      = nil          -- 硬件自动翻转，必须留空
local en_level    = 0
local rs485_delay = 20000        -- 发送→接收切换延时（微秒）

-- ============================================================
-- 对外接口
-- ============================================================
function _M.send(data)
    if type(data) ~= "string" or #data == 0 then
        log.warn("485", "send 无效数据")
        return false
    end
    uart.write(uartid, data)
    return true
end

-- ============================================================
-- 初始化（require 时自动执行）
-- ============================================================
log.info("485", "init", "uart=" .. uartid,
         "baud=" .. baudrate,
         "data=" .. databits,
         "stop=" .. stopbits,
         "parity=" .. tostring(parity),
         "en_pin=" .. tostring(en_pin),
         "delay=" .. rs485_delay .. "us")

uart.setup(uartid, baudrate, databits, stopbits,
           parity, order, buf_size,
           en_pin, en_level, rs485_delay)

log.info("485", "init", "UART2 初始化完成")

return _M

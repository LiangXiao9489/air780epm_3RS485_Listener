--[[
@module  rs485_hardware
@summary RS485 底层收发模块（仅 UART2），基于 demo/hardware.lua 的 u2 参数
@version 1.0
@date    2026.11.17
@usage
require "listener.rs485_hardware"  -- require 时自动初始化 UART2
本模块提供 UART2 的 send() / wait_response() 接口，为上层 Modbus 协议提供收发能力。
]]

local _M = {}

-- ============================================================
-- 配置区：UART2（RS485_2，EN 硬件自动翻转）
-- ============================================================
local uartid      = 2
local baudrate    = 9600
local databits    = 8
local stopbits    = 1
local parity      = uart.NONE    -- "N" → uart.NONE
local order       = uart.LSB
local buf_size    = 1024
local en_pin      = nil          -- 硬件自动翻转，必须留空
local en_level    = 0
local rs485_delay = 20000        -- 发送→接收切换延时（微秒）

-- 帧间静默间隔（毫秒）：连续无新数据超过此值视为一帧结束
local frame_gap_ms = 8
local recv_max_read = 256

local resp_event  = "UART485_U2_RESP"
local resp_buffer = nil

-- ============================================================
-- 内部工具
-- ============================================================
local function to_hex_spaced(data)
    local parts = {}
    for i = 1, #data do
        parts[#parts + 1] = string.format("%02X", data:byte(i))
    end
    return table.concat(parts, " ")
end

-- ============================================================
-- 接收回调
-- ============================================================
local function recv_cb(id, len)
    local s = ""
    repeat
        s = uart.read(id, recv_max_read)
        if #s > 0 then
            resp_buffer = (resp_buffer or "") .. s
        end
    until s == ""

    if resp_buffer and #resp_buffer > 0 then
        sys.publish(resp_event)
    end
end

-- ============================================================
-- 发送完成回调
-- ============================================================
local function sent_cb(id)
    -- log.info("485", "sent", "uart=" .. id, "发送完成")
end

-- ============================================================
-- 对外接口
-- ============================================================
function _M.send(data)
    if type(data) ~= "string" or #data == 0 then
        log.warn("485", "send 无效数据")
        return false
    end
    -- u2 不清接收缓冲：从站处理期间到达的请求需保留
    log.info("485", "send", "uart=" .. uartid,
             "len=" .. #data, "hex=" .. to_hex_spaced(data))
    uart.write(uartid, data)
    return true
end

function _M.wait_response(timeout_ms)
    local t0 = mcu.ticks()

    -- 阶段1：等待首段数据到达
    while not (resp_buffer and #resp_buffer > 0) do
        local remain = timeout_ms - (mcu.ticks() - t0)
        if remain <= 0 then
            log.warn("485", "wait_response 超时(" .. timeout_ms .. "ms)")
            return nil, -1
        end
        if not sys.waitUntil(resp_event, remain) then
            log.warn("485", "wait_response 超时(" .. timeout_ms .. "ms)")
            return nil, -1
        end
    end

    -- 阶段2：等总线静默
    local last_len
    repeat
        if not resp_buffer then
            log.warn("485", "wait_response resp_buffer 意外为 nil")
            return nil, -2
        end
        last_len = #resp_buffer
        sys.wait(frame_gap_ms)
    until resp_buffer and #resp_buffer == last_len

    local data = resp_buffer
    resp_buffer = nil

    log.info("485", "recv", "uart=" .. uartid,
             "len=" .. #data, "hex=" .. to_hex_spaced(data))
    return data, 0
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

uart.on(uartid, "receive", recv_cb)
uart.on(uartid, "sent", sent_cb)

log.info("485", "init", "UART2 初始化完成")

return _M

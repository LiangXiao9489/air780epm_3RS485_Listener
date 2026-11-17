--[[
@module  function.listener
@summary UART2 实时监听，将总线上所有数据按帧静默间隔分组后以十六进制打印
@version 1.0
@date    2026.11.17
@usage
require "function.listener"  -- require 时自动启动监听，在 log 中实时打印
本模块纯监听，不向 UART2 发送任何数据。
]]

local _M = {}

local uartid      = 2
local frame_gap_ms = 8   -- 帧间静默，超过此间隔视为一帧结束
local recv_max_read = 256

local resp_event  = "LISTENER_U2_RESP"
local resp_buffer = nil

-- ============================================================
-- 内部工具：字节串转十六进制（每字节空格分隔）
-- ============================================================
local function to_hex_spaced(data)
    local parts = {}
    for i = 1, #data do
        parts[#parts + 1] = string.format("%02X", data:byte(i))
    end
    return table.concat(parts, " ")
end

-- ============================================================
-- 接收回调：读走所有数据，追加到暂存区后发布事件
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
-- 打印 task：等数据 → 等静默 → 整帧 hex 打印 → 循环
-- ============================================================
local function listener_task()
    while true do
        -- 阶段1：等待首段数据到达
        while not (resp_buffer and #resp_buffer > 0) do
            sys.waitUntil(resp_event)
        end

        -- 阶段2：等总线静默
        local last_len
        repeat
            last_len = #resp_buffer
            sys.wait(frame_gap_ms)
        until resp_buffer and #resp_buffer == last_len

        local data = resp_buffer
        resp_buffer = nil
        log.info("listener", "UART2", "len=" .. #data, "hex=" .. to_hex_spaced(data))
    end
end

-- ============================================================
-- 初始化（require 时自动执行）
-- ============================================================
require "function.rs485_hardware"  -- UART2 的 uart.setup 由它完成
uart.on(uartid, "receive", recv_cb)

sys.taskInit(listener_task)
log.info("listener", "UART2 实时监听已启动")

return _M

require "sys"

PROJECT = "Air780EPM_3RS485_Listener"
VERSION = "888666999"
pm.ioVol(pm.IOVOL_ALL_GPIO, 3300)

log.info("=========== 当前模组的固件版本是 [" .. VERSION .. "] =========")
log.info("=========== 芯片 UID [" .. mcu.unique_id():toHex() .. "] =========")

-- UART2 实时监听
require "function.listener"

sys.run()


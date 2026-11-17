# Air780EPM 双路 RS485 网关（Modbus + MQTT）

基于合泰 LuatOS 的 Air780EPM 模组固件，实现双路 RS485（Modbus RTU 协议）与 MQTT 云端的双向数据网关。

## 功能概览

| 模块 | 说明 |
|------|------|
| **双路 RS485** | u1（RS485_1，EN 软件翻转）+ u2（RS485_2，EN 硬件自动翻转），波特率/校验位独立配置 |
| **Modbus RTU** | 纯函数编解码引擎，主站（下行读设备）与从站（上行应平台）共用一套核心 |
| **MQTT 通道** | 自动建链、批量订阅、退避重连、心跳喂狗，主题按芯片 UID 动态生成 |
| **4G 联网** | SNTP 校时、网络看门狗守护 |

## 目录结构

```
main.lua                      -- 入口：版本打印 + sys.run()
_extra/
└── demo/
    ├── modbus/               -- Modbus 协议与硬件层
    │   ├── hardware.lua      -- 双路 RS485 串口收发（纯管道，方向控制）
    │   ├── core.lua          -- Modbus RTU 编解码引擎（CRC/组帧/解帧）
    │   ├── master.lua        -- 主站侧：发起请求、解析响应
    │   ├── slave.lua         -- 从站侧：接收请求、构造响应
    │   ├── point_table.lua   -- 点位表（寄存器映射）
    │   └── downlink_uart_lock.lua -- 下行串口互斥锁
    ├── wireless/
    │   ├── mqtt/
    │   │   ├── basic.lua     -- MQTT 主调度：建链/订阅/断线重连
    │   │   ├── sender.lua    -- 上行发送队列 + 发送 task
    │   │   ├── receiver.lua  -- 下行接收分发 task
    │   │   └── protocol/     -- 协议层（主题模板、上报帧、下行帧解析）
    │   ├── 4g/
    │   │   ├── net_4g.lua    -- 4G 联网流程
    │   │   ├── sntp.lua      -- SNTP 校时
    │   │   └── net_watchdog.lua -- 网络看门狗
    │   └── ota.lua           -- OTA 升级
    ├── data/
    │   ├── config.lua        -- 参数读写（波特率/地址等）
    │   └── store.lua         -- 数据持久化
    └── device/
        └── ext_wdt.lua       -- 外部看门狗喂狗
```

## 硬件依赖

- **主控模组**：Air780EPM（LuatOS）
- **串口**：UART1 + UART2，分别接两路 RS485 收发器
- **方向控制**：UART1 需 GPIO 控制 DE/RE（默认 GPIO25），UART2 硬件自动翻转无需 GPIO
- **网络**：4G Cat.1，SIM 卡接入 MQTT Broker

## 快速开始

1. 用 LuatIDE 打开工程目录
2. 如需启用 demo 代码，将 `_extra/demo/` 下对应模块复制到工程根目录（或在 main.lua 中手动 require）
3. 修改 `wireless/mqtt/basic.lua` 中的 Broker 地址、端口、账号
4. 修改 `modbus/hardware.lua` 中的波特率、校验位、EN 引脚号，匹配现场设备
5. 编译烧录，观察串口日志确认固件版本和芯片 UID

## 关键设计

- **Modbus core 纯函数化**：不依赖 uart、不启动 task、无全局可变状态，便于单测和复用
- **双路串口独立状态**：u1 为问答式（发前清接收缓冲），u2 为被动式（不清缓冲，保留到达的上行请求）
- **帧间静默判帧**：8ms 无新数据视为一帧结束，兼顾 9600 波特率下的响应延迟
- **MQTT 事件分发**：通过 `sys.sendMsg` 将 broker 事件路由到 sender/receiver task，回调保持轻量
- **退避重连**：5s 起步、翻倍、30s 封顶，避免 broker 异常时高频刷日志

## 版本信息

- 工程版本：`888666999`
- 主入口模块：`Air780EPM_3RS485_Listener`

# 一个五级流水线 CPU Labs

本仓库当前的核心实现位于 vsrc 目录，已经搭起了一个面向实验的 RV64 五级流水线 CPU 框架。代码结构比较清晰，顶层通过 SimTop 将 core、指令/数据总线转换模块、CBus 仲裁器和内存模型连接起来，便于后续继续扩展缓存、AXI 互连或更多控制逻辑。

## 当前实现概览

- 处理器数据通路采用经典五级流水：IF -> ID -> EX -> MEM -> WB。
- 字长为 64 位，寄存器堆为 32 x 64 位整数寄存器。
- 已实现基础整数算术/逻辑指令、部分 RV64 W 类指令、LUI、Load/Store 以及实验自定义 trap 指令。
- 取指路径和数据访存路径分离，对外分别通过 IBus 和 DBus 发起请求。
- 顶层通过 IBusToCBus / DBusToCBus 统一接入 CBus，再由 CBusArbiter 与 RAMHelper2 对接。
- 集成了 Difftest 提交、寄存器状态、store event 和 trap event 输出，便于实验验证。

## 目录说明

```text
vsrc/
├─ SimTop.sv                    # 实验顶层，连接 core / 总线适配 / RAMHelper2
├─ include/
│  ├─ common.sv                # 全局类型、总线定义、常量与宏
│  └─ config.sv                # 实验配置参数
├─ src/
│  ├─ core.sv                  # CPU 主体，组织五级流水和 Difftest 信号
│  └─ pipeline/
│     ├─ stages/               # IF/ID/EX/MEM/WB 各阶段实现
│     ├─ regs/                 # 级间流水寄存器
│     └─ units/
│        ├─ decoder/           # 指令译码器
│        └─ regfile/           # 通用寄存器堆
└─ util/
	 ├─ IBusToCBus.sv           # IBus 到 CBus 的请求/响应转换
	 ├─ DBusToCBus.sv           # DBus 到 CBus 的请求/响应转换
	 ├─ CBusArbiter.sv          # 多主 CBus 仲裁
	 ├─ CBusMultiplexer.sv      # 简单多路选择器
	 ├─ CBusToAXI.sv            # CBus 到 AXI 的桥接模板
	 └─ SimpleArbiter.sv        # 更复杂场景下的访存仲裁模块
```

## 顶层连接关系

当前顶层数据通路可以概括为：

```text
core
	|-- ireq/iresp --> IBusToCBus --|
	|                               |--> CBusArbiter --> RAMHelper2
	|-- dreq/dresp --> DBusToCBus --|
```

其中：

- SimTop 负责实例化 core、两类总线转换器、CBus 仲裁器和 RAMHelper2。
- core 只关心 IBus/DBus 级别的取指与数据访存，不直接处理底层仲裁细节。
- IBusToCBus 通过复用 DBusToCBus 的能力，把取指请求映射到统一的 CBus 协议。
- CBusArbiter 当前在指令访存和数据访存之间做二选一仲裁，存在 1 个周期的额外仲裁延迟。

## 五级流水线说明

### IF: 取指阶段

- if_stage 内部维护 PC，复位后从 common.sv 中定义的 PCINIT = 0x80000000 开始取指。
- 当前实现还没有分支预测或跳转重定向，因此取指严格按 PC + 4 顺序前进。
- 当收到 iresp.data_ok 且核心未 halt 时，PC 才会前移。
- 发生 trap 排空时，可以通过 drop_resp_i 丢弃返回的取指响应。

### ID: 译码阶段

- id_stage 调用 decoder 生成控制信号、立即数、源/目的寄存器编号和 ALU 操作类型。
- 内置简单前递机制：优先使用 EX/MEM 结果，其次使用 MEM/WB 结果。
- 目前没有完整的通用冒险检测单元，主要通过前递和 MEM 阶段停顿来维持正确性。

### EX: 执行阶段

- ex_stage 是整数 ALU，支持加、减、与、或、异或。
- 对 RV64 的 W 类指令，会将结果低 32 位符号扩展回 64 位。
- Load/Store 也在 EX 阶段完成地址计算。

### MEM: 访存阶段

- mem_stage 根据地址低位生成 byte mask，并完成 load 数据对齐与符号/零扩展。
- 访问内存时会保持请求稳定，直到收到 dresp.data_ok 为止。
- 对 store 指令会额外生成 store event，供 Difftest 使用。
- 非访存指令会直接旁路 EX 结果进入写回。

### WB: 写回阶段

- wb_stage 负责向寄存器堆写回，并生成提交信号。
- 对 x0 的写入会被抑制，不会真正修改寄存器堆。
- core 在该阶段之后更新提交信息、指令计数、trap 状态和 Difftest 观测信号。

## 流水寄存器与控制

- if_id_reg、id_ex_reg、ex_mem_reg 支持 flush 和 stall。
- mem_wb_reg 负责锁存最终提交所需的数据和 store event。
- 全局 flush 条件为 reset 或 trap_valid_q 置位。
- 当 ID 阶段识别到 trap 指令后，core 会先停止继续取指；当该指令到达 WB 后，记录 trap 信息并整体清空流水线。
- mem_stage 在等待数据返回期间会拉高 mem_stall，阻塞前级流水寄存器更新。

## 当前支持的指令子集

根据 decoder.sv，当前已实现的指令主要包括：

- OP-IMM: addi, xori, ori, andi
- OP: add, sub, xor, or, and
- OP-IMM-32: addiw
- OP-32: addw, subw
- U-type: lui
- Load: lb, lh, lw, ld, lbu, lhu, lwu
- Store: sb, sh, sw, sd
- 自定义 trap 指令：opcode = 1101011，用于实验结束/陷入

这意味着当前版本更接近“可跑基础算术与访存测试的实验 CPU 骨架”，还没有看到分支、跳转、CSR、异常中断处理、乘除法或缓存体系等完整实现。

## Difftest 与调试支持

在 VERILATOR 宏打开时，core 会导出以下 Difftest 接口：

- DifftestInstrCommit: 每条提交指令的信息
- DifftestStoreEvent: store 指令写内存事件
- DifftestArchIntRegState: 32 个通用寄存器状态
- DifftestTrapEvent: trap 触发时的 PC、周期数和指令计数
- DifftestCSRState: 当前以固定值占位输出 CSR 状态

因此，这套代码不仅是在写功能逻辑，也是在为后续实验的自动化对拍做准备。

## 总线与公共定义

- common.sv 定义了 word_t、addr_t、msize_t、IBus/DBus/CBus 请求响应结构等全局公共类型。
- 当前 XLEN = 64，PC 初值为 0x00000000_80000000。
- config.sv 中 AXI_BURST_NUM 默认配置为 16，用于 CBus/AXI 相关工具模块。
- IBus 被定义为 DBus 的子集，因此可以复用 DBus 到 CBus 的转换逻辑。

## 当前代码特征与限制

- 取指为严格顺序取指，尚未实现跳转重定向。
- 数据相关主要依赖简单前递，尚未看到完整的统一 hazard detection 单元。
- 中断输入 trint、swint、exint 已经在顶层和 core 接口中预留，但当前未实际参与控制流。
- util 目录中存在 CBusToAXI、SimpleArbiter 等可扩展组件，但当前顶层主路径实际使用的是 IBusToCBus、DBusToCBus 和 CBusArbiter。

## 适合作为 README 后续继续补充的方向

后续如果继续完成课程实验，可以在本文档中继续补充：

- 支持的测试程序与运行方式
- 仿真命令、Verilator 构建流程和波形查看方式
- 已通过/未通过的功能点
- 分支、跳转、异常中断、CSR、缓存等后续扩展设计
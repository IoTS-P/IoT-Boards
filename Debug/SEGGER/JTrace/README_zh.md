
在本篇博客中，我们将介绍 J-Trace 流式追踪探针，并指导你如何使用 nRF52840-DK 评估板来捕获指令追踪。

## [什么是 J-Trace？](https://www.segger.com/products/debug-probes/j-trace/)

J-Trace 是一款强大的流式追踪探针，能够长时间捕获完整的指令追踪，从而记录偶发的、难以复现的 bug。理论上，几乎所有 ARM Cortex MCU 都支持追踪功能。但并非所有评估板都引出了追踪接口。对于已支持/已测试的评估板，SEGGER 在[此页面](https://www.segger.com/products/debug-probes/j-trace/technology/tested-devices/)维护了所有经过 J-Trace 测试的设备列表。

## [了解 J-Trace 引脚定义](https://kb.segger.com/19-pin_JTAG/SWD_and_Trace_Connector)

![引脚定义](https://kb.segger.com/images/a/a9/19pinTracePort.png)

J-Trace 探针提供一个 19 针 JTAG / SWD + Trace 连接器（0.05" / 1.27mm 间距）。它通过 1-1 追踪线缆连接到目标板。也可以通过 [20 针 J-Link 连接器](https://wiki.segger.com/20-pin_J-Link_Connector "20-pin J-Link Connector")来连接 J-Trace。

关于 nRF52840-DK 追踪连接器的具体细节，请参考这篇 [Nordic DevZone 帖子](https://devzone.nordicsemi.com/f/nordic-q-a/53998/trace-connector-pin-9-in-nrf52833-and-52840-dk-pca10100-and-pca10056)。

**注意：**
切勿同时连接 19 针和 20 针线缆，否则可能导致调试和追踪连接不稳定。
![注意事项](https://kb.segger.com/images/thumb/4/49/190405_J-trace_connection-final.jpg/600px-190405_J-trace_connection-final.jpg)

下面我们将详细介绍如何在 nRF52840DK 评估板上获取指令追踪。

## 为 J-Trace 设置 nRF52840-DK

nRF52840-DK 默认未焊接 19 针追踪接口，你需要先进行组装。请按以下步骤操作：

1. **焊接排针**：在 nRF52840DK 的 **P25** 连接器上焊接一个 2x10 针、1.27mm 间距的贴片排针。
2. **切换到追踪模式**：将 **TRACE 开关 (SW7)** 从 "Def." 拨到 "Alt."。

更多细节请参阅 [nRF52840_DK_User_Guide_v1.2](https://infocenter.nordicsemi.com/pdf/nRF52840_DK_User_Guide_v1.2.pdf) 第 35-36 页，以及 SEGGER 的 [在 nRF52840 DK 上进行追踪](https://wiki.segger.com/Tracing_on_Nordic_Semiconductor_nRF52840) 指南。

![nrf52840dk-jtrace](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/nrf52840dk-jtrace.jpg)

<center><b>重要：连接追踪线缆时请确保连接器卡扣方向正确。</b></center>

> **实验室说明：** 我们实验室有两块 nRF52840DK 开发板。贴有 J-Trace 标签的那块已经过预测试，可以直接使用。另一块可能需要重新焊接。

## 使用 SEGGER Ozone 捕获指令追踪

捕获指令追踪最简单的方法是使用 SEGGER Ozone —— 一款适用于 [J-Link](https://www.segger.com/products/debug-probes/j-link/) 和 [J-Trace](https://www.segger.com/products/debug-probes/j-trace/) 的跨平台调试器和性能分析器。

#### 前置条件

* 确保已安装 [Ozone](https://www.segger.com/downloads/jlink/#Ozone) 和 [J-Link](https://www.segger.com/downloads/jlink/) 软件。
* 可选：使用 J-Link 软件更新 J-Trace 固件以获得最佳性能。

#### 分步操作指南

1. **下载示例项目**：下载 [Nordic_NRF52840_Trace_Example.zip](https://kb.segger.com/images/c/ce/Nordic_nRF52840_Trace_Example.zip) 并解压。

2. **在 Ozone 中打开项目**：启动 Ozone，选择 **Open Existing Project**。导航到解压后的项目文件夹，选择 **nRF52840_Trace_Ozone.jdebug**。

![ozone 打开项目](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_open.png)

3. **连接硬件**：通过 19 针追踪线缆将 J-Trace 探针连接到 nRF52840-DK，如下所示。

![追踪线缆连接](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/trace-plug-new.jpg)

![nrf52840dk-jtrace](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/nrf52840dk-jtrace.jpg)

<center><b>重要：连接追踪线缆时请确保连接器卡扣方向正确。</b></center>

4. **烧录程序**：在 Ozone 中点击 **Download & Reset Program** 按钮（绿色电源图标），并选择 **J-Trace PRO Cortex** 作为目标仿真器。

![ozone 烧录](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_flash.png)

5. **查看指令追踪**：追踪数据将显示在 Ozone 左侧窗口中。

![ozone 完整界面](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_trace.png)

6. **导出追踪数据**：
    - 在指令追踪窗口中右键点击，选择 **Export**。
    - 在对话框中，为 **Maximum Instruction Count** 输入一个很大的值，例如 100G。
    - 选择追踪文件的输出路径和文件名。

![ozone 追踪导出](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_instruction_trace_export.png)

**导出对话框**
![ozone 追踪输出](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_trace_output.png)

#### 理解追踪输出

导出的追踪数据以 CSV 文件格式保存，按倒序排列，每行包含以下字段：
- **time：** 指令的时间戳。
- **pc：** 程序计数器的值。
- **unknown：** 可能是寄存器或占位符（需要进一步确认）。
- **size：** 指令的大小。
- **assembly code：** 执行的汇编指令。
- **source code：** 对应的源代码（如果可用）。

![ozone 追踪 CSV](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_instruction_trace_csv.png)
> 待确认：unknown 字段的具体含义，可能是寄存器？

## 参考资料
* [19 针 JTAG/SWD 和追踪连接器](https://wiki.segger.com/19-pin_JTAG/SWD_and_Trace_Connector)
* [J-Trace 连接器](https://devzone.nordicsemi.com/f/nordic-q-a/53998/trace-connector-pin-9-in-nrf52833-and-52840-dk-pca10100-and-pca10056)

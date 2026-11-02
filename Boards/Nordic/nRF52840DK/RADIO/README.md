# nRF52840 RADIO 双开发板真机烧录与 GDB 语义采集复现指南

## 1. 实验目标与判定标准

本实验使用两块 Nordic nRF52840 DK：一块作为无线发送端（TX），一块作为无线接收端（RX）。将各自的原始二进制固件（`.bin`）烧录至片上 Flash，使用对应 AXF 文件提供 GDB 调试符号，再通过两个 J-Link GDB Server 和独立的 GDB 自动脚本捕获 RADIO 寄存器写入、硬件状态、事件标志、数据缓冲区变化以及函数返回情况。

目标是得到可审计的真实外设功能语义证据，而非测量 RADIO 精确周期或射频时延。一次有效收发至少应具备：

1. TX 的一次按钮事件触发 `send_packet()`，`EVENTS_END` 在本轮先清零后重新置位，随后执行 `TASKS_DISABLE` 并返回。
2. RX 的 `read_packet()` 先清除旧 `EVENTS_END`、执行 `TASKS_RXEN` 与 `TASKS_START`，随后观测到本轮 `EVENTS_END=1`、`CRCSTATUS=1` 并返回。
3. TX 和 RX 本轮的有效 payload 字节一致。当前固件 `PCNF0.LFLEN=0`、`PCNF1.STATLEN=1`，因此 `packet[0]` 是唯一的有效 payload 字节，**不是长度字段**。
4. 采集过程未命中 `HardFault_Handler`。若 RX 停在 STEP 5/9 的等待状态而尚未发包，不能判为失败。

“成功复现”指在相同固件和脚本版本下独立获得至少一次满足上述条件的收发记录。示例基准运行记录中有两次成功收发；不要求第三次 `read_packet()` 自动完成，因为接收程序会循环等待下一帧。

## 2. 硬件、软件与实验文件

### 2.1 硬件

- 两块 nRF52840 DK 开发板，分别通过板载调试 USB 接入 Windows 主机；两块板保持正常供电。
- 可操作 TX 板的物理按键 Button3 和 Button4。针对这里的 DK 按键配置，Button3 对应 P0.24，Button4 对应 P0.25；低电平表示按下。
- 两块板之间通过 RADIO 空中收发，无需额外连接数据线。

实验板序列号和 GDB 端口的对应关系如下。**序列号属于这套实验设备；换板时必须重新识别，不能照抄。**

| 项目 | RX（接收板） | TX（发送板） |
|---|---|---|
| J-Link USB 序列号 | `1050275288` | `1050233983` |
| J-Link GDB Server TCP 端口 | `2331` | `2334` |
| SWD 时钟（kHz） | `1000` | `1000` |
| 裸 BIN | `nrf52840_xxaa_radio_receiver.bin` | `nrf52840_xxaa_radio_transmitter.bin` |
| 调试符号 AXF | `nrf52840_xxaa_radio_receiver.axf` | `nrf52840_xxaa_radio_transmitter.axf` |
| **使用的原版脚本** | `radio_rx_capture_v2.gdb` | `radio_tx_capture_v2.gdb` |
| 脚本默认输出日志 | `radio_rx_capture_v5.log` | `radio_tx_capture_v5.log` |

### 2.2 Windows 软件

安装下列组件并保证相应程序位于 `PATH`：

- Windows 10/11 和 PowerShell（Windows 内置；[Microsoft PowerShell 文档](https://learn.microsoft.com/powershell/)）。
- [SEGGER J-Link Software and Documentation Pack（官方下载）](https://www.segger.com/downloads/jlink/)：安装 Windows 版，包含 `JLink.exe`（J-Link Commander）和 `JLinkGDBServerCL.exe`。
- [Arm GNU Toolchain（官方发布与下载）](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain)：选择 Windows 的 `arm-none-eabi` 裸机工具链，确保包含 `arm-none-eabi-gdb.exe` 和 `arm-none-eabi-readelf.exe`。
- [Git for Windows（官方下载）](https://git-scm.com/install/windows)：用于获取源码并记录实验文件版本。

版本没有在提供的运行记录中固定，正式复现应记录本机输出，而不要将某个未核实版本视为已测试配置：

```powershell
Get-Command JLink.exe, JLinkGDBServerCL.exe, arm-none-eabi-gdb.exe, arm-none-eabi-readelf.exe
arm-none-eabi-gdb --version
JLinkGDBServerCL.exe -?
git --version
```

`JLinkGDBServerCL.exe -?` 的支持情况取决于安装版本；若程序返回帮助信息即可，无须启动实际 Server。

### 2.3 文件准备与工作目录

下文使用以下 Windows 示例路径。若项目存储于其他盘符，只需修改 `$root`；**所有 GDB 调试命令仍应在相应 AXF/脚本目录执行**：

```powershell
$root  = 'D:\Github\LibAFL-Emulator\examples\unit-tests\additional-tests\nRF52840'
$rxDir = Join-Path $root 'radio_receiver'
$txDir = Join-Path $root 'radio_transmitter'
```

源工程入口：`https://github.com/IoTS-P/LibAFL-Emulator`，目标开发分支 `gemu-v2`。可以获取源工程供源码核对：

```powershell
git clone --branch gemu-v2 https://github.com/IoTS-P/LibAFL-Emulator.git
cd LibAFL-Emulator
git rev-parse HEAD
```

以上仓库克隆命令是通用获取方法，不等于已经验证仓库当前必然包含与此实验完全相同的 BIN/AXF。**必须取得与本实验匹配的两套 BIN/AXF**。若仅有源码，需要按照相应固件工程构建说明生成；不要以不同构建的 AXF 调试已烧录的 BIN。提供的材料没有证明可以用一条特定构建命令从零生成全部四个工件，因此此处不虚构 Keil/Make/CMake 构建命令。

检查六个必要文件：

```powershell
Test-Path "$rxDir\nrf52840_xxaa_radio_receiver.bin"
Test-Path "$rxDir\nrf52840_xxaa_radio_receiver.axf"
Test-Path "$rxDir\radio_rx_capture_v2.gdb"
Test-Path "$txDir\nrf52840_xxaa_radio_transmitter.bin"
Test-Path "$txDir\nrf52840_xxaa_radio_transmitter.axf"
Test-Path "$txDir\radio_tx_capture_v2.gdb"
```

六次结果都应为 `True`。保存文件 SHA-256，以便复现者确认实际运行的是同一份工件：

```powershell
Get-FileHash "$rxDir\nrf52840_xxaa_radio_receiver.bin" -Algorithm SHA256
Get-FileHash "$rxDir\nrf52840_xxaa_radio_receiver.axf" -Algorithm SHA256
Get-FileHash "$rxDir\radio_rx_capture_v2.gdb" -Algorithm SHA256
Get-FileHash "$txDir\nrf52840_xxaa_radio_transmitter.bin" -Algorithm SHA256
Get-FileHash "$txDir\nrf52840_xxaa_radio_transmitter.axf" -Algorithm SHA256
Get-FileHash "$txDir\radio_tx_capture_v2.gdb" -Algorithm SHA256
```

检查 AXF 架构与调试信息：

```powershell
arm-none-eabi-readelf -h "$rxDir\nrf52840_xxaa_radio_receiver.axf"
arm-none-eabi-readelf -h "$txDir\nrf52840_xxaa_radio_transmitter.axf"
```

两者应是 ARM ELF32。`readelf` 只验证文件格式，不保证 BIN/AXF 来自同一构建；最好在产出时一起归档。

## 3. 双板识别与烧录准备

保持两块板接通 USB。打开 J-Link Commander 可检查设备连接；如果两块 J-Link 同时在线，应明确选择指定序列号。执行烧录前，关闭已经连接相同设备的 GDB Server、IDE 调试会话及其他 J-Link 进程，避免设备被独占。

烧录使用 **J-Link Commander + BIN + 基地址 `0x00000000`**；不是在 GDB 会话执行 `load`，也不是把 AXF 当作待烧录镜像。

可参考本章的交互方式，具体选项界面受 J-Link 安装版本影响。每次应在终端确认当前所连接设备的 USB 序列号与表中一致。

## 4. 烧录接收端 RX 的 BIN

新开 PowerShell 终端，运行：

```powershell
JLink.exe
```

在 J-Link Commander 中连接 RX 板（USB SN `1050275288`）。若未自动选择目标，输入：

```text
connect
```

根据程序提示指定目标设备 `nRF52840_xxAA`、接口 `S`（SWD）和速度 `1000`（kHz）。提示文本可能因软件版本不同，所需输入值相同。

连接成功后，在 **J-Link Commander 提示符**逐行输入：

```text
loadfile "D:\Github\LibAFL-Emulator\examples\unit-tests\additional-tests\nRF52840\radio_receiver\nrf52840_xxaa_radio_receiver.bin" 0x00000000
r
g
```

如改变工作目录，`loadfile` 路径也须同步改变。`loadfile` 负责烧录裸 BIN 到片上 Flash 起始地址；`r` 复位芯片；`g` 恢复执行。必须查看 `loadfile` 的编程/校验结果，出现错误则停止，不要仅因 `r`、`g` 返回就视作成功。

建议复制 Commander 中显示的 J-Link SN、Flash 编程与 Verify 输出，保存为 `rx_flash_record.txt`。结束后退出 Commander，释放 RX 的 J-Link 连接。

## 5. 烧录发送端 TX 的 BIN

以同样方式打开另一个 J-Link Commander：

```powershell
JLink.exe
```

这次连接 **TX 板 USB SN `1050233983`**，设备 `nRF52840_xxAA`，SWD，速度 `1000`（kHz）。执行：

```text
loadfile "D:\Github\LibAFL-Emulator\examples\unit-tests\additional-tests\nRF52840\radio_transmitter\nrf52840_xxaa_radio_transmitter.bin" 0x00000000
r
g
```

确认 Flash 编程及 Verify 成功，保存输出为 `tx_flash_record.txt`，退出 Commander。**至此完成烧录；以下调试过程不会重新烧录**。

## 6. 开启两路 J-Link GDB Server

需要四个保持打开的 PowerShell 窗口：RX Server、TX Server、RX GDB、TX GDB。烧录用的 Commander 应当已经退出。

窗口 A（RX Server）：

```powershell
JLinkGDBServerCL.exe -select USB=1050275288 -device nRF52840_xxAA -if SWD -speed 1000 -port 2331
```

窗口 B（TX Server）：

```powershell
JLinkGDBServerCL.exe -select USB=1050233983 -device nRF52840_xxAA -if SWD -speed 1000 -port 2334
```

两个进程应保持运行。确认每个窗口显示对应 SN、设备及等待 GDB 连接的端口。若提示端口占用，可使用：

```powershell
Get-NetTCPConnection -LocalPort 2331,2334 -ErrorAction SilentlyContinue
```

不要将 RX/TX 端口、USB SN 交叉使用。文档采用的 `1000` 是 SWD 调试时钟速度（kHz），不是 RADIO 空中比特率。

## 7. 运行 GDB 自动采集脚本

两份 **原版 v2 脚本**已包含 `file`、`target remote`、`monitor reset`、动态断点、`continue` 和日志输出。因此不需要在 GDB 中重新手动输入上述命令，也不要主动运行 `load`。

### 7.1 启动 RX（先执行）

窗口 C：

```powershell
$rxDir = 'D:\Github\LibAFL-Emulator\examples\unit-tests\additional-tests\nRF52840\radio_receiver'
Set-Location $rxDir
arm-none-eabi-gdb -q -x radio_rx_capture_v2.gdb
```

当前脚本连接 `localhost:2331`，读取 `nrf52840_xxaa_radio_receiver.axf` 并输出 `radio_rx_capture_v5.log`。等待初始化完成，接收端将进入 `read_packet()` 循环。正常情况下日志出现 `READ_PACKET ATTEMPT 1`，并进展到 `[STEP 5/9] TASKS_START <- 1`、`STATE=3(RX)`，随后等待收到无线数据包。**这不是卡死或错误。**

### 7.2 启动 TX（RX 就绪后执行）

窗口 D：

```powershell
$txDir = 'D:\Github\LibAFL-Emulator\examples\unit-tests\additional-tests\nRF52840\radio_transmitter'
Set-Location $txDir
arm-none-eabi-gdb -q -x radio_tx_capture_v2.gdb
```

当前脚本连接 `localhost:2334`，读取 `nrf52840_xxaa_radio_transmitter.axf` 并输出 `radio_tx_capture_v5.log`。等待终端显示脚本启动信息（`TX v2 capture initialized`）且 GDB 开始 `continue`；**不能在脚本仍在载入、目标仍暂停时提前按键**，否则可能错过 GPIO 按键事件。

### 7.3 准备可重复的两轮输入

按如下顺序操作 TX 板：

1. 按住 **Button3** 超过 200 ms，松开；至少等待约 1 秒，检查 TX/RX 第一轮均出现 STEP 9/9。
2. 按住 **Button4** 超过 200 ms，松开；至少等待约 1 秒，检查 TX/RX 第二轮均出现 STEP 9/9。
3. 不再按键。RX 进入 `READ_PACKET ATTEMPT 3` 后停在 STEP 5/9，表示正在等待下一帧，是正常终态。

如只想重复相同输入，也可以重复按 Button3，但两种不同 payload 更便于交叉验证。

## 8. 脚本观测内容与方法边界

### 8.1 逐步骤观察点

脚本断点设置在关键写指令的**下一条指令**，打印 `[SW]` 软件动作、`[HW]` 硬件采样和 `[CHG]` 相邻采样差异。状态从一个采样点直接跳到稳定状态，不代表没有经过硬件内部瞬态状态。

| STEP | TX 动作 / 观察 | RX 动作 / 观察 |
|---|---|---|
| 1/9 | 清除 `EVENTS_READY` | 清除 `EVENTS_READY` |
| 2/9 | `TASKS_TXEN=1`，等待 TXREADY | `TASKS_RXEN=1`，等待 RXREADY |
| 3/9 | 离开 READY 轮询 | 离开 READY 轮询 |
| 4/9 | 清除 `EVENTS_END` | 清除 `EVENTS_END` |
| 5/9 | `TASKS_START=1` 开始发射 | `TASKS_START=1` 开始接收 |
| 6/9 | 离开 END 轮询，发射完成 | 离开 END 轮询，检查 `CRCSTATUS` |
| 7/9 | 清除 `EVENTS_DISABLED` | 清除 `EVENTS_DISABLED` |
| 8/9 | `TASKS_DISABLE=1` | `TASKS_DISABLE=1` |
| 9/9 | `send_packet()` 返回 | `read_packet()` 返回 |

当前脚本包含所用 AXF 对应的指令绝对地址断点。因此更换固件、修改编译优化参数或重新构建 AXF 时，必须先用反汇编检查断点与写入指令是否仍匹配；不能假定此脚本与任意 nRF52840 固件兼容。

### 8.2 RX 哨兵机制与返回值

RX 脚本每轮接收前，会通过 GDB 将数据缓冲区的 `packet[0..3]` 主动设置成 `AA AA AA AA`，用于检测射频外设到底写了多少字节：

```text
接收前     AA AA AA AA
接收 0x04  04 AA AA AA
接收 0x08  08 AA AA AA
```

这是**调试器主动修改 SRAM**，不是纯只读观测。相应日志中的 `r0=0xAAAAAA04`、`r0=0xAAAAAA08` 是原始 32 位函数返回值，不应把其高三字节解释为真实无线 payload。在本配置下，应结合 `PCNF0.LFLEN=0`、`PCNF1.STATLEN=1` 和哨兵变化判断有效 payload 是单个低字节。

日志的 `EVENTS_CRCOK`、`EVENTS_PHYEND` 等事件位可保留原始读数，但不能将某个位在多次采样时持续为 `1` 错当成每一次都新触发。尤其要核对本轮 `EVENTS_END` 清零之后重新置位。`PHYEND` 的观察不作为本实验独立 PASS 条件。

### 8.3 源码关联与 GDB 警告

如果出现类似 `..\\..\\..\\main.c: No such file or directory`，通常是 AXF 中记录的编译时源文件相对路径与当前工作目录不同；GDB 仍可根据符号和地址运行断点。需要查看对应源码行时，应先从 `arm-none-eabi-gdb` 或 AXF 调试信息核对真实源路径，再使用：

```gdb
show directories
info sources
info source
```

若掌握原始编译路径前缀，再按本机路径配置（以下是**语法示例，不是已确认的映射**）：

```gdb
set substitute-path ORIGINAL_BUILD_SOURCE_PREFIX D:/actual/source/root
```

不要机械复制其他 STM32 工程的路径映射。若提示 `could not convert '$rx_attempt'`、`could not convert '$tx_attempt'`，应保留原始警告并检查实际断点是否持续触发，不能仅凭编码警告判断收发失败。

### 8.4 清理断点与停止调试

本脚本每轮会使用链式断点管理，不需要手工补充或改写断点。若意外进入 GDB 命令提示符并需核查：

```gdb
info breakpoints
```

不要在自动采集期间执行 `delete breakpoints`，否则会破坏脚本流程。**只在结束采集之后**，可按 `Ctrl+C` 中断目标；在 GDB 提示符中执行：

```gdb
set logging enabled off
info breakpoints
delete breakpoints
detach
quit
```

以上退出顺序为通用结束操作；若 GDB 已因脚本异常退出，则直接检查现存日志。退出后再关闭 GDB Server 窗口。重新测试前可按下文归档日志，避免 `set logging overwrite on` 覆盖证据。

## 9. 预期日志、实际基准结果和验收

### 9.1 基准输出

本指南所附 `radio_tx_capture_v5.log`（404 行）及 `radio_rx_capture_v5.log`（556 行）是一次已经获得的真机运行记录。TX 两次发送、RX 两次接收均完成完整 STEP 1–9。第三个 RX 尝试正在等待下一帧。观察摘要如下：

| 轮次 | TX 按键与发送 payload | RX 有效 payload | RX CRCSTATUS | 结果 |
|---|---|---|---|---|
| 1 | Button3 → `0x04` | `0x04` | `1` | PASS |
| 2 | Button4 → `0x08` | `0x08` | `1` | PASS |
| 3 | 没有第三次 TX | `read_packet()` 等待 | 无新帧 | 等待，非 FAIL |

第一轮 RX 在 STEP 6 观测到 `EVENTS_END=1`、`CRCSTATUS=1`、`packet[0..3]=04 aa aa aa`；第二轮为 `EVENTS_END=1`、`CRCSTATUS=1`、`packet[0..3]=08 aa aa aa`。这两轮前都已分别清除 `EVENTS_END`。TX 分别以 `0x04`、`0x08` 输入完成发送。

### 9.2 独立复现检查命令

在 PowerShell 中可快速定位关键证据：

```powershell
Select-String -Path "$txDir\radio_tx_capture_v5.log" -Pattern 'BSP_EVT_HANDLER ENTRY','SEND_PACKET ENTRY','STEP 6/9','STEP 9/9','HardFault'
Select-String -Path "$rxDir\radio_rx_capture_v5.log" -Pattern 'READ_PACKET ATTEMPT','STEP 4/9','STEP 5/9','STEP 6/9','STEP 9/9','CRCSTATUS=1','HardFault'
```

实际审阅时，还需要在 STEP 4/9 与 STEP 6/9 的相邻日志块中人工核对 `EVENTS_END` 的 `1 → 0 → 1` 转换，并确认对应的 payload。单纯统计 `EVENTS_END=1` 出现次数不足以确定收包次数。

可复制两轮日志至单独目录并生成哈希：

```powershell
$archive = Join-Path $root 'radio_ground_truth_run'
New-Item -ItemType Directory -Force -Path $archive | Out-Null
Copy-Item "$rxDir\radio_rx_capture_v5.log" $archive
Copy-Item "$txDir\radio_tx_capture_v5.log" $archive
Get-FileHash "$archive\radio_rx_capture_v5.log", "$archive\radio_tx_capture_v5.log" -Algorithm SHA256
```

### 9.3 PASS / FAIL / WAIT 定义

- **PASS**：TX 和 RX 分别完成本轮 STEP 1–9；RX 在本轮清零后重新观测 `END=1`、`CRCSTATUS=1`；有效 payload 与 TX 一致；未出现 HardFault。
- **WAIT**：RX 已到 STEP 5/9 的 `STATE=3(RX)` 且没有新 TX 输入，符合接收循环的预期等待状态。
- **FAIL**：已执行 TX 发送而 RX 在合理的人工检查窗口中没有对应的新收包；或 CRC 错误、payload 不一致、出现 HardFault、断点未命中、GDB/Server 连接失败等。当前证据未提供自动超时阈值，因此不要将主观等待时间当成精确定义的时限。

## 10. 故障排查

| 现象 | 检查与处理 |
|---|---|
| `JLink.exe` / `arm-none-eabi-gdb` 找不到 | 确认安装目录并加入 `PATH`；重开 PowerShell |
| 两块板被连错 / `Cannot connect to target` | 核对板载 J-Link SN 和 USB 供电；确认同一板没有被 Commander、IDE 和 GDB Server 同时独占 |
| `target remote localhost:2331/2334` 失败 | 先启动对应 Server，核对监听端口与防火墙/端口占用 |
| GDB 提示找不到 AXF | 从含 AXF 与脚本的固件目录运行，核对脚本的 `file` 指令 |
| GDB 提示源文件不存在 | 检查 DWARF 编译路径，必要时使用 `set substitute-path`；不必因此重新烧录 |
| GDB 报 `Cannot insert breakpoint` | 检查硬件断点资源与原版脚本的链式断点；不要叠加额外断点；重新启动干净会话 |
| TX 按键无响应 | 等待脚本启动 banner 后再按，按住超过 200 ms 并释放，检查 GPIO 按键位与 `BSP_EVT_HANDLER ENTRY` |
| RX 停在 STEP 5/9 | 这是等待空中包；先核对 TX 是否确实发射，再核对两端频率、MODE、地址和 CRC 配置 |
| RX CRCSTATUS=0 | 检查射频配置一致性、供电/干扰、数据长度和 CRC 参数；不要直接判定为脚本地址错误 |
| `packet[1..3]` 保持 `0xAA` | 正常，当前固定长度只有 1 字节；这三个字节是哨兵 |
| 日志仅有部分 STEP | 先检查是否还在等待下一事件，再检查中途 HardFault、按键未触发或 GDB 断开 |
| 重跑后找不到旧日志 | 脚本开启 `set logging overwrite on`；每轮复现前归档旧日志 |
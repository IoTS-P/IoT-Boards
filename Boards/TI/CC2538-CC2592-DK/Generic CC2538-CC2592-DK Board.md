## 概述

![CC2538-CC2592-DK 开发板正面](https://raw.githubusercontent.com/maribu/images/master/CC2538-CC2592-DK-front.jpeg) ![CC2538-CC2592-DK 开发板背面](https://raw.githubusercontent.com/maribu/images/master/CC2538-CC2592-DK-back.jpeg)

通用 CC2538-CC2592-DK 开发板可以从各种供应商的[在线](https://www.aliexpress.com/wholesale?SearchText=CC2538+CC2592+development+board)[商店](https://www.ebay.com/sch/i.html?_nkw=CC2538+CC2592+development+board)购买。目前市面上价格实惠且易于获取的搭载传统 CC2538 MCU 的开发板选择较少，这是其中之一。

这些开发板似乎基于 [`@knowic`](https://github.com/knowic) 通过 [CC2538\_CC2592\_DK 仓库](https://github.com/knowic/CC2538_CC2592_DK) 提供的原理图。

## 硬件规格

| MCU | CC2538SF53 |
| --- | --- |
| 内核架构 | ARM Cortex-M3 |
| 制造商 | 德州仪器 (Texas Instruments) |
| RAM | 32 KiB |
| Flash | 512 KiB |
| 主频 | 32 MHz |
| 浮点单元 (FPU) | 无 |
| 定时器 | 4 |
| ADC | 1x 12位 (8通道) |
| UART | 2 |
| SPI | 2 |
| I2C | 1 |
| 供电电压 | 3.6 V - 5 V (MCU 通过 LDO 稳压至 3.3 V) |
| 原理图 | [开发板原理图](https://github.com/knowic/CC2538_CC2592_DK/blob/main/CC2538_CC2592_DK_1V3.pdf) |

### 原理图

![CC2538-CC2592-DK 开发板原理图](https://raw.githubusercontent.com/maribu/images/master/CC2538-CC2592-DK-schematic.svg)

[从作者仓库下载原理图](https://github.com/knowic/CC2538_CC2592_DK/blob/main/CC2538_CC2592_DK_1V3.pdf)。

## 烧录

烧录前需要进入引导加载程序。为此，按住 "SELECT" 按钮，按下 "RESET" 按钮，然后松开 "SELECT" 按钮。现在运行

```shell
BOARD=generic-cc2538-cc2592-dk make flash
```

**注意**

通过 J-Link 烧录也是可行的，传递参数 `PROGRAMMER=jlink`，但需要连接 J-Link 编程器/调试器。

## 访问终端

该开发板配备 CP2102 USB 转 UART 桥接芯片，默认用于 stdio。只需使用
```shell
BOARD=generic-cc2538-cc2592-dk make term
```

## 调试

假设已连接 J-Link（例如 J-Link EDU Mini）调试器，调试非常简单：
```shell
BOARD=generic-cc2538-cc2592-dk make debug
```

**注意**

默认使用 OpenOCD 进行调试。虽然使用 OpenOCD 调试工作正常，但烧录仅支持通过引导加载程序或 `jlink` 进行。

<table><tbody><tr><td colspan="2"><h2><a id="files" name="files"></a>文件</h2></td></tr><tr><td>文件 &nbsp;</td><td><a href="https://api.riot-os.org/generic-cc2538-cc2592-dk_2include_2board_8h.html">board.h</a></td></tr><tr><td>&nbsp;</td><td>通用 CC2538-CC2592-DK 开发板的定义。<br></td></tr><tr><td colspan="2">&nbsp;</td></tr><tr><td>文件 &nbsp;</td><td><a href="https://api.riot-os.org/generic-cc2538-cc2592-dk_2include_2gpio__params_8h.html">gpio_params.h</a></td></tr><tr><td>&nbsp;</td><td>通用 CC2538-CC2592-DK 开发板的定义。<br></td></tr><tr><td colspan="2">&nbsp;</td></tr><tr><td>文件 &nbsp;</td><td><a href="https://api.riot-os.org/boards_2generic-cc2538-cc2592-dk_2include_2periph__conf_8h.html">periph_conf.h</a></td></tr><tr><td>&nbsp;</td><td>通用 CC2538-CC2592-DK 开发板的 MCU 外设配置。<br></td></tr><tr><td colspan="2">&nbsp;</td></tr></tbody></table>
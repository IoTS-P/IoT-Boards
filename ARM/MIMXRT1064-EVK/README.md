# MIMXRT1064-EVK

The i.MX RT1064 adds to the industry’s first crossover processor series and expands the i.MX RT series to three scalable families. The i.MX RT1064 doubles the On-Chip SRAM to 1MB while keeping pin-to-pin compatibility with i.MX RT1050. This series introduces additional features ideal for real-time applications such as High-Speed GPIO, CAN FD, and synchronous parallel NAND/NOR/PSRAM controller. The i.MX RT1064 runs on the Arm® Cortex-M7® core up to 600 MHz.

## Overview

![MIMXRT1064-EVK](https://docs.zephyrproject.org/latest/_images/mimxrt1064_evk.jpg)

This board is shipped with a [MT9M114 camera module](https://www.onsemi.com/PowerSolutions/product.do?id=MT9M114) through fpc24 by default.

## Flash

I recommend to use [LinkServer](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/linkserver-for-microcontrollers:LINKERSERVER) flashing the board 

```shell
west flash --runner=linkserver
```

## Debug

ToDo

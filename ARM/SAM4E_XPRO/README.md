# SAM4E_XPRO

## Overview

The SAM4E Xplained Pro evaluation kit is a development platform to evaluate the Atmel SAM4E series microcontrollers.

![sam4e_xpro](https://docs.zephyrproject.org/latest/_images/sam4e_xpro.jpg)

> Install the zephyr SDK firstly can save you as many time as possible 

## Hardware

| MCU              | CC2538SF53                                                   |
| ---------------- | ------------------------------------------------------------ |
| Family           | ARM Cortex-M4F                                               |
| Vendor           | Atmel                                                        |
| SRAM             | 2*512k                                                       |
| FLASH            | 2Gb NAND                                                     |
| User Guide       | [Microchip](http://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-42216-SAM4E-Xplained-Pro_User-Guide.pdf) |
| Reference Manual | [DataSheet](https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ProductDocuments/DataSheets/Atmel-11157-32-bit-Cortex-M4-Microcontroller-SAM4E16-SAM4E8_Datasheet.pdf) |

## Supported Features

The sam4e_xpro board configuration supports the following hardware features:

| Interface    | Controller | Driver/Component                   |
| ------------ | ---------- | ---------------------------------- |
| NVIC         | on-chip    | nested vector interrupt controller |
| SYSTICK      | on-chip    | systick                            |
| UART         | on-chip    | serial port                        |
| USART        | on-chip    | serial port                        |
| I2C          | on-chip    | i2c                                |
| SPI          | on-chip    | spi                                |
| ETHERNET     | on-chip    | ethernet                           |
| WATCHDOG     | on-chip    | watchdog                           |
| GPIO         | on-chip    | gpio                               |
| IEEE802.15.4 | off-chip   | rf2xx over SPI                     |

The default configuration can be found in the Kconfig [boards/arm/sam4e_xpro/sam4e_xpro_defconfig](https://github.com/zephyrproject-rtos/zephyr/blob/main/boards/arm/sam4e_xpro/sam4e_xpro_defconfig).

## SHIELDS

The sam4e_xpro board can be expanded by utilizing the `EXTENSION HEADERs` via the **SPI** protocol. For example, the [shields](https://docs.zephyrproject.org/latest/boards/shields/atmel_rf2xx/doc/index.html) that contains an IEEE802.15.4 module. To activate the module, simply plug it into any of the three extension headers and include the necessary compilation options in Zephyr

## Flash

sam4e_xpro can be flashed using openocd

For example: my Zephyr-SDK is in `/data/.local/zephyr-sdk-0.16.1`, my zephyr source code is in `/data/zephyrproject/zephyr`  

```shell
/data/.local/zephyr-sdk-0.16.1/sysroots/x86_64-pokysdk-linux/usr/bin/openocd -s /data/zephyrproject/zephyr/boards/arm/sam4e_xpro/support -s /data/.local/zephyr-sdk-0.16.1/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts -f /data/zephyrproject/zephyr/boards/arm/sam4e_xpro/support/openocd.cfg '-c init' '-c targets' -c 'reset init' -c 'flash write_image erase </path/to>/<firmware>.hex' -c 'at91sam4 gpnvm set 1' -c 'reset run' -c shutdown
```

## Debug

Same as last section. The following shell command can be used to start a GDB server  

```shell
/data/.local/zephyr-sdk-0.16.1/sysroots/x86_64-pokysdk-linux/usr/bin/openocd -s /data/zephyrproject/zephyr/boards/arm/sam4e_xpro/support -s /data/.local/zephyr-sdk-0.16.1/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts -f /data/zephyrproject/zephyr/boards/arm/sam4e_xpro/support/openocd.cfg
```

## Reference

- [zephyr-SAM4E-xpro](https://docs.zephyrproject.org/latest/boards/arm/sam4e_xpro/doc/index.html)
- [zephyr-shields](https://docs.zephyrproject.org/latest/boards/shields/atmel_rf2xx/doc/index.html)
- [AT86RF233](https://www.microchip.com/en-us/development-tool/ATREB233-XPRO)
- [Microchip-sam4e_xpro](https://www.microchip.com/en-us/development-tool/atsam4e-xpro#)


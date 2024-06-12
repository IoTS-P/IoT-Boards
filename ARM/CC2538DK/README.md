# CC2538DK

The [CC2538DK](http://www.ti.com/tool/cc2538dk) is Texas Instruments' developer kit for the CC2538 SoC MCU, which combines an ARM Cortex-M3 microcontroller with an IEEE802.15.4 radio.

## Overview

* **CC2538:** 32-bit Arm Cortex-M3 Zigbee, 6LoWPAN, and IEEE 802.15.4 wireless MCU with 512kB Flash and 32kB RAM

![cc2538dk](http://www.ti.com/diagrams/cc2538dk_cc2538dk_web_1.jpg)



| MCU              | CC2538SF53                                               |
| ---------------- | -------------------------------------------------------- |
| Family           | ARM Cortex-M3                                            |
| Vendor           | Texas Instruments                                        |
| RAM              | 32KiB                                                    |
| Flash            | 512KiB                                                   |
| Frequency        | 32MHz                                                    |
| FPU              | no                                                       |
| Timers           | 4                                                        |
| ADCs             | 1x 12-bit (8 channels)                                   |
| UARTs            | 2                                                        |
| SPIs             | 2                                                        |
| I2Cs             | 1                                                        |
| Vcc              | 2V - 3.6V                                                |
| Datasheet        | [Datasheet](http://www.ti.com/lit/gpn/cc2538) (pdf file) |
| Reference Manual | [Reference Manual](http://www.ti.com/lit/pdf/swru319)    |


## Unlock Backdoor

When you first got the CC2538DK, it is in the ship mode(locked out), The bootloader will be normally executed directly after reset, if there is no valid image exists in the flash. If you want to flash your own firmware, you need to unlock the backdoor first.

1. Using [Ti Flash Programmer](https://www.ti.com/tool/download/FLASH-PROGRAMMER-2/1.8.0) to change the value at address `0x27FFD7` to `0xF3FFFFFF` 
2. Holding down the `select` button while pushing the `EM reste` button before flash

## Serial Driver 

### Linux 

```shell
sudo modprobe ftdi_sio vendor=0x403 product=0xa6d1
# switch to the root user
echo 0403 a6d1 > /sys/bus/usb-serial/drivers/ftdi_sio/new_id
```

### Windows 


## Flash

For open source codes, using [cc2538-bsl](https://github.com/JelmerT/cc2538-bsl) to flash the firmware.

1. **RIOT:** `python /path/to/cc2538-bsl/cc2538-bsl.py -p "/dev/ttyUSB<x>" --write-erase -v -b 460800 /path/to/<firmware>.bin`

2. **Contiki-NG:** `python /path/to/cc2538-bsl/cc2538-bsl.py -e -w -v -a 0x00202000 /path/to/<firmware>.bin`


## Debug

1. download the TI GDB server/agent via [XDS simulation](http://processors.wiki.ti.com/index.php/XDS_Emulation_Software_Package) 
2. The GDB server is in `/path/to/ti/common/uscif/gdb_agent_console[.exe]` 
3. Download the [AN128](http://www.ti.com/lit/zip/swra443) which contain the dat file for debug
4. unzip the downloaded AN128 zip, the dat file is `CC2538_XDS100v3c2_linux.dat`
5. open the gdb server using command:

```shell
/path/to/ti/common/uscif/gdb_agent_console /path/to/AN128/CC2538_XDS100v3c2_linux.dat
```

> use JTAG instead of USB in Segger Ozone

## References 

- [cc2538-bsl](https://github.com/JelmerT/cc2538-bsl)
- [RIOT-doc](https://doc.riot-os.org/group__boards__cc2538dk.html)
- [CC2538-Bootloader-Backdoor](https://web.archive.org/web/20170610111337/http://processors.wiki.ti.com/index.php/CC2538_Bootloader_Backdoor)
- [contiki-ng-doc](https://docs.contiki-ng.org/en/develop/doc/platforms/cc2538dk.html)
- [Debug CC2538DK](http://embedded-funk.net/debugging-cc2538dk-demo-on-windows/)
- [CC2538 Manual](https://www.ti.com/lit/pdf/swru319)

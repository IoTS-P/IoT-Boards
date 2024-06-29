# Arduino DUE


## Overview 

The arduino_due board configuration is used by Zephyr applications that run on the Arduino Due board. It provides support for the Atmel SAM3X8E ARM Cortex-M3 CPU and the following devices:

* Nested Vectored Interrupt Controller (NVIC)
* System Tick System Clock (SYSTICK)
* Serial Port over USB (ATMEL_SAM3)

More information about the board can be found at the [Arduino Due website](https://www.arduino.cc/en/Main/ArduinoBoardDue). The [Atmel SAM3X8E Datasheet](http://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-11057-32-bit-Cortex-M3-Microcontroller-SAM3X-SAM3A_Datasheet.pdf) has the information and the datasheet about the processor.

![arduino due](https://docs.zephyrproject.org/latest/_images/arduino_due.jpg)


## Hardware

### Supported Features

The arduino_due board configuration supports the following hardware features:
Other hardware features are not currently supported by the Zephyr kernel. See Arduino Due website and Atmel SAM3X8E Datasheet for a complete list of Arduino Due board hardware features.

The default configuration can be found in the Kconfig boards/arduino/due/arduino_due_defconfig.


> For I2C, pull-up resistors are required for using SCL1 and SDA1 (near IO13).

| Interface | Controller | Driver/Component                     |
| --------- | ---------- | ------------------------------------ |
| NVIC      | on-chip    | nested vectored interrupt controller |
| SYSTICK   | on-chip    | system clock                         |
| UART      | on-chip    | serial port                          |
| GPIO      | on-chip    | gpio                                 |
| I2C       | on-chip    | i2c                                  |
| Watchdog  | on-chip    | watchdog                             |

### Interrupt Controller

There are 15 fixed exceptions including exceptions 12 (debug monitor) and 15 (SYSTICK) that behave more as interrupts than exceptions. In addition, there can be a variable number of IRQs. Exceptions 7-10 and 13 are reserved. They don’t need handlers.

A Cortex-M3/4-based board uses vectored exceptions. This means each exception calls a handler directly from the vector table.

Handlers are provided for exceptions 1-6, 11-12, and 14-15. The table here identifies the handlers used for each exception.

> After a reset, all exceptions have a priority of 0. Interrupts cannot run at priority 0 for the interrupt locking mechanism and exception handling to function properly.

### System Clock

Arduino Due has two external oscillators/resonators. The slow clock is 32.768 kHz, and the main clock is 12 MHz. The processor can set up PLL to drive the master clock, which can be set as high as 84 MHz.

### Serial Port

The Atmel SAM3X8E processor has a single UART that is used by the SAM-BA bootloader. This UART has only two wires for RX/TX and does not have flow control (CTS/RTS) or FIFO. The RX/TX pins are connected to the ATmega16U2, which provides USB-to-TTL serial function. The Zephyr console output, by default, is utilizing this controller.


## Flash

### BOSSA

Flashing onto Arduino Due requires the bossa tool.

There are GUI and command line versions of the bossa tool. The following section provides the steps to build the command line version. Please refer to the bossa tool’s README file on how to build the GUI version.

To build the bossa tool, follow these steps:

1. Checkout the bossa tool’s code from the repository.

```shell
git clone https://github.com/shumatech/BOSSA.git
cd BOSSA
```

2. Checkout the arduino branch. The code on the master branch does not work with Arduino Due.

```shell
git checkout arduino
```

3. Build the command line version of the bossa tool.

```shell
make bin/bossac
```

4. The resulting binary is available at bin/bossac.

### Flashing 

1. Reset the configuration of the serial port 

```shell
stty -F </dev/ttyACM0> raw ispeed 115200 ospeed 115200 cs8 -cstopb ignpar eol 255 eof 255
```

2. flash the firmware 

```shell
bossac -p </dev/ttyACM0> -R -e -w -v -b <firmware.bin>
```

## Debug

1. JLinkGDBServer

```shell
JLinkGDBServer -select usb -port 2331 -if swd -speed 4000 -device atsam3x8e -silent -singlerun -nogui
```

2. gdb

```shell
arm-none-eabi-gdb <firmware.elf> -ex 'target remote :2331' -ex 'monitor halt' -ex 'monitor reset' -ex load -ex 'monitor reset'
```

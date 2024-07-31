# nRF52840dk



The [nRF52840 Development Kit](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html) (PCA10056) hardware provides support for the Nordic Semiconductor nRF52840 ARM Cortex-M4F CPU and the radio (Bluetooth Low Energy and 802.15.4)

## Overview

![nrf52840dk](https://docs.zephyrproject.org/latest/_images/nrf52840dk_nrf52840.jpg)

| Interface | Controller | Driver/Component      |
| --------- | ---------- | --------------------- |
| ADC       | on-chip    | adc                   |
| CLOCK     | on-chip    | clock_control         |
| FLASH     | on-chip    | flash                 |
| GPIO      | on-chip    | gpio                  |
| I2C(M)    | on-chip    | i2c                   |
| MPU       | on-chip    | arch/arm              |
| NVIC      | on-chip    | arch/arm              |
| PWM       | on-chip    | pwm                   |
| RADIO     | on-chip    | Bluetooth, ieee802154 |
| RTC       | on-chip    | system clock          |
| RTT       | Segger     | console               |
| SPI(M/S)  | on-chip    | spi                   |
| UART      | on-chip    | serial                |
| USB       | on-chip    | usb                   |
| WDT       | on-chip    | watchdog              |

More information about the board can be found at the [nRF52840 DK website](https://www.nordicsemi.com/Software-and-Tools/Development-Kits/nRF52840-DK) [6](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id17) [2](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id7). [nRF52840 Product Specification](https://docs.nordicsemi.com/bundle/ps_nrf52840/page/keyfeatures_html5.html) [7](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id20) [3](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id10) contains the processor’s information and the datasheet.

Other hardware features have not been enabled yet for this board. See [nRF52840 DK website](https://www.nordicsemi.com/Software-and-Tools/Development-Kits/nRF52840-DK) [6](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id17) [2](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id7) and [nRF52840 DK Hardware guide](https://docs.nordicsemi.com/bundle/ug_nrf52840_dk/page/UG/dk/intro.html) [8](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id23) [4](https://docs.zephyrproject.org/latest/boards/nordic/nrf52840dk/doc/index.html#id13) for a complete list of nRF52840 Development Kit board hardware features.

## Flash

If multiple NRF52 is connected to your device, use --snr to specify the id, otherwise just execute every following commands end at `-f NRF52`

get your boards id

```shell
nrfjprog --ids
```

Replace the `<id>` with the output of above command in the following commands 

**optional**: recover the board

```shell
nrfjprog --recover -f NRF52 --snr <id>
```

flash the program

```shell
nrfjprog --program <*.hex> --sectoranduicrerase --verify -f NRF52 --snr <id>
```

reset pin 

```shell
nrfjprog --pinresetenable -f NRF52 --snr <id>
nrfjprog --pinreset -f NRF52 --snr <id>
```



## Debug

open the gdb server 

```shell
JLinkGDBServer -select usb -port 2331 -if swd -speed 4000 -device nRF52840_xxAA -silent -singlerun -nogui
```

Then you can use gdb to connect the exposed port 

```shell
gdb zephyr.elf -ex 'target remote :2331' -ex 'monitor halt' -ex 'monitor reset' -ex load
```


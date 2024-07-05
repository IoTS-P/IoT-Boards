# NUCLEO_64



## Flash

#### Using openocd

```shell
openocd -s /data/zephyrproject/zephyr/boards/st/nucleo_l152re/support -s /data/.local/zephyr-sdk-0.16.8/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts -f /data/zephyrproject/zephyr/boards/st/nucleo_l152re/support/openocd.cfg '-c init' '-c targets' -c 'reset init' -c 'flash write_image erase <firmware.hex>' -c 'reset run' -c shutdown
```

#### Using st-flash

```shell
st-flash write <firmware.bin> 0x8000000
```

## Debug 

1. debug server 

```shell
/data/.local/zephyr-sdk-0.16.8/sysroots/x86_64-pokysdk-linux/usr/bin/openocd -s /data/zephyrproject/zephyr/boards/st/nucleo_l152re/support -s /data/.local/zephyr-sdk-0.16.8/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts -f /data/zephyrproject/zephyr/boards/st/nucleo_l152re/support/openocd.cfg -c 'tcl_port 6333' -c 'telnet_port 4444' -c 'gdb_port 3333' '-c init' '-c targets' '-c halt'
```

2. gdb 

```shell
arm-none-eabi-gdb -ex 'target extended-remote :3333' <firmware.elf> -ex load
```

## J-Tag

[Segger Wiki](https://wiki.segger.com/Connecting_to_STM32_Nucleo_boards)


## Q&A

1. How to solve flash failed and st-flash `Failed to enter SWD mode` ?

According to [blog](https://www.cnblogs.com/milton/p/15894662.html)

```shell
st-flash --connect-under-reset erase
```

check SWD mode

```shell
st-info --probe
```

if something like this is output 

```shell
Found 1 stlink programmers
  version:    V2J33S25
  serial:     0670FF485370514867084652
  flash:      524288 (pagesize: 256)
  sram:       81920
  chipid:     0x437
  dev-type:   STM32L1xx_Cat_5
```

The device is successfully erased, **NOW you can flash your new firmware**


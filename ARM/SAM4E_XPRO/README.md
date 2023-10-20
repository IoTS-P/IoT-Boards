# SAM4E_XPRO

Install the zephyr SDK firstly can save you as many time as possible 

## SHIELDS

the [shields](https://docs.zephyrproject.org/latest/boards/shields/atmel_rf2xx/doc/index.html) can be used to activate IEEE802.15.4 module.

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


# CC2538DK


## Unlock Backdoor

1. Using UniFlash to change the value at address `0x27FFD7` to `0xF3FFFFFF` 
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

## Reference 

- [cc2538-bsl](https://github.com/JelmerT/cc2538-bsl)
- [RIOT-doc](https://doc.riot-os.org/group__boards__cc2538dk.html)
- [CC2538-Bootloader-Backdoor](https://web.archive.org/web/20170610111337/http://processors.wiki.ti.com/index.php/CC2538_Bootloader_Backdoor)
- [contiki-ng-doc](https://docs.contiki-ng.org/en/develop/doc/platforms/cc2538dk.html)
- [Debug CC2538DK](http://embedded-funk.net/debugging-cc2538dk-demo-on-windows/)
- [CC2538 Manual](https://www.ti.com/lit/pdf/swru319)

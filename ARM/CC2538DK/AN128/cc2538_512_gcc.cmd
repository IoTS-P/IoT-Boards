/******************************************************************************
 *
 *
 * cc2538_512_gcc.cmd - Example GCC linker configuration file for CC2538
 *
 *
 *****************************************************************************/
 
MEMORY
{
    FLASH (rx) : ORIGIN = 0x200000, LENGTH = 0x0007FFD4
    FLASH_CCA (RX) : ORIGIN = 0x0027FFD4, LENGTH = 12
    SRAM_NON_RETENTION (RWX) : ORIGIN =  0x20000000, LENGTH = 0x00004000
    SRAM_RETENTION (RWX) : ORIGIN = 0x20004000, LENGTH = 0x00004000
}

SECTIONS
{
    .text :
    {
        _text = .;
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
        _etext = .;
    } > FLASH= 0
    .data : AT(ADDR(.text) + SIZEOF(.text))
    {
        _data = .;
        *(vtable)
        *(.data*)
        _edata = .;
    } > SRAM_NON_RETENTION
    .bss :
    {
        _bss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > SRAM_NON_RETENTION
    .flashcca :
    { 
    } > FLASH_CCA   
}

# STM32F103 USART2 DMA trace (no GDB Python required)
# Log: D:/stm32-trace/stm32f103_dma_trace.log
# DMA register values are printed with explicit register names.

set pagination off
set confirm off
set logging file D:/stm32-trace/stm32f103_dma_trace.log
set logging overwrite on
set logging enabled on

define dma_snapshot
  printf "PC = 0x%08x\n", $pc
  printf "SP = 0x%08x\n", $sp

  printf "\n-- USART2 registers --\n"
  printf "USART2_SR   [0x40004400] = 0x%08x\n", *(unsigned int *)0x40004400
  printf "USART2_BRR  [0x40004408] = 0x%08x\n", *(unsigned int *)0x40004408
  printf "USART2_CR1  [0x4000440C] = 0x%08x\n", *(unsigned int *)0x4000440c
  printf "USART2_CR2  [0x40004410] = 0x%08x\n", *(unsigned int *)0x40004410
  printf "USART2_CR3  [0x40004414] = 0x%08x\n", *(unsigned int *)0x40004414

  printf "\n-- DMA1 interrupt status --\n"
  set $dma_isr = *(unsigned int *)0x40020000
  printf "DMA1_ISR    [0x40020000] = 0x%08x\n", $dma_isr
  printf "DMA1_ISR flags: "
  printf "GIF6=%u TCIF6=%u HTIF6=%u TEIF6=%u; ", \
    ((*(unsigned int *)0x40020000 >> 20) & 1), \
    ((*(unsigned int *)0x40020000 >> 21) & 1), \
    ((*(unsigned int *)0x40020000 >> 22) & 1), \
    ((*(unsigned int *)0x40020000 >> 23) & 1)
  printf "GIF7=%u TCIF7=%u HTIF7=%u TEIF7=%u\n", \
    ((*(unsigned int *)0x40020000 >> 24) & 1), \
    ((*(unsigned int *)0x40020000 >> 25) & 1), \
    ((*(unsigned int *)0x40020000 >> 26) & 1), \
    ((*(unsigned int *)0x40020000 >> 27) & 1)

  printf "\n-- DMA1 Channel 6 (USART2 RX) --\n"
  printf "DMA1_CCR6   [0x4002006C] = 0x%08x\n", *(unsigned int *)0x4002006c
  printf "DMA1_CNDTR6 [0x40020070] = 0x%08x\n", *(unsigned int *)0x40020070
  printf "DMA1_CPAR6  [0x40020074] = 0x%08x\n", *(unsigned int *)0x40020074
  printf "DMA1_CMAR6  [0x40020078] = 0x%08x\n", *(unsigned int *)0x40020078

  printf "\n-- DMA1 Channel 7 (USART2 TX) --\n"
  printf "DMA1_CCR7   [0x40020080] = 0x%08x\n", *(unsigned int *)0x40020080
  printf "DMA1_CNDTR7 [0x40020084] = 0x%08x\n", *(unsigned int *)0x40020084
  printf "DMA1_CPAR7  [0x40020088] = 0x%08x\n", *(unsigned int *)0x40020088
  printf "DMA1_CMAR7  [0x4002008C] = 0x%08x\n", *(unsigned int *)0x4002008c

  printf "\n-- Firmware variables --\n"
  printf "ubTransmissionComplete = %u\n", (unsigned int)ubTransmissionComplete
  printf "ubReceptionComplete = %u\n", (unsigned int)ubReceptionComplete
  printf "num_correct = %d\n", num_correct

  printf "\n-- RX buffer (dma_buf) --\n"
  printf "dma_buf address = 0x%08x\n", (unsigned int)&dma_buf
  x/8bx &dma_buf
end

printf "\n===== TRACE SETUP =====\n"
printf "Log: D:/stm32-trace/stm32f103_dma_trace.log\n"

break StartTransfers
commands
  silent
  printf "\n===== EVENT StartTransfers ENTER =====\n"
  dma_snapshot
  continue
end

break WaitAndCheckEndOfTransfer
commands
  silent
  printf "\n===== EVENT WaitAndCheckEndOfTransfer ENTRY =====\n"
  dma_snapshot
  continue
end

break DMA1_Channel7_IRQHandler
commands
  silent
  printf "\n===== EVENT DMA1 CHANNEL7 TX IRQ ENTRY =====\n"
  dma_snapshot
  continue
end

break DMA1_Channel6_IRQHandler
commands
  silent
  printf "\n===== EVENT DMA1 CHANNEL6 RX IRQ ENTRY =====\n"
  dma_snapshot
  continue
end

break check_password
commands
  silent
  printf "\n===== EVENT check_password ENTRY =====\n"
  dma_snapshot
  continue
end

break pwcheck_success
commands
  silent
  printf "\n===== EVENT PASSWORD MATCH SUCCESS =====\n"
  dma_snapshot
  bt 5
  set logging enabled off
end

printf "\nTRACE INSTALLED. Run info breakpoints to verify all six.\n"
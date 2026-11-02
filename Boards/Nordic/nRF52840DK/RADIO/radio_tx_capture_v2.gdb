# ============================================================================
# nRF52840 RADIO transmitter —— 真机采集 v2（软写 -> 硬件反应 逐步对照）
#
# 与旧版的差别：
#   旧版断点打在"写指令本身"，停下时读到的还是写入前的状态，也不打印变化，
#   所以看不出"这条写入让硬件发生了什么"。本版把断点统一放在每条 store 的
#   **下一条指令**上（写入已生效），每次停下固定打印三块：
#
#     [SW ] 刚刚被软件写入的寄存器 / 值 / 触发它的指令地址
#     [HW ] 此刻读回的全部 RADIO 事件 + 状态 + 关键字 + packet 内容
#     [CHG] 与上一个观察点逐项对比，列出变化（没变化也会明说）
#
# 覆盖的链路：
#   按钮 -> bsp_evt_handler(0xFBC) 把按键掩码整字写进 packet(0x20000000)
#        -> 该值同时就是 packet[0] = 发送长度
#   0x2104  PACKETPTR <- 0x20000000              (main)
#   0x4556  EVENTS_READY=0   -> 观察点 0x4558
#   0x455c  TASKS_TXEN=1     -> 观察点 0x455e
#   (轮询 EVENTS_READY, 0x4560..0x4566)          -> 观察点 0x4568
#   0x456e  EVENTS_END=0     -> 观察点 0x4570
#   0x4574  TASKS_START=1    -> 观察点 0x4576
#   (轮询 EVENTS_END, 0x4578..0x4580)            -> 观察点 0x4582
#   0x45b6  EVENTS_DISABLED=0 -> 观察点 0x45b8
#   0x45bc  TASKS_DISABLE=1   -> 观察点 0x45be
#   pop {r4,r5,r6,pc}         -> 观察点 0x45ca
#
# 断点预算：Cortex-M4 FPB 只有 6 个指令断点。
#   常驻 main / bsp_evt_handler / send_packet / HardFault，其余链式武装，
#   任何时刻同时有效的断点 <= 6。每次进入 send_packet 都会重置整条链。
#
# 用法：
#   arm-none-eabi-gdb -q -x radio_tx_capture_v2.gdb
#   复用同一脚本采集仿真器：只改下面 [EDIT] 两行的端口/日志名即可（格式一致，可 diff）
#
# 注意：日志默认写到 *_v3.log，避免覆盖你已有的 v2 采集；
#      想直接覆盖旧 v2 日志就把下面的文件名改回去。
# ============================================================================

set pagination off
set confirm off
set verbose off
set print pretty off
set breakpoint pending on
set disassemble-next-line off
set print elements 64

file nrf52840_xxaa_radio_transmitter.axf
# [EDIT] 日志文件名（跑仿真器时改名，避免覆盖真机日志）
set logging file radio_tx_capture_v5.log
set logging overwrite on
set logging redirect off
set logging enabled on

# [EDIT] J-Link GDB Server 端口（仿真器 gdbstub 换成对应端口）
target remote localhost:2334
monitor reset

set $tx_attempt = 0

# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
# 统一打印：LABEL [addr] = 0xVALUE
# （不用 x/wx，否则会再把地址回显一遍，出现 [0x40001100] = 0x40001100: 0x...）
define preg
  printf "%-16s [0x%08x] = 0x%08x\n", $arg0, $arg1, *(unsigned int*)$arg1
end

# nRF52840 STATE 编码：0=Disabled 1=RxRu 2=RxIdle 3=Rx 4=RxDisable
#                       9=TxRu 10=TxIdle 11=Tx 12=TxDisable
# 打印前先把数值放进 $sv（GDB 的用户命令不能返回字符串，只能这样拼行）
define pstnm
  if $sv == 0
    printf "0(DISABLED)"
  end
  if $sv == 1
    printf "1(RXRU)"
  end
  if $sv == 2
    printf "2(RXIDLE)"
  end
  if $sv == 3
    printf "3(RX)"
  end
  if $sv == 4
    printf "4(RXDISABLE)"
  end
  if $sv == 9
    printf "9(TXRU)"
  end
  if $sv == 10
    printf "10(TXIDLE)"
  end
  if $sv == 11
    printf "11(TX)"
  end
  if $sv == 12
    printf "12(TXDISABLE)"
  end
  if $sv > 12 || ($sv > 4 && $sv < 9)
    printf "%u(UNKNOWN)", $sv
  end
end

define pstate
  set $raw = *(unsigned int*)0x40001550
  printf "STATE            [0x40001550] = 0x%08x = ", $raw
  set $sv = $raw & 15
  pstnm
  printf "\n"
end

define dump_radio_state
  printf "\n--- RADIO EVENTS ---\n"
  preg "EVENTS_READY" 0x40001100
  preg "EVENTS_ADDRESS" 0x40001104
  preg "EVENTS_PAYLOAD" 0x40001108
  preg "EVENTS_END" 0x4000110c
  preg "EVENTS_DISABLED" 0x40001110
  preg "EVENTS_DEVMATCH" 0x40001114
  preg "EVENTS_DEVMISS" 0x40001118
  preg "EVENTS_RSSIEND" 0x4000111c
  preg "EVENTS_CRCOK" 0x40001130
  preg "EVENTS_CRCERROR" 0x40001134
  preg "EVENTS_TXREADY" 0x40001154
  preg "EVENTS_PHYEND" 0x4000116c

  printf "\n--- RADIO STATUS ---\n"
  preg "CRCSTATUS" 0x40001400
  preg "RXMATCH" 0x40001408
  preg "RXCRC" 0x4000140c
  preg "DAI" 0x40001410
  preg "PDUSTAT" 0x40001414

  printf "\n--- RADIO CONTROL ---\n"
  preg "SHORTS" 0x40001200
  preg "INTENSET" 0x40001304
  preg "INTENCLR" 0x40001308
  # RADIO_IRQn = 1（bit1）；bit1=0 说明固件纯轮询，不靠 RADIO 中断
  preg "NVIC_ISER0" 0xE000E100

  printf "\n--- RADIO CONFIGURATION ---\n"
  preg "PACKETPTR" 0x40001504
  preg "FREQUENCY" 0x40001508
  preg "TXPOWER" 0x4000150c
  preg "MODE" 0x40001510
  preg "PCNF0" 0x40001514
  preg "PCNF1" 0x40001518
  preg "BASE0" 0x4000151c
  preg "BASE1" 0x40001520
  preg "PREFIX0" 0x40001524
  preg "PREFIX1" 0x40001528
  preg "TXADDRESS" 0x4000152c
  preg "RXADDRESSES" 0x40001530
  preg "CRCCNF" 0x40001534
  preg "CRCPOLY" 0x40001538
  preg "CRCINIT" 0x4000153c
  preg "TIFS" 0x40001544
  preg "DATAWHITEIV" 0x40001554
  preg "MODECNF0" 0x40001650
  pstate
end

# packet 在 0x20000000。packet[0] 的含义取决于 PCNF0.LFLEN：
#   LFLEN>0 -> packet[0] 是长度域，载荷从 packet[1] 开始
#   LFLEN=0 -> 没有长度域，packet[0] 就是 PAYLOAD[0]
# 本固件 PCNF0=0、PCNF1.STATLEN=1，所以是后者：只有 packet[0] 这 1 字节上天
define ppkt
  printf "      PACKETPTR=0x%08x  packet[0..7]=%02x %02x %02x %02x %02x %02x %02x %02x   (packet[0]=LENGTH if LFLEN>0 else PAYLOAD[0])\n", *(unsigned int*)0x40001504, *(unsigned char*)0x20000000, *(unsigned char*)0x20000001, *(unsigned char*)0x20000002, *(unsigned char*)0x20000003, *(unsigned char*)0x20000004, *(unsigned char*)0x20000005, *(unsigned char*)0x20000006, *(unsigned char*)0x20000007
end

define dump_packet
  printf "--- TX PACKET BUFFER (0x20000000) ---\n"
  ppkt
end

# ---------------------------------------------------------------------------
# 快照 / 变化对比
# ---------------------------------------------------------------------------
define psnap
  set $p_state  = *(unsigned int*)0x40001550 & 15
  set $p_ready  = *(unsigned int*)0x40001100
  set $p_addr   = *(unsigned int*)0x40001104
  set $p_pay    = *(unsigned int*)0x40001108
  set $p_end    = *(unsigned int*)0x4000110c
  set $p_dis    = *(unsigned int*)0x40001110
  set $p_crcok  = *(unsigned int*)0x40001130
  set $p_crcerr = *(unsigned int*)0x40001134
  set $p_txrdy  = *(unsigned int*)0x40001154
  set $p_phyend = *(unsigned int*)0x4000116c
  set $p_crcst  = *(unsigned int*)0x40001400
  set $p_rxcrc  = *(unsigned int*)0x4000140c
  set $p_pdu    = *(unsigned int*)0x40001414
  set $p_pptr   = *(unsigned int*)0x40001504
  set $p_pktw   = *(unsigned int*)0x20000000
end

# 与上一快照对比，只打印变化项；无变化时明确说一句，避免"看着像没反应"
define pdiff
  set $chg = 0

  set $nv = *(unsigned int*)0x40001550 & 15
  if $nv != $p_state
    printf "      [CHG] STATE          : "
    set $sv = $p_state
    pstnm
    printf "  ->  "
    set $sv = $nv
    pstnm
    printf "\n"
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001100
  if $nv != $p_ready
    printf "      [CHG] EVENTS_READY   : %u  ->  %u\n", $p_ready, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001104
  if $nv != $p_addr
    printf "      [CHG] EVENTS_ADDRESS : %u  ->  %u\n", $p_addr, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001108
  if $nv != $p_pay
    printf "      [CHG] EVENTS_PAYLOAD : %u  ->  %u\n", $p_pay, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x4000110c
  if $nv != $p_end
    printf "      [CHG] EVENTS_END     : %u  ->  %u\n", $p_end, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001110
  if $nv != $p_dis
    printf "      [CHG] EVENTS_DISABLED: %u  ->  %u\n", $p_dis, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001130
  if $nv != $p_crcok
    printf "      [CHG] EVENTS_CRCOK   : %u  ->  %u\n", $p_crcok, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001134
  if $nv != $p_crcerr
    printf "      [CHG] EVENTS_CRCERROR: %u  ->  %u\n", $p_crcerr, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001154
  if $nv != $p_txrdy
    printf "      [CHG] EVENTS_TXREADY : %u  ->  %u\n", $p_txrdy, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x4000116c
  if $nv != $p_phyend
    printf "      [CHG] EVENTS_PHYEND  : %u  ->  %u\n", $p_phyend, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001400
  if $nv != $p_crcst
    printf "      [CHG] CRCSTATUS      : %u  ->  %u\n", $p_crcst, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x4000140c
  if $nv != $p_rxcrc
    printf "      [CHG] RXCRC          : 0x%04x  ->  0x%04x\n", $p_rxcrc & 0xffff, $nv & 0xffff
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001414
  if $nv != $p_pdu
    printf "      [CHG] PDUSTAT        : 0x%08x  ->  0x%08x\n", $p_pdu, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001504
  if $nv != $p_pptr
    printf "      [CHG] PACKETPTR      : 0x%08x  ->  0x%08x\n", $p_pptr, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x20000000
  if $nv != $p_pktw
    printf "      [CHG] packet[0..3]   : 0x%08x  ->  0x%08x   (packet[0] = TX LENGTH if LFLEN>0, else PAYLOAD[0])\n", $p_pktw, $nv
    set $chg = $chg + 1
  end

  if $chg == 0
    printf "      [CHG] (none) write had no effect on any RADIO state/event\n"
  end
end

# 每次停下的统一输出：[HW] 全量现状 + [CHG] 与上一观察点的差异，然后刷新快照
define preact
  printf "[HW ] STATE="
  set $sv = *(unsigned int*)0x40001550 & 15
  pstnm
  printf "   (raw STATE=0x%08x)\n", *(unsigned int*)0x40001550
  printf "      EVENTS: READY=%u ADDRESS=%u PAYLOAD=%u END=%u DISABLED=%u CRCOK=%u CRCERROR=%u TXREADY=%u PHYEND=%u\n", *(unsigned int*)0x40001100, *(unsigned int*)0x40001104, *(unsigned int*)0x40001108, *(unsigned int*)0x4000110c, *(unsigned int*)0x40001110, *(unsigned int*)0x40001130, *(unsigned int*)0x40001134, *(unsigned int*)0x40001154, *(unsigned int*)0x4000116c
  printf "      STATUS: CRCSTATUS=%u RXCRC=0x%04x PDUSTAT=0x%08x  SHORTS=0x%08x INTENSET=0x%08x\n", *(unsigned int*)0x40001400, *(unsigned int*)0x4000140c & 0xffff, *(unsigned int*)0x40001414, *(unsigned int*)0x40001200, *(unsigned int*)0x40001304
  ppkt
  pdiff
  psnap
end

# ---------------------------------------------------------------------------
# 常驻断点（main 命中后自动禁用）
# ---------------------------------------------------------------------------
break main
set $b_main = $bpnum
commands
  silent
  printf "\n========== TX MAIN ENTRY (RADIO 还是复位值) ==========\n"
  printf "LEGEND: 0=DISABLED 1=RXRU 2=RXIDLE 3=RX 4=RXDISABLE 9=TXRU 10=TXIDLE 11=TX 12=TXDISABLE\n"
  printf "        [SW ]=软件刚写了什么  [HW ]=写入后读回的硬件状态  [CHG]=与上一观察点的差异\n"
  info registers pc sp lr xpsr
  dump_radio_state
  psnap
  disable $b_main
  continue
end

# 按键 -> bsp_evt_handler：真正把"要发包"这件事写进内存的地方
break bsp_evt_handler
set $b_evt = $bpnum
commands
  silent
  printf "\n========== BSP_EVT_HANDLER ENTRY (button event) ==========\n"
  printf "[SW ] event code in r0 = %u   (14..21 = BSP_EVENT_KEY_0..7)\n", $r0
  printf "[HW ] before: STATE="
  set $sv = *(unsigned int*)0x40001550 & 15
  pstnm
  printf ", packet[0..3]=0x%08x  PACKETPTR=0x%08x\n", *(unsigned int*)0x20000000, *(unsigned int*)0x40001504
  set $pin = *(unsigned int*)0x50000510
  printf "[BTN] P0.IN=0x%08x  BTN1(P0.11)=%u BTN2(P0.12)=%u BTN3(P0.24)=%u BTN4(P0.25)=%u   (0=pressed)\n", $pin, ($pin >> 11) & 1, ($pin >> 12) & 1, ($pin >> 24) & 1, ($pin >> 25) & 1
  psnap
  continue
end

# 0x1008 str r6,[r0] 之后：按键掩码整字写进 packet
# packet[0] 是不是长度域，取决于 PCNF0.LFLEN / PCNF1.STATLEN，这里一并打出来
break *0x100a
set $b_evt2 = $bpnum
commands
  silent
  printf "\n[EVT] [SW ] pc=0x1008  packet[0..3] <- button mask (r6 = 0x%08x)\n", $r6
  preact
  printf "           note: LFLEN=%u STATLEN=%u MAXLEN=%u -> ", *(unsigned int*)0x40001514 & 0xf, (*(unsigned int*)0x40001518 >> 8) & 0xff, *(unsigned int*)0x40001518 & 0xff
  if $r6 == 0
    printf "WARN: mask=0 (no button low when this event was handled)\n"
    printf "           WARN: packet[0] stays 0 -> main's if(packet[0]) fails -> send_packet will NOT be called.\n"
    printf "           WARN: hold the button >200ms (app_button debounce ~50ms, mask is sampled at handler entry).\n"
  else
    printf "ok: mask=0x%02x\n", $r6
  end
  if (*(unsigned int*)0x40001514 & 0xf) == 0 || ((*(unsigned int*)0x40001518 >> 8) & 0xff) != 0
    printf "payload length is FIXED (STATLEN), so packet[0] is PAYLOAD[0]\n"
  else
    printf "packet[0] is the LENGTH field, payload follows it\n"
  end
  continue
end

break send_packet
commands
  silent
  set $tx_attempt = $tx_attempt + 1
  printf "\n********************************************************************\n"
  printf "**** SEND_PACKET ENTRY #%u  (called from main, lr=0x%08x)\n", $tx_attempt, $lr
  printf "********************************************************************\n"
  info registers pc sp lr r0 r1 r2 r3 xpsr
  bt 6
  dump_radio_state
  psnap
  # 重置整条链，保证每次都从 STEP 1 开始
  disable $b_t1 $b_t2 $b_t3 $b_t4 $b_t5 $b_t6 $b_t7 $b_t8 $b_t9
  enable $b_t1 $b_t2
  continue
end

break HardFault_Handler
commands
  silent
  printf "\n========== TX HARDFAULT ==========\n"
  info registers pc sp lr xpsr r0 r1 r2 r3
  preg "CFSR" 0xE000ED28
  preg "HFSR" 0xE000ED2C
  preg "MMFAR" 0xE000ED34
  preg "BFAR" 0xE000ED38
  bt 12
  dump_radio_state
  printf "Execution remains stopped at HardFault.\n"
end

# ---------------------------------------------------------------------------
# 写入序列观察点：断点在下一条指令（写入已生效），链式武装
# ---------------------------------------------------------------------------
# STEP 1: 0x4556 EVENTS_READY = 0 之后
break *0x4558
set $b_t1 = $bpnum
commands
  silent
  printf "\n[STEP 1/9] [SW ] pc=0x4556  EVENTS_READY <- 0        (clear stale 'ramp-up done' flag)\n"
  preact
  disable $b_t1
  continue
end

# STEP 2: 0x455c TASKS_TXEN = 1 之后
break *0x455e
set $b_t2 = $bpnum
commands
  silent
  printf "\n[STEP 2/9] [SW ] pc=0x455c  TASKS_TXEN <- 1          (0x40001000, start TX ramp-up)\n"
  printf "           expect: STATE 0 -> 9(TXRU) -> 10(TXIDLE), EVENTS_READY rises when ramp-up finishes\n"
  preact
  disable $b_t2
  enable $b_t3
  continue
end

# STEP 3: EVENTS_READY 轮询退出
break *0x4568
set $b_t3 = $bpnum
commands
  silent
  printf "\n[STEP 3/9] [EV ] software left the EVENTS_READY poll at 0x4560 (READY became 1)\n"
  x/4i 0x4560
  preact
  printf "           note: TX is only ready now; nothing has been transmitted yet.\n"
  disable $b_t3
  enable $b_t4
  continue
end

# STEP 4: 0x456e EVENTS_END = 0 之后
break *0x4570
set $b_t4 = $bpnum
commands
  silent
  printf "\n[STEP 4/9] [SW ] pc=0x456e  EVENTS_END <- 0          (clear stale 'frame done' flag)\n"
  preact
  disable $b_t4
  enable $b_t5
  continue
end

# STEP 5: 0x4574 TASKS_START = 1 之后
break *0x4576
set $b_t5 = $bpnum
commands
  silent
  printf "\n[STEP 5/9] [SW ] pc=0x4574  TASKS_START <- 1         (0x40001008, transmit one frame)\n"
  printf "           expect: STATE 10(TXIDLE) -> 11(TX)\n"
  preact
  printf "           NOTE: from here the CPU spins in the EVENTS_END poll at 0x4578.\n"
  disable $b_t5
  enable $b_t6
  continue
end

# STEP 6: EVENTS_END 轮询退出 = 一帧发完
break *0x4582
set $b_t6 = $bpnum
commands
  silent
  printf "\n[STEP 6/9] [EV ] EVENTS_END poll at 0x4578 exited -> one frame transmitted\n"
  x/5i 0x4578
  preact
  printf "           note: SHORTS=0x%08x, so hardware did NOT auto-disable; it fell back to 10(TXIDLE).\n", *(unsigned int*)0x40001200
  disable $b_t6
  enable $b_t7
  continue
end

# STEP 7: 0x45b6 EVENTS_DISABLED = 0 之后
break *0x45b8
set $b_t7 = $bpnum
commands
  silent
  printf "\n[STEP 7/9] [SW ] pc=0x45b6  EVENTS_DISABLED <- 0     (clear stale 'radio off' flag)\n"
  preact
  disable $b_t7
  enable $b_t8
  continue
end

# STEP 8: 0x45bc TASKS_DISABLE = 1 之后
break *0x45be
set $b_t8 = $bpnum
commands
  silent
  printf "\n[STEP 8/9] [SW ] pc=0x45bc  TASKS_DISABLE <- 1       (0x40001010, power down radio)\n"
  printf "           expect: STATE 10(TXIDLE) -> 12(TXDISABLE) -> 0(DISABLED), EVENTS_DISABLED rises\n"
  preact
  disable $b_t8
  enable $b_t9
  continue
end

# STEP 9: pop {r4,r5,r6,pc}，send_packet 返回
break *0x45ca
set $b_t9 = $bpnum
commands
  silent
  printf "\n[STEP 9/9] [RET] send_packet returns to main (lr=0x%08x)\n", $lr
  preact
  printf "           NOTE: radio is DISABLED; main will clear packet[0] and wait for the next button.\n"
  disable $b_t9
  continue
end

disable $b_t1 $b_t2 $b_t3 $b_t4 $b_t5 $b_t6 $b_t7 $b_t8 $b_t9

printf "\n############ SESSION START (firmware=nrf52840_xxaa_radio_transmitter.axf) ############\n"
printf "TX v2 capture initialized. Log: radio_tx_capture_v5.log\n"
printf "WAIT for this banner, then press: anything pressed while the script is still loading is LOST\n"
printf "  (GPIO edge arrives before 'continue', app_button sees the pin already released -> no event).\n"
printf "Hold each button >200ms, release, wait ~1s, then press the next one.\n"
printf "Read it like this:  [SW] what firmware wrote -> [HW] what hardware did -> [CHG] what changed.\n"
printf "Press BUTTON3 on the TX board: you should see BSP_EVT_HANDLER ENTRY, then SEND_PACKET STEP 1..9.\n"
printf "Log stops after STEP 5 (STATE=11 TX) only if the radio hangs; TX normally finishes within ms.\n"
continue
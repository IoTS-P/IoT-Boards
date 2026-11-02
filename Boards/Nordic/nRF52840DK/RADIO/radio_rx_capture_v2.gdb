# ============================================================================
# nRF52840 RADIO receiver —— 真机采集 v2（软写 -> 硬件反应 逐步对照）
#
# 与旧版的差别：
#   旧版断点打在"写指令本身"(如 0x4318)，停下时读到的还是写入前的状态，
#   而且不打印变化，所以看不出"这条写入到底让硬件发生了什么"。
#   本版把断点统一放在每条 store 的**下一条指令**上（写入已经生效），
#   每次停下固定打印三块：
#
#     [SW ] 刚刚被软件写入的寄存器 / 值 / 触发它的指令地址
#     [HW ] 此刻读回的全部 RADIO 事件 + 状态 + 关键字 + packet 内容
#     [CHG] 与上一个观察点逐项对比，列出变化（没变化也会明说）
#
#   于是日志是"一条写入 -> 一条反应"的线性序列，可以直接当状态机时序读。
#
# 覆盖的写入序列（read_packet，指令级已验证）：
#   0x4312 EVENTS_READY=0 -> 观察点 0x4314
#   0x4318 TASKS_RXEN=1   -> 观察点 0x431a
#   (轮询 EVENTS_READY，0x431c..0x4322) -> 观察点 0x4324
#   0x432a EVENTS_END=0   -> 观察点 0x432c
#   0x4330 TASKS_START=1  -> 观察点 0x4332
#   (轮询 EVENTS_END，0x4334..0x433c)  -> 观察点 0x433e
#   0x4350 EVENTS_DISABLED=0 -> 观察点 0x4352
#   0x4356 TASKS_DISABLE=1   -> 观察点 0x4358
#   bx lr                    -> 观察点 0x4364
#
# 断点预算：Cortex-M4 FPB 只有 6 个指令断点。
#   常驻 main / radio_configure / read_packet / HardFault，其余链式武装，
#   任何时刻同时有效的断点 <= 6。每轮 read_packet 进入时会重置整条链。
#
# 用法：
#   arm-none-eabi-gdb -q -x radio_rx_capture_v2.gdb
#   复用同一脚本采集仿真器：只改下面 [EDIT] 两行的端口/日志名即可（格式一致，可 diff）
#
# 注意：日志默认写到 *_v5.log，避免覆盖已有的 v2 / v3 / v4 采集；
#      想直接覆盖旧日志就把下面的文件名改回去。
#
# 已知配置（真机实测）：radio_config 写入 PCNF0=0x00000000（LFLEN=0，无长度字段）、
#   PCNF1=0x01040101（STATLEN=1 静态载荷 1 字节 / MAXLEN=1 / BALEN=4 / ENDIAN=1）。
#   因此每帧只有 packet[0] 这 1 个字节会上天，packet[1..] 不会被硬件改写。
# ============================================================================

set pagination off
set confirm off
set verbose off
set print pretty off
set breakpoint pending on
set disassemble-next-line off
set print elements 64

file nrf52840_xxaa_radio_receiver.axf
# [EDIT] 日志文件名（跑仿真器时改名，避免覆盖真机日志）
set logging file radio_rx_capture_v5.log
set logging overwrite on
set logging redirect off
set logging enabled on

# [EDIT] J-Link GDB Server 端口（仿真器 gdbstub 换成对应端口）
target remote localhost:2331
monitor reset

set $rx_attempt = 0

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
  preg "EVENTS_RXREADY" 0x40001158
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

# packet 是 4 字节数组(0x20000000)，packet[0]=长度字节；多打 4 字节便于看残留
define ppkt
  printf "      PACKETPTR=0x%08x  packet[0..7]=%02x %02x %02x %02x %02x %02x %02x %02x   (packet[0]=LENGTH if LFLEN>0 else PAYLOAD[0])\n", *(unsigned int*)0x40001504, *(unsigned char*)0x20000000, *(unsigned char*)0x20000001, *(unsigned char*)0x20000002, *(unsigned char*)0x20000003, *(unsigned char*)0x20000004, *(unsigned char*)0x20000005, *(unsigned char*)0x20000006, *(unsigned char*)0x20000007
end

define dump_packet
  printf "--- RX PACKET BUFFER (0x20000000) ---\n"
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
  set $p_rxrdy  = *(unsigned int*)0x40001158
  set $p_phyend = *(unsigned int*)0x4000116c
  set $p_crcst  = *(unsigned int*)0x40001400
  set $p_rxmat  = *(unsigned int*)0x40001408
  set $p_rxcrc  = *(unsigned int*)0x4000140c
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

  set $nv = *(unsigned int*)0x40001158
  if $nv != $p_rxrdy
    printf "      [CHG] EVENTS_RXREADY : %u  ->  %u\n", $p_rxrdy, $nv
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

  set $nv = *(unsigned int*)0x40001408
  if $nv != $p_rxmat
    printf "      [CHG] RXMATCH        : %u  ->  %u\n", $p_rxmat, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x4000140c
  if $nv != $p_rxcrc
    printf "      [CHG] RXCRC          : 0x%04x  ->  0x%04x\n", $p_rxcrc & 0xffff, $nv & 0xffff
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x40001504
  if $nv != $p_pptr
    printf "      [CHG] PACKETPTR      : 0x%08x  ->  0x%08x\n", $p_pptr, $nv
    set $chg = $chg + 1
  end

  set $nv = *(unsigned int*)0x20000000
  if $nv != $p_pktw
    printf "      [CHG] packet[0..3]   : 0x%08x  ->  0x%08x\n", $p_pktw, $nv
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
  printf "      EVENTS: READY=%u ADDRESS=%u PAYLOAD=%u END=%u DISABLED=%u CRCOK=%u CRCERROR=%u RXREADY=%u PHYEND=%u\n", *(unsigned int*)0x40001100, *(unsigned int*)0x40001104, *(unsigned int*)0x40001108, *(unsigned int*)0x4000110c, *(unsigned int*)0x40001110, *(unsigned int*)0x40001130, *(unsigned int*)0x40001134, *(unsigned int*)0x40001158, *(unsigned int*)0x4000116c
  printf "      STATUS: CRCSTATUS=%u RXMATCH=%u RXCRC=0x%04x DAI=%u PDUSTAT=0x%08x  SHORTS=0x%08x INTENSET=0x%08x\n", *(unsigned int*)0x40001400, *(unsigned int*)0x40001408, *(unsigned int*)0x4000140c & 0xffff, *(unsigned int*)0x40001410, *(unsigned int*)0x40001414, *(unsigned int*)0x40001200, *(unsigned int*)0x40001304
  ppkt
  pdiff
  psnap
end

# ---------------------------------------------------------------------------
# 常量断点（常驻，共 4 个；main/radio_configure 命中后自动禁用）
# ---------------------------------------------------------------------------
break main
set $b_main = $bpnum
commands
  silent
  printf "\n========== RX MAIN ENTRY ==========\n"
  printf "LEGEND: 0=DISABLED 1=RXRU 2=RXIDLE 3=RX 4=RXDISABLE 9=TXRU 10=TXIDLE 11=TX 12=TXDISABLE\n"
  printf "        [SW ]=软件刚写了什么  [HW ]=写入后读回的硬件状态  [CHG]=与上一观察点的差异\n"
  info registers pc sp lr xpsr
  dump_radio_state
  psnap
  disable $b_main
  continue
end

break radio_configure
set $b_rcfg = $bpnum
commands
  silent
  printf "\n========== RADIO_CONFIGURE ENTRY (复位值还没被改) ==========\n"
  info registers pc sp lr r0 r1 r2 r3 xpsr
  bt 8
  dump_radio_state
  psnap
  disable $b_rcfg
  continue
end

break read_packet
commands
  silent
  set $rx_attempt = $rx_attempt + 1
  printf "\n********************************************************************\n"
  printf "**** READ_PACKET ATTEMPT %u  (called from main, lr=0x%08x)\n", $rx_attempt, $lr
  printf "********************************************************************\n"
  info registers pc sp lr r0 r1 r2 r3 xpsr
  bt 6
  dump_radio_state
  # 哨兵：预填 0xAA，之后从残留字节就能看出硬件到底覆盖了几个字节
  set {unsigned int}0x20000000 = 0xAAAAAAAA
  printf "[SW ] sentinel: packet[0..3] <- 0xAAAAAAAA (0x20000000)\n"
  psnap
  # 重置整条链，保证每轮都从 STEP 1 开始
  disable $b_r1 $b_r2 $b_r3 $b_r4 $b_r5 $b_r6 $b_r7 $b_r8 $b_r9
  enable $b_r1 $b_r2
  continue
end

break HardFault_Handler
commands
  silent
  printf "\n========== RX HARDFAULT ==========\n"
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
# STEP 1: 0x4312 EVENTS_READY = 0 之后
break *0x4314
set $b_r1 = $bpnum
commands
  silent
  printf "\n[STEP 1/9] [SW ] pc=0x4312  EVENTS_READY <- 0        (clear stale 'ramp-up done' flag)\n"
  preact
  disable $b_r1
  continue
end

# STEP 2: 0x4318 TASKS_RXEN = 1 之后
break *0x431a
set $b_r2 = $bpnum
commands
  silent
  printf "\n[STEP 2/9] [SW ] pc=0x4318  TASKS_RXEN <- 1          (0x40001004, start RX ramp-up)\n"
  printf "           expect: STATE 0 -> 1(RXRU) -> 2(RXIDLE), EVENTS_READY rises when ramp-up finishes\n"
  preact
  disable $b_r2
  enable $b_r3
  continue
end

# STEP 3: EVENTS_READY 轮询退出
break *0x4324
set $b_r3 = $bpnum
commands
  silent
  printf "\n[STEP 3/9] [EV ] software left the EVENTS_READY poll at 0x431c (READY became 1)\n"
  x/4i 0x431c
  preact
  printf "           note: if STATE is still 1(RXRU) here, ramp-up is only part-way done.\n"
  disable $b_r3
  enable $b_r4
  continue
end

# STEP 4: 0x432a EVENTS_END = 0 之后
break *0x432c
set $b_r4 = $bpnum
commands
  silent
  printf "\n[STEP 4/9] [SW ] pc=0x432a  EVENTS_END <- 0          (clear stale 'packet received' flag)\n"
  preact
  disable $b_r4
  enable $b_r5
  continue
end

# STEP 5: 0x4330 TASKS_START = 1 之后
break *0x4332
set $b_r5 = $bpnum
commands
  silent
  printf "\n[STEP 5/9] [SW ] pc=0x4330  TASKS_START <- 1         (0x40001008, enter RX and listen)\n"
  printf "           expect: STATE 2(RXIDLE) -> 3(RX)\n"
  preact
  printf "           NOTE: from here the CPU spins in the EVENTS_END poll at 0x4334.\n"
  printf "           NOTE: if this log stops here, no packet arrived yet - this is WAITING, not a fault.\n"
  disable $b_r5
  enable $b_r6
  continue
end

# STEP 6: EVENTS_END 轮询退出 = 一帧收完（或 CRC 错），固件随后判 CRCSTATUS
break *0x433e
set $b_r6 = $bpnum
commands
  silent
  printf "\n[STEP 6/9] [EV ] EVENTS_END poll at 0x4334 exited -> one frame completed\n"
  x/5i 0x4334
  preact
  printf "           firmware now checks CRCSTATUS: %u  (1 = CRC OK, 0 = CRC fail)\n", *(unsigned int*)0x40001400
  if *(unsigned int*)0x4000110c == 1 && *(unsigned int*)0x40001400 == 1
    printf "           OBSERVATION: END=1 && CRCSTATUS=1 -> frame accepted, packet[0] returned as length\n"
  else
    printf "           OBSERVATION: END/CRC condition NOT satisfied -> length 0 returned\n"
  end
  disable $b_r6
  enable $b_r7
  continue
end

# STEP 7: 0x4350 EVENTS_DISABLED = 0 之后
break *0x4352
set $b_r7 = $bpnum
commands
  silent
  printf "\n[STEP 7/9] [SW ] pc=0x4350  EVENTS_DISABLED <- 0     (clear stale 'radio off' flag)\n"
  preact
  disable $b_r7
  enable $b_r8
  continue
end

# STEP 8: 0x4356 TASKS_DISABLE = 1 之后
break *0x4358
set $b_r8 = $bpnum
commands
  silent
  printf "\n[STEP 8/9] [SW ] pc=0x4356  TASKS_DISABLE <- 1       (0x40001010, power down radio)\n"
  printf "           expect: STATE 2(RXIDLE) -> 4(RXDISABLE) -> 0(DISABLED), EVENTS_DISABLED rises\n"
  preact
  disable $b_r8
  enable $b_r9
  continue
end

# STEP 9: bx lr，read_packet 返回
break *0x4364
set $b_r9 = $bpnum
commands
  silent
  printf "\n[STEP 9/9] [RET] read_packet returns, r0 = 0x%08x  (packet[0] if CRC OK, else 0)\n", $r0
  preact
  printf "           NOTE: radio is DISABLED now; the next iteration re-runs STEP 1-9 from scratch.\n"
  disable $b_r9
  continue
end

disable $b_r1 $b_r2 $b_r3 $b_r4 $b_r5 $b_r6 $b_r7 $b_r8 $b_r9

printf "\n############ SESSION START (firmware=nrf52840_xxaa_radio_receiver.axf) ############\n"
printf "RX v2 capture initialized. Log: radio_rx_capture_v5.log\n"
printf "Read it like this:  [SW] what firmware wrote -> [HW] what hardware did -> [CHG] what changed.\n"
printf "The receiver loops read_packet() forever after reset: each attempt prints STEP 1..9.\n"
printf "Stopping after STEP 5 (STATE=3 RX) means it is waiting for a frame; press TX BUTTON3 to continue.\n"
printf "Expected on a good frame: CRCSTATUS=1, packet[0]=TX button mask, packet[1..3] stay 0xAA.\n"
printf "  (STATLEN=1 -> only 1 payload byte on air; the 0xAA tail is NOT a hardware fault.)\n"
continue
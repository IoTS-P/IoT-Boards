
In this blog, we'll explore the J-Trace streaming trace probe and walk you through setting it up with the  nRF52840-DK evaluation board to capture instruction traces.

## [What is J-Trace?](https://www.segger.com/products/debug-probes/j-trace/) 

J-Trace is a powerful streaming trace probes designed to capture complete instruction traces over infinite periods of time, enabling the recording of infrequent, hard-to-reproduce bugs. In theory, almost all ARM cortex MCUs support tracing feature. However, not all evaluation boards exporse the trace interface. For supported / tested evaluation boards, SEGGER maintains all J-Trace tested-devices list in [this page](https://www.segger.com/products/debug-probes/j-trace/technology/tested-devices/)
## [Understanding the J-Trace PinOut](https://kb.segger.com/19-pin_JTAG/SWD_and_Trace_Connector)

![Pinout](https://kb.segger.com/images/a/a9/19pinTracePort.png)

The J-Trace probe provides a 19-pin JTAG / SWD + Trace connector(0.05" / 1.27mm pitch). It connects to the target board via an 1-1 trace cable. Alternatively J-Trace can be connected via the [20-pin J-Link Connector](https://wiki.segger.com/20-pin_J-Link_Connector "20-pin J-Link Connector").

For specific details on the nRF52840-DK's trace connector, refer to this [Nordic DevZone post](https://devzone.nordicsemi.com/f/nordic-q-a/53998/trace-connector-pin-9-in-nrf52833-and-52840-dk-pca10100-and-pca10056)

**Note:**  
Never connect 19- & 20-pin cable at the same time because this may lead to unstable debug and trace connections.
![Note](https://kb.segger.com/images/thumb/4/49/190405_J-trace_connection-final.jpg/600px-190405_J-trace_connection-final.jpg)

Below we will make a detailed description about how to get instruction trace on nrf52840dk evaluation board.

## Setting Up the nRF52840-DK for J-Trace

The nRF52840-DK doesn't come with the 19-pin trace interface soldered by default, you'll need to assembled it first. Follow these steps:

1. **Solder the Pin Header**: Attach a 2x10 pin, 1.27mm pitch surface-mount pin header to the **P25** connector on the nRF52840DK.
2. **Switch to Trace Mode**: Slide the **TRACE switch (SW7)** from "Def." to "Alt."

For more details, see page 35-36 of the [nRF52840_DK_User_Guide_v1.2](https://infocenter.nordicsemi.com/pdf/nRF52840_ DK_User_Guide_v1.2.pdf) and SEGGER guide on [Tracing on nRF52840 DK](https://wiki.segger.com/Tracing_on_Nordic_Semiconductor_nRF52840) 

![nrf52840dk-jtrace](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/nrf52840dk-jtrace.jpg)

<center><b> IMPORTANT: Ensure the connector tab is oriented correctly when attaching the trace cable. </b> </center> 

> **Lab Note:** In our lab, we have two nRF52840DK boards. The one with the J-Trace sticker is pre-tested and ready to go. The other may need re-soldering.

## Capturing Instruction Traces with SEGGER Ozone

The simplest way to capture instruction trace is by utilizing SEGGER Ozone - a multi-platform debugger and performance analyzer for [J-Link](https://www.segger.com/products/debug-probes/j-link/) and [J-Trace](https://www.segger.com/products/debug-probes/j-trace/).

#### Prerequisites

* Make sure you have installed [ozone](https://www.segger.com/downloads/jlink/#Ozone), [jlink](https://www.segger.com/downloads/jlink/) software first.  
* Optionally, use the J-Link software to update your J-Trace firmware for optimal performance.

#### Step-by-Step Instructions 

1. **Download the Example Project**: Grab the [Nordic_NRF52840_Trace_Example.zip](https://kb.segger.com/images/c/ce/Nordic_nRF52840_Trace_Example.zip) and unzip it.

2. **Open the Project in Ozone**: Launch ozone and select **Open Existing Project**. Navigate to the unzipped project folder and choose the **nRF52840_Trace_Ozone.jdebug**

![ozone open](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_open.png)

3. **Connect the Hardware**: Plug the J-Trace probe into the nRF52840-DK via the 19-pin trace cable as below.
![trace plug](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/trace-plug-new.jpg)


![nrf52840dk-jtrace](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/nrf52840dk-jtrace.jpg)

<center><b> IMPORTANT: Ensure the connector tab is oriented correctly when attaching the trace cable. </b> </center> 

4. **Flash the Program:** In Ozone, click the **Download & Reset Program** button (green power icon), and select **J-Trace PRO Cortex** as the target emulator

![ozone flash](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_flash.png)

5. **View the Instruction Trace**: The trace data will appear in the left-hand window of Ozone.

![ozone all](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_trace.png)

6. **Export the Trace**:
    - Right-click in the instruction trace window and select **Export**.    
    - In the dialog, enter a very large value for **Maximum Instruction Count** such as 100G
    - Choose the output file path and name for the trace file.

![ozone trace export](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_instruction_trace_export.png)

**Export Dialog**
![ozone trace output](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_trace_output.png)

#### Understanding the Trace Output

The exported trace is saved as a CSV file in reverse order, with each line containing these items:
- **time:** Timestamp of the instruction.
- **pc:** Program counter value.
- **unknown:** Likely a register or placeholder (needs further clarification).
- **size:** Size of the instruction.
- **assembly code:** The assembly instruction executed.
- **source code:** Corresponding source code (if available).

![ozone trace csv](https://testingcf.jsdelivr.net/gh/dingiso/Files-public/img/ozone_instruction_trace_csv.png)
> TODO: what the unknown is, maybe register ?
## References
* [19-pin JTAG/SWD and Trace Connector](https://wiki.segger.com/19-pin_JTAG/SWD_and_Trace_Connector)
* [jtrace connector](https://devzone.nordicsemi.com/f/nordic-q-a/53998/trace-connector-pin-9-in-nrf52833-and-52840-dk-pca10100-and-pca10056)
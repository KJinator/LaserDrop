# Full System V0

## Features/Quirks:
- Sends data over lasers. Will handshake at beginning of every packet.
- ** Transmitter only sends data in 1kB chunks ** Afterwards, it rehandshakes
  to transmit next packet.
- ** Receiver only sends over data in 1kB chunks ** If bytes in buffer is less
  than 1kB and times out, it fills the rest with 0x01.
- There is a 128kB buffer on both the receiver and sender side.
- I think the FPGA should be able to handle read/write of 128kB through USB at
  once.
- Once FPGA thinks it saw a message on the FTDI, it will keep transmission.
  You would need to press Reset (KEY0) to restart. This may happen on startup,
  because start behavior can be weird on FTDI and FPGA side.


## CONFIGURATIONS:
- KEY0: RESET

- SW[0]: (ON)
    Turns the whole FPGA on/off.
- SW[1]: (OFF)
    Constant Receive Mode. For debug. Will send over handshaking, etc. bits.
- SW[2]: (OFF)
    Turn on to toggle both lasers.
- SW[3]: (OFF)
    Turning on forces both lasers to turn on. Will not turn off until switch
    turned off.
- SW[8:4]: (0100 for 6.25MHz transmission; 1000 for 3.125MHz)
    Sets clock divider to be used for laser transmission. Set MSB (left) to
    LSB (right), in binary.
- SW[9]: (OFF)
    Debug Mode. Ask Anju for details. Some bits overwritten to send FPGA
    information.

- HEX0/1: Last byte sent to FTDI chip.
- HEX2/3: Last byte received over lasers.
- HEX4/5: Last byte sent over lasers.

- LEDR[1:0]
    Laser_TX2/1, respectively.
- LEDR[4] 
    tx_done. Flashes for a clock cycle whenever a byte is sent over UART.
- LEDR[5]
    data_valid. Flashes for a clock cycle whenever a byte is received over UART.
- LEDR[6]
    clock_start. GPIO[33]. Ask Anju for details. Used for timer counter to get
    metrics.
- LEDR[8]
    laser_rx. What it sees on the laser receiver line.
- LEDR[9]
    wrq_empty. Lights up whenever 1k buffer on receiver is empty.


## FPGA Programming
- Open the .bat file, and press 3. Wait for it to program. Click red button
  twice to start it up.


## Wire configuration (without PCB)
- GND to GND
- All ACBUS and ADBUS pins connected from PCB to FPGA
- Laser_TX2 to Laser_RX, Laser_RX to LASER_TX2
- GPIO[33] (TX) to GPIO[35] (RX) - only needed when doing counter metrics
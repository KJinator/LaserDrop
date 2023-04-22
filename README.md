# LaserDrop
KJ Newman, Anju Ito, and Roger Lacson Senior Capstone

To compile code, run:
gcc send_library.c receive_library.c queue.c protocol_1024.c -o test -Wall -Wextra -lftd2xx -lpthread -lobjc -framework IOKit -framework CoreFoundation -Wl,-rpath /usr/local/lib -L/usr/local/lib


FPGA Configuration:
- KEY0: RESET
- SW[0]: (ON) Turns the whole FPGA on/off.
- SW[1]: (OFF) Constant Receive Mode. For debug. Will send over handshaking, etc. bits.
- SW[2]: (OFF) Turn on to toggle both lasers.
- SW[3]: (OFF) Turning on forces both lasers to turn on. Will not turn off until switch turned off.
- SW[4]: (OFF) Turn on to disable ambient light filtering.
- SW[8:5]: (0100 for 6.25MHz transmission; 1000 for 3.125MHz) Sets clock divider to be used for laser transmission. Set MSB (left) to LSB (right), in binary.
- SW[9]: (OFF) Debug Mode. Ask Anju for details. Some bits overwritten to send FPGA information.
- HEX0/1: Last byte sent to FTDI chip.
- HEX2/3: Last byte received over lasers.
- HEX4/5: Last byte sent over lasers.
More details can be found in output_files/FinalVDuty

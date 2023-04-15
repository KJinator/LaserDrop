import atexit
import time
import serial

s = serial.Serial('COM5', timeout=1)
atexit.register(s.close)


send1 = bytearray([1, 2, 3, 4, 5, 6, 7, 8])
send2 = bytearray([0xc1, 0xc2, 0xc3, 0xc4, 0x71, 0x72, 0x73, 0x74])
send3 = bytearray([0x77])
send4 = bytearray([i for i in range(256)] * 4) 

send = send2

# Write
print(s.read(100).hex())
s.write(send)
print(f"Sent {send.hex()}")
print(s.read(100).hex())
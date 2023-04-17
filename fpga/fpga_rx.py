import atexit
import time
import serial

s = serial.Serial('COM6', timeout=1)
atexit.register(s.close)

# Read
while True:
    read = s.read(1024).hex()
    num_read = len(read) // 2
    print(f"Read {read} ({num_read} bytes)")


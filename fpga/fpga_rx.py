import atexit
import time
import serial

s = serial.Serial('COM6', timeout=1)
atexit.register(s.close)

# Read
while True:
    print(f"Read {s.read(1024).hex()}")


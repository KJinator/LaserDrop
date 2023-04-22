import atexit
import time
import serial
from common import send

s = serial.Serial('COM9', timeout=1)
atexit.register(s.close)

expected = send

# Read
while True:
    read = s.read(1024).hex()
    num_read = len(read) // 2
    print(f"Read {read} ({num_read} bytes)")

    # if (num_read > 0):
    #     print(f"Read {read} ({num_read} bytes)")
    #     print("Num errors: ")
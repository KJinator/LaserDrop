import atexit
import time
import serial
from common import send

s = serial.Serial('COM10', timeout=1)
atexit.register(s.close)



print(s.read(100).hex())

# Write
# for seq in [send6]:
for seq in send:
    message = seq
    s.write(message)
    print(f"Sent {message.hex()} ({len(message)} bytes)")
    print(s.read(100).hex())

    time.sleep(2)

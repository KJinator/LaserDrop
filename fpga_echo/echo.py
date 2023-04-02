import atexit
import serial

s = serial.Serial('COM6', timeout=1)
atexit.register(s.close)

for i in range(10):
    s.write(bytearray([i]))
    print(f"Sent {bytearray([i])}, Received:", s.read())
print("Finished!")

import atexit
import serial

s = serial.Serial('COM5', timeout=1)
atexit.register(s.close)
print(s.read(100))
for i in range(10):
    send = bytearray([i])
    s.write(send)
    print(f"Sent {send}, Received:", s.read())
print(s.read(100))
print("Finished!")

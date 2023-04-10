import atexit
import time
import serial

s = serial.Serial('COM5', timeout=1)
atexit.register(s.close)

# # Read
# while True:
#     print(s.read().hex())

# # Write
# i = 0
# while True:
#     i = (i + 1) % 25
#     s.write(bytearray([i, i + 1]))
#     print("Sent!")
#     time.sleep(1)

# Echo
print(s.read(100))
for i in range(251):
    send = bytearray([i])
    s.write(send)
    read = s.read(1)
    try:
        print(f"Sent {send.hex()}, Received {read.hex()}")
    except:
        print(f"Sent {send} Received {read}")
print(s.read(100))
print("Finished!")

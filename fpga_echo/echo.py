import atexit
import time
import serial

s = serial.Serial('COM5', timeout=1)
atexit.register(s.close)

# # Read
# while True:
#     print(s.read().hex())

# # Write
while True:
    s.write(bytearray([1]))
    print("Sent!")
    time.sleep(1)

# # Echo
# print(s.read(100))
# for i in range(255):
#     send = bytearray([i])
#     s.write(send)
#     read = s.read(1)
#     try:
#         print(f"Sent {int(send.hex(), base=16)}, Received {int(read.hex(), base=16)}")
#     except:
#         print(f"Sent {send} Received {read}")
# print(s.read(100))
# print("Finished!")

import atexit
import serial

s = serial.Serial('COM5', timeout=1)
atexit.register(s.close)
print(s.read(100))
for i in range(215):
    send = bytearray([i])
    s.write(send)
    read = s.read()
    try:
        print(f"Sent {int(send.hex(), base=16)}, Received {int(read.hex(), base=16)}")
    except:
        print(f"Sent {send}, Received {read}")
    # print(f"Sent {bin(int(send.hex(), base=16))} ({int(send.hex(), base=16)}), Received {bin(int(s.read().hex(), base=16))} ({int(s.read().hex(), base=16)})")
print(s.read(100))
print("Finished!")

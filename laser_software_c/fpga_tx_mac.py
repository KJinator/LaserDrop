import pyftdi.serialext
import atexit
import time

'''
import pyftdi.ftdi as f
f.Ftdi.show_devices()
'''

s = pyftdi.serialext.serial_for_url('ftdi://ftdi:232:FT87CJN9/1', baudrate=3000000, timeout=1)
atexit.register(s.close)


send1 = bytearray([1, 2, 3, 4, 5, 6, 7, 8])
send2 = bytearray([0xc1, 0xc2, 0xc3, 0xc4, 0x71, 0x72, 0x73, 0x74])
send3 = bytearray([0x77])
send4 = bytearray([i for i in range(250)] * 4)
send5 = bytearray([0xa1, 0xa2, 0xa3, 0xa4] * (1024 // 4))
send6 = bytearray([0x51, 0x52, 0x53, 0x54] * (1024 // 4))
send7 = bytearray([0xb1, 0xb2, 0xb3, 0xb4] * (1024 // 4))
send8 = bytearray([0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8] * (1024 // 8))

send = send2
print(s.read(100).hex())

# Write
# for seq in [send6]:
for seq in [send5, send6, send7, send8]:
    message = seq
    s.write(message)
    print(f"Sent {message.hex()} ({len(message)} bytes)")
    print(s.read(100).hex())

    time.sleep(2)
import pyftdi.serialext
import atexit
import time

'''
import pyftdi.ftdi as f
f.Ftdi.show_devices()
'''

s = pyftdi.serialext.serial_for_url('ftdi://ftdi:232:FT89ZXSQ/1', baudrate=3000000, timeout=1)
atexit.register(s.close)

# Read
while True:
    read = s.read(1024).hex()
    num_read = len(read) // 2
    print(f"Read {read} ({num_read} bytes)")
# This file is executed on every boot (including wake-boot from deepsleep)
#import esp
#esp.osdebug(None)
#import webrepl
#webrepl.start()

# Early boot diagnostic - if you see this in serial output, MicroPython is running
print("boot.py: MicroPython is running, about to load main.py")

# Quick LED blink to show the board is alive before main.py loads
# This helps diagnose "solid red power LED only" situations
try:
    import machine
    _boot_led = machine.Pin(2, machine.Pin.OUT)
    _boot_led.value(1)
    import time
    time.sleep(0.1)
    _boot_led.value(0)
    del _boot_led
    print("boot.py: LED pin 2 confirmed working")
except Exception as e:
    print("boot.py: Could not blink LED -", e)

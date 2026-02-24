import machine
import time

print("main.py: Starting imports...")

try:
    import urequests
    print("  urequests OK")
except ImportError as e:
    print("  MISSING: urequests -", e)
    raise

try:
    from wifi import wifi_init
    print("  wifi OK")
except ImportError as e:
    print("  MISSING: wifi.py -", e)
    raise

try:
    from opto_control import activate_opto
    print("  opto_control OK")
except ImportError as e:
    print("  MISSING: opto_control.py -", e)
    raise

try:
    from post_request import post_request
    print("  post_request OK")
except ImportError as e:
    print("  MISSING: post_request.py -", e)
    raise

try:
    from led_control import boot_sequence_flash, BOOT_START, BOOT_WIFI_START, BOOT_WIFI_CONNECTED, BOOT_FIRST_RESPONSE
    print("  led_control OK")
except ImportError as e:
    print("  MISSING: led_control.py -", e)
    raise

try:
    from config import (
        OPTO_PIN,
        BUTTON_PIN,
        POST_INTERVAL,
    )
    print("  config OK")
except ImportError as e:
    print("  MISSING: config.py -", e)
    raise

print("main.py: All imports successful")

try:
    # Boot sequence - Stage 1: Program starts loading
    boot_sequence_flash(BOOT_START)

    # Initialize hardware
    opto = machine.Pin(OPTO_PIN, machine.Pin.OUT)
    button = machine.Pin(BUTTON_PIN, machine.Pin.IN, machine.Pin.PULL_UP)

    # Global flag for button press
    should_trigger = False
    # Flag for tracking first successful post response
    first_post_response_received = False

    def button_isr(pin):
        try:
            global should_trigger
            should_trigger = True
        except Exception as e:
            print("Button handler error")

    # Set up button interrupt
    button.irq(trigger=machine.Pin.IRQ_FALLING, handler=button_isr)

    # Boot sequence - Stage 2: Starting to connect to WiFi
    boot_sequence_flash(BOOT_WIFI_START)

    # Connect to WiFi
    wifi_init()

    # Boot sequence - Stage 3: WiFi connected
    boot_sequence_flash(BOOT_WIFI_CONNECTED)

    # Initialize timing variables
    last_post_time = 0
    error_count = 0

    print("Device ready and running!")

    # Main loop
    while True:
        try:
            now = time.ticks_ms()

            # Periodic server check-in
            if time.ticks_diff(now, last_post_time) >= POST_INTERVAL:
                try:
                    response_code, response_body = post_request()
                    print("Server responded:", response_code)

                    # Boot sequence - Stage 4: First successful server response
                    if response_code == 200 and not first_post_response_received:
                        first_post_response_received = True
                        boot_sequence_flash(BOOT_FIRST_RESPONSE)

                    if response_code == 200:
                        activate_opto(opto)
                    last_post_time = now
                    error_count = 0  # Reset error counter on successful communication
                except Exception as e:
                    print("Error communicating with server")
                    error_count += 1
                    # If too many errors, try to reconnect WiFi
                    if error_count > 10:
                        print("Too many errors - reconnecting WiFi")
                        try:
                            wifi_init()
                        except:
                            pass
                        error_count = 0

            # Handle button press
            if should_trigger:
                try:
                    print("Button pressed")
                    activate_opto(opto)
                    # Debounce button
                    while button.value() == 0:
                        time.sleep(0.02)
                    should_trigger = False
                except Exception as e:
                    print("Error handling button press")
                    should_trigger = False

            # Small delay to prevent CPU overload
            time.sleep(0.01)

        except Exception as e:
            print("Main loop error - will continue")
            time.sleep(1)  # Delay to prevent rapid error loops

except Exception as e:
    # Critical error handling
    print("Critical error in main program - restarting in 10 seconds")
    time.sleep(10)
    machine.reset()


from time import sleep

from picamera2 import Picamera2
import RPi.GPIO as GPIO


def main():
    p = Picamera2()
    p.start_and_capture_file("/out/test.jpg")

    GPIO.setmode(GPIO.BCM)
    GPIO.setup(16, GPIO.OUT)
    GPIO.output(16, True)
    sleep(1)
    GPIO.cleanup()


if __name__ == '__main__':
    main()

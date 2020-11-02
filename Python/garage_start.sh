#!/bin/bash

# disabling wifi power management
printf "\nDisabling WiFi Power Management...\n"
/sbin/iwconfig wlan0 power off

# run Garage Door App using provided certificates
printf "\nRunning Garage Door Application...\n"
python $AWS_IOT_PYTHON_CMD_OPTIONS &
python ./ble-uart-peripheral/uart_peripheral.py &

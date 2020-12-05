#!/bin/bash

# disabling wifi power management
printf "\nDisabling WiFi Power Management...\n"
/sbin/iwconfig wlan0 power off

# run Garage Door App using provided certificate (included in python .env)s
printf "\nRunning Garage Door Application...\n"
# just run the script with no parameters
# parameters are included in python .env file
python3 awsiot_garage.py &
printf "\nRunning BLE UART peripheral application..\n"
sleep 5
python3 ./ble-uart-peripheral/uart_peripheral.py &

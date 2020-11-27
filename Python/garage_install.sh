#!/bin/bash

printf "Starting Script...\n"

# stop script on error
set -e

# Add the daily/nightly reset job to crontab - this will overwrite anything in the crontab
# This will include all cron files with extension .d
printf "\nUpdating crontab to update code and reset receiver every night...\n"
cat *.d | sudo crontab -

# Install ansible libraries for nightly code provisioning updates
printf "\nUpdating Ansible libraries for nightly code provisioning...\n"
sudo apt-get update
sudo apt-get install ansible --fix-missing

# Turn off wifi power management on wlan0
printf "\nDisabling WiFi Power Management on wlan0...\n"
sudo iwconfig wlan0 power off

# Check to see if user downloaded the AWS start.sh file to the python directory
if [ ! -f ./start.sh ]; then
	printf "\nstart.sh not found. Please download from AWS....\n"
	exit 0
else
	printf "\nNeed to remove any extra newlines at EOF if they exist...\n"
	while [ -z "$(tail -c 1 start.sh)" ]
	do
		printf "Newline found at end of file...\n"
		head -c -1 start.sh > start.tmp
		mv start.tmp start.sh
	done
	printf "\nExtracting Credentials from AWS start.sh file...\n"
	# The credentials that we are looking for are located after the call to the python function in the AWS start.sh file
	# grep appears to be more stable than the previous while loop
	AWSINFO="$(grep -o ".py -e.*" start.sh)"
fi

# Check to see if root CA file exists, download if not
if [ ! -f ./root-CA.crt ]; then
  printf "\nDownloading AWS IoT Root CA certificate from AWS...\n"
  curl https://www.amazontrust.com/repository/AmazonRootCA1.pem > root-CA.crt
else
  printf "Checking to see if there is data...\n"
  # Check to see if root CA file has data
  if [ -s "root-CA.crt" ]; then
    printf "Existing root-CA.crt is not empty...\n"
  else
    rm root-CA.crt
    # Update CA Certificates
    sudo update-ca-certificates --fresh
    # Re download AWS IoT Root CA certificate
    curl https://www.amazontrust.com/repository/AmazonRootCA1.pem > root-CA.crt
  fi
  printf "Finished checking certificates...\n"
fi

# Provide write access to python dist-packages directory. This is needed to install python libraries here.
sudo chmod -R 777 /usr/local/lib/python2.7/dist-packages/

# install AWS Device SDK for Python if not already installed
if [ ! -d /usr/local/lib/python2.7/dist-packages/AWSIoTPythonSDK ]; then
  printf "\nInstalling AWS SDK...\n"
  git clone https://github.com/aws/aws-iot-device-sdk-python.git
  pushd aws-iot-device-sdk-python
  python setup.py install
  popd
fi

# It appears that Raspbian Stretch comes pre-installed with bluez 5.43 but we still need to install python-bluez
# lets check if it is installed and only try to install if not using bluez 5.43
BT_VERSION="$(sudo /usr/sbin/bluetoothd -v)"

if (( $(awk 'BEGIN {print ("'$BT_VERSION'" >= 5.43)}') )); then
	printf "Bluez 5.43+ already installed...\n"
	printf "Checking to see if bluez is correctly installed...\n"
	if [ ! -d /usr/lib/python2.7/dist-packages/bluetooth/bluez.py ]; then
		printf "Bluez was not correctly installed...\n"
		sudo apt-get install python-bluez
	fi
else
	printf "Installing latest version of Bluez...\n"
	sudo apt-get install python-bluez
fi

# set bluetooth capabilities for python to get the code to run without sudo
printf "Setting Bluetooth Capabilities to run without sudo...\n"
sudo setcap 'cap_net_raw,cap_net_admin+eip' /usr/bin/python2.7

# install dotenv code to load environment variables into python
# Need to do for both user and sudo since script runs as root
printf "Installing python-dotenv libraries...\n"
sudo pip install python-dotenv
pip install python-dotenv

sudo python3 -m pip install python-dotenv
python3 -m pip install python-dotenv

# Install I2C-Tools and SMBUS for LCD
sudo apt-get install i2c-tools
sudo apt-get install python-smbus

# Update environment variables
# from stackoverflow.com/questions/19331497/set-environment-variables-from-file-of-key-value-pairs
#
# This will read values from the .env file so you will need to have a .env present
set -o allexport
eval $(grep -v '^#' .env | sed 's/^/export /')
set +o allexport

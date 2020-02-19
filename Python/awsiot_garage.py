''' /*
 * Copyright 2010-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */
 '''

from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTClient
import logging
import time
import argparse
import json
import RPi.GPIO as GPIO
import i2c_lcd_driver
import socket
import fcntl
import struct
import os
from dotenv import load_dotenv
load_dotenv()

AllowedActions = ['both', 'publish', 'subscribe']
LCD_DISPLAY_DELAY = 3
GARAGE_SHUT_VALUE = 1
DISPLAY_TIMER_THRESHOLD = 10
CODE_VERSION = "1.3"

def get_ip_addr():
	try:
		ip_addr = (([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith("127.")]
				or [[(s.connect(("8.8.8.8", 53)), s.getsockname()[0], s.close())
				for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]]) + ["no IP found"])[0]
	except:
		ip_addr = "0.0.0.0"
	return ip_addr

def setup_GPIO():
	GPIO.setmode(GPIO.BCM)
	GPIO.setwarnings(False)
	GPIO.setup(17,GPIO.OUT, initial=True)
	GPIO.setup(27,GPIO.OUT, initial=True)
	GPIO.setup(22,GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
	GPIO.output(17,GPIO.HIGH)

def get_garage_status(garage_num):
	return GPIO.input(garage_num)

def initialize_garage(myClient, topic):
	garage1_status = get_garage_status(22)
	garage2_status = get_garage_status(22)

	myClient.publish(topic, "{\"state\":{\"reported\":{\"garage1_status\":\""+str(garage1_status)+"\",\"garage2_status\":\""+str(garage2_status)+"\"}}}",0)
	return garage1_status, garage2_status

# Custom MQTT message callback
def customCallback(client, userdata, message):
	global InitialGPIOSetup
	print("Received a new message: ")
	print(message.payload)
	print("from topic: ")
	print(message.topic)
	print("--------------\n\n")

	if message.topic == topic:
		# Setup the GPIO pins the first time one attempts to open/close garage
		# This resolves a previous issue where the power cycle caused the GPIOs
		# to go from HIGH to LOW --> end result is that garage opens/closes when
		# the power cycles
		if InitialGPIOSetup == True:
			setup_GPIO()
			InitialGPIOSetup = False
		json_msg = json.loads(message.payload.decode())
		if json_msg["state"]["reported"]["ON_OFF"] == "ON":
			print "GPIO HIGH"
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.HIGH)
		elif json_msg["state"]["reported"]["ON_OFF"] == "OFF":
			print "GPIO LOW"
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.LOW)
		elif json_msg["state"]["reported"]["ON_OFF"] == "TOGGLE":
			lcd_block = True
			mylcd.lcd_clear()
			mylcd.lcd_display_string("Toggle "+str(json_msg["state"]["reported"]["GPIO"]), 1)
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.LOW)
			time.sleep(0.2)
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.HIGH)
			time.sleep(LCD_DISPLAY_DELAY)
			lcd_block = False
		elif json_msg["state"]["reported"]["ON_OFF"] == "REQUEST_STATUS":
			print "GETTING STATUS"
			lcd_block = True
			mylcd.lcd_clear()
			garagenumber = int(json_msg["state"]["reported"]["GPIO"])
			mylcd.lcd_display_string("Garage {} Status".format(garagenumber), 1)
			garagestatus = GPIO.input(garagenumber)
			if garagestatus == 1:
				myAWSIoTMQTTClient.publish("Garage","{\"state\":{\"reported\":{\"ON_OFF\":\"UPDATE_STATUS\",\"DATA\":\"SHUT\"}}}",0)
				mylcd.lcd_display_string("Shut",2)
			else:
				myAWSIoTMQTTClient.publish("Garage","{\"state\":{\"reported\":{\"ON_OFF\":\"UPDATE_STATUS\",\"DATA\":\"OPEN\"}}}",0)
				mylcd.lcd_display_string("Open",2)
			time.sleep(LCD_DISPLAY_DELAY)
			lcd_block = False
# Read in command-line parameters
parser = argparse.ArgumentParser()
parser.add_argument("-e", "--endpoint", action="store", required=True, dest="host", help="Your AWS IoT custom endpoint")
parser.add_argument("-r", "--rootCA", action="store", required=True, dest="rootCAPath", help="Root CA file path")
parser.add_argument("-c", "--cert", action="store", dest="certificatePath", help="Certificate file path")
parser.add_argument("-k", "--key", action="store", dest="privateKeyPath", help="Private key file path")
parser.add_argument("-p", "--port", action="store", dest="port", type=int, help="Port number override")
parser.add_argument("-w", "--websocket", action="store_true", dest="useWebsocket", default=False,
                    help="Use MQTT over WebSocket")
parser.add_argument("-id", "--clientId", action="store", dest="clientId", default="garage",
                    help="Targeted client id")
parser.add_argument("-t", "--topic", action="store", dest="topic", default="Garage", help="Targeted topic")
parser.add_argument("-m", "--mode", action="store", dest="mode", default="both",
                    help="Operation modes: %s"%str(AllowedActions))
parser.add_argument("-M", "--message", action="store", dest="message", default="Hello World!",
                    help="Message to publish")

args = parser.parse_args()
host = args.host
rootCAPath = args.rootCAPath
certificatePath = args.certificatePath
privateKeyPath = args.privateKeyPath
port = args.port
useWebsocket = args.useWebsocket
clientId = args.clientId
update_topic = os.getenv("AWS_SHADOW_UPDATE_TOPIC")
topic = args.topic

if args.mode not in AllowedActions:
    parser.error("Unknown --mode option %s. Must be one of %s" % (args.mode, str(AllowedActions)))
    exit(2)

if args.useWebsocket and args.certificatePath and args.privateKeyPath:
    parser.error("X.509 cert authentication and WebSocket are mutual exclusive. Please pick one.")
    exit(2)

if not args.useWebsocket and (not args.certificatePath or not args.privateKeyPath):
    parser.error("Missing credentials for authentication.")
    exit(2)

# Port defaults
if args.useWebsocket and not args.port:  # When no port override for WebSocket, default to 443
    port = 443
if not args.useWebsocket and not args.port:  # When no port override for non-WebSocket, default to 8883
    port = 8883

# Configure logging
logger = logging.getLogger("AWSIoTPythonSDK.core")
logger.setLevel(logging.ERROR)
streamHandler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
streamHandler.setFormatter(formatter)
logger.addHandler(streamHandler)

# Init AWSIoTMQTTClient
myAWSIoTMQTTClient = None
if useWebsocket:
    myAWSIoTMQTTClient = AWSIoTMQTTClient(clientId, useWebsocket=True)
    myAWSIoTMQTTClient.configureEndpoint(host, port)
    myAWSIoTMQTTClient.configureCredentials(rootCAPath)
else:
    myAWSIoTMQTTClient = AWSIoTMQTTClient(clientId)
    myAWSIoTMQTTClient.configureEndpoint(host, port)
    myAWSIoTMQTTClient.configureCredentials(rootCAPath, privateKeyPath, certificatePath)

# AWSIoTMQTTClient connection configuration
myAWSIoTMQTTClient.configureAutoReconnectBackoffTime(1, 32, 20)
myAWSIoTMQTTClient.configureOfflinePublishQueueing(-1)  # Infinite offline Publish queueing
myAWSIoTMQTTClient.configureDrainingFrequency(2)  # Draining: 2 Hz
myAWSIoTMQTTClient.configureConnectDisconnectTimeout(10)  # 10 sec
myAWSIoTMQTTClient.configureMQTTOperationTimeout(5)  # 5 sec

# Connect and subscribe to AWS IoT
myAWSIoTMQTTClient.connect()

if args.mode == 'both' or args.mode == 'subscribe':
    myAWSIoTMQTTClient.subscribe(topic, 1, customCallback)
time.sleep(2)

setup_GPIO()
mylcd = i2c_lcd_driver.lcd()
lcd_block = False

# Initialize Garage Door
garage1_status, garage2_status = initialize_garage(myAWSIoTMQTTClient, update_topic)

#clear the lcd screen
mylcd.lcd_clear()

mylcd.lcd_display_string("IP Address:", 1)
mylcd.lcd_display_string(get_ip_addr(),2)
time.sleep(3)

mylcd.lcd_clear()
mylcd.lcd_display_string("Garage 1: %s" %garage1_status, 1)
mylcd.lcd_display_string("Garage 2: %s" %garage2_status, 2)
time.sleep(4)

ipaddr = get_ip_addr()
ip_timer = 0

InitialGPIOSetup = True

# The main loop just sleeps
while True:
	if lcd_block == False:
		mylcd.lcd_display_string("Time: %s" %time.strftime("%H:%M:%S"), 1)
		mylcd.lcd_display_string("Date: %s" %time.strftime("%m/%d/%Y"), 2)
		time.sleep(1)
		if ip_timer >= DISPLAY_TIMER_THRESHOLD:
			mylcd.lcd_clear()
			mylcd.lcd_display_string("IP: %s" %ipaddr, 1)
			mylcd.lcd_display_string("Version: %s" %CODE_VERSION, 2)
			time.sleep(3)
			mylcd.lcd_clear()
			ip_timer = 0
		else:
			ip_timer = ip_timer + 1
	else:
		time.sleep(2)

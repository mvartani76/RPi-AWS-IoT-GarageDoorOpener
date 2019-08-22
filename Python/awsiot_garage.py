'''
/*
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

AllowedActions = ['both', 'publish', 'subscribe']

def setup_GPIO():
	GPIO.setmode(GPIO.BCM)
	GPIO.setwarnings(False)
	GPIO.setup(17,GPIO.OUT, initial=True)
	GPIO.setup(27,GPIO.OUT, initial=True)
	GPIO.setup(22,GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
	GPIO.output(17,GPIO.HIGH)

# Custom MQTT message callback
def customCallback(client, userdata, message):
	global InitialGPIOSetup
	print("Received a new message: ")
	print(message.payload)
	print("from topic: ")
	print(message.topic)
	print("--------------\n\n")

	if message.topic == "Garage":
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
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.LOW)
			time.sleep(0.2)
			GPIO.output(int(json_msg["state"]["reported"]["GPIO"]),GPIO.HIGH)
		elif json_msg["state"]["reported"]["ON_OFF"] == "REQUEST_STATUS":
			print "GETTING STATUS"
			garagestatus = GPIO.input(int(json_msg["state"]["reported"]["GPIO"]))
			if garagestatus == 1:
				myAWSIoTMQTTClient.publish("Garage","{\"state\":{\"reported\":{\"ON_OFF\":\"UPDATE_STATUS\",\"DATA\":\"SHUT\"}}}",0)
			else:
				myAWSIoTMQTTClient.publish("Garage","{\"state\":{\"reported\":{\"ON_OFF\":\"UPDATE_STATUS\",\"DATA\":\"OPEN\"}}}",0)

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
logger.setLevel(logging.DEBUG)
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

InitialGPIOSetup = True

# The main loop just sleeps
while True:
    time.sleep(1)

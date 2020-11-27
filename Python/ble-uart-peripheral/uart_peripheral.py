import sys
import dbus, dbus.mainloop.glib
from gi.repository import GLib
from example_advertisement import Advertisement
from example_advertisement import register_ad_cb, register_ad_error_cb
from example_gatt_server import Service, Characteristic
from example_gatt_server import register_app_cb, register_app_error_cb
import RPi.GPIO as GPIO
import time

BLUEZ_SERVICE_NAME =           'org.bluez'
DBUS_OM_IFACE =                'org.freedesktop.DBus.ObjectManager'
LE_ADVERTISING_MANAGER_IFACE = 'org.bluez.LEAdvertisingManager1'
GATT_MANAGER_IFACE =           'org.bluez.GattManager1'
GATT_CHRC_IFACE =              'org.bluez.GattCharacteristic1'
UART_SERVICE_UUID =            '6e400001-b5a3-f393-e0a9-e50e24dcca9e'
UART_SLIDER1_RX_CHARACTERISTIC_UUID =  '6e400002-b5a3-f393-e0a9-e50e24dcca9e'
UART_SLIDER2_RX_CHARACTERISTIC_UUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'
UART_SLIDER3_RX_CHARACTERISTIC_UUID = '6e400004-b5a3-f393-e0a9-e50e24dcca9e'
UART_BUTTON_RX_CHARACTERISTIC_UUID = '6e400005-b5a3-f393-e0a9-e50e24dcca9e'
UART_TX_CHARACTERISTIC_UUID =  '6e400006-b5a3-f393-e0a9-e50e24dcca9e'

GARAGE1TOGGLE_BTVALUE = 25
GARAGE2TOGGLE_BTVALUE = 50
REQUESTGARAGE1STATUS_BTVALUE = 75
REQUESTGARAGE2STATUS_BTVALUE = 100

LOCAL_NAME = 'garagepi-gatt-server'
mainloop = None

def setup_GPIO():
	GPIO.setmode(GPIO.BCM)
	GPIO.setwarnings(False)
	GPIO.setup(17,GPIO.OUT, initial=True)
	GPIO.setup(27,GPIO.OUT, initial=True)
	GPIO.setup(22,GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
	GPIO.output(17,GPIO.HIGH)

class TxCharacteristic(Characteristic):
    def __init__(self, bus, index, service):
        Characteristic.__init__(self, bus, index, UART_TX_CHARACTERISTIC_UUID,
                                ['notify'], service)
        self.notifying = False
        GLib.io_add_watch(sys.stdin, GLib.IO_IN, self.on_console_input)

    def on_console_input(self, fd, condition):
        s = fd.readline()
        if s.isspace():
            pass
        else:
            self.send_tx(s)
        return True

    def send_tx(self, s):
        if not self.notifying:
            return
        value = []
        for c in s:
            print(c)
            value.append(dbus.Byte(c.encode()))
        self.PropertiesChanged(GATT_CHRC_IFACE, {'Value': value}, [])

    def StartNotify(self):
        if self.notifying:
            return
        self.notifying = True

    def StopNotify(self):
        if not self.notifying:
            return
        self.notifying = False

class RxCharacteristic(Characteristic):
    def __init__(self, bus, index, param_uuid, service):
        Characteristic.__init__(self, bus, index, param_uuid,
                                ['read','write','write-without-response','notify','authorize'], service)
        self.notifying = False

    def send_tx(self, s):
        if not self.notifying:
            return
        value = []
        for c in s:
            print(c)
            value.append(dbus.Byte(c.encode()))
        self.PropertiesChanged(GATT_CHRC_IFACE, {'Value': value}, [])

    def WriteValue(self, value, options):
	# convert value into UInt8
        temp = [hex(c) for c in value]
        int8Value = int(temp[0],0)
        print("uuid: %s value: %s " % (self.uuid, int8Value))

        if int8Value == GARAGE1TOGGLE_BTVALUE:
            print("Garage 1 toggle")
            GPIO.output(17, GPIO.LOW)
            time.sleep(0.2)
            GPIO.output(17, GPIO.HIGH)
            time.sleep(3)
        elif int8Value == GARAGE2TOGGLE_BTVALUE:
            print("Garage 2 toggle")
            GPIO.output(27, GPIO.LOW)
            time.sleep(0.2)
            GPIO.output(27, GPIO.HIGH)
            time.sleep(3)
        elif int8Value == REQUESTGARAGE1STATUS_BTVALUE:
            print("garage 1 status")
            garagestatus = GPIO.input(17)
            if garagestatus == 1:
                self.send_tx("Garage 1 is Closed")
            else:
                self.send_tx("Garage 1 is Open")
        elif int8Value == REQUESTGARAGE2STATUS_BTVALUE:
            print("garage 2 status")
            garagestatus = GPIO.input(27)
            if garagestatus == 1:
                self.send_tx("Garage 2 is Open")
            else:
                self.send_tx("Garage 2 is Closed")
            TxCharacteristic.send_tx(garagestatus)
        else:
            print("Invalid Command.")

    def StartNotify(self):
        if self.notifying:
            return
        self.notifying = True

    def StopNotify(self):
        if not self.notifying:
            return
        self.notifying = False

class UartService(Service):
    def __init__(self, bus, index):
        Service.__init__(self, bus, index, UART_SERVICE_UUID, True)
        self.add_characteristic(RxCharacteristic(bus, 1, UART_SLIDER1_RX_CHARACTERISTIC_UUID, self))
        self.add_characteristic(RxCharacteristic(bus, 2, UART_SLIDER2_RX_CHARACTERISTIC_UUID, self))
        self.add_characteristic(RxCharacteristic(bus, 3, UART_SLIDER3_RX_CHARACTERISTIC_UUID, self))
        self.add_characteristic(RxCharacteristic(bus, 4, UART_BUTTON_RX_CHARACTERISTIC_UUID, self))
        self.add_characteristic(TxCharacteristic(bus, 5, self))

class Application(dbus.service.Object):
    def __init__(self, bus):
        self.path = '/'
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service(self, service):
        self.services.append(service)

    @dbus.service.method(DBUS_OM_IFACE, out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            chrcs = service.get_characteristics()
            for chrc in chrcs:
                response[chrc.get_path()] = chrc.get_properties()
        return response

class UartApplication(Application):
    def __init__(self, bus):
        Application.__init__(self, bus)
        self.add_service(UartService(bus, 0))

class UartAdvertisement(Advertisement):
    def __init__(self, bus, index):
        Advertisement.__init__(self, bus, index, 'peripheral')
        self.add_service_uuid(UART_SERVICE_UUID)
        self.add_local_name(LOCAL_NAME)
        self.include_tx_power = True

def find_adapter(bus):
    remote_om = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, '/'),
                               DBUS_OM_IFACE)
    objects = remote_om.GetManagedObjects()
    # check python version --> use objects.items() if python3
    # else use objects.iteritems()
    if sys.version_info[:3] > (3,0):
        for o, props in objects.items():
            if LE_ADVERTISING_MANAGER_IFACE in props and GATT_MANAGER_IFACE in props:
                return o
            print('Skip adapter:', o)
        return None
    else:
        for o, props in objects.iteritems():
            if LE_ADVERTISING_MANAGER_IFACE in props and GATT_MANAGER_IFACE in props:
                return o
            print('Skip adapter:', o)
        return None

def main():
    global mainloop
    setup_GPIO()
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    adapter = find_adapter(bus)
    if not adapter:
        print('BLE adapter not found')
        return

    service_manager = dbus.Interface(
                                bus.get_object(BLUEZ_SERVICE_NAME, adapter),
                                GATT_MANAGER_IFACE)
    ad_manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, adapter),
                                LE_ADVERTISING_MANAGER_IFACE)

    app = UartApplication(bus)
    adv = UartAdvertisement(bus, 0)

    mainloop = GLib.MainLoop()

    service_manager.RegisterApplication(app.get_path(), {},
                                        reply_handler=register_app_cb,
                                        error_handler=register_app_error_cb)
    ad_manager.RegisterAdvertisement(adv.get_path(), {},
                                     reply_handler=register_ad_cb,
                                     error_handler=register_ad_error_cb)
    try:
        mainloop.run()
    except KeyboardInterrupt:
        adv.Release()
 
if __name__ == '__main__':
    main()

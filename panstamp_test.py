#!/usr/bin/env python

import thread, sys, time, pprint, binascii, thread

from SerialModem import SerialModem
from CcPacket import CcPacket
from signal import *

isRunning = True

def signal_handler(signal, frame):  #nicely shut things down
    print "Exiting..."
    modem.stop()
    global isRunning
    isRunning = False
    exit
    
def _ccPacketReceived(ccPacket):
    print "got ccpacket: " + ccPacket.toString()
    print "raw: " + chr(ccPacket.data[0])

def read_from_stdin():
    while isRunning:
        print "Writing a character"
        b = 'F'
        if len(b) == 1:
            modem.sendCcPacket(CcPacket('(CAFE)' + binascii.hexlify(b))) # CAFE is hex-encoded dest addr
            data_to_modem_sketch.write(b)
            data_to_modem_sketch.flush()
            time.sleep(0.1)

for sig in (SIGABRT, SIGINT, SIGTERM):
    signal(sig, signal_handler)
    
unprocessed_payload_bytes = []
data_to_modem_sketch = open('/tmp/bytes_to_modem_sketch_' + sys.argv[1].replace('/','_').replace('.','_'), 'wb')

modem = SerialModem(sys.argv[1], 57600, verbose=True)
modem.setRxCallback(_ccPacketReceived)

thread.start_new_thread(read_from_stdin, ())

while isRunning:
    time.sleep(1)

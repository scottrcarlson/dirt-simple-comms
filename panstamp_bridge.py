#!/usr/bin/env python

# usage:
#  PYTHONPATH=/home/tz/proj/dsc/panstamp_python/pyswap/swap/:/home/tz/proj/dsc/panstamp_python/pyswap/ ./panstamp_bridge.py

import thread, sys, time, pprint, binascii, thread

from SerialModem import SerialModem
from CcPacket import CcPacket

def _ccPacketReceived(ccPacket):
	#print "got ccpacket: " + ccPacket.toString()
	#print "raw: " + chr(ccPacket.data[0])
	unprocessed_payload_bytes.append(ccPacket.data[0])

def read_from_stdin():
	f = sys.stdin
	while True:
		b = f.read(1)
		if len(b) == 1:
			modem.sendCcPacket(CcPacket('(CAFE)' + binascii.hexlify(b))) # CAFE is hex-encoded dest addr
			data_to_modem_sketch.write(b)
			data_to_modem_sketch.flush()

def write_to_stdout():
	while True:
		if len(unprocessed_payload_bytes) > 0:
			b = unprocessed_payload_bytes.pop()
			sys.stdout.write(chr(b)) # instead of print() to avoid printing CRLF
			sys.stdout.flush()
			data_from_modem_sketch.write(chr(b))
			data_from_modem_sketch.flush()

unprocessed_payload_bytes = []
data_from_modem_sketch = open('/tmp/bytes_from_modem_sketch_' + sys.argv[1].replace('/','_').replace('.','_'), 'wb')
data_to_modem_sketch = open('/tmp/bytes_to_modem_sketch_' + sys.argv[1].replace('/','_').replace('.','_'), 'wb')
modem = SerialModem(sys.argv[1], 38400, verbose=False)
modem.setRxCallback(_ccPacketReceived)

thread.start_new_thread(read_from_stdin, ())
thread.start_new_thread(write_to_stdout, ())

time.sleep(60*60) # TODO: replace w/ threading module and join()

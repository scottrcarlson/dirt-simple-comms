#include <SimpleFIFO.h>
#include "modem.h"
//#include "HardwareSerial.h"
#include "cc430uart.h"
#include "timer1a0.h"

#define TIMER         timer1a0
#define RESET_TIMER()
#define INIT_TIMER()  TIMER.attachInterrupt(isrT1event)
#define START_TIMER() TIMER.start(20)
#define STOP_TIMER()  TIMER.stop()

SimpleFIFO<char,3072> outbound_FIFO;
 
CCPACKET packet;    //Radio Packet Structure
/**
 * LED pinsh
 */
#define LEDPIN  4
#define RX_LED 16 //14
//16
#define TX_LED 0

/**
 * This function is called whenever a wireless packet is received
 */
void rfPacketReceived(CCPACKET *packet)
{
    rxPacket = packet;
    packetAvailable = true;
}

/**
 * isrT1event
 *
 * Timer1 interrupt routine
 */
void isrT1event(void)
{
    // Detach Timer1 interrupt
    STOP_TIMER();
    RESET_TIMER();
    checkForData = true;
}

/**
 * setup
 *
 * Arduino setup function
 */
void setup()
{
  pinMode(TX_LED, OUTPUT);
  pinMode(RX_LED, OUTPUT);
  digitalWrite(TX_LED, HIGH);
  digitalWrite(RX_LED, HIGH);

  sleep(3000);

  //Welcome Blinks  
  for(byte i=0 ; i<3 ; i++) 
  {
    digitalWrite(TX_LED, HIGH);
    digitalWrite(RX_LED, LOW);
    sleep(250);
    digitalWrite(TX_LED, LOW);
    digitalWrite(RX_LED, HIGH);
    sleep(250);
  }
  digitalWrite(TX_LED, LOW);
  digitalWrite(RX_LED, LOW);

  // Reset serial buffer
  memset(strSerial, 0, sizeof(strSerial));

  
  Serial.begin(38400);
  Serial.flush();
  Serial.println("");
  
  // Disable address check from the RF IC
  panstamp.radio.disableAddressCheck();
   
  // Declare RF callback function
  panstamp.attachInterrupt(rfPacketReceived);
 
  // Initialize Timer object
  INIT_TIMER();
}

/**
 * loop
 *
 * Arduino main loop
 */
void loop()
{
  // Read wireless packet?
  if (packetAvailable)
  {
    packetAvailable = false;
    
    digitalWrite(RX_LED, HIGH);
   /* Serial.print("(");
    if (rxPacket->rssi < 0x10)
      Serial.print("0");
    Serial.print(rxPacket->rssi, HEX);
    if (rxPacket->lqi < 0x10)
      Serial.print("0");
    Serial.print(rxPacket->lqi, HEX);
    Serial.print(")");*/

    byte i; 
    for(i=0 ; i<rxPacket->length ; i++)
    {
      Serial.write(rxPacket->data[i]);
    }
    //Serial.println("");
    
    // Enable wireless reception
    digitalWrite(RX_LED, LOW);
  }
  
  
  // Buffer Fille Timed out, let send the remaining bytes over the radio
  if (checkForData == true) 
  {
    checkForData = false;
    if (len > 0) 
    {
      //Serial.println("BUFFER FILL TIMEOUT, Sending " + String(len) + " bytes.");
      // Disable wireless reception
      digitalWrite(TX_LED, HIGH);
      //Set the Packet Length
      //packet.length = len + 1;
      packet.length = len;
      //Serial.println("Buffer Contents:[" + String(strSerial) + "]");
      //Serial.println("packet length:" + String(packet.length));
      byte i;
      for(i=0 ; i<packet.length ; i++)
      {     
        packet.data[i]=strSerial[i];
        //Serial.print(packet.data[i], HEX);
      }
      panstamp.radio.sendData(packet);
      
      //Serial.println("");
      memset(strSerial, 0, sizeof(strSerial));
      len = 0;
      
      // Enable wireless reception
      digitalWrite(TX_LED, LOW);
    }
  }
  
  // Read all available data from Uart and queue it up!
  if (Serial.available()) 
  {
    while (Serial.available())
    {
      if (Serial.available() > 0)
      {
        outbound_FIFO.enqueue(Serial.read());
      }
    }
  }
  
  if (outbound_FIFO.count() > 0)
   // Serial.println("FIFO: " + String(outbound_FIFO.count()));
   //if (Serial.available())
   {
    digitalWrite(TX_LED, HIGH);
    STOP_TIMER();
    RESET_TIMER();
    //Serial.println("LEN=" + String(len) + " Char: " + char(ch));
    if (len == SERIAL_BUF_LEN-1)
    {
      strSerial[len] = outbound_FIFO.dequeue(); // Put the last char into buffer
      packet.length = len + 1;
      //Serial.println("BUFFER FILLED" + String(packet.length));
      
      //Serial.println("1");
      byte i; 
      //Serial.println("2");      
     //Serial.println("Buffer Contents:[" + String(strSerial) + "]");
      //Serial.println("packet length:" + String(packet.length));
      //Serial.println("3");
      for(i=0 ; i<packet.length ; i++)
      {     
        packet.data[i]=strSerial[i];
      }
      //Serial.println("");
      // Send packet via RF
      panstamp.radio.sendData(packet);
      //Serial.println("5");
      len = 0;
      memset(strSerial, 0, sizeof(strSerial));
    }
    else
    {
      strSerial[len] = outbound_FIFO.dequeue();
      len++;
      START_TIMER();
    }
    // Enable wireless reception
     digitalWrite(TX_LED, LOW);
  }
}


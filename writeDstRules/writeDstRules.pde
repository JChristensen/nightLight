//Write dst rules for night light
//J. Christensen 28Dec2011

#include <EEPROM.h>
#include <Streaming.h>
#include <Time.h>          //http://www.arduino.cc/playground/Code/Time
#include "tz.h"
 
dstRule dstStartRule = {3, 1, 2, 2, -240, "EDT"};    //month, dow, k, hour, offset, abbrev
dstRule dstEndRule = {11, 1, 1, 2, -300, "EST"};

void setup(void)
{   
    Serial.begin(9600);
    pinMode(13, OUTPUT);     
    
    //dst rules
    writeDstParms();
    Serial << endl << "** DST RULES **\n";
    readEE_dst(0, dstStartRule);
    readEE_dst(16, dstEndRule);
    printDstRule(dstStartRule);
    printDstRule(dstEndRule);
}

void loop(void)
{
    digitalWrite(13, HIGH);   //blink the LED to indicate setup() is complete
    delay(250);
    digitalWrite(13, LOW);
    delay(250);     
}

void writeDstParms()
{
    writeEE_dst(0, dstStartRule);
    writeEE_dst(16, dstEndRule);
}

void printDstRule(dstRule &d)
{
    Serial << "Month: " << _DEC(d.Month) << " DOW: " << _DEC(d.DOW) << " K: " << _DEC(d.K);
    Serial << " Hour: " << _DEC(d.Hour) << " Offset: " << _DEC(d.Offset) << " TZ: " << d.Abbrev << endl;
}

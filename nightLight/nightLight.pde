/*----------------------------------------------------------------------*
 * ATmega328P "Night Light" -- On at sunset, off at sunrise.            *
 * Jack Christensen 28Dec2011                                           *
 * Developed under Arduino 0022                                         *
 *                                                                      *
 * Connect an LED to Arduino pin 3 (DIP pin 5).                         *
 * Connect a piezo transducer to Arduino pin 8 (DIP pin 14) to make     *
 * a little noise at sunrise and sunset.                                *
 *                                                                      *
 * Set fuse bytes: lfuse=0x62, hfuse=0xD6, efuse=0x06.                  *
 * System clock is 1MHz internal RC oscillator.                         *
 * Timer/Counter2 is clocked from a 32.768kHz crystal                   *
 * and configured to generate an interrupt every 8 seconds.             *
 * The ISR is responsible for updating the RTC variables.               *
 * The RTC is set to UTC time which enables automatic changes for       *
 * daylight saving time, and is initialized from the                    *
 * compile date and time when the sketch is uploaded.                   *
 *                                                                      *
 * Rules for daylight saving time changes are stored in EEPROM          *
 * by a separate sketch.                                                *
 *                                                                      *
 * This work is licensed under the Creative Commons Attribution-        *
 * ShareAlike 3.0 Unported License. To view a copy of this license,     *
 * visit http://creativecommons.org/licenses/by-sa/3.0/ or send a       *
 * letter to Creative Commons, 171 Second Street, Suite 300,            *
 * San Francisco, California, 94105, USA.                               *
 *----------------------------------------------------------------------*/

#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <util/atomic.h>
#include <util/delay.h>
#include <EEPROM.h>
#include <Streaming.h>
#include <Time.h>                 //http://www.arduino.cc/playground/Code/Time
#include "tz.h"

#define DEBUG 0
#define MINS_PER_HOUR 60          //number of minutes in an hour
#define LED 3                     //LED night light
#define PIEZO 8                   //piezo speaker

//CONSTANTS FOR SUNRISE AND SUNSET CALCULATIONS
#define OFFICIAL_ZENITH 90.83333
#define LAT 42.93                 //latitude
#define LONG -83.62               //longitude

dstRule dstStartRule, dstEndRule;     //rules for daylight savings time changes
time_t dstStartUTC_t, dstEndUTC_t;    //dst start and end for current year, in utc
time_t dstStartLoc_t, dstEndLoc_t;    //dst start and end for current year, in local time

uint8_t sunriseH, sunriseM, sunsetH, sunsetM;    //hour and minute for sunrise and sunset 
int mSunrise, mSunset;                           //sunrise and sunset expressed as minute of day (0-1439)
int ord;                                         //ordinal date (day of year)
time_t utcNow, utcLast, localNow;                //utc and local time
int minNow, minLast = -1, hourNow, hourLast = -1, minOfDay;    //time parts to trigger various actions

void setup(void)
{
    #if DEBUG == 1
    Serial.begin(9600);
    #endif
    pinMode(LED, OUTPUT);
    pinMode(PIEZO, OUTPUT);
    TIMSK2 = 0;                        //stop timer2 interrupts while we set up
    ASSR = _BV(AS2);                   //Timer/Counter2 clocked from external crystal
    TCCR2A = 0;                        //override arduino settings, ensure WGM mode 0 (normal mode)
    TCCR2B = _BV(CS22) | _BV(CS21) | _BV(CS20);    //prescaler clk/1024 -- TCNT2 will overflow once every 8 seconds
    TCNT2 = 0;                         //start the timer at zero
    while (ASSR & (_BV(TCN2UB) | _BV(TCR2AUB) | _BV(TCR2BUB))) {}    //wait for the registers to be updated    
    TIFR2 = _BV(OCF2B) | _BV(OCF2A) | _BV(TOV2);                     //clear the interrupt flags
    TIMSK2 = _BV(TOIE2);               //enable interrupt on overflow

    calcDstChanges(year(compileTime()));    //bit of chicken-and-egg here
    setRTC(localToUtc(compileTime()));      //convert the compile time to UTC to set the RTC
    utcNow = rtcTime();
    localNow = utcToLocal(utcNow);
    calcDstChanges(year(utcNow));
    calcSunriseSunset();
}

void loop(void)
{
    utcNow = rtcTime();
    minNow = minute(utcNow);
    if (minNow != minLast) {
        localNow = utcToLocal(utcNow);
        minLast = minNow;
        hourNow = hour(localNow);
        minOfDay = hourNow * 60 + minute(localNow);    //minute of day will be in the range 0-1439
        #if DEBUG == 1
        Serial << _DEC(minOfDay) << ' ';
        printTime(localNow);
        #endif
        if (hourNow != hourLast) {
            calcDstChanges(year(utcNow));
            calcSunriseSunset();
            hourLast = hourNow;
        }
        digitalWrite(LED, minOfDay < mSunrise || minOfDay >= mSunset);
        if (minOfDay == mSunrise || minOfDay == mSunset) whistle();
    }
    goToSleep();
}

void calcSunriseSunset(void)
{
    float utcOffset;
    
    utcOffset = isDST(utcNow) ? dstStartRule.Offset / MINS_PER_HOUR : dstEndRule.Offset / MINS_PER_HOUR;
    ord = ordinalDate(localNow);
    calcSunset (ord, LAT, LONG, false, utcOffset, OFFICIAL_ZENITH, sunriseH, sunriseM);
    calcSunset (ord, LAT, LONG, true, utcOffset, OFFICIAL_ZENITH, sunsetH, sunsetM);
    mSunrise = sunriseH * 60 + sunriseM;
    mSunset = sunsetH * 60 + sunsetM;
    #if DEBUG == 1
    Serial << "Sunrise " << _DEC(sunriseH) << ':' << _DEC(sunriseM) << ", " << _DEC(mSunrise);
    Serial << " Sunset " << _DEC(sunsetH) << ':' << _DEC(sunsetM) << ", " << _DEC(mSunset) << endl;
    #endif
}

void goToSleep()
{
    byte adcsra, mcucr1, mcucr2;

    //Cannot re-enter sleep mode within one TOSC cycle. This provides the needed delay.
    OCR2A = 0;                        //write to OCR2A, we're not using it, but no matter
    while (ASSR & _BV(OCR2AUB)) {}    //wait for OCR2A to be updated  

    #if DEBUG == 1
    delay(50);
    Serial.end();
    #endif
    sleep_enable();
    set_sleep_mode(SLEEP_MODE_PWR_SAVE);
    adcsra = ADCSRA;                  //save the ADC Control and Status Register A
    ADCSRA = 0;                       //disable ADC
    ATOMIC_BLOCK(ATOMIC_FORCEON) {    //ATOMIC_FORCEON ensures interrupts are enabled so we can wake up again
        mcucr1 = MCUCR | _BV(BODS) | _BV(BODSE);  //turn off the brown-out detector
        mcucr2 = mcucr1 & ~_BV(BODSE);
        MCUCR = mcucr1;               //timed sequence
        MCUCR = mcucr2;               //BODS stays active for 3 cycles, sleep instruction must be executed while it's active
    }
    sleep_cpu();                      //go to sleep
                                      //wake up here
    sleep_disable();
    ADCSRA = adcsra;                  //restore ADCSRA
    #if DEBUG == 1
    Serial.begin(9600);
    #endif
}


void whistle() {
    for (byte n=0; n<4; n++) {
        for (byte p=24; p>=2; p--) {
            for (byte c1=0; c1<10; c1++) {
                for (byte c2=0; c2<100/p; c2++) {
                    PINB |= _BV(PINB0);
                    delayMicroseconds(p);
                }
            }
        }
    }
}

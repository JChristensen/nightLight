//Real Time Clock for ATmega328P

tmElements_t tm;
time_t t;
char monthDays[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

//Return the current RTC time
time_t rtcTime(void)
{
    cli();                //no interrupts while we convert the time
    t = makeTime(tm);
    sei();
    return t;
}

//Set the RTC time
void setRTC(time_t t)
{
    cli();                //no interrupts while we set the time
    breakTime(t, tm);
    sei();
}

//Timer/Counter2 Overflow Interrupt Service Routine
ISR(TIMER2_OVF_vect)
{
    if ((tm.Second += 8) > 59) {
        tm.Second = tm.Second % 60;
        if (++tm.Minute > 59) {
            tm.Minute = 0;
            if(++tm.Hour > 23) {
                tm.Hour = 0;
                if(++tm.Day > (((tm.Month == 2) && isLeap(tm.Year)) ? monthDays[tm.Month] + 1 : monthDays[tm.Month]) ) {
                    tm.Day = 1;
                    if(++tm.Month > 12) {
                        tm.Month = 1;
                        ++tm.Year;
                    }
                }
            }
        }
    }                
}

//Check for leap year
boolean isLeap(int y)
{
    return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
}

//Returns the compile date and time as a time_t value
time_t compileTime(void)
{
#define FUDGE 25        //fudge factor to allow for compile time (seconds, YMMV)

    char *compDate = __DATE__, *compTime = __TIME__, *months = "JanFebMarAprMayJunJulAugSepOctNovDec";
    char chMon[3], *m;
    int d, y;
    tmElements_t tm;
    time_t t;
    
    strncpy(chMon, compDate, 3);
    chMon[3] = '\0';
    m = strstr(months, chMon);
    tm.Month = ((m - months) / 3 + 1);
    
    tm.Day = atoi(compDate + 4);
    tm.Year = atoi(compDate + 7) - 1970;
    tm.Hour = atoi(compTime);
    tm.Minute = atoi(compTime + 3);
    tm.Second = atoi(compTime + 6);
    t = makeTime(tm);
    return t + FUDGE;        //add fudge factor to allow for compile time
}

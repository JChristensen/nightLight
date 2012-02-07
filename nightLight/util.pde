//Utility functions

#if DEBUG == 1
//Print time to serial monitor.
void printTime(time_t t)
{
    sPrintI00(hour(t));
    sPrintDigits(minute(t));
    sPrintDigits(second(t));
    Serial << ' ' << dayShortStr(weekday(t)) << ' ' << day(t) << ' ' << monthShortStr(month(t)) << ' ' << _DEC(year(t)) << endl;
}

//Print an integer in "00" format (with leading zero).
//Input value assumed to be between 0 and 99.
void sPrintI00(int val)
{
    if (val < 10) Serial << '0';
    Serial << _DEC(val);
    return;
}

//Utility function for digital clock display: prints preceding colon and leading 0
void sPrintDigits(int digits)
{
    Serial << ':';
    if(digits < 10)  Serial << '0';
    Serial << _DEC(digits);
}
#endif

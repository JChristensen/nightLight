#define CONVERSIONS 0    //0 -> read/write functions only, 1 -> all functions

/*----------------------------------------------------------------------*
 * Time zone and Daylight Savings info stored in EEPROM.                *
 * The following values refer to the local time of the change.          *
 *                                                                      *
 * EEPROM                                                               *
 * ADDR  DESCRIPTION                                                    *
 * ----- -------------------------------------------------------------- *
 * 00-01 DST start month (int, 1-12)                                    *
 * 02-03 DST start day of week aka DOW (int, 1-7, 1=Sun, 2=Mon, etc.)   *
 * 04-05 DST start kth day (int, 1-5, e.g. if start DOW=1 and k=2,      *
 *       then the 2nd Sunday of the month is indicated.  Does not yet   *
 *       support k<0 which would mean previous, e.g. "last Sunday       *
 *       of the month")                                                 *
 * 06-07 DST start hour (int, 0-23)                                     *
 * 08-09 DST offset, minutes (int, e.g. -240 for US Eastern time zone)  *
 * 10-13 DST abbreviation (char, e.g. "EDT\0")                          *
 *                                                                      *
 * 16-17 Std time end month (int, 1-12)                                 *
 * 18-19 Std time end DOW (int, 1-7)                                    *
 * 20-21 Std time end kth day (int, 1-5)                                *
 * 22-23 Std time end hour (int, 0-23)                                  *
 * 24-25 Std time offset, minutes (int, e.g. -300 for US Eastern)       *
 * 26-29 Std time abbreviation (char, e.g. "EST\0"                      *
 *                                                                      *
 * As of 2007, values for the US Eastern time zone would be:            *
 *   DST starts on 2nd Sun in Mar @ 0200 local time:                    *
 *     {3, 1, 2, 2, -240, "EDT"}                                        *
 *   DST ends on 1st Sun in Nov @ 0200 local time:                      *
 *     {11, 1, 1, 2, -300, "EST"}                                       *
 *----------------------------------------------------------------------*/

#if CONVERSIONS == 1 
/*----------------------------------------------------------------------*
 * Convert the given UTC time to local time, standard or                *
 * daylight time, as appropriate.                                       *
 *----------------------------------------------------------------------*/
time_t utcToLocal(time_t utc)
{
    if (isDST(utc))
        return utc + dstStartRule.Offset * SECS_PER_MIN;
    else
        return utc + dstEndRule.Offset * SECS_PER_MIN;
}

/*----------------------------------------------------------------------*
 * Convert the given local time to UTC time.                            *
 *                                                                      *
 * Note that ambiguous situations occur near the Local -> DST and the   *
 * DST -> Local time transitions. At Local -> DST, there is one hour    *
 * of local time that does not exist, since the clock moves forward     *
 * one hour. Similarly, at the DST -> Local transition, there is one    *
 * hour of local times that occur twice since the clock moves back      *
 * one hour.                                                            *
 *                                                                      *
 * This function does not test whether it is passed an erroneous time   *
 * value during the Local -> DST transition that does not exist.        *
 * If passed such a time, an incorrect time value will be returned.     *
 *                                                                      *
 * If passed a local time value during the DST -> Local transition      *
 * that occurs twice, it will be treated as the earlier time, i.e.      *
 * the time that occurs before the transistion.                         *
 *                                                                      *
 * Calling this function with local times during a transition interval  *
 * should be avoided!                                                   *
 *----------------------------------------------------------------------*/
time_t localToUtc(time_t local)
{
    if (local >= dstStartLoc_t && local < dstEndLoc_t)
        return local - dstStartRule.Offset * SECS_PER_MIN;
    else
        return local - dstEndRule.Offset * SECS_PER_MIN;
}

/*----------------------------------------------------------------------*
 * Calculate the DST change times for the given year in local time      *
 * and in UTC.                                                          *
 *----------------------------------------------------------------------*/
void calcDstChanges(int y)
{
    static boolean first = true;
    
    if (first) {                        //get the dst rules from eeprom first time only
        readEE_dst(0, dstStartRule);
        readEE_dst(16, dstEndRule);
        first = false;
    }
    dstStartLoc_t = dstChange_t(dstStartRule, y);
    dstEndLoc_t = dstChange_t(dstEndRule, y);
    dstStartUTC_t = dstStartLoc_t - dstEndRule.Offset * SECS_PER_MIN;
    dstEndUTC_t = dstEndLoc_t - dstStartRule.Offset * SECS_PER_MIN;
}

/*----------------------------------------------------------------------*
 * Convert the given DST change rule to a local time_t value            *
 * for the given year.                                                  *
 *----------------------------------------------------------------------*/
time_t dstChange_t(dstRule dst, int yr)
{
    tmElements_t timeParts;
    time_t dstChg;
    
    timeParts.Hour = dst.Hour;
    timeParts.Minute = 0;
    timeParts.Second = 0;
    timeParts.Day = 1;
    timeParts.Month = dst.Month;
    timeParts.Year = yr - 1970;
    dstChg = makeTime(timeParts);    //first day of the month in which the change occurs

    if (weekday(dstChg) == dst.DOW) {    //first day of month is the same DOW as the DST change day
        dstChg += (7 * (dst.K - 1)) * SECS_PER_DAY;
    }
    else {                               //first day of month is a different DOW than the DST change day
        dstChg += (7 * dst.K - abs(weekday(dstChg) - dst.DOW)) * SECS_PER_DAY;
    }
    return dstChg;
}

/*----------------------------------------------------------------------*
 * Determine whether the given UTC time_t is within the DST interval    *
 * or the Standard time interval.                                       *
 *----------------------------------------------------------------------*/
boolean isDST(time_t utc)
{
    return (utc >= dstStartUTC_t && utc < dstEndUTC_t);
}
#endif

/*----------------------------------------------------------------------*
 * Read a dstRule struct from EEPROM at the given address.              *
 *----------------------------------------------------------------------*/
void readEE_dst(int addr, dstRule &d)
{
    d.Month = readEE_int(addr);
    d.DOW = readEE_int(addr + 2);
    d.K = readEE_int(addr + 4);
    d.Hour = readEE_int(addr + 6);
    d.Offset = readEE_int(addr + 8);
    d.Abbrev[0] = EEPROM.read(addr + 10);
    d.Abbrev[1] = EEPROM.read(addr + 11);
    d.Abbrev[2] = EEPROM.read(addr + 12);
    d.Abbrev[3] = EEPROM.read(addr + 13);
}

/*----------------------------------------------------------------------*
 * Read an int (2 bytes) from EEPROM at the given address.              *
 *----------------------------------------------------------------------*/
int readEE_int(int addr)
{
    return (EEPROM.read(addr) << 8) + EEPROM.read(addr+1);
}

void writeEE_dst(int addr, dstRule &d)
{
    writeEE_int(addr, d.Month);
    writeEE_int(addr + 2, d.DOW);
    writeEE_int(addr + 4, d.K);
    writeEE_int(addr + 6, d.Hour);
    writeEE_int(addr + 8, d.Offset);
    writeEE_byte(addr + 10, d.Abbrev[0]);
    writeEE_byte(addr + 11, d.Abbrev[1]);
    writeEE_byte(addr + 12, d.Abbrev[2]);
    writeEE_byte(addr + 13, d.Abbrev[3]);
}

void writeEE_int(int addr, int val)
{
    //check first, write only if the value already stored is different
    if (EEPROM.read(addr) != highByte(val)) EEPROM.write(addr, highByte(val));
    if (EEPROM.read(addr+1) != lowByte(val)) EEPROM.write(addr+1, lowByte(val));
}

void writeEE_byte(int addr, byte val)
{
    //check first, write only if the value already stored is different
    if (EEPROM.read(addr) != val) EEPROM.write(addr, val);
}    


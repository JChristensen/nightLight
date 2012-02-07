/*----------------------------------------------------------------------*
 * Structure to describe a Daylight Savings Time change rule.           *
 * Change rules are expressed in local time.                            *
 *                                                                      *
 * Effective 2007 in the US, the change to DST has been 2nd Sun in Mar, *
 * and the change to Std Time has been 1st Sun in Nov, both at          *
 * 02:00 local time, so e.g., Eastern time zone:                        *
 *   dstRule dstStart = {3, 1, 2, 2, -240, "EDT"};                      *
 *   dstRule dstEnd = {11, 1, 1, 2, -300, "EST"};                       *
 *----------------------------------------------------------------------*/
struct dstRule
{
    int Month;        //Month the change occurs in, 1-12.
    int DOW;          //Day of week the change occurs on, 1-7, 1=Sun, 2=Mon, etc.
    int K;            //Which DOW the change occurs on, e.g. DOW=1 and K=2 means second Sunday in the month.
                      //Note that "last" rules, e.g. "Last Sunday in March" are not currently supported.
    int Hour;         //Local hour the change occurs on.
    int Offset;       //The offset in minutes to apply to convert UTC to local time after the change.
    char Abbrev[4];   //Abbreviation for the time zone name.
};

**==============================================================================================
** MAKE A WIDE FILES WITH THE DATE OF CHANGES IN MARITAL STATUS USING DATA FROM ALL SOURCES
**==============================================================================================


local id ="p8"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_marriage_transition_dates_from_surveys"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/surveys_${sitename}" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/mstat_transition_dates_wide_${sitename}"
local does="Gets the dates of changes in marital status and puts in a wide file"


**** USE THE DATA

use ${alphapath}/ALPHA/clean_data/${sitename}/surveys_${sitename},clear


****  IF SPOUSE LINK DATA ARE AVAILABLE THIS IS THE PLACE TO MERGE THEM IN 

/*  EXAMPLE FOR KISESA ONLY, DATA NOT PREPARED FOR OTHER SITES. COULD BE DONE....
if "${sitename}"=="Kisesa" {
merge 1:m idno survey_name using spouse_data
drop if _m==2
}
*/
** drop DSS data for Ifakara because there are no never marrieds in that
drop if study_name==9 & (survey_name~="Sero1" & survey_name~="Sero2")

*** MARITAL STATUS IN 7.4 IS SPLIT INTO MANY CATEGORIES

*REDUCE THIS TO FOUR CATEGORIES- never, currently married, formerly married and single
*"Single" is to cope with proxy DSS respondent reports where the person reporting may 
*know that the person is not currently married but be unable/unwilling to say whether they have ever been married.

recode marital_status (0=0 "Never married") (1/4=1 "Married") (5/6 8 = 2 "Formerly married") (11=3 "Single") (88/99=88 "Don't know/missing"),gen(mstat) label(mstat)

********* IF NO PARTNER LINKS MERGED,  MAKE AN EMPTY sp_id
cap confirm numeric variable sp_id
if _rc~=0 {
gen sp_id=.
}

** KEEP ONLY RELEVANT VARIABLES
sort study_name idno
keep idno  date_int survey_name mstat marital_status sp* study_name

*DROP RECORDS WITHOUT ANY USEFUL INFORMATION
drop if marital_status==. & sp_id==.

*ESTABLISH FOR EACH INDIVIDUAL: HOW MANY RECORDS IN TOTAL AND THE SEQUENCE IN WHICH THEY WERE REPORTED
bys idno: gen totrec=_N
bys idno (date_int): gen recnum=_n

*WORK OUT THE MAXIMUM NUMBER OF RECORDS FOR A SINGLE PERSON IN THE DATASET AND STORE IN A LOCAL MACRO
summ totrec
local maxrec=r(max)

/**NOT SURE WHAT THIS WAS ABOUT- CHANGING GEOGRAPHIC IDS I THINK
bys idno:gen tmpchangeidno=1 if idno~=idno[_n-1] & recnum>1
bys idno:egen changedid=max(tmpchangeidno)
*/

*FLAG PEOPLE WHO HAVE GOT MARRIED
*not married in previous record, now married
bys idno (recnum): gen gotmar=1 if mstat==1 & mstat[_n-1]~=1 & mstat[_n-1]<88
*never married in last record, now ex-married
bys idno (recnum): replace gotmar=1 if mstat==2 & mstat[_n-1]==0 
*single in previous record, now ex-married: assume got married and then separated
bys idno: replace gotmar=1 if mstat==2 & mstat[_n-1]==3 

*FLAG PEOPLE WHO ARE NO LONGER MARRIED
*was previously married, but now isn't
bys idno: gen stopmar=1 if mstat>1 & mstat<88 & mstat[_n-1]==1 
*previously never married, now ex-married
bys idno: replace stopmar=1 if mstat==2 & mstat[_n-1]==0 
*previously single,now ex-married: assuming got married and then separated between surveys
bys idno: replace stopmar=1 if mstat==2 & mstat[_n-1]==3 
*previously married, now single: assume have got separated
bys idno: replace stopmar=1 if mstat==3 & mstat[_n-1]==1 


*** RESHAPE WIDE FIRST- to get all the changes in sequence
drop marital_status 
reshape wide date_int survey_name sp* mstat gotmar stopmar ,i(idno ) j(recnum)

*LOOP THROUGH EACH REPORTING ROUND (NOT SURVEY ROUNDS, JUST NUMBER OF OCCASIONS ON WHICH MADE A REPORT)
* AND SUMMARISE THEIR MARITAL HISTORY OVER TIME
forvalues x=1/`maxrec' {
*for each occasion generate new variables to store the reports
gen mrevert`x'=0
label var mrevert`x' "Gone back to never married `x'"
gen timesmar`x'=0
label var timesmar`x' "Number of times married `x'"
gen timessep`x'=0
label var timessep`x' "Number of times separated `x'"
*make a local macro for the reporting occasion before this one
local before=`x'-1

*on the first record
if `x'==1 {
*assume all those married are in first marriage- 
*we don't distinguish remarriages from first so can't do anything else
replace timesmar`x'=1 if mstat`x'==1 | mstat`x'==2
replace timesmar`x'=0 if mstat`x'==0
*if formerly married then has been separated at least once
replace timessep`x'=1 if mstat`x'==2
replace timessep`x'=0 if mstat`x'<2
}
*For all subsequent records
else {
*add a new marriage if they have got married between last round and this
*people who are now married or separated:
replace timesmar`x'=timesmar`before'+ 1 if  gotmar`x'==1 & (mstat`x'==1 | mstat`x'==2)  
*otherwise carry forward the total from the previous round
replace timesmar`x'=timesmar`before' if gotmar`x'~=1

*same for separations
replace timessep`x'=timessep`before'+ 1 if ( mstat`x'>1 & mstat`x'<88) & stopmar`x'==1
replace timessep`x'=timessep`before' if  stopmar`x'~=1
*flag those who have gone from married/ex-married to never married- not correct, problem somewhere
replace mrevert`x'=1 if (mstat`before'==1 | mstat`before'==2) & mstat`x'==0
}

}

reshape long date_int survey_name sp_id mstat gotmar stopmar mrevert timesmar timessep ,i(idno ) j(recnum)

*DROP THE SURPLUS RECORDS CREATED IN THE RESHAPE
drop if date_int==.

*DON'T WANT THE ORIGINAL (REPORTED) mstat NOW, BUT KEEP FOR COMPARISON, SO RENAME
rename mstat  oldmstat

*CREATE NEW MSTAT
*0 for never married if never been married or separated
gen mstat=0 if timesmar==0 & timessep==0
*married when number of marriages started is greater than the number ended
replace mstat=1 if timesmar>timessep & timesmar<.
*ex-married when number ended is equal to or larger than ones started 
*(can come in on married and then separated so can observe more separations than marriages)
replace mstat=2 if timesmar<=timessep & timessep<. & timesmar>0

*NOW NEED TO GROUP TOGETHER EPISODES OF TIME WHERE NOTHING CHANGES 
*make an id variable for each spell of marital status
bys idno (date_int): gen marsetid=1 if recnum==1

*loop through each set of records - if the marital status on this line is the same as the line above then carry over the marsetid
*if there has been a change then change the marsetid to a new one (add 1 to the value)
*done in a while loop because Stata is only moving down the records each two line comparison at a time so need to
*repeat many times for people with lots of records- very inefficient.
count if marsetid==.
local stilltodo=r(N)
while `stilltodo'>0 {

bys idno (date_int): replace marsetid=marsetid[_n-1] if mstat==mstat[_n-1] & recnum>1 & marsetid==.
bys idno (date_int): replace marsetid=marsetid[_n-1]+1 if mstat~=mstat[_n-1] & marsetid==.
count if marsetid==.
local stilltodo=r(N)
}

**NOW COLLAPSE THE DATA SO THAT FOR EACH INDIVIDUAL THERE IS ONE RECORD FOR EACH
*PERIOD OF MARITAL STATUS 
 collapse (min) start_marset_date=date_int mstat sp* ///
 (max) end_marset_date=date_int timesmar timessep ///
  (count) marset_count=recnum,by(idno marsetid study_name)

  
*NOW THERE IS A SMALL PROBLEM. THERE ARE GAPS IN TIME BETWEEN THE PERIODS OF MARITAL STATUS- GAPS BETWEEN INTERVIEW DATES
*WHERE THERE HAS BEEN A CHANGE, IT HAS OCCURRED IN THAT TIME, DON'T KNOW WHEN SO ASSUME THE MIDPOINT.

** ADD EXTRA RECORDS TO DESCRIBE THE PERIODS OF TRANSITION BETWEEN MARITAL STATUSES  
*THESE ARE LIKELY TO BE TIMES OF HIGH HIV RISK

*it would be better to take the earlier record
bys idno: gen transition=1 if marsetid~=marsetid[_n+1] & end_marset_date<start_marset_date[_n+1] & idno==idno[_n+1]
bys idno: gen next_start_date=start_marset_date[_n+1] if  marsetid~=marsetid[_n+1] & end_marset_date<start_marset_date[_n+1] & idno==idno[_n+1]
format next_start_date %td
move next_start_date timesmar
*add in a record for the transition
*going to let the current state carry on for half the interval
*then the added record will be subsequent state for the remaining half
*i.e. if a person goes from married to separated, they are married until the midpoint and separated after that
expand 2 if transition==1,gen(addedgap)
gsort idno marsetid +addedgap
*move the end date of current record to midpoint
by idno (marsetid addedgap): replace end_marset_date=end_marset_date + (next_start_date-end_marset_date)/2 if transition==1 & addedgap==0
*start the added record at the midpoint
by idno (marsetid  addedgap): replace start_marset_date=end_marset_date[_n-1] if addedgap==1
*finish the added record at the start of the next record
by idno (marsetid): replace end_marset_date=start_marset_date[_n+1] if addedgap==1
*replace the mstat with the subsequent status 
by idno (marsetid): replace mstat=mstat*10+mstat[_n+1] if addedgap==1 & mstat>0
by idno (marsetid): replace mstat=10 if addedgap==1 & mstat==0 



drop transition


label define mstat_detail 0 "Never married" 1 "Married" 2 "Formerly married" 10 "Never married to married" 12 "Married to Separated" 21 "Separated to married" 22 "Separated to separated",modify
label values mstat mstat_detail
**rename the existing mstat var to mstat_detail
rename mstat mstat_detail
label var mstat_detail "Marital status identifying transition periods"
*and create a new mstat that has only 3 groups- never, married, formerly married
*include married to separated in the new variable as married; separated to married will be grouped with separated in the new variable
recode mstat_detail (0=0 "Never married") (1=1 "Married") (2=2 "Formerly married") (10=0) (12=1) (21/22=2),gen(mstat_broad) label(mstat_broad)
label var mstat_broad "Marital status in three groups"

tab mstat_detail mstat_broad,m

drop addedgap
*drop lastrec


*tidy up and reshape wide for merging later on
drop marsetid timesmar timessep
sort idno start_marset_date
bys idno:gen id=_n
drop next_start_date
order mstat_broad mstat_detail start_marset_date end_marset_date marset_count 
reshape wide mstat_broad mstat_detail start_marset_date end_marset_date marset_count  sp_id ,i(idno) j(id)

*===================================================================================
* ADD INFO FOR DOCUMENTATION
*===================================================================================
*new way
char _dta[name_`id'] "`name'"
char _dta[calls_`id'] "`calls'"
char _dta[uses_`id'] "`uses'"
char _dta[saves_`id'] "`saves'"
char _dta[does_`id'] "`does'"
*this needs to be a list of all ids used in making the final dataset so append to this char
*no append option
local currentid:char _dta[id]
local newid="`currentid'" + " " + "`id'"
char _dta[id] "`newid'"
char _dta[thisid] "`id'"
** attach a note describing provenance to each NEW variable- spec variables already have a [source]
qui desc ,varlist sh
foreach v in `r(varlist)' {
local source:char `v'[source]
*if this is empty then
if "`source'"=="" {
char `v'[source] "`saves'"
char `v'[id] "`id'"
} /*close if */

} /*close var loop */
save ${alphapath}/ALPHA/prepared_data/${sitename}/mstat_transition_dates_wide_${sitename}.dta,replace
*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"



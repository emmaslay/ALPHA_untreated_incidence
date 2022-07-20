****************************************************************************
**
**           PREPARE PARTNERSHIP DYNAMICS DATASET                       
****************************************************************************


*===============================================
* SECTION 0: NOTES
*===============================================

*this was started for the Zanzibar workshop and has been reorganised since
*It prepares the sexual partnership history data so that it can be used
*to estimate population level acquisition and loss rates and to provide dates of changes in 
*partnership status for exposure in incidence risk analysis

*===============================================
* SECTION 1: GET DATA AND CREATE UNIQUE ID VARIABLE
*==============================================

global alphapath K:

********** PREPARE THE IMPUTATIONS
global sitelist="Karonga Kisesa Rakai Umkhanyakude"
*global sitelist="Karonga"
*global nimp=5

local s $sitelist

foreach s in $sitelist {

*BRING IN THE RECODED DATASET BASED ON SEXUAL BEHAVIOUR SPEC 10.1

use "${alphapath}/ALPHA/prepared_data/`s'/sexual_behaviour_recoded_`s'.dta", clear

drop pmstat* hiv_disc_r* hiv_disc_p* phiv_lastsex* phiv_firstsex* ///
condom_lastsex* condom_firstsex* condom_freq* contra_lastsex* contramethod_lastsex* ///
contra_firstsex* contramethod_firstsex* presidence* cf_actual_week* cf_actual_month* ///
cf_actual_year* cf_usual_week* cf_usual_month* cf_usual_year* ///
unprotected_acts* p_circumcised* p_alcohol* p_drugs* p_gifts* p_force* p_sex* pcoital_freq*

cap drop _merge
merge m:1 study_name survey_round_name using ${alphapath}/ALPHA/clean_data/survey_metadata
drop if _m==2
drop _merge

*TIDY UP FILES FOR MERGING LATER
cap destring pexactage4, replace
cap destring pexactage5, replace
cap destring pexactage6, replace

*JULY 2019 - DROP SURVEY ROUND 1 FOR RAKAI AS OVERLAP WITH 
*REFERENCE PERIOD FOR THE SECOND SURVEY
if "`s'"=="Rakai"{
drop if survey_round_name=="6"
}

if "`s'"=="Kisesa"{
drop if survey_round_name=="Sero5" | survey_round_name=="Sero6" | survey_round_name=="Sero7"
}

if "`s'"=="Agincourt"{
drop if survey_round_name=="R24 HIV and NCD Survey 2010"
}

if "`s'"=="Karonga"{
drop if survey_round_name=="3"
}

*JULY 2019 - UPDATE INFORMATION ON PARTNERS LAST YEAR FOR AHRI
if "`s'"=="Umkhanyakude"{
replace partners_lastyear=3 if info_on_partner3==1 & partners_lastyear==.
replace partners_lastyear=2 if info_on_partner2==1 & partners_lastyear==.
replace partners_lastyear=1 if info_on_partner1==1 & partners_lastyear==.
replace partners_lastyear=0 if sexever==0 & partners_lastyear==.
drop if partners_lastyear==. 
}

if "`s'"=="Kisesa"{
drop if idno==4758 
drop if idno==5329
drop if idno==5407
drop if idno==5819
drop if idno==5938
drop if idno==80464
}


gen double refstart=interview_date-365.25*phistref
format refstart %td

*DROP ANY DUPLICATES
duplicates report survey_round_name idno interview_date
duplicates drop

*GET START DATE OF THE GREY AREA- THE DATE OF THE PREVIOUS INTERVIEW
*cc - changed sort from survey_name to interview date
sort idno interview_date
gen double greystart=interview_date[_n-1] if idno==idno[_n-1]
bys idno (interview_date):gen double greyend=refstart
format %td grey*
gen overlap=0
*CC - added in "& greystart<."
replace overlap=1 if greyend<greystart & greyend<. & greystart<.
label var overlap "Ref period for subsequent survey starts before this survey date"

replace greyend=greystart if overlap==. 

replace refstart=greyend if overlap[_n-1]==1
format refstart %td
drop overlap


** GENERATE AN ID THAT IS UNIQUE FOR EACH PERSON/SURVEY COMBINATION- MAKES IT EASIER TO STSET
*IN THIS DO FILE WE USE STSET TO TAKE ADVANTAGE OF THE DATA MANIPULATION THAT THE st commands OFFER
egen unique_survey_id=group(study_name idno survey_sequence)


*===============================================
* SECTION 2: MANIPULATE PARTNER HISTORY DATA
*===============================================
*** GET THE DATE AT THE BEGINNING OF THE REFERENCE PERIOD
* this is date of interview minus the partner history reference period
* Stata dates work in days, phistref is in years so multiply by 365.25
gen double date_start_ref_period=interview_date-(365.25*phistref)

***GET OUT MAX NUMBER OF PARTNERS
preserve 
reshape long whenfirst_date whenlast_date who,i(unique_survey_id survey_sequence) j(qorder)
drop if whenlast_date==. & who==.
drop if whenlast_date==. & whenfirst_date==.
summ qorder
local max = r(max)
display `max'
restore

**** WORK OUT HOW MANY PARTNERS WERE REPORTED BY EACH PERSON AND SEPARATE THOSE WITH NONE
*people who had no partners in last year will be saved in a dataset, 
*then temporarily dropped from Stata's memory and brought back in later

*JULY 2019 The current variable "info_on_partner" is set to one, if there is information on "who" and ongoing"
*We are going to change that for this analysis, to also include people, missing information on "ongoing"
*but with information on "whenfirst_date" and "whenlast_date"
forvalues x=1/`max' {
replace info_on_partner`x' = 1 if whenlast_date`x'!=. & whenfirst_date`x'!=. & who`x'!=.
}

egen total_partners=rowtotal(info_on_partner*)
label var total_partners "Total number of partners disclosed in partner history"

count if total_partners==0

** put aside those with 0 partners in the reference period, will bring them back in later on
preserve
keep if total_partners==0
gen spell_start=date_start_ref_period
gen spell_end=interview_date
gen spell_acq=0
gen spell_lost=0
gen spell_nspacq=0
gen spell_nsplost=0
gen spell_spacq=0
gen spell_splost=0
gen infostatus=2
merge m:1 idno using ${alphapath}/ALPHA/prepared_data/`s'/dob_`s'
drop if _m==2
drop _m
save ${alphapath}/ALPHA\Estimates_partnership_dynamics\zeros/zero_partners_`s',replace
restore



*** NOW START REARRANGING THE DATASET TO GET PARTNERS LISTED IN THE ORDER IN WHICH THEY WERE ACQUIRED AND LOST

** FIRST STEP IS TO RESHAPE THE DATA ON PARTNERS FROM WIDE TO LONG


reshape long whenfirst_date whenlast_date who ongoing info_on_partner,i(unique_survey_id survey_sequence) j(qorder)


** DROP THE EMPTY RECORDS 
*(they are empty because people could report many partners but most people did not have the maximum number)
drop if whenlast_date==. & who==.

format whenfirst_date whenlast_date %td


/* AT THIS POINT, EACH RECORD IN THE PARTNERSHIP HISTORY CONTAINS THE DATES FOR TWO 
EVENTS- THE START OF THE PARTNERSHIP AND THE END OF EACH PARTNERSHIP. 
WE WANT ONE RECORD FOR EACH 
EVENT (I.E. ONE RECORD FOR ACQUISITION AND ONE FOR THE LOSS/CENSORING OF A PARTNER)
A partnership is cenosored if it was ongoing at the time of the survey */

count

*number of partnerships with dates in correct order, i.e. start before end, or same date
count if whenfirst_date<=whenlast_date & whenlast_date<.

*number of partnerships with dates in incorrect order, i.e. end before start
count if whenfirst_date>whenlast_date & whenfirst_date<.


***********************************************************************
**** FIX INCONSISTENCIES IN PARTNERSHIP HISTORIES.
***********************************************************************

*IF DATES WRONG WAY ROUND- START AFTER END- SWAP THEM
gen wrongwayround=1 if  whenfirst_date>whenlast_date & whenfirst_date<.
gen oldlastdate=whenlast_date if wrongwayround==1
replace whenlast_date=whenfirst_date if wrongwayround==1
replace whenfirst_date=oldlastdate if wrongwayround==1

*JULY 2019 - REMOVE IMPLAUSIBLE DATES (DATED BEFORE DATE OF BIRTH)
*SHOULD WE MAKE THIS 10 YEARS AFTER DOB?
*bring in from the dataset created earlier by ALPHA_workshop13_master.do
merge m:1 study_name idno using ${alphapath}/ALPHA/prepared_data/`s'/dob_`s'
drop if _m==2
drop _m
replace whenfirst_date=. if whenfirst_date<dob & dob!=.
replace whenlast_date=. if whenlast_date<dob & dob!=.
count if dob==.
drop if dob==.

*DROP DATES OF FIRST OR LAST SEX THAT ARE IMPLAUSIBLE 
local date = date(c(current_date), "DMY")
display `date'

count if whenlast_date>`date' & whenlast_date<.
drop if whenlast_date>`date' & whenlast_date<.

count if whenfirst_date>`date' & whenfirst_date<.
drop if whenfirst_date>`date' & whenfirst_date<.

* IF DATES ARE MISSING, ADD THEM
*FOR LAST SEX, WHEN PARTNERSHIP IS ONGOING, SET TO INTERVIEW DATE- DO THIS LATER ON ANYWAY
*JULY 2019 - For individuals missing information on whether the partnership is ongoing, we assume 
*that it is ongoing
replace whenlast_date=interview_date if whenlast_date==. & whenfirst_date<. & (ongoing==1 | ongoing==. | ongoing==3)

*number of partnerships with start date but missing last date
count if whenfirst_date!=. & whenlast_date==.

*JULY 2019 - DROP THE ONES WITH MISSING END DATES- NOT THE BEST SOLUTION BUT DOING IT FOR NOW
drop if whenlast_date==. & whenfirst_date<.
drop if whenfirst_date==.

drop if who==.

*GOING TO REHSAPE THE DATA AGAIN TO GET TWO RECORDS FOR EACH REPORTED PARTNERSHIP
*NEED TO GENERATE SOME NEW, RESHAPE-FRIENDLY VARIABLES

*dates of each event, same variable names and different suffixes for reshape
*start of partnership
gen double date_event1=whenfirst_date
*end of partnership
gen double date_event2=whenlast_date
*Need to move the end date for ongoing partnerships to one day after the interview date
*otherwise, in the eventual survival analysis, it will look like they have ended at the time of interview
replace date_event2=interview_date+0.5 if ongoing==1 & date_event2<=interview_date

*give a day to one night stands (otherwise they don't get counted in survival analysis)
replace date_event2=date_event2+1 if date_event2==date_event1

*make these two new date variables show up as dates in Stata
format %td date_event*

sort idno interview_date 

*JULY 2019 - IF TWO DIFFERENT PARTNERS REPORTED ON THE SAME DAY THEN ADD ON 1 SO THEY ARE COUNTED AS
*SEPERATE EVENTS
bysort idno (unique_survey_id survey_sequence qorder): replace date_event1 = date_event1+1 if date_event1[_n-1]==date_event1
bysort idno (unique_survey_id survey_sequence qorder): replace date_event2 = date_event2+1 if date_event2[_n-1]==date_event2

duplicates report idno date_event1 date_event2


*RESHAPE THE DATA EVEN LONGER, SO WE WILL HAVE ONE ROW PER EVENT
reshape long date_event ,i(survey_sequence unique_survey_id qorder) j(start_end)
count if date_event==. & who==.
*RESHAPE HAS MADE A NEW VARIABLE WHICH DENOTES WHETHER THE RECORDS REPRESENTS THE
*START OR THE END OF THE PARTNERSHIP.  WE ALSO NEED A THIRD CATEGORY FOR ONGOING PARTNERSHIPS
label define start_end 0 "Ongoing" 1 "Start" 2 "End",modify
label values start_end start_end

** need to recode for non-events i.e. ongoing partnerships, which are censored at the time of the survey
replace start_end=0 if start_end==2 & (ongoing==1 | ongoing==. | ongoing==3)

*should now be two records for each partnership (i.e. equal numbers of starts and ends)
tab start_end
*count the number of ongoing and ended partnerships: these should equal the number started
count if start_end==0 | start_end==2
*NB. LATER ON WE MUST REINSTATE THE PEOPLE WHO HAD NO PARTNERS


**** MAKE A NEW VARIABLE WHICH GROUPS THE RELATIONSHIP TO PARTNER
* INTO FEWER CATEGORIES (JUST EASIER TO DO THAT WHILE DATA ARE LONG)

*Generating a new variable who group
recode who (10/19=1 "Spouse/Cohab") (20/29=2 "Regular") (30/39=3 "Casual not necessarily high risk") ///
(40/49=4 "Sporadic,high risk/Commercial") (50/59=4 ) (60/69=3 ) (70/79=3 )(80=4 "Non-spousal, no more info") ,gen(whogrp) label(whogrp)



*===============================================
* SECTION 4: REARRANGE PARTNER DATA IN ORDER OF OCCURRENCE
*                                  RETURN THE DATA TO WIDE FORMAT
*===============================================


**** GENERATE A VARIABLE TO SHOW THE ORDER IN WHICH THE EVENTS OCCURRED

*JULY 2019 - SORT ON MORE VARIABLES SO NUMBERS STAY CONSISTENT EACH TIME
sort unique_survey_id date_event who ongoing qorder
bys unique_survey_id (date_event):gen dateorder=_n

**** RESHAPE WITH THE EVENTS IN THE ORDER OF OCCURRENCE
drop qorder whenlast_date whenfirst_date  wrongwayround oldlastdate

reshape wide date_event start_end  who whogrp ongoing info_on_partner,i(unique_survey_id survey_sequence) j(dateorder)

count



*===============================================
* SECTION 5: STSET THE DATA
*===============================================

** THE NEXT PART STSETS AND STSPLITS THE DATA
* THIS IS TO DIVIDE EACH PERSON'S PERSON TIME ACROSS DIFFERENT OBSERVATIONS 
* BASED ON THEIR PARTNERSHIP STATUS AT THAT MOMENT.  BY DOING THIS WE CAN
* LOOK AT THE EFFECTS OF NUMBER OF PARTNERS AND LOSS AND ACQUISITION OR A PARTNER


*GENERATE A DUMMY FAILURE VARIABLE
*THIS IS 1 FOR EVERYONE BECAUSE IT SIMPLY REPRESENTS REACHING THE END OF THE
* FOLLOW UP TIME, WHICH IS THE DATE OF INTERVIEW. Everyone who was interviewed "failed"
gen dummy=1


*STSET ON INTERVIEW DATE, EVERYONE ENTERS AT BIRTH AND MULTIPLE FAILURES ARE ALLOWED
*RIGHT NOW THE ONLY REASON TO STSET IS TO TAKE ADVANTAGE OF STSPLIT
*working on days elapsed since time 0 (in Stata 1st Jan 1960) so in Stata date format
*JULY 2019 - change to have origin as DOB, as some partnerships begin before 1960
gen exit_date = interview_date
stset exit_date, origin(dob) id(unique_survey_id) fail(dummy) exit(time exit_date) 



*** DEFINE GREY AREAS

*FIGURE OUT HTE CORRECT REF PERIOD FOR SURVEY TO AVOID OVERLAPS
*DO EVERYTHING AS BEFORE BUT INCLUDE GREY AREA SPLITS BEFORE ALLOCATING SPELL_PSTAT
*INCLUDE START AND END PREV/INC FLAGS

******* NEED TO SPLIT ONE YEAR BEFORE EACH SURVEY AND DISCARD EARLIER INFORMATION
stsplit beforeref if refstart<.,after(refstart) at(0)

*ALSO WANT TO SPLIT TO WORK OUT THE PERIOD FOR WHICH THERE IS NO DATA
stsplit enteredgrey if greystart<.,after(greystart) at(0)
stsplit exitedgrey if greyend<.,after(greyend) at(0)
*FLAG PERSON TIME IN THE GREY AREA FOR WHICH DATA WEREN'T COLLECTED
gen ingrey=0
replace ingrey=1 if enteredgrey==0  & exitedgrey==-1
label var beforeref "Before reference period for survey"
label var ingrey "In the grey area between surveys"

label define infostatus 0 "Before first info" 1 "Grey area between surveys" 2 "Covered by survey",modify

gen infostatus=.
replace infostatus=0 if ingrey==0 & beforeref==-1
replace infostatus=1 if ingrey==1 & beforeref==-1
replace infostatus=2 if ingrey==0 & beforeref==0
label var infostatus "Time varying info on partnerships"
label values infostatus infostatus

** SHOW THE STSET VARIABLES AND dob AS DATES
*format _t* %td dob

** 
*===============================================
* SECTION 6: STSPLIT THE PARTNER DATA
*===============================================

/*We now have a series of records each containing the date of an event and
we need to consider how these are ordered in time.

The start and end of each partnership might occur before the start of any
subsequent partnership: serial monogamy.
Alternatively, some partnerships might overlap others, that is the start of 
one partnership occurs before the end of one (or more) existing 
partnerships- concurrency.

We are going to use stsplit to assign person time during the partner
history reference period by the number of partnerships that are current.
We are additionally going to categorise this by the types of partner that are
onoing: spousal or non-spousal.

The person time during the reference period is divided into spells of time
during which the number and the mix of partnerships remains the same.

*/



*TO BEGIN: GENERATE SOME EMPTY VARIABLES THAT WILL BE USED TO STORE OUTCOME INFORMATION

*NUMBER OF PARTNERSHIPS ONGOING DURING THIS SPELL OF TIME
*Spouses
gen spell_sp=0
label var spell_sp "Number of current spousal partners"
*Non spousal partners
gen spell_nsp=0
label var spell_nsp "Number of current non-spousal partners"

*EVENTS THAT OCCUR AT THE END OF THIS SPELL OF PERSON TIME
*a partner is acquired
gen spell_acq=0
label var spell_acq "Partner acquired (binary)"
*a partner is lost
gen spell_lost=0
label var spell_lost "Partner lost (binary)"
*a non spousal partner is aquired
gen spell_nspacq=0
label var spell_nspacq "Non-spousal partner acquired (binary)"
*a non spousal partner is lost
gen spell_nsplost=0
label var spell_nsplost "Non-spousal partner lost (binary)"
*a spouse was aquired
gen spell_spacq=0
label var spell_spacq "Spouse acquired (binary)"
*a spouse was lost
gen spell_splost=0
label var spell_splost "Non-spousal partner lost (binary)"

/* POST-WORKSHOP: this analysis can be extended to other characteristics of the partner, 
beyond the relationship- such as the age gap between the partners
*Interval where an older partner is acquired.
gen spell_acq_agep=.
*/

** NOW GOING TO SPLIT THE DATA AT EVERY EVENT (ACQUISITION OR LOSS) UP TO
** TWICE THE MAXIMUM NUMBER OF PARTNERS IN THE PARTNER HISTORY
*count the number of events
desc date_event*,varlist
local max:word count `r(varlist)'
di "`max'"
forvalues x=1/`max' {
            local before=`x'-1

            stsplit event`x' if date_event`x'<.,after(date_event`x') at(0)
**now that data are split on grey area need to flag the last record in each block as that is the only one that should be changed
bys unique_survey_id event`x' (_t0) :gen lastrec`x'=1 if _n==_N


            if `x'==1 {
                        *starts (acquisitions)
                        replace spell_acq=1 if start_end`x'==1 & event`x'==-1 & lastrec`x'==1
                        replace spell_acq=0 if start_end`x'==1 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1))
                        *ends (losses)
                        replace spell_lost=0 if start_end`x'==2 & (event`x'~=-1  | (event`x'==-1 & lastrec`x'~=1))
                        replace spell_lost=1 if start_end`x'==2 & event`x'==-1 & lastrec`x'==1

                        *starts (acquisitions)
                        replace spell_spacq=1 if start_end`x'==1 & event`x'==-1 & who`x'>=10 & who`x'<=19 & lastrec`x'==1
                        replace spell_spacq=0 if start_end`x'==1 & (event`x'~=-1  | (event`x'==-1 & lastrec`x'~=1)) & who`x'>=10 & who`x'<=19
                        *ends (losses)
                        replace spell_splost=0 if start_end`x'==2 & (event`x'~=-1  | (event`x'==-1 & lastrec`x'~=1)) & who`x'>=10 & who`x'<=19
                        replace spell_splost=1 if start_end`x'==2 & event`x'==-1 & who`x'>=10 & who`x'<=19 & lastrec`x'==1

                        *starts (acquisitions)
                        replace spell_nspacq=1 if start_end`x'==1 & event`x'==-1 & who`x'>19 & who`x'<. & lastrec`x'==1
                        replace spell_nspacq=0 if start_end`x'==1 & (event`x'~=-1  | (event`x'==-1 & lastrec`x'~=1)) & who`x'>19 & who`x'<.
                        *ends (losses)
                        replace spell_nsplost=0 if start_end`x'==2 & (event`x'~=-1  | (event`x'==-1 & lastrec`x'~=1)) & who`x'>19 & who`x'<. 
                        replace spell_nsplost=1 if start_end`x'==2 & event`x'==-1 & who`x'>19 & who`x'<. & lastrec`x'==1


                        *first event, first line, everyone is 0 because there is no time before the first event

                        } /* end of `x'==1 if clause */

            if `x'>1 {

                        *starts (acquisitions)
                        replace spell_acq=1 if start_end`x'==1 & event`x'==-1 & lastrec`x'==1 & event`before'==0
                        replace spell_acq=0 if start_end`x'==1 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0
                        *ends (losses)
                        replace spell_lost=0 if start_end`x'==2 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0
                        replace spell_lost=1 if start_end`x'==2 & event`x'==-1 & lastrec`x'==1 & event`before'==0

                        *starts (acquisitions)
                        replace spell_spacq=1 if start_end`x'==1 & event`x'==-1 & lastrec`x'==1 & event`before'==0 & who`x'>=10 & who`x'<=19
                        replace spell_spacq=0 if start_end`x'==1 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0 & who`x'>=10 & who`x'<=19
                        *ends (losses)
                        replace spell_splost=0 if start_end`x'==2 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0 & who`x'>=10 & who`x'<=19
                        replace spell_splost=1 if start_end`x'==2 & event`x'==-1 & lastrec`x'==1 & event`before'==0 & who`x'>=10 & who`x'<=19

                        *starts (acquisitions)
                        replace spell_nspacq=1 if start_end`x'==1 & event`x'==-1 & lastrec`x'==1 & event`before'==0 & who`x'>19 & who`x'<.
                        replace spell_nspacq=0 if start_end`x'==1 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0 & who`x'>19 & who`x'<.
                        *ends (losses)
                        replace spell_nsplost=0 if start_end`x'==2 & (event`x'~=-1 | (event`x'==-1 & lastrec`x'~=1)) & event`before'==0 & who`x'>19 & who`x'<.
                        replace spell_nsplost=1 if start_end`x'==2 & event`x'==-1 & lastrec`x'==1 & event`before'==0 & who`x'>19 & who`x'<.


                        } /* end of `x'>1 if clause */



            } /*end of partner loop forvalues x=1/`max'  */

            



*===============================================
* SECTION 7: WORK OUT THE NUMBER OF SPOUSAL AND
* NON-SPOUSAL PARTNERS CURRENT IN EACH SPELL
*===============================================

*SPOUSES

/*The first record for each person describes the spell of time between birth or 
1st Jan 1960 (whichever is the later of the two dates) and the earliest start date
for the partnships reported in the survey.  We assume no partners at this point */

*CUMULATE THE NUMBER OF SPOUSES ACQUIRED
*First spell for each person - start at zero
bys unique_survey_id (_t): gen spell_spacqsum=0 if _n==1
*Subsequent spells: the total acquired is the number in the previous spell plus an acquisition if the spell ended with an acquisition
bys unique_survey_id (_t): replace spell_spacqsum=spell_spacqsum[_n-1] + spell_spacq[_n-1] if _n>1 & unique_survey_id==unique_survey_id[_n-1]

*CUMULATE THE NUMBER OF SPOUSES LOST
*First spell - start at zero
bys unique_survey_id (_t): gen spell_splostsum=0 if _n==1
*subsequent spells: total lost is the number of losses in the previous spell, plus a loss if the spell ended with a loss
bys unique_survey_id (_t): replace spell_splostsum=spell_splostsum[_n-1] + spell_splost[_n-1] if _n>1 & unique_survey_id==unique_survey_id[_n-1]

** WORK OUT THE NUMBER OF SPOUSES CURRENT
* current spouses is the total number acquired minus the total number lost 
bys unique_survey_id (_t):replace spell_sp=spell_spacqsum-spell_splostsum
label var spell_sp "Number of spouses current at this moment"


*NON-SPOUSAL PARTNERS
*same approach as for spouses
*CUMULATE THE NUMBER OF NSP ACQUIRED
*First spell for each person - start at zero
bys unique_survey_id (_t): gen spell_nspacqsum=0 if _n==1
*Subsequent spells: the total acquired is the number in the previous spell plus an acquisition if the spell ended with an acquisition
bys unique_survey_id (_t): replace spell_nspacqsum=spell_nspacqsum[_n-1] + spell_nspacq[_n-1] if _n>1 & unique_survey_id==unique_survey_id[_n-1]

*CUMULATE THE NUMBER OF NSP LOST
*First spell - start at zero
bys unique_survey_id (_t): gen spell_nsplostsum=0 if _n==1
*subsequent spells: total lost is the number of losses in the previous spell, plus a loss if the spell ended with a loss
bys unique_survey_id (_t): replace spell_nsplostsum=spell_nsplostsum[_n-1] + spell_nsplost[_n-1] if _n>1 & unique_survey_id==unique_survey_id[_n-1]

** WORK OUT THE NUMBER OF NSP CURRENT
* current NSP is the total number acquired minus the total number lost 
bys unique_survey_id (_t):replace spell_nsp=spell_nspacqsum-spell_nsplostsum
label var spell_nsp "Number of non-spousal partners current at this moment"


*br unique dob _t0 _t interview_date spell*

*** GET THE DATES OF THE START AND END OF SPELLS IN NEW VARIABLES
gen spell_start=_t0 + _origin
label var spell_start "Date spell begins on"
gen spell_end=_t + _origin
label var spell_end "Date spell ends on"


***** SUMMARISE THE COMBINATION OF SPOUSAL AND NON-SPOUSAL PARTNERS

label define spell_pstat 1 "None" 2 "NSP" 3 "Spouse" 4 "Both",modify
*no partners
gen spell_pstat=1 if spell_nsp==0 & spell_sp==0
*only non spousal partners
replace spell_pstat=2 if spell_nsp>0  & spell_nsp<.& spell_sp==0
*only spousal partners
replace spell_pstat=3 if spell_nsp==0 & spell_sp>0 & spell_sp<.
*both spousal and non-spousal partners
replace spell_pstat=4 if spell_nsp>0 & spell_nsp<. & spell_sp>0 & spell_sp<.
label values spell_pstat spell_pstat
label var spell_pstat "Types of partners current at this moment"

* ADD BACK IN THE PEOPLE WHO REPORTED NO PARTNERS ALL YEAR

append using ${alphapath}/ALPHA\Estimates_partnership_dynamics\zeros/zero_partners_`s'
*update the partner summary variables to include those with no partners
replace spell_pstat=1 if total_partners==0
replace spell_sp=0 if total_partners==0
replace spell_nsp=0 if total_partners==0

** describe the number of survey respondents remaining (should be the same as we started with)
stdes

** find out how many different people have contributed data
duplicates report study_name idno

drop start_end* who* ongoing* date_event* event* spell_spacqsum spell_splostsum spell_nspacqsum spell_nsplostsum

format spell_start spell_end %td

save ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'/partnership_dynamics_`s', replace


use ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'/partnership_dynamics_`s'

*WORK OUT THE CURRENT TOTAL OF ONGOING PARTNERS
egen spell_partners=rowtotal(spell_nsp spell_sp)
label var spell_partners "Number of partners current at this moment"
recode spell_partners (min/0=0) (1=1) (2/max=2)
label define spell_partners 2 "2+",modify
label values spell_partners spell_partners


gen sexby15=0 if sexever<. & firstsex_age<.
replace sexby15=1 if firstsex_age<15

** who are all the missings?
*people are missing before their first HIV test. 
*But why- Gates file should have people from age 15 or first entry. which should be start_status_date1
*It is people who entered aged 15+, and reported a partnership that started before first DSS round/survey
*Happens because we don't have residency data in this file. Will get dropped in analysis anyway.
cap mkdir ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'
save ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'/partnership_dynamics_ready_`s',replace


*===============================================
* SECTION 8:SAVE A SUMMARY DATASET WITH DATES
*OF PARTNER TRANSITIONS TO USE IN INDIVIDUAL 
*LONGITUDINAL SEROCONVERTORS ANALYSIS
*===============================================

use ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'/partnership_dynamics_ready_`s',clear
*keep only people with information on spell_pstat
stgen maxspell_pstat=ever(spell_pstat<.)
keep if maxspell_pstat==1

**REDUCE SIZE OF DATASET, JUST KEEP RELEVANT VARIABLES
keep study_name idno unique_survey_id _*   spell_pstat spell_nsp spell_sp survey_round_name survey_sequence interview_date*  infostatus spell_start spell_end
keep if infostatus==2

sort idno _t0
*br

gen start_date_spell_ = spell_start
gen end_date_spell_ = spell_end
format start_date_spell_ end_date_spell_ %td
drop _st _d interview_date* _t _t0 _origin spell_start spell_end
bys idno (start_date_spell_): gen dateorder=_n
drop survey_seq survey_round_name unique
reshape wide start_date_spell_ end_date_spell_ spell_pstat spell_nsp spell_sp infostatus ,i(idno ) j(dateorder)

save ${alphapath}/ALPHA/ready_data_partnership_dynamics/`s'/partner_status_dates_for_merge_`s',replace


} /*close site loop */












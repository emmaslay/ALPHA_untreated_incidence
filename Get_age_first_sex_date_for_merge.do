
*****************************************************************************
*  GET BEST ESTIMATE OF DATE OF FIRST SEX FROM ALL REPORTS
*****************************************************************************


local id ="p1"

local name="${alphapath}/alpha/dofiles/prepare_data/Get_age_first_sex_data_for_merge"

local level="mid"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/sexual_behaviour_${sitename}.dta ${alphapath}/ALPHA/prepared_data/${sitename}/dob_${sitename}" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/date_first_sex_${sitename}"
local does="Summarises the self-reported age at first sex from all rounds to come up with single most likely age for each person"

*****************************************************************************
*  SECTION 1: HOUSEKEEPING
*****************************************************************************
use "${alphapath}/ALPHA/clean_data/${sitename}/sexual_behaviour_${sitename}.dta", clear

*========================================================== END SECTION 1


*****************************************************************************
*  SECTION 2: EXTRACT REQUIRED DATA FROM SPEC 10.1 AND RESHAPE WIDE FOR MERGE
*****************************************************************************

*get rid of records without any information
drop if   firstsex_age==. & sexever==.

*  Attendance at each round 
*need to order each round
sort study_name idno interview_date
by study_name idno:gen roundorder=_n
gen inround=1
summ roundorder
global rnum=r(max)
keep inround interview_date  sexever firstsex_age  study_name idno roundorder



reshape wide inround interview_date  sexever firstsex_age  ,i(study_name idno) j(roundorder)



* variables for 1st,  last and number of rounds attended:
gen firstround=.
label var firstround "First round attended"
gen lastround=.
label var lastround "Last round attended"
*========================================================== END OF SECTION 2

*****************************************************************************
**  SECTION 3: MAKE EMPTY VARIABLES FOR ANSWERS TO AFS IN SEQUENCE REPORTED,
*              RATHER THAN BY ROUND
*****************************************************************************
*make new variables for the reported AFS and the date on which it was reported
forvalues y=1/$rnum {
gen afs_report`y'=.
gen afs_report_date_`y'=.
}

*** GOING TO GO THROUGH IN SEQUENCE AND UPDATE AFS INFORMATION WITH INFORMATION FROM
* ELSEWHERE IN THE SURVEY
*NEED TWO VARIABLES TO CONTROL THE LOOPS- ONE TO INDICATE A RECORD THAT NEEDS TO BE CHANGED
*AND ANOTHER TO INDICATE THAN IT HAS JUST BEEN CHANGED- TO PREVENT THE SECOND STEP IN THE LOOP
*CHANGING DATA THAT WAS UPDATED IN THE FIRST STEP.
gen willchange=0
gen justchanged=0


forvalues x =1/$rnum {
replace firstround= `x' if inround`x'==1 & firstround==.
replace lastround= `x' if inround`x'==1

forvalues y=1/$rnum {
replace willchange=1 if inround`x'==1 & afs_report`y'==. & justchanged==0
*CHANGE TO REPORTED AGE, IF ONE WAS GIVEN
replace afs_report_date_`y'=interview_date`x' if inround`x'==1 & afs_report`y'==. & willchange==1 & justchanged==0 & firstsex_age`x'<99
replace afs_report`y'=firstsex_age`x' if inround`x'==1 & afs_report`y'==. & willchange==1 & justchanged==0 & firstsex_age`x'<99

*CHANGE TO NEVER HAD SEX IF SEX EVER WAS NO AND NO AFS WAS GIVEN
replace afs_report_date_`y'=interview_date`x' if inround`x'==1 & afs_report`y'==. & willchange==1 & justchanged==0 & firstsex_age`x'==. & sexever`x'==0
replace afs_report`y'=0 if inround`x'==1 & afs_report`y'==. & willchange==1 & justchanged==0 & firstsex_age`x'==. & sexever`x'==0

replace justchanged=1 if inround`x'==1 & afs_report`y'<. & willchange==1
}

replace willchange=0
replace justchanged=0
}
drop willchange justchanged
*=== end of rearranging age at first vars


*make new variables for the current status report and the date on which it was reported
forvalues y=1/$rnum {
gen sexe_report_date_`y'=.
gen sexe_report`y'=.
}
gen willchange=0
gen justchanged=0


forvalues x =1/$rnum {
forvalues y=1/$rnum {
replace willchange=1 if inround`x'==1 & sexe_report`y'==. & justchanged==0
*CHANGE TO marital status, IF ONE WAS GIVEN
replace sexe_report_date_`y'=interview_date`x' if inround`x'==1 & sexe_report_date_`y'==. & willchange==1 & justchanged==0 & sexever`x'<9 
replace sexe_report`y'=sexever`x' if inround`x'==1 & sexe_report`y'==. & willchange==1 & justchanged==0 & sexever`x'<9
replace justchanged=1 if inround`x'==1 & sexe_report`y'<. & willchange==1
}

replace willchange=0
replace justchanged=0
}
*** ==== end of rearranging current status
format %td sexe_report_date* afs_report_date* 


egen roundsreportedafs=anycount(afs_report*), values(1(1)87)
label var roundsreportedafs "Number of AFS reports"
egen roundsreportedafs_status=anycount(sexe_report*), values(0 1)
label var roundsreportedafs_status "Number of ever sex reports"

summ roundsreportedafs
global nreportsafs=r(max)

summ roundsreportedafs_status
global nreportsafs_status=r(max)


*****************************************************************************
**  SECTION 4: MAKE SUMMARY AGE AT FIRST SEX VARIABLE
*****************************************************************************

** MAKE SUMMARY AGE AT FIRST SEX VARIABLE FROM INFORMATION GIVEN IN ALL ROUNDS AND A FLAG FOR REPORTING  **** 
**IN ORDER TO CHECK COHERENCE OF REPORTS, NEED TO KNOW THE AGE OF THE RESPONDENT AT THE TIME THEY MADE THE REPORT

cap drop _merge
merge m:1 study_name idno using ${alphapath}/ALPHA/prepared_data/${sitename}/dob_${sitename},force
drop if _merge==2



** get ages at report and recode AFS to 98 if it is higher than age at  survey
*store number changed in local macro
local nrepolderthanage=0
forvalues x=1/$nreportsafs {

gen double r_ageexact`x'=(afs_report_date_`x'-dob)/365.25
gen  r_age`x'=int(r_ageexact`x')
*give them a little grace in case they are rounding up their current age 
count if afs_report`x'>r_ageexact`x' & afs_report`x'<.
local nrepolderthanage=`nrepolderthanage' + `r(N)'
replace afs_report`x'=98 if afs_report`x'>r_ageexact`x' & afs_report`x'<.
}


* FIRSTLY -  VARIABLES TO CHECK MIN AND MAX AGES:
*IGNORE ANY 88 REPORTS BECAUSE THEY DON'T CONTRIBUTE ANYTHING ,LIKEWISE 0 WHICH IS JUST NEVER HAD SEX
gen tempnum=0
gen tempdenom=0
gen double afsmax=0
gen double afsmin=.
forvalues x=1/$nreportsafs {
replace tempnum=afs_report`x'+tempnum if afs_report`x'<88 & afs_report`x'>0
replace tempdenom=1 +tempdenom if afs_report`x'<88 & afs_report`x'>0
replace afsmax=afs_report`x' if afs_report`x'>afsmax & afs_report`x'<88
replace afsmin=afs_report`x' if afs_report`x'>0 & afs_report`x'<afsmin & afs_report`x'<88
}
gen double afsmean=tempnum/tempdenom
drop tempnum tempdenom

gen afsdiff=afsmax-afsmin


* VARIABLE TO DESCRIBE THE REPORTING OF AGE AT FIRST SEX:
gen firstsex_age_flag=.

/* WILL BE CODED AS FOLLOWS:
           0 Never had sex
           1 Only reported in one round
           2 All reports consistent
           3 Reports differ by 1 year only
           4 Reports differ by >1 year, used mean
           6 Midpoint between saying never sex and ever had sex is used because no AFS given
           8 Used most frequently reported age
           9 Missing
          10 Already had sex on entry, no AFS reported
          77 Needs editing by a human
The last code- 77 brings up a dataset containing people who have given contradictory 
ages that could probably be reconciled.  Unless there are hundreds this isn't 
very important for this workshop as AFS is not the main focus and so they can be ignored.
The code will treat 77 as missing. */

********************* 1. PEOPLE WHO HAVE ONLY REPORTED ONCE- USE THAT AGE:
	gen double firstsex_age = afsmin
	label var firstsex_age "Most likely age at first sex"
	replace firstsex_age_flag = 1 if  afsmin<. & roundsreportedafs==1
	label define firstsex_age_flag 1 "Only reported in one round", modify  


********************* 2. PEOPLE WHO HAVE REPORTED MORE THAN ONCE AND WERE CONSISTENT:
	replace firstsex_age = afsmin if roundsreportedafs>1 & afsmin == afsmax & afsmin<.
	replace firstsex_age_flag = 2 if roundsreportedafs>1 & afsmin == afsmax  & afsmin<.
	label define firstsex_age_flag 2 "All reports consistent", modify

********************* 3. PEOPLE REPORTING INCONSISTENTLY:
count if roundsreportedafs>1 & afsmin ~= afsmax

* TAKE THE MEAN OF THE REPORTED AGES if reports differ and not just because they said 88 one time
replace firstsex_age=afsmean if roundsreportedafs>1 & afsmin~=afsmax  


* FLAG ACCORDING TO RANGE IN REPORTED AGES:
replace firstsex_age_flag = 3 if roundsreportedafs>1 & afsmin~=afsmax & afsdiff<1
label define firstsex_age_flag 3 "Reports differ by 1 year only", modify
tab firstsex_age if firstsex_age_flag==3

* CODE THOSE THAT DIFFER BY 1 YEAR TO BE THE INTEGER VALUE OF OLDEST REPORTED firstsex_age 
replace firstsex_age=int(afsmax) if firstsex_age_flag==3
tab firstsex_age if firstsex_age_flag==3


********************* 4. REPORTS DIFFER BY >1 YEAR:
replace firstsex_age_flag = 4 if roundsreportedafs>1 & afsmin~=afsmax & afsdiff>1 & afsdiff<.
label define firstsex_age_flag 4 "Reports differ by >1 year, used mean", modify



********************* 5. NEVER ASKED - NOT NEEDED RIGHT NOW


********************* 8. IF ONLY 1 REPORT IS DIFFERENT TO THE OTHERS, use the common one instead of the mean
* 3 VARIABLES TO ADD UP THE NUMBER OF REPORTS EQUAL TO THE YOUNGEST AGE GIVEN, THE OLDEST AND ANY OTHER:
*while doign the counting, add up how many reports there were of ever had sex as will need that later
gen afscountmin = 0
gen afscountmax = 0
gen afscountother = 0
gen sexecount0 = 0

forvalues x=1/$rnum {
	replace afscountmin = afscountmin+1 if roundsreportedafs>1 & afs_report`x'==afsmin & afs_report`x'<88
	replace afscountmax = afscountmax+1 if roundsreportedafs>1 & afs_report`x'==afsmax & afs_report`x'<88
	replace afscountother = afscountother+1 if roundsreportedafs>1 & afs_report`x' > afsmin & afs_report`x'<afsmax & afs_report`x'<88
	replace sexecount0 = sexecount0+1 if sexe_report`x'==0
}


* CHANGE TO YOUNGEST AGE IF THATS WHATS MOST COMMONLY REPORTED:
replace firstsex_age = afsmin if (firstsex_age_flag==3 | firstsex_age_flag==4) & roundsreportedafs>1 & afscountmin>afscountmax & afscountmin>afscountother 
replace firstsex_age_flag = 8 if (firstsex_age_flag==3 | firstsex_age_flag==4) & roundsreportedafs>1 & afscountmin>afscountmax & afscountmin>afscountother 

* CHANGE TO OLDEST AGE IF THATS WHATS MOST COMMONLY REPORTED:
replace firstsex_age = afsmax if (firstsex_age_flag==3 | firstsex_age_flag==4) & roundsreportedafs>2 & afscountmax>afscountmin & afscountmax>afscountother
replace firstsex_age_flag = 8 if (firstsex_age_flag==3 | firstsex_age_flag==4) & roundsreportedafs>2 & afscountmax>afscountmin & afscountmax>afscountother

label define firstsex_age_flag 8 "Used most frequently reported age", modify


* 77. IF THE OTHER AGES ARE THE MOST COMMONLY REPORTED:
* NEED TO SEE IF THAT IS MORE CONSISTENT THAN THE MIN OR THE MAX
* STORE THE OTHER VALUES IN A SERIES OF NEW VARIABLES

forvalues x=1/$nreportsafs {
	gen afsother`x'=afs_report`x' if afscountother>afscountmin & afscountother>afscountmax & afs_report`x'~=afsmin & afs_report`x'~=afsmax & afs_report`x'<88 /*don't want to involve the 88 reports here as have already discarded them earlier on */
	}

count if afscountother>afscountmin & afscountother>afscountmax
replace firstsex_age_flag=77 if afscountother>afscountmin & afscountother>afscountmax

label define firstsex_age_flag 77 "Needs editing by a human", modify
*pop this up in edit window to check that the mean of the non88 values is reasonable
preserve
keep if firstsex_age_flag==77
keep firstsex_age* afs_report* firstsex_age afsmin afsmax afsother* 
save firstsex_age_data_to_edit,replace
restore

********************* 6. THOSE WHO HEVER REPORTED AN AGE- USE MIDPOINT BETWEEN REPORTS OF STATUS CHANGE  ***********

*start from the second round in which current status was reported, and look at the values of each round and the previous round to see if 
*the person has gone from never sex to ever sex in the interval.
forvalues x=2/$nreportsafs_status {
local timebefore=`x'-1
* if person went from never had sex to had sex then take the midpoint between those reports as the date of first marriage
replace firstsex_age_flag=6 if sexe_report`x'==1 & sexe_report`timebefore'==0 & (firstsex_age==. | firstsex_age==0)
replace firstsex_age=(dob + (      (sexe_report_date_`x'+ sexe_report_date_`timebefore')  /2      )           )/365.25 if sexe_report`x'==1 & sexe_report`timebefore'==0 & (firstsex_age==. | firstsex_age==0)
label define firstsex_age_flag 6 "Midpoint between saying never sex and ever had sex is used because no AFS given",modify
}



********************* 0. THOSE WHO HAVE NEVER HAD SEX:
replace firstsex_age_flag = 0 if afsmax== 0
replace firstsex_age_flag =0 if firstsex_age_flag==. & sexecount0==roundsreportedafs_status
label define firstsex_age_flag 0 "Never had sex", modify




********************* 10. RESPONDENTS WHO'VE NOT YET BEEN GROUPED SHOULD BE THOSE WHO HAD FIRST SEX BEFORE FIRST IN DSS AND NEVER REPORTED AFS:
replace firstsex_age_flag=10 if  sexe_report1==1 & firstsex_age==.
label define firstsex_age_flag 10 "Already had sex on entry, no AFS reported", modify 

********************* 9. RESPONDENTS WHO'VE NOT YET BEEN GROUPED SHOULD BE THOSE WHO HAVEN'T ANSWERED THE QUESTION:

recode firstsex_age_flag .=9 
label define firstsex_age_flag 9 "Missing", modify 

label values firstsex_age_flag firstsex_age_flag

*========================================================== END OF SECTION 6

*****************************************************************************
**  SECTION 5: DESCRIBE AGE AT FIRST SEX DATA AVAILABLE FOR EACH PERSON
*****************************************************************************
*** summarise and output age at first sex flag

tab firstsex_age_flag,m
* NUMBER OF TIMES RESPONDENT HAS ANSWERED AFS QUESTION:
gen afs_n_reports= roundsreportedafs_status
label var afs_n_reports "Number of times reported AFS"



gen double reportdatemax_afs=.
forvalues x=1/$rnum {
replace reportdatemax_afs=interview_date`x' if firstsex_age`x'<99 | sexever`x'<3
}

label var reportdatemax_afs "Date last reported on AFS/sexever status"
* AFS IS USEABLE:
gen afs_ok = 0 if firstsex_age<.
replace afs_ok = 1 if firstsex_age_flag ==0 | firstsex_age_flag ==1|firstsex_age_flag ==2|firstsex_age_flag ==3|firstsex_age_flag ==8 
label var afs_ok "Useable age at first sex"

gen afs_quality=0 if afs_n_reports>1 & afs_n_reports<.
label define afs_quality 1 "AFS reported consistently" 2 "AFS: inconsistent: can identify most likely age" 3 "AFS inconsistent: prob near birthday" 4"AFS inconsistent: cannot identify most likely age",modify
label values afs_quality afs_quality
replace afs_quality=1 if afs_n_reports>1 & afs_n_reports<. & firstsex_age_flag==2
replace afs_quality=2 if ( firstsex_age_flag==8) & afs_n_reports>1 & afs_n_reports<.
replace afs_quality=3 if firstsex_age_flag==3 & afs_n_reports>1 & afs_n_reports<.
replace afs_quality=4 if (firstsex_age_flag==4 | firstsex_age_flag==6 | firstsex_age_flag==77) & afs_n_reports>1 & afs_n_reports<.

levelsof firstsex_age_flag,local(alist)




*****************************************************************************
**  SECTION 6: MAKE VARIABLE FOR SURVIVAL ANALYSIS FOR ALL ROUNDS USING CORRECTED AFS (firstsex_age)
*****************************************************************************

set seed 2014
gen smooth=uniform()


gen sexemax=-1

	forvalues x=1/$nreportsafs_status{
	replace sexemax=sexe_report`x' if sexe_report`x'>sexemax & sexe_report`x'<3 
	}


** MAKE THE FAILURE VARIABLE- sexever
*
recode firstsex_age (0=0 "Never had sex") (1/88=1 "Had sex") (99=.),gen(sexever) label(sexever)
label var sexever "Ever had sex"
*pick up the current status reports, for the people who we didn't see go from never to ever
replace sexever=0 if sexemax==0 & firstsex_age==.
replace sexever=1 if sexemax>0 & sexemax<3 & firstsex_age==.
recode sexever 3/max=.
label var sexever "Ever had sex"


* HAD SEX: MAKE VAR EQUAL TO AGE AT FIRST SEX no smoothing this time
gen double lt_firstsex_age = firstsex_age if sexever==1 

* VIRGIN: MAKE VAR EQUAL TO AGE AT last INTERVIEW  IN WHICH THEY REPORTED AFS/SEXEVER:
replace lt_firstsex_age = (reportdatemax_afs - dob)/365.25 if sexever==0 


* MAKE VAR EQUAL TO A RANDOM TIME BETWEEN LAST BIRTHDAY & CURRENT AGE FOR THOSE WHOSE AFS = AGE AT last INTERVIEW:
	replace lt_firstsex_age = firstsex_age +(((reportdatemax_afs - dob)/365.25) - firstsex_age) *smooth if int(firstsex_age)>=int((reportdatemax_afs-dob)/365.25) & sexever==1 & firstsex_age<.
	

* MAKE VAR THE EXACT AGE (IE. ON THE BIRTHDAY) FOR THOSE WHOSE REPORTS ARE A YEAR APART (ALREADY AVERAGED):
replace lt_firstsex_age = int(lt_firstsex_age) if firstsex_age_flag==3


* EVERYONE ELSE- SMOOTH THE REPORTED AGE TO AVOID HEAPING ON BIRTHDAYS:
replace lt_firstsex_age = lt_firstsex_age + smooth if firstsex_age_flag~=3  & int(firstsex_age)<int((reportdatemax_afs-dob)/365.25) & sexever==1 & firstsex_age<.


*remove the 77s and 88s (but shouldn't be any of these)
recode lt_firstsex_age 77/89=.


*========================================================== END OF SECTION 6

*****************************************************************************
**  SECTION 7: MAKE LIFETABLE DATE FOR AFS
*****************************************************************************
gen double datefirstsex=(lt_firstsex_age*365.25)+dob
format %td datefirstsex 
label var datefirstsex "Date at first sex for survival analysis"


*****************************************************************************
**  SECTION 8: ADD DOCUMENTATION INFO FROM GLOBAL MACROS DEFINED ABOVE INTO DATASET
*****************************************************************************


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

** attach a note describing provenance to each variable
qui desc ,varlist sh
foreach v in `r(varlist)' {
char `v'[source] "`saves'"
char `v'[id] "`id'"
}


*****************************************************************************
**  SECTION 9: SAVE DATASET
*****************************************************************************

keep study_name idno  datefirstsex lt_firstsex_age sexever afs_ok
qui compress
save ${alphapath}/ALPHA/prepared_data/${sitename}/date_first_sex_${sitename},replace


*========================================================== END OF SECTION 7

*** CREATE DATA DICTIONARY

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"




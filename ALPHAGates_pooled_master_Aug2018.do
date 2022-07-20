*************************************************************************************
********   ALPHA/GATES TREATMENT PYRAMID MASTER - POOLED  UPDATED AUGUST 2018    ****
*************************************************************************************
/*

DESCRIPTION
This do-file is the second verson of the master used to create the pooled dataset for 
the Gates mortality  estimates.
It is derived from the files used to generate the results presented in Seattle
 in Aug and Oct 2013 and the do files used in the ALPHA 11 workshop in Durban and 
substantially altered Feb 2015 to include censoring.

Changed to use data from j:/alpha/data and do files from j:/alpha/dofiles

uses tidy_for_cascade_spec9_1_agesetdob which differs from previous version
by ?making it clear it's set on age? and including information on ever VCT 
regarding dx (hitherto accidentally omitted)


Added in new post negative times from cubic spline (Emma 26th March 2014)
	
Data specs 6.1, 6.2b, 8.1c, 9.1 and 9.2 are processed, combined and results
 and graphs created.
It can be run on one or more sites as long as the name appears in the 
global ${sitelist} which is defined at the top of the do-file.

The macro ${jdrive} is used throughout to refer to the drive the files are on. It 
should be created before running the analysis either in a personal ado file 
or manually.


FILE STARTED   12TH February 2015 by Emma     
LAST EDITED    August 2018 by Emma
CHANGES MADE: 
AUg 2018: Stopped dropping records after analysis end date as this is no longer a useful way of doing things
Oct 2017: there was a mistake in the off ART splits- 0.8 instead of 0.08, this is now fixed.  
Sep 2016: updated cubic spline to include Kisumu and updated this file to take Kisumu post neg times from that not bodge
May 2016: Changed analysis end date source to a Gates specific file
Oct 2015
Changed tidy_for_gates_spec9_2 to pick out people for which ART initiation was not observed in clinic
Changed this do file not to split those people 6 months after first ART date,
 so they are now assiged to stable ART from beginning of observed ART
**31st July by Clara
line 136 - global changed from datapickup to dataput
			  Section 16 - commented out section on certainty
			  Did not run Manicaland through as problem with 6.2b prep file



*/

************************************************************************************
************      1. HOUSEKEEPING		            	                  ***********
*************************************************************************************



**DEFINE MACROS
*location of do-files and working directory for this analysis
global working "${jdrive}\alpha\Gates1/gates_methods/dofiles"
*location of do files shared across other analyses
global doplacecommon "${jdrive}\alpha\dofiles\common"
global doplacebasic "${jdrive}\alpha\dofiles\basics"

*location of outputs from check and edit files
global reportplace "${working}/check_reports"
global output "${working}\Excel_summary"

*location of site datasets
global sitedataplace "${working}/site_ready_data"

***FOR DATA PREPARATION 
*LOCATION OF DATASETS
global dataplace "${jdrive}/alpha\data/"
global certainty= "${jdrive}/alpha\Gates1/gates_methods/certainty"
global datadestination "${jdrive}/alpha\Gates1/gates_methods/prepared_data"
*LOCATION OF METADATA (happens to be in the same place as the do files)
global metadata "${jdrive}\alpha\data"
*global sitelist "Agincourt Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude Ifakara"
*global sitelist " Kisumu Manicaland Masaka Rakai uMkhanyakude Ifakara "
global sitelist "Kisesa"

set more off

*SET GRAPH COLOURS
global chivneg="gs13"
global chivunk="white"
global cnomoreinfo=`""162 149 138""'
global cundx=`""244 132 161""'
global cdx=`""237 214 238""'
global ccare=`""193 210 245""'
global cart `""141 198 63""'
global cartnew `""189 222 146""'
global cartstable `""141 198 63""'
global coffart=`""242 101 49""'

*set scheme alphapresentation

cd "${working}"

*********************************************************************************************
************		       	2.  TIDY SPECS FROM EACH SITE	         ************
*********************************************************************************************


cd "${working}"
*do apply_certainty.do
*NOW ENTER SITE LOOP
foreach site in $sitelist {
global sitename="`site'"

global datapickup="${dataplace}/${sitename}"
global dataput="${datadestination}/${sitename}"
clear all

**TIDY FILES
/*  The tidy do-files get the specs into a format ready for merging and analysis.

This includes working out whether information could have been ascertained, 
whether it was ascertained, and reshaping into wide files with one record per
person (if applicable).
At the end of the do-file the dataset is resaved in the same location as the 
original dataset with the suffix _clean_ready or clean_wide

In the case of 9.1 and 9.2 additional datasets are created which generate 
start and stop dates for care *and ART, these start with the prefix c_ or sr_, 
and in addition the dataset is resaved as _inprogress   */

do tidy_for_gates_spec6_2b $datapickup  $sitename $dataput
do tidy_for_gates_spec8_1 $datapickup  $sitename  $dataput
do tidy_for_cascade_spec9_1_agesetdob $datapickup $sitename $dataput
do tidy_for_gates_spec9_2 $datapickup $sitename $dataput
do tidy_for_gates_spec7_2 $datapickup $sitename $dataput


*do apply_certainty_undx $datapickup $sitename

************************************************************************************************************
************		       	3. MERGES, RETAIN RELEVANT RECORDS AND STSET	   	   	            ************
************************************************************************************************************

******************************************************************************************
**  		3.1. MERGE SPECS TOGETHER & TEMPORARY STSET TO MANIPULATE RECORDS           **
******************************************************************************************
*merge all specs to 6.1, keeping only those who also have residency information (appearing on 6.1)
use "${datapickup}/ALPHA6_spec1_${sitename}_clean",clear
*spec 6.2b
merge m:1 study_name idno using "${dataput}/ALPHA6_spec2b_${sitename}_clean_wide", generate(merge_6_1_and_6_2)   ///
keepusing(frst_neg_date last_neg_date frst_pos_date last_pos_date first_vct_date last_vct_date first_vct_pos_date ///
 first_vct_neg_date last_vct_neg_date lasttest_date firsttest_date ever_had_vct)
drop if merge_6_1_and_6_2==2
*spec 8.1
merge m:1 study_name idno using "${datapickup}/ALPHA8_spec1_${sitename}_clean_ready", generate(merge_6_and_8)  
drop if merge_6_and_8==2
gen hadva=0 if exit_type==2 & merge_6_and_8==1
replace hadva=1 if exit_type==2 & merge_6_and_8==3
label var hadva "VA available for this death"
*metadata
merge m:1 study_name using "${metadata}/alpha_metadata_clean",gen(merge_meta)
drop if merge_meta==2
*want to use Gates mortality specific analysis end date so drop this one
drop analysis_end_date
*Gates mortality-specific metadata
merge m:1 study_name using ${working}/Gates_ALPHA_metadata.dta,gen(merge_gatesmeta) keepusing(analysis_end_date)
drop if merge_gatesmeta==2

*spec 9.1
merge m:1 study_name idno using "${dataput}/alpha9_spec1_${sitename}_clean_wide_cascade_agesetdob", generate(merge_6_1_and_6_2b_and_9_1)
drop if merge_6_1_and_6_2b_and_9_1==2
*spec 9.2
merge m:1 study_name idno using "${dataput}/alpha9_spec2_${sitename}_clean_wide",gen(merge_61_62b_91_92)
*drop if merge_61_62b_91_92==2

*spec 7.2
merge m:1 study_name idno using "${datapickup}/alpha7_spec2_${sitename}_clean_wide",gen(merge_61_62b_91_92_72)
drop if merge_61_62b_91_92_72==2


*labels
label define sex 1 "Men" 2 "Women",modify
label values sex sex


*STSET - death (exit type 2) is failure
cap n stset,clear
gen exit = exit_date
gen entry = entry_date
format %td entry exit
gen failure = exit_type == 2
stset exit, time0(entry) failure(failure) origin(dob) id(idno) scale(365.25) 

******************************************************************************************
**  		3.2. DROP RECORDS BEFORE AGE OF 15            **
******************************************************************************************

*split at analysis end date (defined in metadata) and drop episodes after this point- NO LONGER WANT TO DO THIS AUG 18
*stsplit theend,after(analysis_end_date) at(0)
*drop if theend==0
*drop theend

*split at age 15 and drop all episodes before this age
stsplit pre15,at(15)
drop if pre15==0
drop pre15


******************************************************************************************
**  		3.3. CHECK CONSISTENCY OF START/END DATES ACROSS SPECS AND CORRECT          **
******************************************************************************************
**NB
*first and last seen
gen lasttmp=clinic_last_visit_date
replace lasttmp=sr_last_report_date_any if sr_last_report_date_any>clinic_last_visit_date & sr_last_report_date_any<. & clinic_last_visit_date<.
replace lasttmp=sr_last_report_date_any if clinic_last_visit_date==.
bys study_name idno:egen last_seen_date=max(lasttmp)

drop lasttmp
label var last_seen_date "Date they last provided info on treatment status, clinic or SR"

gen wheretmp=.
replace wheretmp=1 if last_seen_date==clinic_last_visit_date
replace wheretmp=2 if last_seen_date==sr_last_report_date
bys study_name idno: egen last_seen_where=min(wheretmp)
drop wheretmp
label define last_seen_where 1 "Clinic" 2 "Self-report",modify
label values last_seen_where last_seen_where

egen firsttmp=rowmin(clinic_first_visit_date sr_first_report_date_any)
bys study_name idno:egen first_seen_date=min(firsttmp)
drop firsttmp
label var first_seen_date "Date they first provided info on treatment status, clinic or SR"

bys study_name idno:egen dss_last_seen=max(exit_date)

format %td first_seen_date last_seen_date dss_last_seen


**EARLY EXIT ISSUES
bys study_name idno (entry_date):gen episode_sequence=_n
bys study_name idno (entry_date):gen episode_total=_N
gen last_episode=0
replace last_episode=1 if episode_sequence==episode_total
gen temp=exit if last_episode==1
bys study_name idno: egen last_exit_original=max(temp)
drop temp

*if exit is on the same date as the last test, move the exit date to one day after
gen early_exit_fixed_t=1 if exit==lasttest_date & lasttest_date<. & last_episode==1
replace exit=exit+1 if exit==lasttest_date & lasttest_date<. & last_episode==1

*identify people whose latest 6.1 exit is before latest 6.2, 9.1 or 9.2 report & calculate difference
* exit before last test
gen exitgap_test=lasttest_date-exit if exit<lasttest_date & lasttest_date<. & last_episode==1
* exit is before last sr
gen exitgap_sr=sr_last_report_date-exit if exit<sr_last_report_date & sr_last_report_date~=. & last_episode==1
* exit is before clinic
gen exitgap_c=clinic_last_visit_date-exit if exit<clinic_last_visit_date & clinic_last_visit_date~=. & last_episode==1
gen early_exit_problem=.
label define early_exit_problem 1 "Exit<last6.2" 2 "Exit<last9.1" 3 "Exit<last9.2" 4 "Exit<last6.2&9.1" 5 "Exit<last6.2&9.2" 6 "Exit<last 9.1&9.2" 7 "Exit<last6.2&9.1&9.2", modify
replace early_exit_problem=1 if exitgap_test~=. & exitgap_sr==. & exitgap_c==.
replace early_exit_problem=2 if exitgap_test==. & exitgap_sr~=. & exitgap_c==.
replace early_exit_problem=3 if exitgap_test==. & exitgap_sr==. & exitgap_c~=.
replace early_exit_problem=4 if exitgap_test~=. & exitgap_sr~=. & exitgap_c==.
replace early_exit_problem=5 if exitgap_test~=. & exitgap_sr==. & exitgap_c~=.
replace early_exit_problem=6 if exitgap_test==. & exitgap_sr~=. & exitgap_c~=.
replace early_exit_problem=7 if exitgap_test~=. & exitgap_sr~=. & exitgap_c~=.
label values early_exit_problem early_exit_problem

*change exit to one day after last test, SR or clinic report [all exit types for first 2, only if not dead or out-migrated for clinic data as they could move out but still go to same clinic]
*May 2015, stop moving exit to after last clinic date as biased towards positive now we have more data
gen exit_new=.
label define early_exit_fixed 0 "No change to exit" 1 "Exit changed to last 6.2 plus 1 day" 2 "Exit changed to last 9.1 plus 1 day" 3 "Exit changed to last 9.2 plus 1 day"
replace early_exit_fixed_t=1 if exitgap_test<=earlyexit_max
replace exit_new=lasttest_date+1 if early_exit_fixed_t==1
replace early_exit_fixed_t=2 if exitgap_sr<=earlyexit_max & sr_last_report_date>exit_new
replace exit_new=sr_last_report_date+1 if early_exit_fixed_t==2
*replace early_exit_fixed_t=3 if exitgap_c<=earlyexit_max & clinic_last_visit_date>exit_new & exit_type~=2 & exit_type~=3
*replace exit_new=clinic_last_visit_date+1 if early_exit_fixed_t==3
replace early_exit_fixed=0 if early_exit_problem~=. & early_exit_fixed_t==.
bys study_name idno: egen early_exit_fixed=max(early_exit_fixed_t)
label values early_exit_fixed early_exit_fixed

replace exit=exit_new if exit_new~=.

*update failure with data from clinic 
*change exit_type, failure and exit_date if the death report from the clinic is not before the last dss exit date but is within the range used for exit extension above and dss exit_type is not out-migrated
*mAY 2015, CHANGED- was clinic_last_visit_date==exit_date but think that was a mistake
*
gen clinic_death_update=1 if clinic_current_status==2 & (exit_type==1 | exit_type==4) & clinic_last_visit_date>exit_date & clinic_last_visit_date<(exit_date+earlyexit_max) & last_episode==1
replace exit_date=clinic_last_visit_date if clinic_death_update==1
replace exit_type=2 if clinic_death_update==1
replace failure=1 if clinic_death_update==1


******************************************************************************************
**  		3.4. stset FOR ANALYSIS                                                     **
******************************************************************************************

*redo stset to account for changes in exit dates & failure updates
cap n stset,clear
stset exit , time0(entry) failure(failure) origin(dob) id(idno) scale(365.25) 

*--end-3----------------------------------------------------------------------------------------------------*





***********************************************************************************************************
**  	 						     4. SPLIT AT Calendar years               				   			  **
************************************************************************************************************


do ${doplacecommon}/Calendar_year_split.do
qui compress

****************************************************************************
**	     5. SPLIT AT SINGLE YEARS AND MAKE 5 YEAR AGEGRP  	   			  **
****************************************************************************

do ${doplacecommon}/single_year_agegrp_split.do
qui compress
*--end-5-------------------------------------------------------------------*







****************************************************************************
************     	6. ASSIGN HIV STATUS                        	   	 ***
****************************************************************************


*don't use single post neg time any longer (CAME IN FROM METADATA)
drop timepostneg
*post negative times from cubic spline
merge m:1 study_name sex age using "${jdrive}/alpha\Gates1/gates_methods/incidence_for_postneg_times/alpha_incidence_bbe_values",gen(merge_bbe) keepusing(ybfstale)
rename ybfstale timepostneg
drop if merge_bbe==2

preserve
use "${jdrive}/alpha\Gates1/gates_methods/incidence_for_postneg_times/ALPHA_incidence_BBE_values.dta",clear
gen region=1 if study_name==3 | study_name==6
replace region=0 if region==.
label define region 1 "Southern"  0 "Eastern",modify
label values region region
collapse (mean) ybfstale,by(age sex region)
gen study_name=7 if region==1
save "${jdrive}/alpha\Gates1/gates_methods/incidence_for_postneg_times/ALPHA_incidence_BBE_values_Agincourt.dta",replace
restore

*post negative times from cubic spline- use regional averages for Agincourt and Kisumu for which we have no data
merge m:1 study_name sex age using "${jdrive}/alpha\Gates1/gates_methods/incidence_for_postneg_times/alpha_incidence_bbe_values_Agincourt",gen(merge_bbe2) keepusing(ybfstale)
replace  timepostneg= ybfstale if merge_bbe2==3 & timepostneg==.
drop if merge_bbe2==2

**HIV STATUS based on 6.2b data
*changed June 2018- was assign_HIV_status.do
do ${doplacecommon}/assign_HIV_status.do

*time before a first test and after the cutoff after a negative test is unknown, 
*in the seroconversion interval the years are allocated to negative up to the timepostneg cutoff then to unknown until the first positive test
label define hivstatus_broad 1 "Negative" 2 "Positive" 	3 "Unknown",modify
gen hivstatus_broad = hivstatus_detail
recode hivstatus_broad 1=1 2=2 3=3 4=1 5=3 6=3 8=3 
gen fup=_t-_t0
bys study_name idno hivstatus_de:egen totfup=sum(fup)
replace hivstatus_br=1 if hivstatus_de==7 & totfup<timepostneg
replace hivstatus_br=3 if hivstatus_de==7 & totfup>=timepostneg & totfup<.
label values hivstatus_broad hivstatus_broad
tab hivstatus_detail hivstatus_broad
*--end-6---------------------------------------------------------------------------------------------------*

************************************************************************************************************
************		       	7. ASSIGN DIAGNOSIS STATUS BASED ON 6.2B- Q ON VCT IN SEROSURVEY    ************
************************************************************************************************************

**DIAGNOSIS STATUS based on 6.2b data
stsplit study_first_vct_pos if first_vct_pos_date<., after(first_vct_pos_date) at(0)
stsplit study_last_vct_neg if last_vct_neg_date<., after(last_vct_neg_date) at(0)

gen study_diagnosed=.
*doesn't know positive
replace study_diagnosed=0 if study_last_vct_neg==-1 & study_first_vct_pos==-1
replace study_diagnosed=0 if study_last_vct_neg==0 & study_first_vct_pos==-1
replace study_diagnosed=0 if study_last_vct_neg==0 & study_first_vct_pos==.
replace study_diagnosed=0 if study_last_vct_neg==. & study_first_vct_pos==-1
replace study_diagnosed=0 if study_last_vct_neg==. & study_first_vct_pos==. & ever_had_vct==0

*does know positive
replace study_diagnosed=1 if study_last_vct_neg==0 & study_first_vct_pos==0
replace study_diagnosed=1 if study_last_vct_neg==. & study_first_vct_pos==0
label var study_diagnosed "Been told HIV positive"

gen study_ever_measured_dx=1 if study_diagnosed<.
replace study_ever_measured_dx=0 if study_diagnosed==.
*--end-7-----------------------------------------------------------------------------------------------------*


*************************************************************************************
**  		8. SPLIT USING 9.1 DATA (SELF-REPORTS)								  **
************************************************************************************

**DIAGNOSIS STATUS
stsplit sr_lasttest_split if sr_last_htc_date<., after(sr_last_htc_date) at(0)
stsplit sr_firstpos_split if sr_first_positive_date_min<., after(sr_first_positive_date_min) at(0)
gen sr_diagnosed=.

label var sr_diagnosed "Did they know they were HIV positive"
label define sr_diagnosed 0 "No, did not know positive" 1 "Yes, knows positive"  ///
2 "No, not positive at this time" 3 "Don't know what their results were" ,modify
label values sr_diagnosed sr_diagnosed

*negative
replace sr_diagnosed=2 if sr_firstpos_split~=0 & hivstatus_de==1 & sr_ever_measured_dx==1
replace sr_diagnosed=2 if sr_firstpos_split~=0  & (hivstatus_de==4 | hivstatus_de==4 )  & sr_ever_measured_dx==1
*positive
replace sr_diagnosed=0 if sr_firstpos_split~=0  & hivstatus_de==2 & sr_lasttest_split==-1  & sr_ever_measured_dx==1
replace sr_diagnosed=1 if sr_firstpos_split==0 | (hivstatus_de==2  & sr_lasttest_split==0)  & sr_ever_measured_dx==1
*unclear categories- pre-pos, unknown, serocon, post negative censored
replace sr_diagnosed=3 if sr_firstpos_split~=0  & (hivstatus_de==3 | hivstatus_de==5 | hivstatus_de==7 | hivstatus_de==8)  & sr_ever_measured_dx==1
*never had HTC
replace sr_diagnosed=0 if sr_ever_htc==0 & hivstatus_de==2 

***** DIAGNOSIS FROM SELF-REPORT- UNDIAGNOSED
*SPLIT WHEN FIRST ASCERTAIN VCT HISTORY
stsplit sr_qual_dx_split1 if sr_dx_after<.,after(sr_dx_after) at(0)

*SPLIT AT LAST TIME SAID THEY DIDN'T KNOW AND TWO YEARS AFTER THAT 
stsplit sr_qual_dx_split2 if sr_last_unknownstatus_date<., after(sr_last_unknownstatus_date) at(0 2)

**CARE STATUS
stsplit sr_attended if sr_clinic_first_date_min<., after(sr_clinic_first_date_min) at(0)
recode sr_attended -1=0 0=1
label var sr_attended "Been to a clinic for HIV CT, self_report"

**ON ART  
stsplit sr_on_art if sr_art_first_date_min<., after(sr_art_first_date_min) at(0)
recode sr_on_art -1=0 0=1
label var sr_on_art "On ART, self-report"

**OFF ART
*
stsplit sr_off_art_max if sr_art_stop_date_max~=., after(sr_art_stop_date_max) at(0)
recode sr_off_art_max 0=1 -1=0
label var sr_off_art_max "Off ART (last), self-report"

stsplit sr_off_art_min if sr_art_stop_date_min~=., after(sr_art_stop_date_min) at(0)
recode sr_off_art_min 0=1 -1=0
label var sr_off_art_min "Off ART (first), self-report"

*--end-8----------------------------------------------------------------------------*



************************************************************************************
**  	9. SPLIT USING 9.2 DATA (CLINIC RECORDS)		        		          **
************************************************************************************

**DIAGNOSIS STATUS
stsplit c_diagnosed if clinic_diagnosis_first_date~=., after(clinic_diagnosis_first_date) at(0)
recode c_diagnosed -1=0 0=1
label var c_diagnosed "Date of first positive test in clinic data"

**CARE STATUS
stsplit c_attended if clinic_first_visit_date~=., after(clinic_first_visit_date) at(0)
recode c_attended -1=0 0=1
label var c_attended "Been to a clinic for HIV CT, clinic data"

**ON ART  
stsplit c_on_art if clinic_art_first_date~=., after(clinic_art_first_date) at(0)
recode c_on_art -1=0 0=1
label var c_on_art "On ART, clinic data"

**OFF ART
*(allow everyone one month after the stop date)
stsplit c_off_art_max if clinic_art_stop_date_max~=., after(clinic_art_stop_date_max) at(0.083333)
recode c_off_art_max 0.083333=1
label var c_off_art_max "Off ART (last), clinic data"

stsplit c_off_art_min if clinic_art_stop_date_min~=., after(clinic_art_stop_date_min) at(0.083333)
recode c_off_art_min 0.083333=1
label var c_off_art_min "Off ART (first), clinic data"



*--end-9------------------------------------------------------------------------*

*************************************************************************************
**             10.   ART stop dates                                                **
*************************************************************************************
** establish earliest ART stop date and latest ART stop date from clinic and selfreport

egen last_art_stop_date=rowmax(sr_art_stop_date_max clinic_art_stop_date_max)
egen first_art_stop_date=rowmin(sr_art_stop_date_min clinic_art_stop_date_min)

*************************************************************************************
**  11. CREATE PYRAMID & DIAGNOSIS VARIABLES WITH INFO FROM 6.1, 6.2b, 9.1 & 9.2   **
*************************************************************************************

label define treat_pyramid2 0 "No HIV status" 1 "HIV negative" 2 "HIV+ never asked/no clinic data" 3 "HIV+ not diagnosed" ///
4 "HIV+ diagnosed" 5 "HIV+ attended services" ///
6 "HIV+ on ART" 7 "HIV+ off ART" ,modify

** ONLY PEOPLE ON FINAL ART STOP ARE CLASSED AS OFF ART, OTHERS PUT IN THREE CATEGORIES OF ON ART- 
*ON, NEW <6MONTHS NO INTERRUPTION; ON, STABLE 6M+ AND NO INTERUPTION; ON, GAPS IN TREATMENT
label define  treat_pyramid_fine 0 "No HIV status" 1 "HIV negative" 2 "HIV+ never asked/no clinic data" ///
3 "HIV+ not diagnosed" 4 "HIV+ diagnosed" 5 "HIV+ attended services" ///
6 "HIV+ on ART <6m" 7 "HIV+ on ART 6m+" 8 "HIV+ on ART w gaps" 9 "HIV+ off ART" ,modify


gen allinfo_treat_pyramid=.
*HIV status unknown
replace allinfo_treat_pyramid=0 if hivstatus_br==3
*HIV negative in research tests
replace allinfo_treat_pyramid=1 if hivstatus_br==1 
*HIV positive in research tests, not diagnosed or never asked- this doesn't pick up tests done as part of study when results given to participants, that is on next step
replace allinfo_treat_pyramid=2 if hivstatus_br==2
*HIV positive but not diagnosed
replace allinfo_treat_pyramid=3 if (hivstatus_br==2 & study_diagnosed==0)
replace allinfo_treat_pyramid=3 if c_diagnosed==0 & hivstatus_br==2 
replace allinfo_treat_pyramid=3 if  sr_diagnosed==0 & hivstatus_br==2 
*HIV positive in research tests, diagnosed, self_reported or seen in clinic
replace allinfo_treat_pyramid=4 if ((hivstatus_br==2 & study_diagnosed==1) | c_diagnosed==1 | sr_diagnosed==1)
*Been to HIV services
replace allinfo_treat_pyramid=5 if (sr_attended==1 | c_attended==1)

*On ART
replace allinfo_treat_pyramid=6 if (sr_on_art==1 | c_on_art==1)

*** SPLIT 6 MONTHS AFTER TREATMENT START TO WEED OUT MORIBUND STARTERS
*find start date for ART- easier to see which one was used because it can come from different places
sort study_name idno _t0
*only split people for whom ART initiation was observed
bys study_name idno:egen firstARTstart=min(_t0) if allinfo_treat_pyramid==6 & clinic_artstart_notseen~=1
replace firstARTstart=firstARTstart*365.25+dob
format firstARTstart %td
*split 6 months after earliest reported ART start date, assume this is dangerous period
stsplit newonart if firstARTstart<.,after(firstARTstart) at(0.5)
recode newonart 0.5=0 0=1
label define newonart 0 "No, >6m after start" 1 "Yes, <6m since start",modify
label values newonart newonart

replace allinfo_treat_pyramid=7 if allinfo_treat_pyramid==6 & newonart==0
*if initiation wasn't observed in clinic i.e. first ART record was a continuation then put into stable right away
replace allinfo_treat_pyramid=7 if allinfo_treat_pyramid==6 & clinic_artstart_notseen==1

*** INTERUPTED ART
*someone who started ART but is after their first reported stop
replace allinfo_treat_pyramid=8 if (allinfo_treat_pyramid==6 | allinfo_treat_pyramid==7)  ///
 & (c_off_art_min==1 | sr_off_art_min==1)



label values allinfo_treat_pyramid treat_pyramid_fine


*DEFINE EVER TREATED VARIABLE
recode allinfo_treat_pyramid (2=0 "No more info") (1=1 "HIV negative") (3/5=2 "Never treated") (7=4 "Stable ART") (6=3 "Early ART") (8=5 "Interrupted ART") (9=6 "Off ART"),gen(hivtreat) label(hivtreat)
label var hivtreat "Treatment status, distinguishes stable and interrupted ART"

recode allinfo_treat_pyramid (2=0 "No more info") (1=1 "HIV negative") (3/5=2 "Never treated") (6/9=3 "Had ART") ,gen(hivevertreat) label(hivevertreat)
label var hivevertreat "Treatment status, ART naive or exposed"

*MAKE DIAGNOSIS STATUS VARIABLE
gen allinfo_diagnosis_status=allinfo_treat_pyramid
recode allinfo_diagnosis_status 4/7=4
label var allinfo_diagnosis_status "Diagnosis Status"
label define allinfo_diagnosis_status 0 "No HIV status" 1 "HIV negative" 2 "HIV+ never asked/no clinic data" 3 "HIV+ not diagnosed" ///
4 "HIV+ diagnosed" ,modify
label values allinfo_diagnosis_status allinfo_diagnosis_status



** look for births within 6 months of ART initiation
forvalues x=1/30 {
cap confirm numeric variable m_delivery_date`x'
if _rc~=0 {
local bmax=`x'-1
continue, break
}
}
di "`bmax'"

gen birthsoonafterARTstart=.
forvalues x=1/`bmax' {
replace birthsoonafterARTstart=1 if (m_delivery_date`x'-firstARTstart)<182.5 & (m_delivery_date`x'>=firstARTstart) & firstARTstart<.
}

stgen preg_at_art_start=ever(birthsoonafterARTstart==1)



*--end-11----------------------------------------------------------------------------*


*************************************************************************************
**      12. UPDATE HIV STATUS BASED ON CLINIC & SR DATA                 		   **
*************************************************************************************

gen hiv_update_flag=0 
label define hiv_update_flag 0 "No change from study test" 1 "Updated from clinic data" 2 "Updated from SR" 3 "Updated from VA",modify
label values hiv_update_flag hiv_update_flag
replace hiv_update_flag=1 if hivstatus_br~=2 & (c_diagnosed==1 | c_attended==1 | c_on_art==1 ) 
replace hiv_update_flag=2 if hivstatus_br~=2 & (sr_diagnosed==1 | sr_attended==1 | sr_on_art==1 )
replace hivstatus_br=2 if hiv_update_flag==1
replace hivstatus_br=2 if hiv_update_flag==2

*--end-12---------------------------------------------------------------------------*


***********************************************************************************
**  	     13. CENSORING                  					   			     **
***********************************************************************************

bys study_name idno (_t):gen last_record=1 if _n==_N

*gen age vars
gen agelastseen=(last_seen_date-dob)/365.25

gen age_at_exit2=_t
label define age_at_exit2 1 "<35" 2 "35+"
recode age_at_exit2 min/35=1 35/max=2
label values age_at_exit2 age_at_exit2
label var age_at_exit2 "Age at exit (death or censoring)"

gen age_at_exit3=_t
label define age_at_exit3 1 "<30" 2 "30-45" 3 "45+"
recode age_at_exit3 min/30=1 30/45=2 45/max=3
label values age_at_exit3 age_at_exit3
label var age_at_exit3 "Age at exit (death or censoring)"


*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*  CERTAINTY
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
** UNDIAGNOSED
gen sr_qual_dx=.
*happy when sr_qual_dx_split2<. because that means there was a no report at some point
*before the no report, can assume was no, status not known (like pre-positive)
replace sr_qual_dx=1 if sr_qual_dx_split2<0 /*1 is most confident */

*less certain after the no report, running up to the end of obs/ first time reported status known.   OK within first two years
replace sr_qual_dx=2 if sr_qual_dx_split2==0 & sr_diagnosed==0  /*2 is less confident */

*shaky more than two years later
replace sr_qual_dx=3 if sr_qual_dx_split2==2 & sr_diagnosed==0   /*3 is least confident */

*shaky if after questions were asked but no last not known date reported
replace sr_qual_dx=2 if sr_qual_dx_split2==. & sr_diagnosed==0 & sr_qual_dx_split1==0  /*2 is less confident */

label define quality 1 "Good" 2 "OK" 3 "Flimsy",modify
label values sr_qual_dx quality


*** COMBINE WITH THE ASSESSMENT FROM 6.2B
/*merge m:1 idno using ${certainty}/informed_of_result_${sitename}_certainty
	drop _merge
gen undx_certainty=.
label define certainty 1 "Reasonable- 2+ sources" 2 "Reasonable- 1 good source or 2+ probables" 3 "Probable - 1 source" 4 "Tenuous",modify
label values undx_certainty certainty

gen dateat_t=(_t*365.25)+dob
gen dateat_t0=(_t0*365.25)+dob
format dateat_* %td

*from 6.2b
replace undx_certainty=2 if allinfo_treat_pyramid==3 & dk_status_start1<=dateat_t0 & dk_status_end1>=dateat_t
replace undx_certainty=3 if allinfo_treat_pyramid==3 & dk_status_start2<=dateat_t0 & dk_status_end2>=dateat_t
replace undx_certainty=4 if allinfo_treat_pyramid==3 & dk_status_start3<=dateat_t0 

*6.2b and SR agree
replace undx_certainty=1 if undx_certainty==2 & sr_qual_dx==1
*Only SR is reasonable
replace undx_certainty=2 if sr_qual_dx==1 & undx_certainty>2
*SR is probable, 6.2b is probable
replace undx_certainty=2 if sr_qual_dx==2 & undx_certainty==3
*only one source is probable
replace undx_certainty=3 if undx_certainty>3 & (sr_qual_dx==2)

*either or both are flimsy/tenuous
replace undx_certainty=4 if undx_certainty>4 & (sr_qual_dx==3 )



** ART NAIVE- merge in the dates that describe reporting
*clinic data
merge m:1 idno using ${certainty}/never_art_clinic_${sitename}_certainty,
drop _merge
*self-report
merge m:1 idno using ${certainty}/never_art_sr_${sitename}_certainty,
drop _merge



*condense the clinic date variables
egen beforeart=rowmax(never_art_end last_art_naive_report_date)
*Options
*never treated and ever treated: All time before latest report/clinic record of no ART is good
stsplit artnaivesplit if beforeart<.,after(beforeart) at(0 2)

gen artnaive_qual=.
replace artnaive_qual=1 if artnaivesplit==-1

*ever treated: Observed initiation, all time before that is good
*should already have captured that now in allinfo, so all time before allinfo==6 is good
stgen everearlyart=ever(allinfo_treat_pyramid==6)
replace artnaive_qual=1 if allinfo_treat_pyramid<6 & everearlyart==1


stgen everanyart=ever(allinfo_treat_pyramid==6 | allinfo_treat_pyramid==7)
*Never treated: Time for <2 years after last report is OK
replace artnaive_qual=2 if allinfo_treat_pyramid<6 & everanyart==0 & artnaivesplit==0
*Never treated: time >2 years after last report is flimsy
replace artnaive_qual=3 if allinfo_treat_pyramid<6 & everanyart==0 & artnaivesplit==2

*ever treated: did not see initiation: all time before that is shaky if no art naive report
replace artnaive_qual=3 if allinfo_treat_pyramid<6 & everearlyart==0 & everanyart==1 & artnaivesplit==.
*ever treated: did not see initiation: if art naive report then time before that is  good, time between report and art is shaky
replace artnaive_qual=3 if allinfo_treat_pyramid<6 & everearlyart==0 & everanyart==1 & artnaivesplit>-1 & artnaivesplit<.

*giving up at this point
*/




*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=


*--end-13---------------------------------------------------------------------------*


************************************************************************************
**       14. SPLIT AT ART AVAILABILIY            				   			      **
************************************************************************************

do ${doplacecommon}/ART_avail_splits.do
*-----------------------------------------------------------------------------------*


*************************************************************************************
************	15. GENERATE A FEW EXTRA VARIABLES            	          ***********
*************************************************************************************
*MAKE DUMMY
gen dummy=1

*MAKE SITE VARIABLE (sites listed in alphabetical order)
recode study_name   (7=1 "Agincourt") (1=3 "Karonga") (2=4 "Kisesa") ///
(8=5 "Kisumu") (9=2 "Ifakara") (3=6 "Manicaland") (4=7 "Masaka") (5=8 "Rakai")  ///
(6=9 "uMkhanyakude") ,gen(site) label(site)
*save site label in a do file for use later on
label save site using sitelab,replace
label var site "Site"

*MAKE REGION VARIABLE
recode study_name   (7=2 "Southern") (1=1 "Eastern") (2=1)  ///
(8=1)  (3=2)  (4=1) (5=1) (9=1) ///
(6=2) ,gen(region) label(region)
label save region using regionlab,replace



*--end-15---------------------------------------------------------------------------*



*************************************************************************************
************	16. SAVE SITE SPECFIC RESULTS READY FILES                   *********
*************************************************************************************


*** ALL DATA***
qui compress
*save two versions- one without a date- the latest and one with a date
*** here add in a timestamp 

local fndate: subinstr global S_FNDATE " " "_",all
local fndate: subinstr local fndate ":" "",all
*save ${sitedataplace}/ALPHA11Gates_ongoing_ready_yearsplit_agesplit_all_${sitename}_`fndate',replace
saveold "${jdrive}/ALPHA\Gates1\Gates_methods\Current_site_data/ALPHA_Gates_ready_2018_${sitename}",replace


*--end-16---------------------------------------------------------------------------*

} /* close site loop */




global sitelist "Agincourt Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude "




*************************************************************************************
************	17. POOL THE DATA  - CENSORED & NOT                         *********
*************************************************************************************
*list of variables to keep for the pooled dataset
#delimit ;
global keeplist study_name 
idno dob _st _t _t0 _d _origin sex hadva last_seen_date last_seen_where first_seen_date  
hivstatus_detail hivstatus_broad study_diagnosed study_first_vct_pos study_last_vct_neg study_ever_measured_dx 
 sr_diagnosed sr_attended c_diagnosed c_attended  
allinfo_treat_pyramid*  hiv_update_flag 
agelastseen  art_available last_neg_date frst_pos_date  
sr_ever_measured_* study_ever_measured_* 
clinic_ever_measured_* va_did_measure_*  
age_at_exit* dummy  study_diagnosed sr_diagnosed c_diagnosed va_diagnosed  
sr_attended c_attended  va_on_art  va_off_art 
clinic_last_visit_date sr_last_report_date dss_last_seen  art_avail_cat 
entry* exit* failure site hivtreat hivevertreat years_one fiveyear age agegrp region sr_on_art 
sr_off_art_max sr_off_art_min c_on_art c_off_art_max c_off_art_min  
 timepostneg residence
sr_dx_after sr_tx_after sr_art_after sr_default_after clinic_dx_after clinic_tx_after 
clinic_art_after clinic_default_after study_dx_after art_start_year  preg_at_art_start sr_qual* merge_61_62b_91_92
 retro_firstpostmp retro_report_first_pos_date retro_sr_art_first_date idno_original
;
			
# delimit cr



*need to pass the file name stub to the do file so it knows what to find and combine
do ${doplacecommon}/pool_ready_site_files.do  ${jdrive}/ALPHA\Gates1\Gates_methods\Current_site_data/ALPHA_Gates_ready_2018_



local fndate=c(current_date)
local tmptime=c(current_time)
local tmptime=substr("`tmptime'",1,5)
local fndate="`fndate'" + " " + "`tmptime'"
local fndate: subinstr local fndate " " "_" , all
local fndate: subinstr local fndate ":" "_" , all
di "`fndate'"

*save ${working}/ALPHAGates_cascade_yearsplit_agesplit_all_pooled,replace
save ${jdrive}/alpha\Gates1\gates_methods/old_pooled_data/ALPHA_Gates_ready_2018_pooled_`fndate',replace
save ${jdrive}/alpha\Gates1\gates_methods/current_pooled_data/ALPHA_Gates_ready_2018_pooled,replace
*copy ${working}/ALPHA11Gates_ongoing_ready_yearsplit_agesplit_all_pooled.dta ${filr}/data/ALPHA11Gates_ongoing_ready_yearsplit_agesplit_all_pooled.dta  ,replace

/* put name of dataset to use after the do file name */

*do ${working}/alpha11gATES_check_results.do "${jdrive}/alpha\Gates1\gates_methods/current_pooled_data/ALPHA_Gates_ready_2018_pooled"


*do ALPHA_gates_ongoing_site_results_master.do




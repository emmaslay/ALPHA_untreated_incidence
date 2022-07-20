************************************************
***    MAKE HIV test data WIDE FOR MERGING    ***
************************************************

*USES SUMMARY INFORMATION ON RESIDENCY
* prepared_data/${sitename}/residency_summary_dates_${sitename}

local id ="p3"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_HIV_data_from_hiv_tests_check_residency_make_wide_for_merge"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/hiv_tests_${sitename}     ${alphapath}/ALPHA/prepared_data/${sitename}/residency_summary_dates_${sitename}" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/hiv_tests_wide_${sitename}"
local does="Reshapes HIV test data wide for merging and checks residency status for each test. Makes first and last positive and negative dates"

*changed Nov 2019 to exclude clinic data from AHRI

*OPEN DATASET
use "${alphapath}/ALPHA/clean_data/${sitename}/hiv_tests_${sitename}",clear
*merge in the metadata to make info vars and expiry dates, and the 6.1 residency summary for checking test dates
merge m:1 study_name using ${alphapath}/ALPHA/clean_data/alpha_metadata, keepusing(study_dx_after earlyexit_max analysis_end_date)
drop if _merge==2
drop _merge
merge m:1 study_name idno using "${alphapath}/ALPHA/prepared_data/${sitename}/residency_summary_dates_${sitename}", generate(merge_res_summ)   
drop if merge_res_summ==2

cap drop date
** keep population based results only for this analysis- after discussion with AHRI have taken out their clinic results
*(keep self report for Kisumu [study_name 8] only for positives)
keep if source_of_test_information==0 | source_of_test_information==1 |  (source_of_test_information==4 & study_name==8 & hiv_test_result==1) 

cap drop if sample_type==1 & study_name==8
cap drop sample_type

*Karonga only - drop tests from before 2000 as problems with these
drop if study_name==1 & hiv_test_date<mdy(1,1,2000)
*Kisumu only- drop self-reported results that are from more than 1 year before the survey
drop if study_name==8 & source==4 & (test_report_date-hiv_test_date)>365 
*create a sequence variable and pick up maximum number of tests to use later on in looping through test results
bys study_name idno (hiv_test_date): gen test_sequence=_n
summarize test_sequence
global maxtests=r(max)

*FIRST & LAST TESTS

**find first and last test dates (all tests)
*any test
bys study_name idno:  egen firsttest=min(hiv_test_date)
bys study_name idno:  egen firsttest_date_all=min(firsttest)
bys study_name idno:  egen lasttest=max(hiv_test_date)
bys study_name idno:  egen lasttest_date_all=max(lasttest)
*negative
bys study_name idno:  egen first_negative=min(hiv_test_date) if hiv_test_result==0
bys study_name idno:  egen first_neg_date_all=min(first_negative) 
bys study_name idno:  egen last_negative=max(hiv_test_date) if hiv_test_result==0 & hiv_test_date<.
bys study_name idno:  egen last_neg_date_all=min(last_negative)
*positive
bys study_name idno:  egen first_positive=min(hiv_test_date) if hiv_test_result==1
bys study_name idno:  egen first_pos_date_all=min(first_positive)
bys study_name idno:  egen last_positive=max(hiv_test_date) if hiv_test_result==1 & hiv_test_date<.
bys study_name idno:  egen last_pos_date_all=min(last_positive)
drop firsttest lasttest first_negative last_negative first_positive last_positive

*identify tests that are within residency dates 

*JUNE 2018- HAVE REMOVED ALL THIS AS DON'T WANT TO CUT OFF AT analysis_end_date (exit_temp has to be created which is the analysis end date as everything after this is dropped later)
*get number of residency episodes
desc entry_date*,varlist
local nep: word count  `r(varlist)'
gen exit_temp=.
gen test_tag=.
forvalues e=1/`nep' {

replace exit_temp=exit_date`e'+earlyexit_max 

*(earlyexit_max is from the metadata and is the maximum time a test can be after the exit date for each site)
replace test_tag=1 if hiv_test_date>=entry_date`e' & hiv_test_date<=exit_temp & hiv_test_date<. & entry_date`e'<. & exit_temp<. 
}

/* replaced this with code above 26/5
gen exit_temp=analysis_end_date
replace exit_temp=last_exit_date+earlyexit_max if last_exit_date+earlyexit_max<analysis_end_date
*(earlyexit_max is from the metadata and is the maximum time a test can be after the exit date for each site)
gen test_tag=1 if hiv_test_date>=first_entry_date & hiv_test_date<=exit_temp & hiv_test_date<. & first_entry_date<. & exit_temp<.
*/
**find first and last test dates (within the residency dates only)
*any test
bys study_name idno:  egen firsttest=min(hiv_test_date) if test_tag==1
bys study_name idno:  egen firsttest_date=min(firsttest)
bys study_name idno:  egen lasttest=max(hiv_test_date) if test_tag==1
bys study_name idno:  egen lasttest_date=max(lasttest)
*negative
bys study_name idno:  egen first_negative=min(hiv_test_date) if hiv_test_result==0 & test_tag==1
bys study_name idno:  egen first_neg_date=min(first_negative) 
bys study_name idno:  egen last_negative=max(hiv_test_date) if hiv_test_result==0 & hiv_test_date<. & test_tag==1
bys study_name idno:  egen last_neg_date=min(last_negative)
*positive
bys study_name idno:  egen first_positive=min(hiv_test_date) if hiv_test_result==1 & test_tag==1
bys study_name idno:  egen first_pos_date=min(first_positive)
bys study_name idno:  egen last_positive=max(hiv_test_date) if hiv_test_result==1 & hiv_test_date<. & test_tag==1
bys study_name idno:  egen last_pos_date=min(last_positive)
drop firsttest lasttest first_negative last_negative first_positive last_positive test_tag



*reshape to wide format, retain all test dates and details
reshape wide hiv_test_date hiv_test_result test_assumption test_report_date  source_of_test_information survey_round_name informed_of_result   ,i(study_name idno lasttest_date firsttest_date ) j(test_sequence) 


*===============================================================================================
* ADD DOCUMENTATION INFORMATION
*===============================================================================================


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


save "${alphapath}/ALPHA/prepared_data/${sitename}/hiv_tests_wide_${sitename}",replace
*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"

*****************************************************************************
*  GET SURVEY DATES AND REFERENCE PERIODS FROM SEXUAL BEHAVIOUR DATA 
*****************************************************************************

*===================================================================================
*DEFINE MACROS FOR DOCUMENTATION
local id ="p18"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_grey_area_dates_for_behaviour_from_survey_data.do"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename}.dta" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/grey_area_dates_for_behaviour_from_survey_data_${sitename}"
local does="Gets dates of surveys and reference periods for sexual behaviour questions to work out which periods of time contain known behaviour and which unknown- the grey areas."
*===================================================================================

*===================================================================================
*  DEFINE DATES FOR GREY AREAS 
*===================================================================================

*===============================================
*GET SURVEY DATES AND GREY AREA BOUNDARIES
*===============================================

*BRING IN THE RECODED DATASET BASED ON SEXUAL BEHAVIOUR SPEC 10.1
use "${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename}.dta", clear

cap drop _merge
merge m:1 study_name survey_round_name using ${alphapath}/ALPHA/clean_data/survey_metadata
drop if _m==2

gen double refstart=interview_date-phistref*365.25


*DROP ANY DUPLICATES
duplicates report survey_round_name idno interview_date
duplicates drop

*GET START DATE OF THE GREY AREA- THE DATE OF THE PREVIOUS INTERVIEW
sort idno survey_round_name
gen double greystart=interview_date[_n-1] if idno==idno[_n-1]
bys idno (survey_round_name):gen double greyend=refstart
format %td grey*
gen overlap=0
replace overlap=1 if greyend<greystart & greyend<.
label var overlap "Ref period for subsequent survey starts before this survey date"

replace greyend=greystart if overlap==. 

replace refstart=greyend if overlap[_n-1]==1
format refstart %td
drop overlap

**** SAVE A DATASET CONTAINING GREY AREA DATES

keep study_name idno survey_round_name interview_date refstart grey* 
bys study_name idno (survey_round_name):gen seq=_n
reshape wide survey_round_name interview_date refstart greystart greyend,i(idno study_name) j(seq)



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

*===================================================================================
*  SAVE THE DATA AND CREATE A DOCUMENT WITH DATA INFO
*===================================================================================

save ${alphapath}/ALPHA/prepared_data/${sitename}/grey_area_dates_for_behaviour_from_survey_data_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"


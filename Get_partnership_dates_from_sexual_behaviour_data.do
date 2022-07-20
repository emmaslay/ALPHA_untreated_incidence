*****************************************************************************
*  GET SURVEY DATES AND REFERENCE PERIODS FROM SEXUAL BEHAVIOUR DATA 
*****************************************************************************

*===================================================================================
*DEFINE MACROS FOR DOCUMENTATION
local id ="p19"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_partnership_dates_from_sexual_behaviour_data.do"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename}.dta" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/partnership_dates_from_from_sexual_behaviour_data_${sitename}"
local does="Gets start and end dates for all sexual partnerships reported in the partner history of each survey."
*===================================================================================

*===================================================================================
*  GET START AND END DATES FOR PARTNERSHIPS 
*===================================================================================

*BRING IN THE RECODED DATASET BASED ON SEXUAL BEHAVIOUR SPEC 10.1
use "${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename}.dta", clear

keep study_name idno survey_round_name whenfirst_date* whenlast_date* ongoing*
reshape long whenfirst_date whenlast_date ongoing,i(idno survey_round_name) j(seq)
drop if whenfirst==. & whenlast==.
rename whenfirst early_pship_start_
rename whenlast late_pship_end_
replace late_pship_end=. if ongoing==1 | ongoing==3
gen early_pship_end_=early_pship_start_+182.5
gen late_pship_start_=late_pship_end_-182.5
format %td early* late*
drop ongoing
reshape wide early_pship_start_ early_pship_end_ late_pship_start_ late_pship_end_,i(idno survey_round_name) j(seq)
*reshape again to get one record per person, wide for each survey they participated in
bys study_name idno (survey_round_name):gen seq=_n
rename early_pship_start_* early_pship_start_*_
rename early_pship_end_* early_pship_end_*_
rename late_pship_start_* late_pship_start_*_
rename late_pship_end_* late_pship_end_*_
rename survey_round_name pship_dates_survey
reshape wide pship_dates_survey early_pship_start_*_ early_pship_end_*_ late_pship_start_*_ late_pship_end_*_,i(idno) j(seq) 


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

save ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_partnership_dates_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"




*****************************************************************************
*  GET BEST ESTIMATE OF DATE OF BIRTH
*****************************************************************************


local id ="p12"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_Date_of_Birth_from_residency_spec.do"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/residency_${sitename}.dta" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/dob_${sitename}"
local does="Summarises the dates of birth for each person and assigns single most likely one for each person"



*****************************************************************************
*  SECTION 1: HOUSEKEEPING
*****************************************************************************
use "${alphapath}/ALPHA/clean_data/${sitename}/residency_${sitename}.dta", clear
if lower("${sitename}")=="kisumu" {
keep if residenc==2
}
keep idno dob sex study_name
collapse (min) mindob=dob minsex=sex (max) maxdob=dob maxsex=sex (mean) meandob=dob ,by(idno study_name)
*need to consider how to resolve any differences
*ideally this would be done prior to creation of spec 6.1
gen dob=meandob
count if maxdob~=mindob
if r(N)==0 {

drop mindob maxdob meandob
}
count if maxsex~=minsex
if r(N)==0 {
gen sex=minsex
drop minsex maxsex
}
format dob %td


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
save ${alphapath}/ALPHA/prepared_data/${sitename}/dob_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"


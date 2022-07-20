*****************************************************************************
*  GET DATES OF HOUSE MOVES FROM RESIDENCY EPISODES 
*****************************************************************************


local id ="p13"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Get_change_of_residence_dates_from_residency_spec.do"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/residency_${sitename}" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/move_dates_${sitename}"
local does="Gets dates of changes in residence, wide file for merging"


** do it this way for all sites except Manicaland- no HH mobility in their residency spec. Instead that info is in 10.1 (see end of do file).
if lower("${sitename}")~="manicaland" {
*get dates of changes in residence from 6.1
use ${alphapath}/ALPHA/clean_data/${sitename}/residency_${sitename},clear
*rename variables for reshape
cap drop date
recast  double idno
rename entry_date date1 
rename entry_type type1
rename exit_date date2 
rename exit_type type2

*Creating a label that combines exit and entry types
recode type1 1=11 2=12 3=13
label define type  1 "Present in Study"  2 "Death" 3 "out-migration" 4 "Lost to follow up" 11 "Baseline" 12 "Birth" 13 "in-migration"
label values type1 type
label values type2 type

*identify changes in household
bys idno (date1):gen order=_n
bys idno (order):gen hhchange=1 if idno==idno[_n-1] & hhold_id~=hhold_id[_n-1]

*two dates on each record- each might be an event of interest 
*reshape long to manage them more easily
reshape long date type,i(idno order) j(inout)

*look at exits, outmigration
bys idno (order):gen event_date=date if type==3 & inout==2 & date~=date[_n+1] & idno==idno[_n+1]

*look at entry, inmigration- but only if this record doesn't carry on from previous
bys idno (order):replace event_date=date if type==13 & inout==1 & date~=date[_n-1] & idno==idno[_n-1]

*pick up the changes in hhold id from above
bys idno (order):replace event_date=date if hhchange==1 & inout==1 

keep if event_date<.

keep idno event_date study_name

rename event_date move_date

format move_date %td
bys idno (move_date):gen order=_n

reshape wide  move_date,i(study_name idno) j(order)
}


***DIFFERENT FOR MANICALAND

if lower("${sitename}")=="manicaland" {

use study_name idno interview_date mobile using  ${alphapath}/ALPHA/clean_data/${sitename}/sexual_behaviour_${sitename},clear
*keep the people who had moved in the last year
keep if mobile==1
*make the date 6 months before interview- don't know whey they did move so on average it was 6 months ago
gen move_date=interview_date-182
format move_date %td
bys idno (move_date):gen order=_n

drop interview_date
reshape wide  move_date,i(study_name idno) j(order)
drop mobile
}


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
*now have a dataset with the dates of a change in household/migration
save ${alphapath}/ALPHA/prepared_data/${sitename}/move_dates_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"


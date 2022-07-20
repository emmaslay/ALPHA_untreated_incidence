

*** define global macros used in documentation
local id ="s9"
local name="${alphadrive}/dofiles/common/create_fiveyear.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Uses years_one created by calendar_year_split and groups it into five-year groups, first group is 1989-94 though. Creates fiveyear"


gen fiveyear=years_one
recode fiveyear 1989/1994=1 1995/1999=2 2000/2004=3 2005/2009=4 2010/2014=5 2015/2019=6 2020/2024=7 
label define fiveyear 1 "1989-1994" 2 "1995-1999" 3 "2000-2004" 4 "2005-2009" 5 "2010-2014" 6 "2015-2019" 7 "2020-2024",modify
label values fiveyear fiveyear
label var fiveyear "Calendar year in 5-year groups"


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

** attach a note describing provenance to each NEW variable- spec variables already have a [source]
qui desc ,varlist sh
local newvarlist=subinstr("`r(varlist)'","`oldvarlist'","",.)

foreach v in `newvarlist' {
local source:char `v'[source]
*if this is empty then
if "`source'"=="" {
char `v'[source] "`name'"
char `v'[id] "`id'"
} /*close if */

} /*close var loop */

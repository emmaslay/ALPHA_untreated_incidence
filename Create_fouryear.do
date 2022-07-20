

*** define global macros used in documentation
local id ="s9"
local name="${alphadrive}/dofiles/common/Create_fouryear.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Uses years_one created by calendar_year_split and groups it into groups primarily useful for incidence analysis: first group is 1989-99 (not used much) then 2000-04 (for power) and 4 year groups after that. Creates fouryear"


recode years_one (1989/1999=0 "earliest-1999") (2000/2004=1 "2000-04") (2005/2008=2 "2005-08") (2009/2012=3 "2009-12") (2013/2016=4 "2013-16") (2017/2020=5 "2017-20") (2021/2024=6 "2021-24"),gen(fouryear) label(fouryear)
label var fouryear "Calendar year, grouped in 4 years post 2005"


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

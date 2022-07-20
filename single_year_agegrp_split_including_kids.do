



*** define global macros used in documentation
local id ="s2"
local name="${alphadrive}/dofiles/common/single_year_agegrp_split_including_kids.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Splits person time, in an already stset dataset, into age in single years- creates age variable"



************* SPLIT DATA INTO SINGLE YEARS AND CREATE AGE

stsplit age, at(0(1)90)

label var age "Age in single years"

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

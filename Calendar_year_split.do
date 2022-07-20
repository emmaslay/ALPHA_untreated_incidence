

*** define global macros used in documentation
local id ="s3"
local name="${alphadrive}/dofiles/common/Calendar_year_split.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Splits person time, in an already stset dataset, based on calendar year into single years and creates years_one"

*get list of existing variables
qui desc,sh varlist
local oldvarlist "`r(varlist)'"


local scale: char _dta[st_s]
di "`scale'"


tempvar  tempyearentry
tempvar  tempyearexit

gen `tempyearentry'=year((_t0*`scale')+_origin)
gen `tempyearexit'=year((_t*`scale')+_origin)


summ `tempyearentry'
local firstyear=r(min)

summ `tempyearexit'
local lastyear=r(max)


gen years_one=.
forvalues i=`firstyear'/`lastyear' {
	stsplit years, after(mdy(1,1,`i')) at(0)
	replace years_one=`i' if years==0 
	drop years
	} /*close forvalues*/


label var years_one "Calendar year"
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

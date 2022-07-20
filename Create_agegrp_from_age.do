

*** define global macros used in documentation
local id ="s8"
local name="${alphadrive}/dofiles/common/create_agegrp.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Uses age which is created in single_year_agegrp_split_including_kids so must run after that. Creates agegrp which is 5-year groups starting at age 0"



gen agegrp=age
recode agegrp 0/4=0 5/9=1 10/14=2 15/19=3 20/24=4 25/29=5 30/34=6 35/39=7 40/44=8 45/49=9 50/54=10 55/59=11 60/64=12 65/69=13 70/74=14   ///
75/79=15 80/84=16 85/89=17 90/max=18
label define agegrp 0 "0-4" 1 "5-9" 2 "10-14" 3 "15-19" 4 "20-24" 5 "25-29" 6 "30-34" 7 "35-39" 8 "40-44" 9 "45-49" ///
 10 "50-54" 11 "55-59" 12 "60-64" 13 "65-69" 14 "70-74" 15"75-79" 16 "80-84" 17 "85-89" 18 "90+",modify
label values agegrp agegrp
label var agegrp "Five year age group"




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

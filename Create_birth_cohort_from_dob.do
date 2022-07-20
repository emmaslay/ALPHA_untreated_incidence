

*** define global macros used in documentation
local id ="s9"
local name="${alphadrive}/dofiles/common/create_birth_cohort_from_dob.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Makes year of birth and recodes that into 5-year birth cohorts"

tempname yob

gen `yob'=year(dob)
#delimit;
recode `yob' 

(1900/1904=1 "1900-1904")
(1905/1909=2 "1905-1909")
(1910/1914=3 "1910-1914")
(1915/1919=4 "1915-1919")
(1920/1924=5 "1920-1924")
(1925/1929=6 "1925-1929")
(1930/1934=7 "1930-1934")
(1935/1939=8 "1935-1939")
(1940/1944=9 "1940-1944")
(1945/1949=10 "1945-1949")
(1950/1954=11 "1950-1954")
(1955/1959=12 "1955-1959")
(1960/1964=13 "1960-1964")
(1965/1969=14 "1965-1969")
(1970/1974=15 "1970-1974")
(1975/1979=16 "1975-1979")
(1980/1984=17 "1980-1984")
(1985/1989=18 "1985-1989")
(1990/1994=19 "1990-1994")
(1995/1999=20 "1995-1999")
(2000/2004=21 "2000-2004")
(2005/2009=22 "2005-2009")
(2010/2014=23 "2010-2014")
(2015/2019=24 "2015-2019")
(2020/2024=25 "2020-2024")
(2025/2029=26 "2025-2029")
,label(birth_cohort) gen(birth_cohort);
#delimit cr
 
label var birth_cohort "Five year birth_cohort"




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

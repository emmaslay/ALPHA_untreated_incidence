

/*
This do file creates a variable hivstatus_deatil that splits a persons person time
in to the most detailed categories.  It relies on you having already created the following
variables in your analysis file:

timepostneg - This is the cut off you want to you for post negative time
timeprepos - This is the cut off you want for pre positive time

Also HIV test data variables based on 6.2b data

first_neg_date - First negative test date
last_neg_date - Last negative test date
first_pos_date - First positive test date
last_pos_date - First positive test date


sero_conv_date - This is the date halfway between last negative date and first positive date


The global macro ${prefix} is so that if you have more that one set of hivstatus details to create in one dataset
you can use the prefix to differentiate them.  For example a file of children with date also on mothers and fathers
you might want hivstatus for the child and then split the childs experience in to the hivstatus_detail of the parents
*/


*** define global macros used in documentation
local id ="s1"
local name="${alphapath}/dofiles/common/create_hivstatus_detail.do"
local level="common"
local calls=""
local uses="" 
local saves=""
local does="Splits person time, in an already stset dataset, based on HIV status from study tests"


*get list of existing variables
qui desc,sh varlist
local oldvarlist "`r(varlist)'"


*Creating label and hivstatus_detail variable

#delimit ;
label define hivstatus_detail 

1 "Negative" 
2 "Positive"  

3 "Before first negative test" 
4 "Post Negative within cutoff" 
5 "Post negative beyond cutoff" 

6 "After last positive test"
7 "Pre positive within cutoff" 
8 "pre positive beyond cutoff"

9 "SC interval post neg within cutoff" 
10 "SC interval post neg beyond cutoff" 
11 "SC interval pre positive within cutoff" 
12 "SC interval pre positive beyond cutoff"

13 "Unknown, never tested"
, modify;
#delimit cr

gen ${prefix}hivstatus_detail=.
label values ${prefix}hivstatus_detail hivstatus_detail


*Generate a date that is X years after the last negative test
gen after_negXyear=${prefix}last_neg_date+(365.25*timepostneg)
format after_neg*year %td
label var after_negXyear "date X years after last negative test "


*Generate a date that is  X years before the first positive test
gen before_posXyear=${prefix}first_pos_date-(365.25*timeprepos) 
label var before_posXyear "date X years before first positive test "


*Splitting up follow-up time by HIV status as appropriate

*Negative splits
stsplit split_on_firstneg if ${prefix}first_neg_date~=., after(${prefix}first_neg_date) at(0)
stsplit split_on_lastneg if ${prefix}last_neg_date~=., after(${prefix}last_neg_date) at(0)
stsplit split_on_afternegXyear if after_negXyear~=., after(after_negXyear) at(0)

*Positive splits
stsplit split_on_firstpos if ${prefix}first_pos_date~=., after(${prefix}first_pos_date) at(0)
stsplit split_on_beforeposXyear if before_posXyear~=., after(before_posXyear) at(0)
stsplit split_on_lastpos if ${prefix}last_pos_date~=., after(${prefix}last_pos_date) at(0)

*Sero conversion split
stsplit split_at_sc if ${prefix}sero_conv_date~=., after(${prefix}sero_conv_date) at(0)

*Negative time
replace ${prefix}hivstatus_detail=1 if split_on_firstneg==0 & split_on_lastneg==-1 /*negative*/
replace ${prefix}hivstatus_detail=3 if split_on_firstneg==-1 /*before first negative test*/
replace ${prefix}hivstatus_detail=4 if split_on_lastneg==0 & split_on_afternegXyear==-1 /*post negative within cutoff*/
replace ${prefix}hivstatus_detail=5 if split_on_lastneg==0 & split_on_afternegXyear==0 /*post negative beyond cutoff*/

*Positive time
replace ${prefix}hivstatus_detail=2 if split_on_firstpos==0 & split_on_lastpos==-1 /*positive*/
replace ${prefix}hivstatus_detail=6 if split_on_lastpos==0 /*after last positive test*/
replace ${prefix}hivstatus_detail=7 if split_on_firstpos==-1 & split_on_beforeposXyear==0 & split_on_firstneg==.  /* pre positive within cutoff*/
replace ${prefix}hivstatus_detail=8 if split_on_firstpos==-1 & split_on_beforeposXyear==-1 & split_on_firstneg==. /*pre positive beyond cutoff*/

*Sero conversion interval
replace ${prefix}hivstatus_detail=9 if split_on_lastneg==0 & split_at_sc==-1 & split_on_afternegXyear==-1 /*SC interval post neg within cutoff*/
replace ${prefix}hivstatus_detail=10 if split_on_lastneg==0 & split_at_sc==-1 & split_on_afternegXyear==0 /*SC interval post neg beyond cutoff*/

replace ${prefix}hivstatus_detail=11 if split_on_firstpos==-1 & split_at_sc==0 & split_on_beforeposXyear==0 /*SC interval pre pos within cutoff*/
replace ${prefix}hivstatus_detail=12 if split_on_firstpos==-1 & split_at_sc==0 & split_on_beforeposXyear==-1 /*SC interval pre pos beyond cutoff*/

*Unknown time
replace ${prefix}hivstatus_detail=13 if ${prefix}first_neg_date==. & ${prefix}first_pos_date==. /*unknown, no test results*/


*Drop all variables that were created to make hivstatus_detail
drop after_negXyear before_posXyear 
drop split_on_firstneg split_on_lastneg split_on_afternegXyear split_on_firstpos split_on_beforeposXyear split_on_lastpos split_at_sc

label var ${prefix}hivstatus_detail "HIV status detail"



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

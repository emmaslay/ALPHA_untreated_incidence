
cap mkdir ${alphapath}/ALPHA\Incidence_ready_data/pooled

local poolsites="Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude"

quietly {

*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
* POOL THE MI FILES
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*** NEED TO DO THIS FOR AS MANY IMPUTATIONS AS THERE ARE IN ALL THE DIRECTORIES

*LOOK IN EACH SITE'S FOLDER AND COUNT THE IMPUTATIONS, find the minimum number available for all sites
global min_imp=1000

foreach p in `poolsites' {
local counter=1
local keepgoing=1

while `keepgoing'==1 {
*see if the file can be found
cap confirm file "${alphapath}/ALPHA\Incidence_ready_data/`p'/mi_data/incidence_ready_MI_`p'_`counter'.dta"
*if it can't be found stop the loop
if _rc~=0 {
local keepgoing=0
} /*close _rc if */

local site_imp=`counter'-1
local counter=`counter'+1
} /*close while loop */


*make this the new minimum number of imputations, if it is lower than the current number
if `site_imp'<$min_imp {
global min_imp=`site_imp'
}

} /*close site loop */


*** NOW POOL THE NUMBER OF IMPUATIONS THAT ARE AVAILABLE FOR EACH SITE

*set up the loop to run until there are no more files - no more imputations
forvalues x=1/$min_imp {

clear
*loop through each site, append datasets for this imputation into a pooled file
foreach p in `poolsites' {
*check the  file exists, if it does not exist then exit the loop by setting while to 0
cap use ${alphapath}/ALPHA\Incidence_ready_data/`p'/mi_data/incidence_ready_MI_`p'_`x'.dta
if _rc~=0 {
local withinrange=0
}
append using ${alphapath}/ALPHA\Incidence_ready_data/`p'/mi_data/incidence_ready_MI_`p'_`x'.dta,
} /*close site loop */

rename idno idno_orig
gen double idno=study_name*1000000 + idno_orig
*save the poold file for this imputation
save ${alphapath}/ALPHA\Incidence_ready_data/pooled/mi_data/incidence_ready_MI_pooled_`x'.dta,replace

} /*close while */

} /*close quietly */





*POOL THE AGE RANGE OF THE SEXUAL PARTNERS
/* Done already for acquisitions
use K:/ALPHA\Ready_data_untreated_prevalence/karonga/partner_age_range_karonga,clear
append using K:/ALPHA\Ready_data_untreated_prevalence/kisesa/partner_age_range_kisesa
append using K:/ALPHA\Ready_data_untreated_prevalence/manicaland/partner_age_range_manicaland
append using K:/ALPHA\Ready_data_untreated_prevalence/rakai/partner_age_range_rakai
append using K:/ALPHA\Ready_data_untreated_prevalence/umkhanyakude/partner_age_range_umkhanyakude
append using K:/ALPHA\Ready_data_untreated_prevalence/kisumu/partner_age_range_kisumu
append using K:/ALPHA\Ready_data_untreated_prevalence/ifakara/partner_age_range_ifakara

gen orig=1
append using K:/ALPHA\Ready_data_untreated_prevalence/rakai/partner_age_range_rakai
replace study_name=4 if study_name==5 & orig==.

*FILL IN GAPS
sort study_name sex age years_one
by study_name sex age:egen tmpmean=mean(p5age)
by study_name sex age:replace p5age=tmpmean if p5age==. 
drop tmpmean
by study_name sex age:egen tmpmean=mean(p95age)

by study_name sex age:replace p95age=tmpmean if p95age==. 

drop anypagedata orig tmpmean
save K:\ALPHA\Projects\Gates_incidence_risks_2019/partner_age_range_pooled,replace
*/

*SUMMARISE THE PAR
use "K:\ALPHA\Ready_data_partnership_dynamics\pooled\losses_ready_pooled.dta",clear
drop fouryear
do  "K:\ALPHA\DoFiles\Common\Create_fouryear.do" 

stset
strate study_name fouryear sex age,output(K:\ALPHA\Projects\Gates_incidence_risks_2019/fouryear_ASPLR.dta,replace) per(100)



*use the age gaps dataset

use K:\ALPHA\Projects\Gates_incidence_risks_2019/partner_age_range_pooled,clear

do  "K:\ALPHA\DoFiles\Common\Create_fouryear.do" 
drop if years_one<1995 | years_one==.
merge m:1 study_name sex fouryear age using  K:\ALPHA\Projects\Gates_incidence_risks_2019/fouryear_ASPLR.dta,
keep if _m==3





** WRITE A DATASET WITH SUMMARY OF AGE, FIVE CALENDAR YEAR GROUP AND THE OPPOSITE SEX PREVALENCE 
* USE frames

cap  frame drop opp_sex_asplr
frame create opp_sex_asplr study_name sex  age fouryear opp_sex_plr


*loop through study_name
levels study_name,local(slist)
foreach site in `slist' {

	*loop through calendar years
	levels fouryear if study_name==`site',local(flist)
	foreach f in `flist'{

		** MEN
		forvalues x=15/59 {
			qui summ p5 if  sex==1 & age==`x' & fouryear==`f' & study_name==`site'
			local agemin=r(mean)
			qui summ p95 if  sex==1 & age==`x'  & fouryear==`f' & study_name==`site'
			local agemax=r(mean)
			*if both ages are the same, spread them out 5 years either side- i.e. a 10 year range
			if `agemin'==`agemax' {
				local agemin=`agemin'-5
				local agemax=`agemax'+5
				}
			
				*PAR IN OPPOSITE SEX- HAPHAZARDLY WEIGHTED BY AGE RANGE- HAPHAZARD BECAUSE THIS RELIES ON THE DISTRIBUTION OF AGES IN THE DATASET INSTEAD OF THE POPULATION
				qui summ  _Rate if sex==2 & age>=`agemin' & age<=`agemax' & fouryear==`f' & study_name==`site'
				local par_est=r(mean)
				
				*SEND RESULTS TO DATASET
				frame post opp_sex_asplr (`site') (1)  (`x') (`f') (`par_est')
				

			} /*close age loop */



		** WOMEN
		forvalues x=15/59 {
			qui summ p5 if  sex==2 & age==`x' & fouryear==`f' & study_name==`site'
			local agemin=r(mean)
			qui summ p95 if  sex==2 & age==`x'  & fouryear==`f' & study_name==`site'
			local agemax=r(mean)
			*if both min and max ages are the same, spread them out 5 years either side- i.e. a 10 year range
			if `agemin'==`agemax' {
				local agemin=`agemin'-5
				local agemax=`agemax'+5
				}
				*PAR IN OPPOSITE SEX- HAPHAZARDLY WEIGHTED BY AGE RANGE- HAPHAZARD BECAUSE THIS RELIES ON THE DISTRIBUTION OF AGES IN THE DATASET INSTEAD OF THE POPULATION
				qui summ  _Rate if sex==1 & age>=`agemin' & age<=`agemax' & fouryear==`f' & study_name==`site'
				local par_est=r(mean)
				
				*SEND RESULTS TO DATASET
				frame post opp_sex_asplr (`site')  (2) (`x') (`f') (`par_est')
				

			} /*close age loop */



	} /*close fouryear loop */

} /*close site loop */
frame opp_sex_asplr:save K:\ALPHA\Projects\Gates_incidence_risks_2019/opp_sex_asplr_for_merge,replace


*use the dataset we just output
use "K:\ALPHA\Projects\Gates_incidence_risks_2019/opp_sex_asplr_for_merge",clear
*label the variables using the value labels saved earlier
label var sex "Sex"
label var study_name "Study"
label var fouryear "Calendar year, 4-year groups"
label var opp_sex_plr "Mean PLR in opposite sex partners"
label data "Estimates of mean partner loss rates among potential sexual partners of the opposite sex, age and calendar time specific"


*no date in over 49s
drop if age>49
save K:\ALPHA\Projects\Gates_incidence_risks_2019/opp_sex_asplr_for_merge,replace



use K:\ALPHA\Projects\Gates_incidence_risks_2019/opp_sex_asplr_for_merge,clear
merge 1:1 study_name sex age fouryear using K:\ALPHA\Projects\Gates_incidence_risks_2019/fouryear_ASPLR.dta

drop _m
drop _D _Y _L _U
rename _Rate same_sex_plr

save K:\ALPHA\Projects\Gates_incidence_risks_2019/asplr_for_merge,replace






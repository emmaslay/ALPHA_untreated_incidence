
/************************************************************************
THIS DO FILE GETS:
1) THE AGE RANGE OF SEXUAL PARTNERS
2) THE HIV PREVALENCE IN EACH SITE IN MEMBERS OF THE OPPOSITE SEX. 
3) THE PROPORTION OF HIV POSITIVE PEOPLE OF THE OPPOSITE SEX WHO ARE ON TREATMENT.

************************************************************************/


foreach s in    Karonga kisesa kisumu manicaland  rakai umkhanyakude  Ifakara masaka {
*foreach s in    rakai  {

global sitename="`s'"

*=========================================================================
**  SECTION 1: RANGE OF AGES AMONG REPORTED SEXUAL PARTNERS
*=========================================================================

*reshapes the information given in partner histories so that we have one record per partnership
*then estimates the age of each sexual partner, based on actual age or age relative to respondent's age
*works out the minimum, maximum and 5th and 95th percentiles of the age distribution
*does this for men and women, by single year of age and for calendar year period

use "${alphapath}/ALPHA\Prepared_data/${sitename}/sexual_behaviour_recoded_${sitename}.dta",clear
gen years_one=year(interview_date)
drop _merge
*If no sex collected in survey need to merge it in from residency
cap confirm variable sex
if _rc~=0{
merge m:1 study_name idno using "${alphapath}/ALPHA\Prepared_data/${sitename}/dob_${sitename}"
drop if _merge==2 
drop _merge
}

*check if survey_age is empty
cap confirm variable survey_age
if _rc==0 {                           /*if variable exists */
summ survey_age                              /*check to see if there are any values */
if r(N)==0 {                     /*if none, replace them with age calculated from date of birth */
replace survey_age=int((interview_date-dob)/365.25)
}
}

*if variable doesn't exist, create it by calculating age from date of birth
if _rc~=0 {
survey_age=int((interview_date-dob)/365.25)
}

*** check if there is variable for pexactage
cap confirm variable pexactage1
if _rc~=0{
gen pexactage1=.
}

keep study_name idno years_one sex survey_age page* pexactage* survey_round_name
  
reshape long page pexactage,i(study_name idno sex survey_age years_one survey_round_name) j(pnum)
cap label drop artlbl
do "${alphapath}/ALPHA\DoFiles\Common\Create_fouryear.do" 


*estimate partner's age
*use eact age if reported
gen estage=pexactage if pexactage>14 & pexactage<98
*put as same age if age difference is less than 5 years
replace estage=survey_age-0 if page==3 &  estage==.
* put as 7.5 years older/younger if page is 2 or 4
replace estage=survey_age-7.5 if page==4 & estage==.
replace estage=survey_age+7.5 if page==2 & estage==.

* put as 10.5 years older/younger if page is 1 or 5
replace estage=survey_age+10.5 if page==1 & estage==.
replace estage=survey_age-10.5 if page==5 & estage==.

*make minimum age 15
replace estage=15 if estage<15


/* example histograms
cap mkdir  ${alphapath}/ALPHA\Estimates_untreated_prevalence/results/
cap mkdir  ${alphapath}/ALPHA\Estimates_untreated_prevalence/results/${sitename}

hist estage if fouryear==4 & survey_age==20,discrete by(sex) xtitle("Age of partner") xline(20,lcolor(lime)) norm  normopts(lcolor(gs10)) percent title("Age 20") xsize(8) xlabel(15(5)85) 
graph export ${alphapath}/ALPHA\Estimates_untreated_prevalence/results/${sitename}/age_distribution_20.png,replace width(6000)

hist estage if fouryear==4 & survey_age==30,discrete by(sex) xtitle("Age of partner") xline(30,lcolor(lime)) norm  normopts(lcolor(gs10)) percent title("Age 30") xsize(8)  xlabel(15(5)85)
graph export ${alphapath}/ALPHA\Estimates_untreated_prevalence/results/${sitename}/age_distribution_30.png,replace width(6000)

hist estage if fouryear==4 & survey_age==40,discrete by(sex) xtitle("Age of partner") xline(40,lcolor(lime)) norm  normopts(lcolor(gs10)) percent title("Age 40") xsize(8)  xlabel(15(5)85)
graph export ${alphapath}/ALPHA\Estimates_untreated_prevalence/results/${sitename}/age_distribution_40.png,replace width(6000)
*/
collapse (min) minage=estage (p5) p5age=estage (p95) p95age=estage (max) maxage=estage,by(study_name sex survey_age years_one )

sort years_one sex survey_age
*borrow from the year before if there is just no estimate for this age group
bys study_name years_one sex (survey_age):replace minage=minage[_n-1] if minage==. 
bys study_name years_one sex (survey_age):replace p5age=p5age[_n-1] if p5age==. 
bys study_name years_one sex (survey_age):replace p95age=p95age[_n-1] if p95age==. 
bys study_name years_one sex (survey_age):replace maxage=maxage[_n-1] if maxage==. 

*if no estimate for a calendar year period, borrow the average
bys study_name sex years_one:egen anypagedata=max(p5age)
recode anypagedata 0/max=1 .=0
label var anypagedata "Data on partners' ages directly reported"

label define anypagedata 0 "No data on page for this period" 1 "Data reported on page",modify
label values anypagedata anypagedata

sort years_one sex survey_age

bys sex survey_age: egen temp_minage=mean(minage)
bys sex survey_age: egen temp_p5age=mean(p5age)
bys sex survey_age: egen temp_p95age=mean(p95age)
bys sex survey_age: egen temp_maxage=mean(maxage)

replace minage=temp_minage if minage==. & anypagedata==0 
replace p5age=temp_p5age if p5age==. & anypagedata==0 
replace p95age=temp_p95age if p95age==. & anypagedata==0 
replace maxage=temp_maxage if maxage==. & anypagedata==0 

drop temp_* 

drop if survey_age<15
drop if survey_age>59
rename survey_age age
save "${alphapath}/ALPHA\Ready_data_untreated_prevalence/${sitename}/partner_age_range_${sitename}",replace
*++++++++++++++++++++++++++++++++++++++


*=========================================================================
**  SECTION 2: PROPORTION OF HIV POSITIVE PEOPLE WHO HAVE INITIATED ART, BY AGE
*=========================================================================
*** THIS IS A BODGE- MARCH 2019- REALLY THIS SHOULD BE DONE FROM SCRATCH USING THE PREPARED DATA- THE GATES FILE IS A BIT OVER THE TOP FOR THIS 
*** ANOTHER ISSUE IS KISUMU'S CLINIC DATA: WE NEED TO USE THE OLD GATES FILE FOR PRE-2016.
*** BRING IN THE ANALYSIS READY FILE FROM THE GATES WORKSHOP (VERY SIMILAR TO DATASET FROM DURBAN WORKSHOP)
if lower("${sitename}")~="kisumu" & lower("${sitename}")~="rakai" {
use ${jdrive}/alpha/gates1/gates_methods/current_site_data/ALPHA_Gates_ready_2018_${sitename},clear


*KEEP HIV POSITIVE PEOPLE WITH KNOWN AGE, AND INFORMATION ON ART HISTORY
drop if age==.

keep if hivstatus_br==2
keep if allinfo_treat_pyramid>2

*RESTRICT TO AGES 15-59 & YEARS 2000-2017
keep if agegrp<10
keep if year>1999 & year<2018

*MAKE A VARIABLE TO SUMMARISE PERSON TIME
cap drop fup
gen fup=_t-_t0

*define fouryear
do "${alphapath}/ALPHA\DoFiles\Common\Create_fouryear.do" 
*redefine agegrp- different coding was used in Gates mortality file
drop agegrp
do "${alphapath}/ALPHA\DoFiles\Common\Create_agegrp_from_age.do" 

** save the value labels to reattach later
label save study_name using ${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}/artlbls,replace


*SUM THE PERSON TIME BY SEX, FIVE YEAR AGEGRP, FIVE CALENDAR YEAR GROUP AND HIV
*in masaka we only use people who were seen in clinic as denominator
if lower("`s'")=="masaka" {
collapse  (sum) fup if merge_61_62b_91_92==3,by(study_name sex agegrp  hivevertreat fouryear)
}
*everywhere else it is all positives 
else {
collapse  (sum) fup ,by(study_name sex agegrp  hivevertreat years_one fouryear)
}


*MAKE THE EVER TREATED VARIABLE BINARY
recode hivev 2=0 3=1
gen dummy=1
collapse  (mean) prop_treated=hivevertreat (sum) pyrs=dummy [iw=fup],by(study_name sex agegrp   fouryear)
label var prop_treated "Proportion of HIV+ time after ART initiation"

save "${alphapath}/ALPHA\Ready_data_untreated_prevalence/${sitename}/proportion_treated_${sitename}",replace

} /*close not kisumu loop */
if lower("${sitename}")=="kisumu" {
do   "K:\ALPHA\DoFiles\Analysis\Make_treatment_coverage_Kisumu_only.do" 
}

if lower("${sitename}")=="rakai" {
do   "K:\ALPHA\DoFiles\Analysis\Make_treatment_coverage_Rakai_only.do" 
}



*=========================================================================
**  SECTION 3: PROPORTION OF PEOPLE TESTED WHO ARE HIV POSITIVE (PREVALENCE)
*=========================================================================

** start with the wide HIV tests, these are already checked for residency
use ${alphapath}/ALPHA/prepared_data/${sitename}/hiv_tests_wide_${sitename},clear
*add in date of birth and sex
merge 1:1 study_name idno using ${alphapath}/ALPHA/prepared_data/${sitename}/dob_${sitename}

keep study_name idno sex dob hiv_test_date* hiv_test_result* source_of_test_information*

reshape long hiv_test_date hiv_test_result source_of_test_information,i(study_name idno) j(testnum)
drop if hiv_test_date==.

*Make age variable
gen age=int((hiv_test_date-dob)/365.25)
*Make a calendar year variable
gen years_one=year(hiv_test_date)

*RESTRICT TO 15-69 AND 2000-2017
keep if age>14 & age<60
keep if years_one>1999 & years_one<2019

do  "${alphapath}/ALPHA\DoFiles\Common\Create_fouryear.do" 
do  "${alphapath}/ALPHA\DoFiles\Common\Create_agegrp_from_age.do" 

*ONLY USE POPULATION BASED TESTS
keep if source==1
*drop indeterminate tests
drop if hiv_test_result==2
*drop random codeS
drop if hiv_test_result>2

*SAVE THE DATA FOR REFERENCE
save "${alphapath}/ALPHA\Ready_data_untreated_prevalence/${sitename}/observed_proportion_positive_${sitename}",replace

cap drop _merge

*BRING IN THE AGE RANGE OF SEXUAL PARTNERS
** Masaka doesn't have its own so will borrow Rakai's
if lower("${sitename}")~="masaka" {
merge m:1 study_name sex years_one age using "${alphapath}/ALPHA\Ready_data_untreated_prevalence/${sitename}/partner_age_range_${sitename}"
drop if _m==2
drop _m
}
if lower("${sitename}")=="masaka" {
merge m:1  sex years_one age using "${alphapath}/ALPHA\Ready_data_untreated_prevalence/Rakai/partner_age_range_Rakai"
drop if _m==2
drop _m
}

*BRING IN THE PROPORTION TREATED
*Ifakara doesn't have this data so will borrow Kisesa's
if lower("${sitename}")~="ifakara" {
merge m:1 study_name sex fouryear agegrp using "${alphapath}/ALPHA\Ready_data_untreated_prevalence/${sitename}/proportion_treated_${sitename}"
drop if _m==2
drop _m
}

if lower("${sitename}")=="ifakara" {
merge m:1  sex fouryear agegrp using "${alphapath}/ALPHA\Ready_data_untreated_prevalence/Kisesa/proportion_treated_Kisesa"
drop if _m==2
drop _m
}

** WRITE A DATASET WITH SUMMARY OF AGE, FIVE CALENDAR YEAR GROUP AND THE OPPOSITE SEX PREVALENCE 
* USE POSTFILE
*need a file handle, use a tempname as more efficient to run
tempname output_oppsexprev
*set up the new output dataset: define variable names and file name
cap mkdir ${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}
postfile `output_oppsexprev' sex study_name age years_one opp_sex_prev opp_sex_prev_lb opp_sex_prev_ub opp_sex_treated using ${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}/prevalence_in_opposite_sex_${sitename},replace

*loop through study_name
levels study_name,local(slist)
foreach site in `slist' {

	*loop through calendar years
	levels years_one if study_name==`site',local(flist)
	foreach f in `flist'{
		** MEN
		forvalues x=15/59 {
			qui summ p5 if  sex==1 & age==`x' & years_one==`f' & study_name==`site'
			local agemin=r(mean)
			qui summ p95 if  sex==1 & age==`x'  & years_one==`f' & study_name==`site'
			local agemax=r(mean)
			*if both ages are the same, spread them out 5 years either side- i.e. a 10 year range
			if `agemin'==`agemax' {
				local agemin=`agemin'-5
				local agemax=`agemax'+5
				}
			*PREVALENCE IN OPPOSITE SEX
			cap ci prop  hiv_test_result if sex==2 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
			if _rc==0 {
				qui ci prop  hiv_test_result  if sex==2 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
				local myest=r(proportion)
				local mylb=r(lb)
				local myub=r(ub)
			
				*PROPORTION TREATED IN OPPOSITE SEX- HAPHAZARDLY WEIGHTED BY AGE RANGE- HAPHAZARD BECAUSE THIS RELIES ON THE DISTRIBUTION OF AGES IN THE DATASET INSTEAD OF THE POPULATION
				qui summ  prop_treated if sex==2 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
				local treat_est=r(mean)
				
				*SEND RESULTS TO DATASET
				post `output_oppsexprev' (1) (`site') (`x') (`f') (`myest') (`mylb') (`myub') (`treat_est')
				
				} /*close no obs loop */

			} /*close age loop */



		** WOMEN
		forvalues x=15/59 {
			qui summ p5 if  sex==2 & age==`x' & years_one==`f' & study_name==`site'
			local agemin=r(mean)
			qui summ p95 if  sex==2 & age==`x'  & years_one==`f' & study_name==`site'
			local agemax=r(mean)
			*if both min and max ages are the same, spread them out 5 years either side- i.e. a 10 year range
			if `agemin'==`agemax' {
				local agemin=`agemin'-5
				local agemax=`agemax'+5
				}
			*PREVALENCE IN OPPOSITE SEX
			cap ci prop  hiv_test_result if sex==1 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
			if _rc==0 {
				qui ci prop  hiv_test_result if sex==1 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
				local myest=r(proportion)
				local mylb=r(lb)
				local myub=r(ub)
			
				*PROPORTION TREATED IN OPPOSITE SEX- HAPHAZARDLY WEIGHTED BY AGE RANGE- HAPHAZARD BECAUSE THIS RELIES ON ALL AGES WITHIN THE RANGE BEING REPRESENTED IN THE DATASET
				qui summ  prop_treated if sex==1 & age>=`agemin' & age<=`agemax' & years_one==`f' & study_name==`site'
				local treat_est=r(mean)
				
				*SEND RESULTS TO DATASET
				post `output_oppsexprev' (2) (`site') (`x') (`f') (`myest') (`mylb') (`myub') (`treat_est')
				
				} /*close no obs loop */

			} /*close age loop */



	} /*close years_one loop */

} /*close site loop */
*finish dataset
postclose `output_oppsexprev'

*use the dataset we just output
use "${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}/prevalence_in_opposite_sex_${sitename}",clear
*label the variables using the value labels saved earlier
do ${alphapath}/ALPHA/Ready_data_untreated_prevalence/prevlbls
label values years_one years_one
label values study_name study_name
label var sex "Sex"
label var study_name "Study"
label var years_one "Calendar year, 4-year groups"
label var opp_sex_prev "Estimated HIV prevalence in opposite sex partners"
label var opp_sex_prev_lb "Lower 95% CI for opposite sex prevalence"
label var opp_sex_prev_ub "Upper 95% CI for opposite sex prevalence"
label var opp_sex_treated "Estimated proportion of opposite sex PLHIV on treatment"
label data "Estimates of HIV prevalence and ART coverage among potential sexual partners of the opposite sex, age and calendar time specific"


*MULTIPLY THE HIV PREVALENCE BY THE PROPORTION UNTREATED TO GET UNTREATED PREVALENCE
gen untreated_opp_sex_prevalence=opp_sex_prev*(1-opp_sex_treated)
label var untreated_opp_sex_prevalence "Prevalence untreated HIV in opp sex partners"



save "${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}/prevalence_treatment_in_opposite_sex_${sitename}",replace


} /*close site loop */




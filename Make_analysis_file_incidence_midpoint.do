****************************************************************************
* ALPHA BASIC INCIDENCE ANALYSIS USING MIDPOINT AS SEROCONVERSION DATE
****************************************************************************

/* this is the simplest incidence do file and is the starting point for incidence 
analyses, most of which will additionally use the multiply imputed seroconversion dates
and the behavioural and socio-demographic data 
*/


	*need an estimate for number of years after 15th birthday we make the adjustment for prevalence positives
	*this could vary between sites but in the workshop everyone used 3
	global maxinter=2


	** *START WITH RESIDENCY EPISODES
	use "${alphapath}/ALPHA/clean_data/${sitename}/residency_${sitename}",clear

	*For Manicaland, drop out the communities that weren't included in R6
	if lower("${sitename}")=="manicaland" {
	tempname community
	gen `community'=int(hhold_id/10000)
	tab `community'
	drop if `community'==1 |`community'==6 |`community'==11 |`community'==12
	}
	** For uMkhanyakude drop TasP people
	local lowsite=lower("${sitename}")
	if "`lowsite'"=="umkhanyakude" {
	drop if entry_type==1 & year(entry_date)==2017
	}

	*MERGE IN TEST DATES IN WIDE FORM, ONLY USING TESTS DONE WHEN PERSON WAS RESIDENT
	merge m:1 study_name idno using "${alphapath}/ALPHA/prepared_data/${sitename}/HIV_tests_wide_${sitename}", generate(merge_6_1_and_6_2) 	keepusing(first_neg_date last_neg_date first_pos_date last_pos_date  lasttest_date firsttest_date )
		
	drop if merge_6_1_and_6_2==2



	*merging in metadata
	merge m:1 study_name using "${alphapath}/alpha/clean_data/alpha_metadata",gen(merge_meta)
	drop if merge_meta==2

	*labels
	label define sex 1 "Men" 2 "Women",modify
	label values sex sex

	** For Kisumu keep only Gem
	local lowsite=lower("${sitename}")
	if "`lowsite'"=="kisumu" {
		keep if residence==2
		*remove the people whose survey and residency details are very different
		*merge m:1 idno using ${alphapath}/ALPHA/prepared_data/${sitename}/imposters_kisumu
		*drop if _merge==3
		*drop _merge
		}


	*STSET - death (exit type 2) is failure
	*setting on mortality temporarily to organise the data- want to be able to use stsplit
	cap  stset,clear
	gen exit = exit_date
	gen entry = entry_date
	format %td entry exit
	gen failure=1 if exit_type == 2
	stset exit, time0(entry) failure(failure) origin(dob) id(idno) scale(365.25) 


	**EARLY EXIT ISSUES- these arise in sites where the DSS interview and the HIV test don't always take place on the same day.  It is necessary to move the exit date to after
	*the test dates, but there is an upper limit (defined in the metadata) beyond which the exit date shouldn't be moved.
	*The upper limit depends on what is known about fieldwork and how long the lag between DSS and HIV test is likely to have been.
	*If the tests are beyond the upper limit they are discarded if this is the last episode
	bysort study_name idno (entry_date):gen episode_sequence=_n
	bysort study_name idno (entry_date):gen episode_total=_N
	gen last_episode=0
	replace last_episode=1 if episode_sequence==episode_total
	gen temp=exit if last_episode==1
	bysort study_name idno: egen last_exit_original=max(temp)
	drop temp

	*if exit is on the same date as the last test, move the exit date to one day after
	gen early_exit_fixed_t=1 if exit==lasttest_date & lasttest_date<. & last_episode==1
	replace exit=exit+1 if exit==lasttest_date & lasttest_date<. & last_episode==1

	*identify people whose latest 6.1 exit is before latest 6.2 report & calculate difference
	* exit before last test
	gen exitgap_test=lasttest_date-exit if exit<lasttest_date & lasttest_date<. & last_episode==1

	gen early_exit_problem=.
	label define early_exit_problem 1 "Exit<last6.2" 2 "Exit<last9.1" 3 "Exit<last9.2" 4 "Exit<last6.2&9.1" 5 "Exit<last6.2&9.2" 6 "Exit<last 9.1&9.2" 7 "Exit<last6.2&9.1&9.2", modify
	replace early_exit_problem=1 if exitgap_test~=.
	label values early_exit_problem early_exit_problem

	*change exit to one day after last test, SR or clinic report [all exit types for first 2, only if not dead or out-migrated for clinic data as they could move out but still go to same clinic]
	gen exit_new=.
	label define early_exit_fixed 0 "No change to exit" 1 "Exit changed to last 6.2 plus 1 day" 2 "Exit changed to last 9.1 plus 1 day" 3 "Exit changed to last 9.2 plus 1 day"
	replace early_exit_fixed_t=1 if exitgap_test<=earlyexit_max
	replace exit_new=lasttest_date+1 if early_exit_fixed_t==1

	replace early_exit_fixed=0 if early_exit_problem~=. & early_exit_fixed_t==.
	bys study_name idno: egen early_exit_fixed=max(early_exit_fixed_t)
	label values early_exit_fixed early_exit_fixed

	replace exit=exit_new if exit_new~=.


	*redo stset to account for changes in exit dates & failure updates
	stset exit , time0(entry) failure(failure) origin(dob) id(idno) scale(365.25) 

	************************************************************************************************************
	**  				3. SPLIT USING 6.2b DATA (HIV TESTS) & CREATE HIV STATUS VARIABLE					  **
	************************************************************************************************************

	format %td first_neg_date last_neg_date first_pos_date last_pos_date 

	gen double sero_conv_date=last_neg_date+((first_pos_date-last_neg_date)/2) if last_neg_date~=. & first_pos_date~=. 
	label var sero_conv_date "Seroconversion date: midpoint"
	gen timeprepos=0

	do "${alphapath}/ALPHA\DoFiles\Common/create_hivstatus_detail.do"


	********* REORGANISE FOR INCIDENCE ANALYSIS  *********

	** define date of 15th birthday
	gen double fifteen=dob+(15*365.25)
	format %td fifteen
	label var fifteen "Date of 15th birthday"

	* OPTION TO INCLUDE YOUNGEST RESIDENTS COMING TO FIRST SERO
	* WHO WERE RESIDENT AT EARLIER SERO BUT NOT AGE ELIGIBLE
	* ASSUMING THEY WERE NEGATIVE AT AGE 15
	* COMMENT OUT THIS BIT IF THIS OPTION NOT NEEDED
	summ nrounds_sero
	local maxrounds=r(mean)

	gen tested_first_opportunity=0
	label var tested_first_opp "Tested for the first time at the first survey after 15th birthday"
	replace tested_first_opp =1 if firsttest_date<(fifteen+${maxinter}*365.25) & firsttest_date>fifteen & firsttest_date<.

	*check if resident at 15
	stgen resat15=ever(fifteen>(_t0*365.25+dob) & fifteen<(_t*365.25+dob))
	label var resat15 "Resident on 15th birthday"

	*RETAIN RECORDS RELEVANT FOR INCIDENCE ANALYSIS
	*BETWEEN TWO NEGATIVE TESTS, AFTER A NEGATIVE TEST BUT WITHIN CUTOFF,IN THE SEROCONVERSION INTERVAL
	gen tokeep=1 if hivstatus_detail==1 | hivstatus_detail==4 | hivstatus_detail==9 | hivstatus_detail==10 | hivstatus_detail==11 | hivstatus_detail==12  
	*also keep the time of young people prior to their first test if they 1) were too young to have been tested in the previous round and 2) had their first test
	* at the first opportunity
	replace tokeep=1 if tested_first_opp==1 & resat15==1 & (_t*365.25+dob)<=firsttest_date



	keep if tokeep==1
	drop tokeep

	*for young prevalent positives, impute a seroconversion date midway between their first test date and fifteenth birthday 
	replace sero_conv_date = ((first_pos_date - fifteen)*0.5)+fifteen if  tested_first_opp==1 & resat15==1 & (_t*365.25+dob)<=firsttest_date & firsttest_date==first_pos_date


	keep idno sex dob residence entry entry_type exit exit_type study_name first_neg_date ///
	last_neg_date first_pos_date last_pos_date firsttest_date lasttest_date  ///
		_st _d _origin _t _t0 hivstatus_detail   ///
	 nrounds_sero fifteen tested_first_opp  failure sero_conv_date

	*********************************************************************************
	*  SPLIT THE DATA BY AGE AND CALENDAR YEAR FOR AGE AND YEAR SPECIFIC ESTIMATES
	*********************************************************************************


	*split the data by age group and calendar year
	do "${alphapath}/ALPHA/DoFiles/common/single_year_agegrp_split_including_kids.do"

	do "${alphapath}/ALPHA/DoFiles/common/calendar_year_split.do"

	*create new categorical variables
	drop if age<15
	do "${alphapath}/ALPHA/DoFiles/common/Create_agegrp_from_age.do"
	do "${alphapath}/ALPHA/DoFiles/common/Create_birth_cohort_from_dob.do"

	do "${alphapath}/ALPHA/DoFiles/common/create_fiveyear.do"
	do "${alphapath}/ALPHA/DoFiles/common/create_fouryear.do"


	qui compress



	*********************************************************************************
	*   SET UP FOR ANALYSIS WITH MIDPOINT AS SEROCONVERSION
	*********************************************************************************

	*censor everyone at the most recent test date
	stsplit afterlasttest,after(lasttest_date) at(0)
	drop if afterlasttest==0
	drop afterlasttest


	** recreate entry and exit variables- old dates no longer valid after splits- Stata isn't reliable about updating them in all versions.
	gen double start_ep_date=_t0*365.25+dob
	gen double end_ep_date=_t*365.25+dob
	gen died=_d
	format %td start_ep_date end_ep_date
	label var start_ep_date "Date this record starts on, for everyone included in midpoint file"
	label var end_ep_date "Date this record ends on, for everyone included in midpoint file"
	*CAN'T USE A FILE STSET ON INCIDENCE AS THE BASIS FOR MI ESTIMATES OF INCIDENCE RISK FACTORS. THIS IS BECAUSE 
	*THE DATASET REQUIRES ADDITIONAL SPLITTING TO PREPARE THE DATA FOR RISK FACTOR ANALYSIS. WE NEED ALL RECORDS TO BE SPLIT AS APPROPRIATE BUT
	*IF THE DATASET IS SET ON SERCONVERSION, WITH FAILURE AT THE MIDPOINT, THE STSET WILL EXCLUDE ANY SEROCONVERTORS WHO ARE NOT RESIDENT AT THE MIDPOINT
	*THIS MEANS THEY WOULD NOT BE PROPERLY INCLUDED IN THE RISK FACTOR ANALYSIS.  TO GET AROUND THIS PROBLEM, WE CREATE THE RISK FACTOR FILE FROM ONE
	*THAT IS SET ON MORTALITY SO THAT EVERYONE IS INCLUDED.
	label data "ALPHA input data for ${sitename} to be used to create the dataset for incidence risk factor analysis. Currently set on mortality."
	save "${alphapath}/ALPHA/incidence_ready_data/${sitename}/incidence_temp_for_risk_factors_${sitename}",replace

	*NOW STSET THE DATA FOR INCIDENCE ANALYSIS USING THE MIDPOINT AS THE SEROCONVERSION DATE
	*count the number of people observed to seroconvert- no necessarily resident on this date
	stdes if first_pos_date<. & last_neg_date<. & first_pos_date>last_neg_date
	stset,clear


	** make a variable to indicate records that contain a seroconversion
	gen serocon_fail=0
	replace serocon_fail=1 if sero_conv_date>start_ep_date & sero_conv_date<=end_ep_date

	*Move the end date of episodes that contain a seroconversion- the episode will now end at the time of seroconversion
	replace end_ep_date=sero_conv_date if serocon_fail==1

	stset end_ep_date,fail(serocon_fail) id(idno) entry(fifteen) origin(dob) time0(start_ep_date) scale(365.25)


	*********************************************************************************
	*   SAVE THE DATA
	*********************************************************************************
	cap mkdir "${alphapath}/ALPHA/incidence_ready_data/${sitename}"
	qui compress
	label data "ALPHA incidence data set with the midpoint of the interval as the seroconversion date, ${sitename}"
	save "${alphapath}/ALPHA/incidence_ready_data/${sitename}/incidence_ready_midpoint_${sitename}",replace



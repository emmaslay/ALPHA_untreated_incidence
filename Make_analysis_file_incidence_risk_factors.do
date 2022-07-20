

********** PREPARE THE IMPUTATIONS
*global sitelist="Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude"
global sitelist="Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude"

*global sitelist="manicaland"


global nimp=70

foreach s in $sitelist {
global sitename="`s'"


	**** PICK UP THE M0 FILE WITH THE SEROCONVERSION DATE SET TO MISSING (SO IT CAN BE IMPUTED)
	*ADD IN THE RISK FACTOR INFORMATION
	use  "${alphapath}/ALPHA/incidence_ready_data/${sitename}/incidence_temp_for_risk_factors_${sitename}", clear



	** MERGE IN MARRIAGE DATA derived from spec 7.4
	cap drop _merge
	merge  m:1 study_name idno using  "${alphapath}/ALPHA/prepared_data/${sitename}/mstat_transition_dates_wide_${sitename}",gen(mstat_merge)


	** ASSIGN MARITAL STATUS TO EACH EPISODE

	drop if mstat_merge==2
	gen tv_mstat=.
	label var tv_mstat "Time varying marital status"
	*these are only relevant where we have spouse links
	gen sp_id=.
	gen sp_sex=.
	gen sp_agegrp=.
	gen sp_allinfo=.
	gen sp_claim_date=.

	*work out how many different marital status episodes we have in the wide marriage file and then loop through them all
	quietly {
		desc mstat_broad*,varlist
		local nmar:word count `r(varlist)'
		forvalues x=1/`nmar' {
			noi di `x'
			*split each time marital status changes
			stsplit mar`x',after(start_marset_date`x') at(0)

			*want to transfer mstat info onto correct portion of person time
			replace tv_mstat=mstat_detail`x' if mar`x'==0 & mstat_detail`x'<.
			*and if we have them, add spouse details onto portion of person time
			replace sp_id=sp_id`x' if mar`x'==0 & sp_id`x'<.
			cap replace sp_sex=sp_sex`x' if mar`x'==0 & sp_sex`x'<.
			*if we have spouse details, NEED TO CALCULATE AGE DIFFERENCE HERE AND SAVE THAT
			cap replace sp_agegrp=sp_agegrp`x' if mar`x'==0 & sp_agegrp`x'<.
			cap replace sp_allinfo=sp_allinfo_treat_pyramid`x' if mar`x'==0 & sp_allinfo_treat_pyramid`x'<.
			cap replace sp_claim_date=spouse_claim_date`x' if mar`x'==0 & spouse_claim_date`x'<.
			*the dataset is getting large and messy so get rid of variables we have finished with
			*drop mstat_detail`x' sp_id`x' 
			cap drop sp_sex`x' sp_agegrp`x' ///
			sp_dob`x' sp_residence`x' sp_dss_last_seen`x' ///
			sp_allinfo_treat_pyramid`x' spouse_claim_date`x'

			} /*close for values loop for marital status episodes */
		} /*close quietly */

	*drop unnecessary variables
	drop mar* marset_count* end_marset_date* start_marset_date* mstat_broad*

	bys study_name idno (_t0):gen issep=1 if tv_mstat==2
	bys study_name idno (_t0):gen sumsep=sum(issep)

	replace tv_mstat=2 if tv_mstat==1 & sumsep>0
	label define tv_mstat 0 "Never married" 1 "Married" 2 "Formerly married" 10 "Never married to married" 12 "Married to Separated" 21 "Separated to married" 22 "Separated to separated",modify

	label values tv_mstat tv_mstat
	*now we have a single, time varying marital status variable for everyone, interpolated from the cross-sectional surveys and where available DSS reports.



	******  BRING IN THE MOVE DATES 
	*(drop _merge beforehand, if it already exists)
	cap drop _merge
	merge m:1 study_name idno using "${alphapath}/ALPHA/prepared_data/${sitename}/move_dates_${sitename}"
	drop if _m==2
	drop _merge
	*as above for marriage, work out maximum number of move episodes in dataset and loop through
	desc move_date*,varlist
	local nmoves:word count `r(varlist)'
	di `nmoves'

	forvalues x=1/`nmoves' {
		*split after the move: split on that date and 1 year later
		stsplit move`x',after(move_date`x') at(0 1)
		*recode the new variable to show whether or not this spell of person time was within the year after a move
		recode move`x' -1=0 0=1 1=0
		} /*close moves loop */
	drop move_date* 

	*make a variable indicating whether this bit of person time within a year of a move-
	*maximum of all the split variables concerning all the moves.
	egen mobile=rowmax(move*)
	label var mobile "Changed residence within last 12m"
	
	*drop surplus variables
	drop move* 
	*Work out the total time elapsed on each record that was within a year of a move
	gen movefup=_t-_t0 if mobile==1
	label var movefup "Person time spent within 1 year of a move, on this record"
	*sum for each person total time spent mobile- running total so only time spent so far, will accumulate with increasing follow up time
	bys study_name idno (_t0):gen movetotal=sum(movefup)
	label var movetotal "Person time spent within 1 year of a move, running total to date"

	
	** now we have marriage and mobility from 7.4 and 6.1 respectively

	*** MERGE IN DATE OF FIRST SEX FOR SEX EVER SPLIT
	merge m:1 study_name idno using "${alphapath}/ALPHA/prepared_data/${sitename}/date_first_sex_${sitename}"
	drop if _m==2
	drop _merge
	stsplit tv_sexever if datefirstsex<.,after(datefirstsex) at(0)
	recode tv_sexever -1=0 0=1
	label values tv_sexever yesno
	label var tv_sexever "Time varying: ever had sex"



	/*ADD IN LONGITUDINAL PARTNER STATUS USING INFORMATION DERIVED FROM PARTNER HISTORY DATA REPORTED IN THE MOST RECENT SURVEY
	** THIS HAS CHANGED SINCE THE WORKSHOP.  AT THE ZANZIBAR WORKSHOP WE USED ONLY THE MOST RECENT PARTNER HISTORY DATA
	* NOW WE ARE BRINGING IN ALL PARTNERSHIP DATA AND INCORPORATING EVERYTHING
	THIS MEANS WE NOW HAVE THREE FILES TO BRING IN HERE:

	${alphapath}/ALPHA/prepared_data/${sitename}/partner_status_dates_for_merge_${sitename}_ALLSURVEYS: THIS HAS THE PARTNERSHIP STATUS 
	AND DATES WHEN THIS CHANGES, JUST FOR THE PERIODS COVERED BY SURVEY REFERENCE PERIOD

	${alphapath}/ALPHA/prepared_data/${sitename}/grey_area_dates_for_merge_${sitename}: THIS HAS THE DATES FOR THE GREY AREAS BETWEEN
	SURVEYS AND THE SURVEY REFERENCE PERIOD

	${alphapath}/ALPHA/prepared_data/${sitename}/pship_dates_for_merge_${sitename}: THIS HAS THE DATES FOR THE EARLY AND LATE 
	PARTNERSHIPS (I.E. FIRST 6 MONTHS OF A NEW PSHIP AND LAST 6 MONTHS OF ONE THAT FINISHES). HAVE QUALMS ABOUT
	USING THE LATE ONE- UNLESS WE HAVE CONTINUOUS DATA, I.E. NO GREY AREA, WE MIGHT MISS THE END OF PARTNERSHIPS AND
	THEREFORE MISCLASSIFY PEOPLE ON THIS ONE. BIASED.

	*/


	*(drop _merge beforehand, if it already exists)
	cap drop _merge
	merge m:1 study_name idno using "${alphapath}/ALPHA/ready_data_partnership_dynamics/${sitename}/partner_status_dates_for_merge_${sitename}"
	drop if _m==2
	drop _merge

	cap drop _merge
	merge m:1 study_name idno  using "${alphapath}/ALPHA/prepared_data/${sitename}/grey_area_dates_for_behaviour_from_survey_data_${sitename}"
	drop if _m==2
	drop _merge


	cap drop _merge
	merge m:1 study_name idno using "${alphapath}/ALPHA/prepared_data/${sitename}/sexual_partnership_dates_${sitename}"
	drop if _m==2
	drop _merge

	**DEFINE SURVEY REFERENCE PERIODS AND GREY AREAS
	gen str20 which_surveystr=""
	desc interview_date*,varlist
	local numrounds:word count `r(varlist)'
	di "`numrounds'"
		forvalues r=1/`numrounds' {
			stsplit befores`r' if refstart`r'<.,after(refstart`r') at(0)
			stsplit afters`r' if interview_date`r'<.,after(interview_date`r') at(0)
			*only do this for rounds that aren't the first round
			if `r'>1 {
				stsplit startgrey`r' if greystart`r'<.,after(greystart`r') at(0)
				stsplit endgrey`r' if greyend`r'<.,after(greyend`r') at(0)
				replace which_survey="In grey area" if startgrey`r'==0 & endgrey`r'==-1

				} /*close not first round if */

			replace which_surveystr=survey_round_name`r' if befores`r'==0 & afters`r'==-1
			*For first round
			if `r'==1 {
				replace which_surveystr="Before first survey"' if befores`r'==-1 
				}

			replace which_surveystr="After last survey" if afters`r'==0 & befores`r'==0 & which_surveystr==""  
			} /*close round loop */
				
	replace which_surveystr="Never interviewed" if interview_date1==. & which_surveystr==""

	label define which_survey 1 "Never interviewed" 2 "Before first survey" 3 "After last survey" 4 "In grey area",modify
	encode which_surveystr,gen(which_survey) label(which_survey)



	** DEFINE TIME VARYING VARIABLES FOR TO HOLD THIS INFORMATION
	gen tv_partner_status=.
	label var tv_partner_status "Time varying from partner history: types of partnerships ongoing at this time"
	label values tv_partner_status spell_pstat
	gen tv_number_spouses=.
	label var tv_number_spouses "Time varying from partner history: number of spousal partnerships ongoing at this time"
	gen tv_number_noncohab=.
	label var tv_number_noncohab "Time varying from partner history: number of non-cohabiting/non-spousal partnerships ongoing"
	gen tv_new6months=.
	label var tv_new6months "Time varying from partner history: within first 6 months after getting a new partner"
	*JUNE 2017: DECIDED TO MAKE THIS JUST 1 MONTH EITHER SIDE TO GET AROUND BIAS DUE TO MISSED ENDINGS THAT OCCUR AFTER LAST SURVEY DATE, OR 
	*IN A GREY AREA
	gen tv_lastmonths=.
	label var tv_lastmonths "Time varying from partner history: within 6 months after the end of a partnership"



	**** SPLIT THE FIRST 6 MONTHS OF A NEW PARTNERSHIP IF THE START WAS OBSERVED
	* MATCH IT UP TO REFERENCE PERIOD FOR EACH SURVEY

	*start with working out number of times people completed partnership histories
	desc pship_dates_survey*,varlist
	global nphists:word count `r(varlist)'
	di "Maximum number of partner spells: " ${nphists}

	*Each P history could contain info on ${phistnum} partners- need to loop through each
	* get these numbers from the survey_metadata
	forvalues h=1/$nphists {
		*work out how many partners these questions were asked for in this partnership history
		desc early_pship_start_?_`h',varlist
		global maxphistnum:word count `r(varlist)'
		forvalues p=1/$maxphistnum {
			stsplit early if early_pship_start_`p'_`h'<. ,after(early_pship_start_`p'_`h') at(0 0.5)
			replace tv_new6months=1 if early==0 & which_surveystr==pship_dates_survey`h'
			replace tv_new6months=0 if early==0.5 & which_surveystr==pship_dates_survey`h'
			drop early
			} /*close partners loop */
		} /*close partner histories loop */


	** split 6 months after the end of a partnership

	forvalues h=1/$nphists {
		desc late_pship_end_?_`h',varlist
		local maxphistnum:word count `r(varlist)'

		forvalues p=1/$maxphistnum {

			stsplit ending if late_pship_end_`p'_`h'<. ,after(late_pship_end_`p'_`h') at(0 0.5)
			replace tv_lastmonths=1 if ending==0 & which_surveystr==pship_dates_survey`h'
			replace tv_lastmonths=0 if ending==0.5 | ending==-1 & which_surveystr==pship_dates_survey`h'
			drop ending
			replace tv_lastmonths=0 if late_pship_end_`p'_`h'==. & which_surveystr==pship_dates_survey`h' & tv_lastmonths==.
			} /*close partners loop */
		} /*close partner histories loop */



	****** TRANSFER INFORMATION ON PARTNER STATUS DURING THE RELEVANT SURVEY REF PERIOD
	desc start_date_spell_*,varlist
	local nspells:word count `r(varlist)'
	di "Maximum number of partner spells: " `nspells'

	forvalues x=1/`nspells' {
		stsplit startspell`x' if start_date_spell_`x'<.,after(start_date_spell_`x') at(0)
		stsplit endspell`x' if end_date_spell_`x'<. ,after(end_date_spell_`x') at(0)

		replace tv_partner_status=spell_pstat`x' if startspell`x'==0 & endspell`x'==-1
		replace tv_number_spouses=spell_sp`x' if startspell`x'==0 & endspell`x'==-1
		replace tv_number_noncohab=spell_nsp`x' if startspell`x'==0 & endspell`x'==-1

		} /*close spells loop */


	drop end_date_spell_* start_date_spell_* infostatus* spell_sp* spell_nsp* spell_pstat* survey_round_name* interview_date* refstart* greystart* greyend* pship_dates_survey* early_pship_start_*_* late_pship_end_*_* early_pship_end_*_* late_pship_start_*_*
	drop startspell* endspell* startgrey* endgrey* befores* afters* mstat_detail* sp_id*

	qui compress


	drop mstat_merge 







	*=========================================================================
	* 	BRING IN PREVALANCE IN OPPOSITE SEX
	cap drop _merge
	merge m:1 study_name sex age years_one using ${alphapath}/ALPHA/Ready_data_untreated_prevalence/${sitename}/prevalence_treatment_in_opposite_sex_${sitename}
	drop if _m==2
	drop _merge
	replace untreated_opp_sex_prev=int(untreated*100)


	*=========================================================================
	* 	BRING IN ASPAR IN SAME AND OPPOSITE SEX
	merge m:1 study_name sex age fouryear using K:\ALPHA\Projects\Gates_incidence_risks_2019/aspar_for_merge
	drop if _m==2
	drop _merge


	*=========================================================================
	* 	BRING IN ASPLR IN SAME AND OPPOSITE SEX
	merge m:1 study_name sex age fouryear using K:\ALPHA\Projects\Gates_incidence_risks_2019/asplr_for_merge
	drop if _m==2
	drop _merge


	*======================================================================================
	*======================================================================================

	*ALL THAT REMAINS IS TO BRING IN THE SEXUAL BEHAVIOUR

	*will make the BIG assumption that behaviour in the year (or other reference period) prior 
	*to one survey carries on until the start of the reference period for the following survey

	*Therefore, using sexual behaviour spec, will summarise behaviour at each round and get the relevant dates for each set

	merge m:1 study_name idno using ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_wide_${sitename},gen(behav_merge)
	drop if behav_merge==2

	** pick up relevant behaviour for this period- ie. if person-time on the observation (line of data)
	*is in the reference period of the survey then those behavioural variables apply to that record
	*if the person time record is for after the survey, and there hasn't been an update, then assume those behaviours still apply.

	*work out the number of rounds for which there are data available
	desc survey_round_name*,varlist
	global behavrounds: word count `r(varlist)'
	di $behavrounds

	*** GENERATE VARIABLES TO HOLD THE TIME-VARYING SEXUAL BEHAVIOUR DATA
	gen tv_sexlastyear=.
	label var tv_sexlastyear "Time varying: had sex in last year"
	gen tv_new_partner=.
	label var tv_new_partner "Time varying: got a new partners in last year"
	gen tv_new_spouse=.
	label var tv_new_spouse "Time varying: got a new spouse in last year"
	gen tv_new_noncohab=.
	label var tv_new_noncohab "Time varying: got a new non-cohab partner in last year"
	gen tv_partners_lastyear=.
	label var tv_partners_lastyear "Time varying: number of partners last year"
	gen tv_partners_life=.
	label var tv_partners_life "Time varying: number of partners in lifetime"
	gen tv_partners_life_grp=.
	label var tv_partners_life_grp "Time varying: number of partners in lifetime, grouped"

	gen tv_num_new_partners=.
	label var tv_num_new_partners "Time varying: number of new partners last year"
	gen tv_morethan1=.
	label var tv_morethan1 "Time varying: had more than one partner in last year"
	gen tv_spouse=.
	label var tv_spouse "Time varying: had sex with a spouse in last year"
	gen tv_regular=.
	label var tv_regular "Time varying: had sex  with a regular partner in last year"
	gen tv_casual=.
	label var tv_casual "Time varying: had sex with a casual partner in last year"
	gen tv_high_risk=.
	label var tv_high_risk "Time varying: had sex with a high-risk partner in last year"
	gen tv_condom_freq_spouses=.
	label var tv_condom_freq_spouses "Time varying: Freq condom use with spouse(s) in last year"
	gen tv_condom_freq_noncohabs=.
	label var tv_condom_freq_noncohabs "Time varying: Freq condom use with non-spousal partner in last year"
	gen tv_condom_freq_all=.
	label var tv_condom_freq_all "Time varying:Freq condom use with all partners in last year"
	gen tv_coital_freq_spouses=.
	label var tv_coital_freq_spouses "Time varying: weekly coital frequency with spouse(s) in last year"
	gen tv_coital_freq_noncohabs=.
	label var tv_coital_freq_noncohabs "Time varying: weekly coital frequency with non-spouse(s) in last year"
	gen tv_coital_freq_all=.
	label var tv_coital_freq_all "Time varying: total weekly coital frequency in last year"
	gen tv_clastyr=.
	label var tv_clastyr "Time varying: condom use summary for last year"
	label define clastyr_summary 0 "No partners" 1 "No condom use" 2 "Some condom use (sometimes or some partners" 3 "Complete condom use (all partners=always)" 4 "Not sure- 6+ptnrs or missing data",modify
	label values tv_clastyr clastyr_summary
	gen tv_sumlastyear=.
	label var tv_sumlastyear "Time varying: number and newness of partners"
	label define sumlastyear 0 "No partners" 1 "One old partner" 2 "One new partner" 3 "one partner dk duration" 4 ">1 partner, none new" 5 ">1 partner, 1+ new" 6 ">1 partner, dk new" 9 "No data",modify
	label values tv_sumlastyear sumlastyear
	gen tv_anylost=.
	label var tv_anylost "Time varying: Ended any partnerships in the last year"

	gen tv_pagegrp=.
	label var tv_pagegrp "Time varying: age gap with any partner >5 years"
	** FIRST SPLIT THE DATA AT THE START OF THE REFERENCE PERIOD FOR EACH SURVEY
	label define splitlbl 0 "Before" 1 "After"
	forvalues br =1/$behavrounds {
		stsplit survey_ref_period`br' if merge_date`br'<.,after(merge_date`br') at(0)
		recode survey_ref_period`br' -1=0 0=1
		label values survey_ref_period`br' splitlbl
		label var survey_ref_period`br' "Before or after start of ref period for survey `br'"
		}

	*make a variable to describe which periods of time are described by each survey.
	* There may be some overlap, in which case the later survey trumps earlier ones.
	gen relevant_round=0
	forvalues br =1/$behavrounds {
		replace relevant_round=`br' if survey_ref_period`br'==1
		}
	label values tv_pagegrp pagegrp
	gen tv_pagegrp_nsp=.
	label var tv_pagegrp_nsp "Time varying: age gap with any non-spousal partner >5 years"
	label values tv_pagegrp_nsp pagegrp

	*** to add: coital freq, partner age, mstat, other partners, alcohol, etc

	gen tv_marever=.
	label var tv_marever "Ever married, from sexual behaviour spec"


	*use relevant round to assign survey data to longitudinal observations 
	forvalues br =1/$behavrounds {
		replace tv_sexlastyear=sexlastyear`br' if relevant_round==`br'

		replace tv_new_partner=new_partner`br' if relevant_round==`br'
		replace tv_new_spouse=new_spouse`br' if relevant_round==`br'
		replace tv_new_noncohab=new_noncohab`br' if relevant_round==`br'
		replace tv_partners_lastyear=partners_lastyear`br' if relevant_round==`br'
		replace tv_partners_life=partners_life`br' if relevant_round==`br'
		replace tv_partners_life_grp=partners_life_grp`br' if relevant_round==`br'
		replace tv_num_new_partners=num_new_partners`br' if relevant_round==`br'
		replace tv_morethan1=morethan1`br' if relevant_round==`br'
		replace tv_spouse=spouse`br' if relevant_round==`br'
		replace tv_regular=regular`br' if relevant_round==`br'
		replace tv_casual=casual`br' if relevant_round==`br'
		replace tv_high_risk=high_risk`br' if relevant_round==`br'
		replace tv_condom_freq_spouses=condom_freq_all_spouse`br' if relevant_round==`br'
		replace tv_condom_freq_noncohabs=condom_freq_all_noncohab`br' if relevant_round==`br'
		replace tv_condom_freq_all=condom_freq_all_`br' if relevant_round==`br'
		label values tv_condom_freq_spouses tv_condom_freq_noncohabs  tv_condom_freq_all condomfreq
		replace tv_coital_freq_spouses=coital_freq_current_sp`br' if relevant_round==`br'
		replace tv_coital_freq_noncohabs=coital_freq_current_nsp`br' if relevant_round==`br'
		replace tv_coital_freq_all=coital_freq_current`br' if relevant_round==`br'
		replace tv_clastyr=clastyr_summary`br' if relevant_round==`br'
		replace tv_sumlastyear=sumlastyear`br' if relevant_round==`br'
		replace tv_pagegrp=pagegrp`br' if relevant_round==`br'
		replace tv_pagegrp_nsp=pagegrp_nsp`br' if relevant_round==`br'
		replace tv_marever=marever`br' if relevant_round==`br'
		replace tv_anylost=anylost`br' if relevant_round==`br'

		}

	**** CIRCUMCISION- TAKE ROWMIN OF ALL AGES AT CIRCUMCISION, ELSE CHANGE WHEN FIRST SAYS YES
	egen age_at_circ_lowest=rowmin(age_at_circ*) if sex==1
	**need a date to split the data on
	*assume midyear if age reported is lower than current age
	gen date_at_circ=dob+(age_at_circ_lowest*365.25)+182 if age_at_circ_lowest<age & sex==1
	*if same as current age take birthday (just easier)
	replace date_at_circ=dob+(age_at_circ_lowest*365.25) if age_at_circ_lowest==age & sex==1
	label var date_at_circ "Date of circumcision, estimated from reported age"
	** IF AGE AT CIRCUMCISION NOT REPORTED, CHANGE AT INTERVIEW when first reported to be circumcised
	forvalues br =1/$behavrounds {
		replace date_at_circ=interview_date`br' if date_at_circ==. & circumcised`br'==1  & sex==1
		}

	stsplit tv_circumcised if date_at_circ<.,after(date_at_circ) at(0)
	label var tv_circumcised "Time varying: has been circumcised"
	recode tv_circumcised -1=0 0=1

	egen anydata_circumcised=  anymatch(circumcised*), values(0 1)
	replace tv_circumcised=. if anydata_circumcised==0

	*** TIME SINCE FIRST SEX
	*make date of first sex
	stgen tv_timefirstsex=when0(tv_sexever==1)
	stsplit tv_timesincefirstsex,after(tv_timefirstsex) at(0 1 2 3 4)
	replace tv_timesince=tv_timesince+1
	label define tv_timesince 0 "Not had sex" 1 "1st year" 2 "2nd year" 3 "3rd year" 4 "4th year" 5 "5+ years",modify
	label values tv_timesince tv_timesince
	label var tv_timefirstsex "Date of first sex- estimated from age"
	*** SOME RECODINGS

	recode agegrp (3/4=1 "15-24") (5/9=0 "25-49") (10/max=.),gen(youth) label(youth)
	label var youth "Aged 15-24"

	*recode tv_coital_freq_spouses (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/2.9=2 "1-2 times/week") (3/4.99=3 "3-4 times/week") (5/50=4 "5+ times/week") (90/max=5 "No answer"),gen(tv_cf_spouse) label(tv_cf_spouse)
	recode tv_coital_freq_spouses (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/50=2 "1+ times/week") (90/max=5 "No answer"),gen(tv_cf_spouse) label(tv_cf_spouse)
	label var tv_cf_spouse "Grouped weekly coital freq with spouse during last year"

	*recode tv_coital_freq_noncohab (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/2.9=2 "1-2 times/week") (3/4.99=3 "3-4 times/week") (5/50=4 "5+ times/week") (90/max=5 "No answer"),gen(tv_cf_nsp) label(tv_cf_nsp)
	recode tv_coital_freq_noncohab (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/50=2 "1+ times/week") (90/max=5 "No answer"),gen(tv_cf_nsp) label(tv_cf_nsp)
	label var tv_cf_nsp "Grouped weekly coital freq with non-spouse during last year"

	*recode tv_coital_freq_all (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/2.9=2 "1-2 times/week") (3/4.99=3 "3-4 times/week") (5/50=4 "5+ times/week") (90/max=5 "No answer"),gen(tv_cf_all) label(tv_cf_all)
	recode tv_coital_freq_all (0=0 "Zero") (0.000001/0.999999=1 "<1/week") (1/89.9=2 "1+ times/week") (90/max=5 "No answer"),gen(tv_cf_all) label(tv_cf_all)
	label var tv_cf_all "Grouped weekly coital freq with all partners during last year"

	*put not applicable/missing into 0. must control for num_ptnrs
	recode tv_condom_freq_all 8/99=0
	recode tv_condom_freq_spouses 8/99=0
	recode tv_condom_freq_noncohabs 8/99=0


	recode tv_partners_lastyear (min/-1=.) (0=0) (1=1) (2=2) (3=3) (4/90=4 "4+") (100/200=4) (97=5 "Don't know"),gen(tv_ptnrs) label(tv_ptnrs)
	label var tv_ptnrs "Number of partners in last year, grouped"
*** MARITAL STATUS

	recode tv_mstat (10=0 "Never married") (12=1 "Currently married") (21=2 "Formerly married") (22=2) (9=9 "Not known"),gen(tv_mstat_br) 
	*label values tv_mstat_br tv_mstat
	label var tv_mstat_br "Marital status in 3 groups"
	*pull in the ever married status from sexual behaviour spec if it is missing
	replace tv_mstat_br=0 if tv_marever==0 & tv_mstat_br==.
	replace tv_mstat_br=1 if tv_marever==1 & tv_mstat_br==.
	replace tv_mstat_br=9 if tv_mstat_br==.

label define new_partner 0 "No new partners in last year" 1 "New partner in last year" 3 "Information missing" 4 "Not collected" 9 "Grey area",modify
label values tv_new_partner new_partner

	recode tv_circumcised .=2
	label define tv_circumcised 0 "Not" 1 "Circumcised" 2 "no information",modify
	label values tv_circumcised tv_circumcised

	gen have_behav=relevant_round
	recode have 1/max=1



	gen sa_v_rest=1 if study==6 | study==7
	replace sa_v_rest=0 if study>=8 | study<6
	label var sa_v_rest "South African study"
	
	gen tv_mstat_semi_br=tv_mstat
	recode tv_mstat_semi_br 12=2
	label var tv_mstat_semi_br "Marital status, fewer groups"

	drop survey_round_name* interview_date* sexever* sexlastyear* partners_lastyear* circumcised* age_at_circ* ///
	spouse_total* regular_total* casual_total* high_risk_total* condom_last_sex_spouse* condom_last_sex_noncohab* ///
	contra_last_sex_spouse* new_partner* new_spouse* new_noncohab* num_new_partners* pagegrp* coital_freq_current* ///
	coital_freq_current_sp* coital_freq_current_nsp* total_partners_in_history* morethan** spouse* regular* casual* ///
	high_risk* condom_freq_all_spouse* condom_freq_all_noncohab* condom_freq_all_* merge_date* survey_ref_period*
	cap xtset,clear
	
	
	**ADD IN THE PROPORTION OF PEOPLE WHO HAD AN HIV TEST IN THE LAST ROUND WHO RETEST IN THE NEXT ROUND

	merge m:1 sex study_name using "${alphapath}/ALPHA/Ready_data_hiv_retesting/pooled/testing_probability_by_round_wide_pooled"
	drop if _m==2
	drop _m



	** split on round dates for HIV testing proportion
	gen neg_retest_percent=.
	label var neg_retest_percent "Percentage of known negatives retested in each round"

	desc sero_end_date*,varlist
	foreach v in `r(varlist)' {
		local suffix=substr("`v'",14,2)
		stsplit tempsplit if `v'<.,after(`v') at(0)
		replace neg_retest_percent=percent_elig_neg_tested`suffix' if tempsplit==-1 & neg_retest_percent==.
		drop tempsplit percent_elig_neg_tested`suffix'
		}

	drop sero_start_date* sero_end_date*  percent_tested*
	qui compress
	
	*** IFAKARA DOESN'T HAVE RETESTING PROBABILITIES BECAUSE THEY HAVE HAD ONLY TWO ROUNDS SO SET ALL TO 1
	replace neg_retest_percent=100 if study_name==9
	replace neg_retest_percent=100 if neg_retest_percent>100 & neg_retest_percent<.

	****** UPDATE THE START AND END DATES FOR EPISODES
	replace start_ep_date=_t0*365.25+dob
	replace end_ep_date=_t*365.25+dob
	label var start_ep_date "Date this record starts on, for everyone included in incidence risk factors file"
	label var end_ep_date "Date this record ends on, for everyone included in incidence risk factors file"

	
	
	****  CODE THE GREY AREAS ON THE INDIVIDUAL BEHAVIOUR VARIABES
	foreach myvar of varlist tv_partner_status tv_number_spouses tv_number_noncohab tv_new6months tv_lastmonths tv_sexlastyear tv_new_partner tv_new_spouse tv_new_noncohab tv_partners_lastyear tv_num_new_partners tv_morethan1 tv_spouse tv_regular tv_casual tv_high_risk tv_condom_freq_spouses tv_condom_freq_noncohabs tv_condom_freq_all tv_cf_spouse tv_cf_nsp tv_cf_all tv_ptnrs tv_anylost {

	di "`myvar'"
	qui summ `myvar'
	*variables with max values less than 9 - set the grey area to 9
	if r(max)<9 {
		replace `myvar'=9 if `myvar'==. & which_survey>=1 & which_survey<=4
		local mylab:value label `myvar'
		
		if "`mylab'" ~="" {
			label define `mylab' 9 "No data",modify
		}
		else {
			label define `myvar' 9 "No data",modify
		}
	} /*close values under 9 if */
	
	*variables with max values between 9 and 98 - set the grey area to 99
	if r(max)>8 & r(max)<99 {
		replace `myvar'=99 if `myvar'==. & which_survey>=1 & which_survey<=4
		local mylab:value label `myvar'
		if "`mylab'" ~="" {
			label define `mylab' 99 "No data",modify
		}
		else {
			label define `myvar' 99 "No data",modify
		}
	} /*close values under 99 if */
	
	*for variables that have a max value over 99- mostly continuous ones
	else  {
		replace `myvar'=.a if `myvar'==. & which_survey>=1 & which_survey<=4
	}
	
	
	} /*close foreach loop for vars */ 
	
	
	*SAVE THE FILE THAT IS NOT STSET ON SEROCONVERSION- THIS WILL BE THE DATASET USED BY STATA'S MI COMMANDS
	label data "ALPHA incidence risk factors data, ${sitename} imputation 0- for Stata's MI commands only"
	*use this as the basis for the imputation files
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_MI_${sitename}_input",replace
	*save this one as the file with no seroconversion date that Stata's MI commands need
	bys study_name idno (start_ep_date):gen ep_num=_n

	keep idno  sex dob residence study_name ep_num sero_conv_date fifteen age years_one agegrp fiveyear fouryear start_ep_date end_ep_date tv_mstat mobile movetotal datefirstsex tv_* date_at_circ youth neg_retest_percent opp_sex_par same_sex_par opp_sex_plr same_sex_plr  _st _d _origin _t _t0 untreated_opp_sex  which_survey
	drop tv_timefirstsex tv_mstat_semi_br tv_coital_freq_all tv_coital_freq_noncohabs tv_coital_freq_spouses
	replace sero_conv_date=.
	gen serocon_fail=.
	
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_MI_${sitename}_0",replace
	
	** MAKE A MIDPOINT FILE FOR PLAYING WITH
	use "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_MI_${sitename}_input",clear
	** make a variable to indicate records that contain a seroconversion
	gen serocon_fail=0
	label var serocon_fail "Observed seroconversion (based on midpoint date)"
	replace serocon_fail=1 if sero_conv_date>start_ep_date & sero_conv_date<=end_ep_date

	*Move the end date of episodes that contain a seroconversion- the episode will now end at the time of seroconversion
	replace end_ep_date=sero_conv_date if serocon_fail==1

	stset end_ep_date,fail(serocon_fail) id(idno) entry(fifteen) origin(dob) time0(start_ep_date) scale(365.25)
	label data "ALPHA incidence risk factors data, ${sitename} seroconversion as midpoint"
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/incidence_ready_risk_factors_midpoint_${sitename}",replace

	

	
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	* MULTIPLE IMPUTATION
	
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	
	*** GENERATE LIST OF IDNO WITH WHICH TO GENERAGE A DATASET OF RANDOM NUMBERS FOR EACH PERSON
	*this is important because we need a number for each person not each record in the dataset
	keep study_name idno
	contract study_name idno
	drop _freq

	forvalues x=1/$nimp {
		set seed `x'
		gen double random`x'=uniform()
		}
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/risk_factors_random_numbers_${sitename}",replace






	**** generate the mi files with the seroconversion date randomly allocated within the interval
	*EACH DATASET CONTAINS ONE IMPUTATION OF THE SEROCONVERSION DATE, SO WE END UP WITH AS MANY DATASETS AS IMPUTATIONS
	*THE FILE NAMING IS IMPORTANT AND MUST FOLLOW A PATTERN WITH ONLY THE IMPUTATION NUMBER CHANGING FOR EACH FILE.
	quietly {
		forvalues x=1/$nimp {
			set seed `x'
			noi di "Imputation `x'"
			use "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_MI_${sitename}_input",clear
			cap drop ep_num
			merge m:1 study_name idno using "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/risk_factors_random_numbers_${sitename}"

			cap drop sero_conv_date
			gen double sero_conv_date=((first_pos_date-last_neg_date)*random`x')+last_neg_date if  first_pos_date<. & last_neg_date<. & first_pos_date>last_neg_date
			replace sero_conv_date = ((first_pos_date - fifteen)*random`x')+fifteen if tested_first_opportunity==1
			*Make a unique id for each record
			
			
			**count total number of people who were tested negative then later positive
			stdes if first_pos_date<. & last_neg_date<. & first_pos_date>last_neg_date
			stdes if sero_conv_date<.


			format %td last_neg_date first_pos_date sero_conv_date start_ep_date end_ep_date

			*identify failures.  take only those who were resident at the imputed date of seroconversion
			gen serocon_fail=0
			label var serocon_fail "Observed seroconversion (based on imputed date)"
			replace serocon_fail=1 if sero_conv_date>start_ep_date & sero_conv_date<=end_ep_date
			tab serocon_fail
			replace end_ep_date=sero_conv_date if serocon_fail==1


			**checking
			format %td last_neg_date first_pos_date sero_conv_date start_ep_date end_ep_date
			*stgen neversc=never(_d==1)
			*sort idno _t0
			*br idno start_ep_date end_ep_date last_neg_date first_pos_date sero_conv_date serocon_fail smooth_fraction length_serocon_interval if sero_conv_date<. & neversc==1



			format %td  start_ep_date end_ep_date
			stset,clear
			stset end_ep_date,fail(serocon_fail) id(idno) time0(start_ep_date)  scale(365.25) origin(dob)
			replace _st=0 if start_ep_date>sero_conv_date & start_ep_date<.



			bys study_name idno (start_ep_date):gen ep_num=_n

			*REDUCE THE NUMBER OF VARIABLES AS SIZE IS A PROBLEM WITH A LARGE NUMBER OF IMPUTATIONS
			*for now this is based on earlier analyses but could/should be reviewed and updated
			keep idno ep_num sex dob residence study_name  fifteen sero_conv_date age years_one agegrp fiveyear fouryear start_ep_date end_ep_date tv_mstat mobile movetotal datefirstsex tv_* date_at_circ youth neg_retest_percent opp_sex_par same_sex_par  opp_sex_plr same_sex_plr  serocon_fail _st _d _origin _t _t0 untreated_opp_sex which_survey tv_pagegrp tv_pagegrp_nsp tv_partners_life_grp 
			*** SAVE FILE 
			label data "ALPHA incidence risk factors data, ${sitename} imputation `x'"
			save ${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_mi_${sitename}_`x',replace

			} /* close imputations loop */

**** MAKE SMALL IMPUTED FILES FOR INCIDENCE TRENDS PAPER
			forvalues x=0/$nimp {
			use ${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_mi_${sitename}_`x',clear
			keep idno  sex dob residence study_name ep_num  sero_conv_date age years_one agegrp fouryear start_ep_date end_ep_date youth neg_retest_percent tv_circumcised  serocon_fail _st _d _origin _t _t0 untreated_opp_sex
			save ${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_risk_factors_mi_${sitename}_small_`x',replace
			} /*close imputations loop  */
			
			} /*close quietly*/


	} /*close study loop */

/*ESTIMATE HIV INCIDENCE USING THE MULTIPLE DATASETS WITH IMPUTED SEROCONVERSION DATES- THIS IS BETTER THAN USING THE MIDPOINT
BETWEEN LAST NEGATIVE AND FIRST POSITIVE TEST DATES.
THIS REQUIRES THE DATA TO HAVE BEEN SET UP ALREADY USING MAKE_ANALYSIS_FILE_INCIDENCE_MI.DO AND THE VALUE OF GLOBAL MACRO useimp
SHOULD BE <= THE NUMBER OF DATASETS GENERATED USING THAT DO FILE.  */
*foreach studysite in  Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude pooled {
foreach studysite in pooled {

	global sitename="`studysite'"

	global useimp=70

	**** ESTIMATE INCIDENCE RATES - CALL STRATE ONCE FOR EACH IMPUTATION AND SAVE OUTPUT IN ${alphapath}/ALPHA\Estimates_Incidence\MI_rates/runs/

forvalues x=1/$useimp {

		use "${alphapath}/ALPHA\Incidence_ready_data/${sitename}\mi_data\incidence_ready_mi_${sitename}_`x'",clear
		cap mkdir  "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}"
		cap mkdir  "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/"

		*AGES 15-49 by sex, site 2005-2016
		strate study_name sex  if age>14 & age<50 & years_one>2004 & years_one<2017,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_allages_`x'",replace)

		*AGES 15-49 by sex and youth, site 2005-2016
		strate study_name sex  if age>14 & age<25 & years_one>2004 & years_one<2017,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_youth_`x'",replace)
		strate study_name sex  if age>24 & age<50 & years_one>2004 & years_one<2017,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_older_`x'",replace)


		*AGES 15-49 by sex, site and calendar years
		strate study_name sex fouryear  if age>14 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_allages_`x'",replace)

		*Age-specific rates by sex, site and calendar years
		strate study_name sex fouryear agegrp if age>14 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_agegrp_`x'",replace)

		*Under 25 rates by sex, site and calendar years
		strate study_name sex fouryear  if age>14 & age<25,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_youth_`x'",replace)

		*Over 25 rates by sex, site and calendar years
		strate study_name sex fouryear  if age>24 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_older_`x'",replace)

		} /*end of forvalues  x=1/$useimp */


		**COMBINE 15-49 2005-2016 RATE ESTIMATES
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_allages_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_allages_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
		
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex 
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_2005_2016_allages",replace


	**COMBINE 15-49 2005-2016 youth RATE ESTIMATES
	*under 25s
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_youth_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_youth_`x'"
		replace imputation=`x'
		} /*end of x=2/$useimp*/
	
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex 
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_2005_2016_youth",replace

	*older group 52-49
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_older_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_older_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
	
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex 
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_2005_2016_older",replace

	**COMBINE 15-49 BY CALENDAR YEAR GROUP RATE ESTIMATES
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_allages_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_allages_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
	
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex fouryear
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_allages",replace




	**COMBINE AGE-SPECIFIC RATE ESTIMATES
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_agegrp_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_agegrp_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
	
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex fouryear agegrp
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_agegrp",replace


	**COMBINE UNDER-25 RATE ESTIMATES
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_youth_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	
	forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_youth_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
	
	*now combine using Rubin's rules
	do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex fouryear
	rename Qhat rate	
	save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_youth",replace


	**COMBINE OVER-25 RATE ESTIMATES
	clear
	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_older_1"
	gen imputation=1
	*get the date the imputations were run and store this in the dataset

	char _dta[imputationdate] `c(filedate)'
	
		forvalues x=2/$useimp {
		append using "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/runs/MI_rates_sex_fouryear_older_`x'"
		replace imputation=`x'
		} /*end of forvalues x=2/$useimp*/
		
	*now combine using Rubin's rules
	count
	if r(N)>0 {
		do "${alphapath}/ALPHA\dofiles/common/rubins_rules_for_strate_output_generic.do" study_name sex fouryear
		rename Qhat rate	
		save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_older",replace
		} /*end of if r(N)>0*/

	*==============================================================




	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	***PUT INTO A REPORT
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

	*** START AN A4 LANDSCAPE DOCUMENT
	cap putdocx clear
	putdocx begin, pagesize(A4) landscape


	*PUT SOME HEADINGS
	putdocx paragraph,style(Heading1)

	putdocx text ("ALPHA HIV incidence rates by study, sex and calendar year.")
	putdocx paragraph,style(Heading2)

	local impdate: char _dta[imputationdate]


	putdocx text ("MI used for seroconversion date with ${useimp} imputations created on `impdate' "),linebreak
	putdocx text ("Estimates produced: `estdate'")
	*==============================================================

	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	*** TABLE OF ESTIMATES FOR ALL AGES
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

	putdocx paragraph,style(Heading2)
	putdocx text ("HIV incidence rates by study, sex and calendar year for men and women aged 15-49.")

	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_allages",clear

	local estdate=c(filedate)
	di "`estdate'"
	replace rate=rate*100
	replace lb=lb*100
	replace ub=ub*100
	format %4.2f rate lb ub

	label var rate "Incidence rate/100 person years"
	label var lb "Lower 95% CI"
	label var ub "Upper 95% CI"

	rename _D failures
	label var failures "Mean number of failures"
	rename _Y person_years
	label var person_years "Mean number of person years"





	*ADD AN EMPTY TABLE THAT HAS 9 COLUMNS AND 4 ROWS
	putdocx table maintable=(4,9)

	*ADD SOME COLUMN HEADINGS
	putdocx table maintable(1,1)=("Study and year"),bold

	putdocx table maintable(1,4)=("Men"),bold

	putdocx table maintable(1,8)=("Women"),bold

	putdocx table maintable(2,3)=("Rate/100PY"),bold
	putdocx table maintable(2,4)=("95% CI"),bold
	putdocx table maintable(2,5)=("N failures (range)"),bold

	putdocx table maintable(2,7)=("Rate/100PY"),bold
	putdocx table maintable(2,8)=("95% CI"),bold
	putdocx table maintable(2,9)=("N failures (range)"),bold

	*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
	local rowcount=4

	*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
	qui levels study_name,local(slist)
	foreach s in `slist' {

		*add study name
		local sname:label (study_name) `s'
		putdocx table maintable(`rowcount',1)=("`sname'"),bold

		*add rows to the table
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount'+1

		qui levels fouryear if study_name==`s' ,local(ylist)

		foreach y in `ylist' {

			local yname: label (fouryear) `y'
			*add year
			putdocx table maintable(`rowcount',1)=("`yname'"),bold

			*add results for men and women for that calendar year period
			*Men
			sum failures if sex==1 & study_name==`s' & fouryear==`y'
			local fail:di %4.0f r(mean)

			sum min_D if sex==1 & study_name==`s' & fouryear==`y'
			local minfail:di %4.0f r(mean)
			sum max_D if sex==1 & study_name==`s' & fouryear==`y'
			local maxfail:di %4.0f r(mean)
			*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
			local range=trim("`minfail'" + " - " + "`maxfail'")
			local range=itrim("`range'")
			putdocx table maintable(`rowcount',5)=("`fail' (`range')")

			if `fail'>0 {

				sum rate if sex==1 & study_name==`s' & fouryear==`y'
				local rate:di %4.2f r(mean)
				putdocx table maintable(`rowcount',3)=("`rate'")

				sum lb if sex==1 & study_name==`s' & fouryear==`y'
				local lb:di %4.2f r(mean)
				sum ub if sex==1 & study_name==`s' & fouryear==`y'
				local ub:di %4.2f r(mean)
				putdocx table maintable(`rowcount',4)=("`lb'-`ub'")
				} /*end of if `fail'>0*/


			*women
			*GET THE NUMBER OF FAILURES- MEAN ACROSS IMPUTATION AND RANGE
			qui sum failures if sex==2 & study_name==`s' & fouryear==`y'
			local fail:di %4.0f r(mean)
			qui sum min_D if sex==2 & study_name==`s' & fouryear==`y'
			local minfail:di %4.0f r(mean)
			qui sum max_D if sex==2 & study_name==`s' & fouryear==`y'
			local maxfail:di %4.0f r(mean)
			*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
			local range=trim("`minfail'" + " - " + "`maxfail'")
			local range=itrim("`range'")

			putdocx table maintable(`rowcount',9)=("`fail' (`range')")

			if `fail' >0 {

				qui sum rate if sex==2 & study_name==`s' & fouryear==`y'
				local rate:di %4.2f r(mean)
				putdocx table maintable(`rowcount',7)=("`rate'")

				qui sum lb if sex==2 & study_name==`s' & fouryear==`y'
				local lb:di %4.2f r(mean)
				qui sum ub if sex==2 & study_name==`s' & fouryear==`y'
				local ub:di %4.2f r(mean)
				putdocx table maintable(`rowcount',8)=("`lb'-`ub'")
				} /*end of if `fail' >0*/



			putdocx table maintable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount' +1

			} /*close year loop */
			
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount' +1

		} /*close site loop */


	** add in a graph
	replace fouryear=fouryear+0.15 if sex==2

	graph twoway rspike lb ub fouryear if sex==1 ,by(study_name,yrescale iyaxes ixaxes note("") caption("") legend(at(9)) )  lwidth(medium) lcolor(${alphacolour1})  ///
		|| rspike lb ub fouryear if sex==2 ,by(study_name, ) lwidth(medium) lcolor(${alphacolour4})   ///
		|| scatter rate fouryear if sex==1, by(study_name, ) mcolor(${alphacolour1}) msize(small) ///
		|| scatter rate fouryear if sex==2, by(study_name, ) mcolor(${alphacolour4}) msize(small) ///
		ylabel(,format(%4.1f)) xlabel(0 1 2 3 4 5 ,val angle(0) labsize(vsmall)) legend(order(3 "Men" 4 "Women") cols(1) )   xsize(12) ysize(7)

	graph export "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_allages.png",replace width(6000)

	putdocx pagebreak
	putdocx paragraph
	putdocx image ("${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_allages.png")

	*==============================================================

	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	*** TABLE OF ESTIMATES FOR UNDER 25s
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	putdocx pagebreak

	putdocx paragraph,style(Heading2)
	putdocx text ("HIV incidence rates by study, sex and calendar year for men and women aged 15-24.")

	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_youth",clear

	local estdate=c(filedate)
	di "`estdate'"
	replace rate=rate*100
	replace lb=lb*100
	replace ub=ub*100
	format %4.2f rate lb ub

	label var rate "Incidence rate/100 person years"
	label var lb "Lower 95% CI"
	label var ub "Upper 95% CI"

	rename _D failures
	label var failures "Mean number of failures"
	rename _Y person_years
	label var person_years "Mean number of person years"





	*ADD AN EMPTY TABLE THAT HAS 9 COLUMNS AND 4 ROWS
	putdocx table youthtable=(4,9)

	*ADD SOME COLUMN HEADINGS
	putdocx table youthtable(1,1)=("Study and year"),bold

	putdocx table youthtable(1,4)=("Men"),bold

	putdocx table youthtable(1,8)=("Women"),bold

	putdocx table youthtable(2,3)=("Rate/100PY"),bold
	putdocx table youthtable(2,4)=("95% CI"),bold
	putdocx table youthtable(2,5)=("N failures (range)"),bold

	putdocx table youthtable(2,7)=("Rate/100PY"),bold
	putdocx table youthtable(2,8)=("95% CI"),bold
	putdocx table youthtable(2,9)=("N failures (range)"),bold

	*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
	local rowcount=4

	*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
	qui levels study_name,local(slist)
	foreach s in `slist' {

		*add study name
		local sname:label (study_name) `s'
		putdocx table youthtable(`rowcount',1)=("`sname'"),bold

		*add rows to the table
		putdocx table youthtable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount'+1

		qui levels fouryear if study_name==`s' ,local(ylist)

		foreach y in `ylist' {

			local yname: label (fouryear) `y'
			*add year
			putdocx table youthtable(`rowcount',1)=("`yname'"),bold

			*add results for men and women for that calendar year period
			*Men
			sum failures if sex==1 & study_name==`s' & fouryear==`y'
			local fail:di %4.0f r(mean)

			sum min_D if sex==1 & study_name==`s' & fouryear==`y'
			local minfail:di %4.0f r(mean)
			sum max_D if sex==1 & study_name==`s' & fouryear==`y'
			local maxfail:di %4.0f r(mean)
			*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
			local range=trim("`minfail'" + " - " + "`maxfail'")
			local range=itrim("`range'")
			putdocx table youthtable(`rowcount',5)=("`fail' (`range')")

			if `fail'>0 {

				sum rate if sex==1 & study_name==`s' & fouryear==`y'
				local rate:di %4.2f r(mean)
				putdocx table youthtable(`rowcount',3)=("`rate'")

				sum lb if sex==1 & study_name==`s' & fouryear==`y'
				local lb:di %4.2f r(mean)
				sum ub if sex==1 & study_name==`s' & fouryear==`y'
				local ub:di %4.2f r(mean)
				putdocx table youthtable(`rowcount',4)=("`lb'-`ub'")
				} /*end of if `fail'>0*/


			*women
			*GET THE NUMBER OF FAILURES- MEAN ACROSS IMPUTATION AND RANGE
			qui sum failures if sex==2 & study_name==`s' & fouryear==`y'
			local fail:di %4.0f r(mean)
			qui sum min_D if sex==2 & study_name==`s' & fouryear==`y'
			local minfail:di %4.0f r(mean)
			qui sum max_D if sex==2 & study_name==`s' & fouryear==`y'
			local maxfail:di %4.0f r(mean)
			*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
			local range=trim("`minfail'" + " - " + "`maxfail'")
			local range=itrim("`range'")

			putdocx table youthtable(`rowcount',9)=("`fail' (`range')")

			if `fail' >0 {

				qui sum rate if sex==2 & study_name==`s' & fouryear==`y'
				local rate:di %4.2f r(mean)
				putdocx table youthtable(`rowcount',7)=("`rate'")

				qui sum lb if sex==2 & study_name==`s' & fouryear==`y'
				local lb:di %4.2f r(mean)
				qui sum ub if sex==2 & study_name==`s' & fouryear==`y'
				local ub:di %4.2f r(mean)
				putdocx table youthtable(`rowcount',8)=("`lb'-`ub'")
				} /*end of if `fail'>0*/



			putdocx table youthtable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount' +1

			} /*close year loop */
		
		putdocx table youthtable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount' +1

		} /*close site loop */

	*===============================================/ end of under 25s /



	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	*** TABLE OF ESTIMATES FOR OVER 25s
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	cap use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_older",clear

	if _rc==0 {
		putdocx pagebreak
		putdocx paragraph,style(Heading2)
		putdocx text ("HIV incidence rates by study, sex and calendar year for men and women aged 25-49.")

		use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_older",clear

		local estdate=c(filedate)
		di "`estdate'"
		replace rate=rate*100
		replace lb=lb*100
		replace ub=ub*100
		format %4.2f rate lb ub

		label var rate "Incidence rate/100 person years"
		label var lb "Lower 95% CI"
		label var ub "Upper 95% CI"

		rename _D failures
		label var failures "Mean number of failures"
		rename _Y person_years
		label var person_years "Mean number of person years"





		*ADD AN EMPTY TABLE THAT HAS 9 COLUMNS AND 4 ROWS
		putdocx table oldertable=(4,9)

		*ADD SOME COLUMN HEADINGS
		putdocx table oldertable(1,1)=("Study and year"),bold

		putdocx table oldertable(1,4)=("Men"),bold

		putdocx table oldertable(1,8)=("Women"),bold

		putdocx table oldertable(2,3)=("Rate/100PY"),bold
		putdocx table oldertable(2,4)=("95% CI"),bold
		putdocx table oldertable(2,5)=("N failures (range)"),bold

		putdocx table oldertable(2,7)=("Rate/100PY"),bold
		putdocx table oldertable(2,8)=("95% CI"),bold
		putdocx table oldertable(2,9)=("N failures (range)"),bold

		*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
		local rowcount=4

		*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
		qui levels study_name,local(slist)
		foreach s in `slist' {

			*add study name
			local sname:label (study_name) `s'
			putdocx table oldertable(`rowcount',1)=("`sname'"),bold

			*add rows to the table
			putdocx table oldertable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount'+1

			qui levels fouryear if study_name==`s' ,local(ylist)

			foreach y in `ylist' {

				local yname: label (fouryear) `y'
				*add year
				putdocx table oldertable(`rowcount',1)=("`yname'"),bold

				*add results for men and women for that calendar year period
				*Men
				sum failures if sex==1 & study_name==`s' & fouryear==`y'
				local fail:di %4.0f r(mean)

				sum min_D if sex==1 & study_name==`s' & fouryear==`y'
				local minfail:di %4.0f r(mean)
				sum max_D if sex==1 & study_name==`s' & fouryear==`y'
				local maxfail:di %4.0f r(mean)
				*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
				local range=trim("`minfail'" + " - " + "`maxfail'")
				local range=itrim("`range'")
				putdocx table oldertable(`rowcount',5)=("`fail' (`range')")

				if `fail'>0 {

					sum rate if sex==1 & study_name==`s' & fouryear==`y'
					local rate:di %4.2f r(mean)
					putdocx table oldertable(`rowcount',3)=("`rate'")

					sum lb if sex==1 & study_name==`s' & fouryear==`y'
					local lb:di %4.2f r(mean)
					sum ub if sex==1 & study_name==`s' & fouryear==`y'
					local ub:di %4.2f r(mean)
					putdocx table oldertable(`rowcount',4)=("`lb'-`ub'")
					} /*end of if `fail'>0*/


				*women
				*GET THE NUMBER OF FAILURES- MEAN ACROSS IMPUTATION AND RANGE
				qui sum failures if sex==2 & study_name==`s' & fouryear==`y'
				local fail:di %4.0f r(mean)
				qui sum min_D if sex==2 & study_name==`s' & fouryear==`y'
				local minfail:di %4.0f r(mean)
				qui sum max_D if sex==2 & study_name==`s' & fouryear==`y'
				local maxfail:di %4.0f r(mean)
				*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
				local range=trim("`minfail'" + " - " + "`maxfail'")
				local range=itrim("`range'")

				putdocx table oldertable(`rowcount',9)=("`fail' (`range')")

				if `fail' >0 {

					qui sum rate if sex==2 & study_name==`s' & fouryear==`y'
					local rate:di %4.2f r(mean)
					putdocx table oldertable(`rowcount',7)=("`rate'")

					qui sum lb if sex==2 & study_name==`s' & fouryear==`y'
					local lb:di %4.2f r(mean)
					qui sum ub if sex==2 & study_name==`s' & fouryear==`y'
					local ub:di %4.2f r(mean)
					putdocx table oldertable(`rowcount',8)=("`lb'-`ub'")
					} /*end of if `fail'>0*/



				putdocx table oldertable(`rowcount',.), addrows(1,after)
				local rowcount=`rowcount' +1

				} /*close year loop */
				
			putdocx table oldertable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount' +1

			} /*close site loop */
		} /* close _rc if */
	*=========================================/ END OF OVER 25s /

	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	*** TABLE OF AGE-SPECIFIC ESTIMATES
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	putdocx pagebreak
	putdocx paragraph,style(Heading2)
	putdocx text ("Age-specific HIV incidence rates by study, sex and calendar year for men and women aged 15-49.")

	use "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/MI_rates_sex_fouryear_agegrp",clear

	local estdate=c(filedate)
	di "`estdate'"
	replace rate=rate*100
	replace lb=lb*100
	replace ub=ub*100
	format %4.2f rate lb ub

	label var rate "Incidence rate/100 person years"
	label var lb "Lower 95% CI"
	label var ub "Upper 95% CI"

	rename _D failures
	label var failures "Mean number of failures"
	rename _Y person_years
	label var person_years "Mean number of person years"




	putdocx paragraph,
	putdocx text ("Men"),bold

	*ADD AN EMPTY TABLE THAT HAS ENOUGH COLUMNS FOR THE GROUPS OF CALENDAR YEAR AND 4 ROWS- MORE WILL BE ADDED AS THE DATA ARE ADDED
	inspect fouryear
	local nvals=r(N_unique)
	local colsneeded=`nvals'*3+1
	putdocx table maintable=(4,`colsneeded')

	*ADD SOME COLUMN HEADINGS
	putdocx table maintable(1,1)=("Study and age group"),bold
	*need to add three columns for each calendar year group
	local colcount=2
	qui levels fouryear,local(ylist)
	foreach y in `ylist' {
		local yname: label (fouryear) `y'
		*sending results to three columns- rates, ci and N
		local ratecol=`colcount'+0
		local cicol=`colcount'+1
		local ncol=`colcount'+2
		putdocx table maintable(1,`cicol')=("`yname'"),bold 
		putdocx table maintable(2,`ratecol')=("Rate/100PY"),bold
		putdocx table maintable(2,`cicol')=("95% CI"),bold
		putdocx table maintable(2,`ncol')=("N failures (range)"),bold
		local colcount=`colcount'+3
		} /*end of foreach y in `ylist'*/

	*Change the font to Arial Narrow size 9
	putdocx table maintable(1,.),font("Arial Narrow",9)
	putdocx table maintable(2,.),font("Arial Narrow",9)


	*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
	local rowcount=4

	*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
	qui levels study_name,local(slist)
		foreach s in `slist' {

		*add study name
		local sname:label (study_name) `s'
		putdocx table maintable(`rowcount',1)=("`sname'"),bold

		*add rows to the table
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount'+1

		qui levels agegrp if study_name==`s' ,local(alist)

		foreach a in `alist' {

			local aname: label (agegrp) `a'
			*add age group
			putdocx table maintable(`rowcount',1)=("`aname'"),bold

			*add results for each age group for that calendar year period
			* need to navigate the columns as well as the rows now
			*start in column 2, and then move across in threes.
			local colcount=2
			
			qui levels fouryear,local(ylist)
			foreach y in `ylist' {
				local yname: label (fouryear) `y'
				*sending results to three columns- rates, ci and N
				local ratecol=`colcount'+0
				local cicol=`colcount'+1
				local ncol=`colcount'+2
				
				*count the numbers of deaths and the range across imputations
				qui sum failures if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local fail:di %4.0f r(mean)

				qui sum min_D if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local minfail:di %4.0f r(mean)
				qui sum max_D if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local maxfail:di %4.0f r(mean)
				*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
				local range=trim("`minfail'" + " - " + "`maxfail'")
				local range=itrim("`range'")
				

				if `fail'>0 & `fail'<. {
					*add the number of deaths to the table
					putdocx table maintable(`rowcount',`ncol')=("`fail' (`range')")	
					*summarise and add the rate (summarize is just a trick to get the value from the dataset)
					qui sum rate if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local rate:di %4.2f r(mean)
					putdocx table maintable(`rowcount',`ratecol')=("`rate'")
					*the 95% CI
					qui sum lb if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local lb:di %4.2f r(mean)
					qui sum ub if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local ub:di %4.2f r(mean)
					putdocx table maintable(`rowcount',`cicol')=("`lb'-`ub'")
					} /*end of if*/

				*Move across to the right in the table for the next year block
				local colcount=`colcount'+3
				*empty the macros
				macro drop fail range rate lb ub
				} /*close year loop */

			putdocx table maintable(`rowcount',.),font("Arial Narrow",9)
			putdocx table maintable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount' +1

			} /*close age loop */
			
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount' +1

		} /*close site loop */



	** WOMEN

	putdocx pagebreak
	putdocx paragraph,
	putdocx text ("Women"),bold

	*ADD AN EMPTY TABLE THAT HAS ENOUGH COLUMNS FOR THE GROUPS OF CALENDAR YEAR AND 4 ROWS- MORE WILL BE ADDED AS THE DATA ARE ADDED
	inspect fouryear
	local nvals=r(N_unique)
	local colsneeded=`nvals'*3+1
	putdocx table maintable=(4,`colsneeded')

	*ADD SOME COLUMN HEADINGS
	putdocx table maintable(1,1)=("Study and age group"),bold
	*need to add three columns for each calendar year group
	local colcount=2
	qui levels fouryear,local(ylist)
	foreach y in `ylist' {
		local yname: label (fouryear) `y'
		*sending results to three columns- rates, ci and N
		local ratecol=`colcount'+0
		local cicol=`colcount'+1
		local ncol=`colcount'+2
		putdocx table maintable(1,`cicol')=("`yname'"),bold
		putdocx table maintable(2,`ratecol')=("Rate/100PY"),bold
		putdocx table maintable(2,`cicol')=("95% CI"),bold
		putdocx table maintable(2,`ncol')=("N failures (range)"),bold
		local colcount=`colcount'+3
		} /* end of foreach y in `ylist' */


	*Change the font to Arial Narrow size 9
	putdocx table maintable(1,.),font("Arial Narrow",9)
	putdocx table maintable(2,.),font("Arial Narrow",9)


	*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
	local rowcount=4

	*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
	qui levels study_name,local(slist)
		foreach s in `slist' {

		*add study name
		local sname:label (study_name) `s'
		putdocx table maintable(`rowcount',1)=("`sname'"),bold

		*add rows to the table
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount'+1

		qui levels agegrp if study_name==`s' ,local(alist)

		foreach a in `alist' {

			local aname: label (agegrp) `a'
			*add age group
			putdocx table maintable(`rowcount',1)=("`aname'"),bold

			*add results for each age group for that calendar year period
			* need to navigate the columns as well as the rows now
			*start in column 2, and then move across in threes.
			local colcount=2
			
			qui levels fouryear,local(ylist)
			foreach y in `ylist' {
				local yname: label (fouryear) `y'
				*sending results to three columns- rates, ci and N
				local ratecol=`colcount'+0
				local cicol=`colcount'+1
				local ncol=`colcount'+2
				
				*count the numbers of deaths and the range across imputations
				qui sum failures if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local fail:di %4.0f r(mean)

				qui sum min_D if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local minfail:di %4.0f r(mean)
				qui sum max_D if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
				local maxfail:di %4.0f r(mean)
				*TIDY UP THE RANGE FOR PRESENTATION- TAKE OUT EXCESS SPACES
				local range=trim("`minfail'" + " - " + "`maxfail'")
				local range=itrim("`range'")
				

				if `fail'>0 & `fail'<. {
					*add the number of deaths to the table
					putdocx table maintable(`rowcount',`ncol')=("`fail' (`range')")	
					*summarise and add the rate (summarize is just a trick to get the value from the dataset)
					qui sum rate if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local rate:di %4.2f r(mean)
					putdocx table maintable(`rowcount',`ratecol')=("`rate'")
					*the 95% CI
					qui sum lb if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local lb:di %4.2f r(mean)
					qui sum ub if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
					local ub:di %4.2f r(mean)
					putdocx table maintable(`rowcount',`cicol')=("`lb'-`ub'")
					} /*end of if*/

				*Move across to the right in the table for the next year block
				local colcount=`colcount'+3
				*empty the macros
				macro drop fail range rate lb ub
				} /*close year loop */

			putdocx table maintable(`rowcount',.),font("Arial Narrow",9)
			putdocx table maintable(`rowcount',.), addrows(1,after)
			local rowcount=`rowcount' +1

			} /*close age loop */
			
		putdocx table maintable(`rowcount',.), addrows(1,after)
		local rowcount=`rowcount' +1

		} /*close site loop */



	*=====================================================/ END AGE SPECIFIC ESTIMATES /



	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
	*** SAVE AND CLOSE THE REPORT DOCUMENT
	*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=


	putdocx save "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/ALPHA_HIV_incidence_estimates_standard_report_${sitename}.docx",replace

	noi di as txt `"Results are in {browse "${alphapath}/ALPHA\Estimates_Incidence\MI_rates/${sitename}/ALPHA_HIV_incidence_estimates_standard_report_${sitename}.docx"}"'
	*==============================================================


	} /*close site loop */





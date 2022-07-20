*
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*** ESTIMATE THE MIDPOINTHIV INCIDENCE RATES
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

use "${alphapath}/ALPHA\Incidence_ready_data/pooled/incidence_ready_midpoint_pooled.dta",clear

*Overall rate by sex, site and calendar years
strate study_name sex fouryear if age>14 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear",replace)

*Age-specific rates by sex, site and calendar years
strate study_name sex fouryear agegrp if age>14 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear_agegrp",replace)

*Under 25 rates by sex, site and calendar years
strate study_name sex fouryear agegrp if age>14 & age<25,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear_youth",replace)


*Over 25 rates by sex, site and calendar years
strate study_name sex fouryear agegrp if age>24 & age<50,per(1) output("${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear_older",replace)
*============================================

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

putdocx text ("Midpoint used for seroconversion date"),linebreak
putdocx text ("Estimates produced: `estdate'")



*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*** TABLE OF ESTIMATES FOR ALL AGES
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

use "${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear",clear
*get rid of small groups- less than 20 person years
drop if _Y<20

local estdate=c(filedate)
di "`estdate'"
format %12.1fc _Y
gen rate=_Rate*100
gen lb=_L*100
gen ub=_U*100
format %4.2f rate lb ub
rename _D failures
rename _Y person_years

label var rate "Incidence rate/100 person years"
label var lb "Lower 95% CI"
label var ub "Upper 95% CI"


*ADD AN EMPTY TABLE THAT HAS 9 COLUMNS AND 50 ROWS
putdocx table maintable=(4,9)

*ADD SOME COLUMN HEADINGS
putdocx table maintable(1,1)=("Study and year"),bold

putdocx table maintable(1,4)=("Men"),bold

putdocx table maintable(1,8)=("Women"),bold

putdocx table maintable(2,3)=("Rate/100PY"),bold
putdocx table maintable(2,4)=("95% CI"),bold
putdocx table maintable(2,5)=("N failures"),bold

putdocx table maintable(2,7)=("Rate/100PY"),bold
putdocx table maintable(2,8)=("95% CI"),bold
putdocx table maintable(2,9)=("N failures"),bold

*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
local rowcount=4

*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
levels study_name,local(slist)
foreach s in `slist' {

	*add study name
	local sname:label (study_name) `s'
	putdocx table maintable(`rowcount',1)=("`sname'"),bold

	*add rows to the table
	putdocx table maintable(`rowcount',.), addrows(1,after)
	local rowcount=`rowcount'+1

	levels fouryear if study_name==`s' ,local(ylist)

	foreach y in `ylist' {

		local yname: label (fouryear) `y'
		*add year
		putdocx table maintable(`rowcount',1)=("`yname'"),bold

		*add results for men and women for that calendar year period
		*Men
		sum failures if sex==1 & study_name==`s' & fouryear==`y'
		local fail:di %4.0f r(mean)
		putdocx table maintable(`rowcount',5)=("`fail'")

		if `fail'>0 {

			sum rate if sex==1 & study_name==`s' & fouryear==`y'
			local rate:di %4.2f r(mean)
			putdocx table maintable(`rowcount',3)=("`rate'")

			sum lb if sex==1 & study_name==`s' & fouryear==`y'
			local lb:di %4.2f r(mean)
			sum ub if sex==1 & study_name==`s' & fouryear==`y'
			local ub:di %4.2f r(mean)
			putdocx table maintable(`rowcount',4)=("`lb'-`ub'")
			} /*end of if*/


		*women
		sum failures if sex==2 & study_name==`s' & fouryear==`y'
		local fail:di %4.0f r(mean)
		putdocx table maintable(`rowcount',9)=("`fail'")

		if `fail' >0 {

			sum rate if sex==2 & study_name==`s' & fouryear==`y'
			local rate:di %4.2f r(mean)
			putdocx table maintable(`rowcount',7)=("`rate'")

			sum lb if sex==2 & study_name==`s' & fouryear==`y'
			local lb:di %4.2f r(mean)
			sum ub if sex==2 & study_name==`s' & fouryear==`y'
			local ub:di %4.2f r(mean)
			putdocx table maintable(`rowcount',8)=("`lb'-`ub'")
			} /*end of if*/



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
	
graph export "${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/midpoint_rates_sex_fouryear_allages.png",replace width(6000)

putdocx pagebreak
putdocx paragraph
putdocx image ("${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/midpoint_rates_sex_fouryear_allages.png")

*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*** TABLE OF AGE-SPECIFIC ESTIMATES
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
putdocx pagebreak
putdocx paragraph,style(Heading2)
putdocx text ("Age-specific HIV incidence rates by study, sex and calendar year for men and women aged 15-49.")

use "${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear_agegrp" ,clear

local estdate=c(filedate)
di "`estdate'"
gen rate=_Rate*100
gen lb=_L*100
gen ub=_U*100
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
levels fouryear,local(ylist)
foreach y in `ylist' {
	local yname: label (fouryear) `y'
	*sending results to three columns- rates, ci and N
	local ratecol=`colcount'+0
	local cicol=`colcount'+1
	local ncol=`colcount'+2
	putdocx table maintable(1,`cicol')=("`yname'"),bold
	putdocx table maintable(2,`ratecol')=("Rate/100PY"),bold
	putdocx table maintable(2,`cicol')=("95% CI"),bold
	putdocx table maintable(2,`ncol')=("N failures "),bold
	local colcount=`colcount'+3
	} 

*Change the font to Arial Narrow size 9
putdocx table maintable(1,.),font("Arial Narrow",9)
putdocx table maintable(2,.),font("Arial Narrow",9)


*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
local rowcount=4

*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
levels study_name,local(slist)
	foreach s in `slist' {

	*add study name
	local sname:label (study_name) `s'
	putdocx table maintable(`rowcount',1)=("`sname'"),bold

	*add rows to the table
	putdocx table maintable(`rowcount',.), addrows(1,after)
	local rowcount=`rowcount'+1

	levels agegrp if study_name==`s' ,local(alist)

	foreach a in `alist' {

		local aname: label (agegrp) `a'
		*add age group
		putdocx table maintable(`rowcount',1)=("`aname'"),bold

		*add results for each age group for that calendar year period
		* need to navigate the columns as well as the rows now
		*start in column 2, and then move across in threes.
		local colcount=2
		
		levels fouryear,local(ylist)
		foreach y in `ylist' {
			local yname: label (fouryear) `y'
			*sending results to three columns- rates, ci and N
			local ratecol=`colcount'+0
			local cicol=`colcount'+1
			local ncol=`colcount'+2
			
			*count the numbers of deaths
			qui sum failures if sex==1 & study_name==`s' & agegrp==`a' & fouryear==`y'
			local fail:di %4.0f r(mean)
			

			if `fail'>0 & `fail'<. {
				*add the number of deaths to the table
				putdocx table maintable(`rowcount',`ncol')=("`fail'")	
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
levels fouryear,local(ylist)
foreach y in `ylist' {
	local yname: label (fouryear) `y'
	*sending results to three columns- rates, ci and N
	local ratecol=`colcount'+0
	local cicol=`colcount'+1
	local ncol=`colcount'+2
	putdocx table maintable(1,`cicol')=("`yname'"),bold
	putdocx table maintable(2,`ratecol')=("Rate/100PY"),bold
	putdocx table maintable(2,`cicol')=("95% CI"),bold
	putdocx table maintable(2,`ncol')=("N failures"),bold
	local colcount=`colcount'+3
	} 


*Change the font to Arial Narrow size 9
putdocx table maintable(1,.),font("Arial Narrow",9)
putdocx table maintable(2,.),font("Arial Narrow",9)


*START A LOCAL MACRO TO KEEP TRACK OF THE ROW WE ARE COMPLETING
local rowcount=4

*LOOP THROUGH THE DATA TO WRITE ONE TABLE ROW AT A TIME
levels study_name,local(slist)
	foreach s in `slist' {

	*add study name
	local sname:label (study_name) `s'
	putdocx table maintable(`rowcount',1)=("`sname'"),bold

	*add rows to the table
	putdocx table maintable(`rowcount',.), addrows(1,after)
	local rowcount=`rowcount'+1

	levels agegrp if study_name==`s' ,local(alist)

	foreach a in `alist' {

		local aname: label (agegrp) `a'
		*add age group
		putdocx table maintable(`rowcount',1)=("`aname'"),bold

		*add results for each age group for that calendar year period
		* need to navigate the columns as well as the rows now
		*start in column 2, and then move across in threes.
		local colcount=2
		
		levels fouryear,local(ylist)
		foreach y in `ylist' {
			local yname: label (fouryear) `y'
			*sending results to three columns- rates, ci and N
			local ratecol=`colcount'+0
			local cicol=`colcount'+1
			local ncol=`colcount'+2
			
			*count the numbers of deaths and the range across imputations
			qui sum failures if sex==2 & study_name==`s' & agegrp==`a' & fouryear==`y'
			local fail:di %4.0f r(mean)
			

			if `fail'>0 & `fail'<. {
				*add the number of deaths to the table
				putdocx table maintable(`rowcount',`ncol')=("`fail'")	
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
				} /*end of if */

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

*===========================================


*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
*** SAVE AND CLOSE THE REPORT DOCUMENT
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=



putdocx save "${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear.docx",replace

noi di as txt `"Results are in {browse "${alphapath}/ALPHA\Estimates_Incidence\midpoint_rates/Midpoint_rates_sex_fouryear.docx"}"'


/*

levels study_name, local(slist)
foreach s in `slist' {
local sname:label (study) `s'
graph twoway rspike lb ub agegrp if fouryear==2 & study_name==`s',by(sex,yrescale iyaxes ixaxes note("") caption("") legend(at(9)) )  lwidth(medium) lcolor(${alphacolour1}%50)  ///
|| rspike lb ub agegrp if fouryear==3  & study_name==`s' ,by(sex, ) lwidth(medium) lcolor(${alphacolour3}%50)   ///
|| rspike lb ub agegrp if fouryear==4  & study_name==`s' ,by(sex, ) lwidth(medium) lcolor(${alphacolour5}%50)   ///
|| rspike lb ub agegrp if fouryear==5  & study_name==`s' ,by(sex, ) lwidth(medium) lcolor(black%50)   ///
|| connected rate agegrp if fouryear==2 & study_name==`s', by(sex, ) mcolor(${alphacolour1}) msize(small)   lcolor(${alphacolour1}) lwidth(thick)  ///
|| connected rate agegrp if fouryear==3 & study_name==`s', by(sex, ) mcolor(${alphacolour3}) msize(small)   lcolor(${alphacolour3}) lwidth(thick)  ///
|| connected rate agegrp if fouryear==4 & study_name==`s', by(sex, ) mcolor(${alphacolour5}) msize(small)   lcolor(${alphacolour5}) lwidth(thick)  ///
|| connected rate agegrp if fouryear==5 & study_name==`s', by(sex, ) mcolor(black) msize(small)  lcolor(black) lwidth(thick)  ///
ylabel(,format(%4.1f)) xlabel( ,val angle(0) labsize(vsmall)) legend(order(3 "Men" 4 "Women") cols(1) )   xsize(12) ysize(7) title("`sname'") name("`sname'",replace)
}

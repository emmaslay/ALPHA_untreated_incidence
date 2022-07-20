
*****************************************************************************
*  RECODE THE INDIVIDUAL LEVEL CROSS-SECTIONAL DATA FROM sexual_behaviour 
*****************************************************************************

local id ="p17"
local name="${alphapath}/ALPHA/dofiles/prepare_data/Recode_sexual_behaviour.do"
local level="prepare"

local calls=""
local uses="${alphapath}/ALPHA/clean_data/${sitename}/sexual_behaviour_${sitename}.dta ${alphapath}/ALPHA/clean_data/survey_metadata" 
local saves="${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename} ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_wide_${sitename}"
local does="The sexual behaviour spec contains a variety of reference periods and codings to accommodate differences between the sites. This produces a more harmonised dataset"


*** 

*USE THIS FOR THE PARTNERSHIP PATTERNS AND IN THE INDIVIDUAL CORRELATES ANALYSES

use "${alphapath}/ALPHA/clean_data/${sitename}/sexual_behaviour_${sitename}.dta" ,clear

/*
if "$sitename"=="kisesa"{
drop study_name
gen study_name=2
label define study_name 2 "Kisesa", modify
label val study_name study_name

forvalues x = 1/6 {
gen whenlast_month`x'=.
}
}
*/

if lower("$sitename")=="masaka"{
forvalues x=1/3 {
recode whenfirst_daysago`x' 88888=.
recode whenfirst_month`x' 888=.
recode whenfirst_year`x' 8888=.

recode whenlast_daysago`x' 8888=.
recode whenlast_month`x' 888=.
recode whenlast_year`x' 8888=.
*masaka- there are large number who haven't reported who or timings, these are people whose last sex was >1 year ago

*few duplicates so drop these
duplicates drop study_name survey_round_name idno,force
}
}


if lower("$sitename")=="ifakara"{
forvalues x=1/6 {
*first sex is only filled in for those for whom it was < 1year. assume others are >1 yr ago
replace whenfirst_daysago`x'=366 if whenfirst_daysago`x'==. & who`x'<. & whenlast_daysago`x'<.

}
}

if lower("$sitename")=="umkhanyakude"{
*drop the records for people who didn't complete the sexual behaviour part of the survey
drop if marever<9  & (who1==88 | who1==99) &  firstsex_age==99 & circ==9 & sexever==9

}

drop if study_name==8 & survey_sex==. & survey_round_name=="LBBS 4"

*Manicaland - make condom freq variables coded rather than proportion of occasions
if lower("$sitename")=="manicaland"{
recode condom_freq1 1/max=2 0.0001/0.9999=1
recode condom_freq2 1/max=2 0.0001/0.9999=1
recode condom_freq3 1/max=2 0.0001/0.9999=1
}



merge m:1 study_name survey_round_name using ${alphapath}/ALPHA/clean_data/survey_metadata
drop if _m==2

****** DEFINE LABELS  ***************
label define yesno 0 "No" 1 "Yes" ,modify

label define yesnodk 0 "No" 1 "Yes" 3 "Don't know" 8 "Not asked" 9 "Missing",modify

label define sex 1 "Men" 2 "Women",modify

label define page 1 "10 or more years older"  2 "5-9 years older" 3 "Within 5 years of your age" 4 "5-9 years younger" 5 "10 or more years younger" 9 "Don’t know/missing",modify
#delimit;
label define who 10 "Spouse or cohabiting"
11 "Spouse"
12 "Cohabiting"
21 "Regular"
22 "Girlfriend/boyfriend"
31 "Friend"
32 "Casual"
33 "Consensual partner"
34 "Workmate"
35 "Boss/work supervisor"
36 "Employee"
37 "Fellow student"
41 "Stranger"
42 "Sugar daddy"
43 "Rapist"
50 "Commercial"
51 "Bar girl"
60 "Ex-spouse"
61 "Former wife or regular partner"
70 "Other"
71 "Other friend or visitor"
72 "Relative"
73 "In-law "
97 "Don’t know"
98 "Not asked"
99 "Not recorded",modify;
#delimit cr

**************************************

rename survey_sex sex
label values sex sex
label var sex "Sex as reported in survey"
*some surveys don't collect this- in which case if there are no records with any data, drop variable
*later on, will merge it in from 6.1
summ sex
if r(N)==0 {
drop sex
}

*CC ADDITION
/*
if "$sitename"=="uMkhanyakude"{
drop if partners_lastyear==999999 & sexever==9
}
*/



label values circumcised yesnodk

gen interview_month=month(interview_date)
gen interview_year=year(interview_date)


**** FIX THE DENOMINATORS WHEN QUESTIONS HAVE BEEN SKIPPED ON FILTERS- THESE SHOULD HAVE BEEN DONE IN SPEC PREP BUT HAVEN'T ALWAYS

** Ever had sex
replace sexever=0 if partners_life==0 & (sexever==9 | sexever==.)
replace sexever=1 if partners_life>0 & partners_life<999999 & (sexever==9 | sexever==.)


*lifetime partners
*flag to see if this was collected- only want to make the next edit for rounds where lifetime partners was asked
bys survey_round_name:egen minlifep=min(partners_life)
replace partners_life=0 if sexever==0 & partners_life==999999 & minlifep==0



*************************************************************
*** LOOK AT WHO REPORTED IN PARTNER HISTORY
*************************************************************

summ phistnum
local maxphistnum=r(max)


** flag survey by what was asked

bys survey_round_name :egen phist_asked=min(who`maxphistnum')
recode phist_asked 1/max=1 .=0
label var phist_asked "This survey included a partner history"

*CC added as AHRI have missing coded as 999999
forvalues x=1/`maxphistnum' {
	
	recode whenfirst_daysago`x' 999999=.
	recode whenlast_daysago`x' 999999=.

}

*did partner history include dates
gen tmpphist_asked_dates=0 if whenfirst_month1==. & whenfirst_year1==. & whenlast_daysago1==.
replace  tmpphist_asked_dates=1 if whenfirst_month1<. | whenfirst_year1<. |  whenlast_daysago1<.

bys survey_round_name :egen phist_asked_dates=max(tmpphist_asked_dates)
label var phist_asked_dates "This survey included a partner history and included dates of partnerships"


*did partner history include relationship to partner
bys survey_round_name :egen phist_asked_who=min(who1)
recode phist_asked_who 0/87=1 88/max=0 .=0



*did partner history include age of partner
bys survey_round_name :egen phist_asked_page=min(page1)
bys survey_round_name :egen phist_asked_pexactage=min(pexactage1)
recode phist_asked_pexactage 1/max=1 .=0 min/0=0


recode phist_asked_page 1/max=1 .=0
replace phist_asked_page=1 if phist_asked_pexactage<.
replace phist_asked_page=1 if phist_asked_pexactage==.
replace phist_asked_page=0 if study_name==3 & survey_round_name=="1"
label var phist_asked_page "This survey included a partner history and asked age of partner"

*did partner history include HIV status of partner (respondent's assesment)
bys survey_round_name :egen phist_asked_status_first=min( phiv_firstsex1)
bys survey_round_name :egen phist_asked_status_last=min(phiv_lastsex1 )
egen phist_asked_status=rowmin(phist_asked_status_first phist_asked_status_last)
recode phist_asked_status 0/2=1 .=0


*did partner history include disclosure of HIV status
bys survey_round_name :egen phist_asked_disclosure_r=min( hiv_disc_r1)
bys survey_round_name :egen phist_asked_disclosure_p=min(hiv_disc_p1 )
egen phist_asked_disclosure=rowmin(phist_asked_disclosure_r phist_asked_disclosure_p)
 recode phist_asked_disclosure 0/1=1 .=0


*information for this partner
forvalues x=1/`maxphistnum' {
	gen info_on_partner`x'=1 if who`x'<88 &  ongoing`x'<9
	label var info_on_partner`x' "Whether reported any information on partner `x'"
	** MANICALAND DOESN'T HAVE INFO ON WHO SO NEED TO TAG PARTNERS USING OTHER INFO
	replace info_on_partner`x'=1 if info_on_partner`x'==. & study_name==3 & cf_actual_week`x'<.

}

egen partners_with_any_info=rownonmiss(info_on_partner*)



*********** TIMING OF PARTNERS ****************


forvalues x=1/`maxphistnum' {


	*GENERATE THE DATE OF     LAST    SEX WITH THIS PARTNER
	** have assumed that days elapsed will be more accurate than month and year, if both are available
	*if described as days elapsed:
	gen double whenlast_date`x'=interview_date-whenlast_daysago`x' if whenlast_daysago`x'<.
	*if both month and year given , assume midnodle of the month
	replace whenlast_date`x'=mdy(whenlast_month`x',15,whenlast_year`x') if whenlast_month`x'<. & whenlast_year`x'<. & whenlast_date`x'==.
	*if the last sex was in the same month as the interview put it midnoway between interview and start of the month
	replace whenlast_date`x'=(interview_date+mdy(interview_month,1,interview_year))/2 if whenlast_month`x'==interview_month & whenlast_year`x'==interview_year & whenlast_daysago`x'==.

	*generate the days since   last   sex with this partner
	gen double dayslastsex`x'=whenlast_daysago`x' if whenlast_daysago`x'<.
	replace dayslastsex`x'=interview_date-whenlast_date`x' if whenlast_daysago`x'==.


	*GENERATE THE DATE OF    FIRST    SEX WITH THIS PARTNER
	*if described as days elapsed:
	gen double whenfirst_date`x'=interview_date-whenfirst_daysago`x' if whenfirst_daysago`x'<.
	*if both month and year given , assume midnodle of the month
	replace whenfirst_date`x'=mdy(whenfirst_month`x',15,whenfirst_year`x') if whenfirst_month`x'<. & whenfirst_year`x'<. & whenfirst_date`x'==.
	*if the last sex was in the same month as the interview put it midnoway between interview and start of the month
	replace whenfirst_date`x'=(interview_date+mdy(interview_month,1,interview_year))/2 if whenfirst_month`x'==interview_month & whenfirst_year`x'==interview_year & whenfirst_daysago`x'==.
	*if only year given

	*generate the days since first sex with this partner
	gen double daysfirstsex`x'=whenfirst_daysago`x' if whenfirst_daysago`x'<.
	replace daysfirstsex`x'=interview_date-whenfirst_date`x' if whenfirst_daysago`x'==.

	label var whenlast_date`x' "Date of most recent sex with partner `x'"
	label var dayslastsex`x' "Days elapsed since most recent sex with partner `x'"

	label var whenfirst_date`x' "Date of first sex with partner `x'"
	label var daysfirstsex`x' "Days elapsed since first sex with partner `x'"

	drop  whenlast_daysago`x' whenlast_year`x' whenlast_month`x' whenfirst_daysago`x' whenfirst_month`x' whenfirst_year`x'
}



***** MORE TIDYING UP- SEX LAST YEAR


*Kisumu
if lower("$sitename")=="kisumu"{
gen sexlastyear2=0 if dayslastsex1>365 & dayslastsex1<. 
replace sexlastyear2=1 if dayslastsex1<366
recode sexlastyear2 .=9
replace sexlastyear=sexlastyear2
drop sexlastyear2
}


*sex last year
replace sexlastyear=0 if partners_lastyear==0 & (sexlastyear==9 |sexlastyear==.)
replace sexlastyear=1 if partners_life>0 & partners_life<999999 & (sexlastyear==9 |sexlastyear==.)
*partners last year (as for lifetime)
bys survey_round_name:egen minyr=min(partners_lastyear)
replace partners_lastyear=0 if sexlastyear==0 & partners_lastyear==999999 & minyr==0


**** make sure never sex are in the denom of sexlastyear
replace sexlastyear=0 if sexever==0 & sexlastyear==.

*and no sex last year......
replace partners_lastyear=0 if sexlastyear==0 & (partners_lastyear==. | partners_lastyear==999999)





**** WAS THIS A PARTNER IN LAST YEAR- MOSTLY WHAT IS RELEVANT to ascertain denominator for several variables
forvalues x=1/`maxphistnum' {
	gen was_partner`x'=1 if dayslastsex`x'<365.25
	label var was_partner`x' "This was a partner `x' in the year before the survey"
	** MANICALAND DOESN'T HAVE INFO ON WHO SO NEED TO TAG PARTNERS USING OTHER INFO
	replace was_partner`x'=1 if was_partner`x'==. & study_name==3 & cf_actual_week`x'<. & dayslastsex`x'<365.25

}
egen total_partners_in_history=rownonmiss(was_partner*)

tab partners_lastyear total_partners_in_history,m



*NUmbers of partners
gen morethan1=0 if sexlastyear<3 | sexever==0 & partners_lastyear<97
replace morethan1=1 if partners_lastyear>1 & partners_lastyear<97
label var morethan1 "More than 1 partner in the last year"

** recode lifetime partners
recode partners_life (0=0 "0") (1=1 "1") (2=2 "2") (3=3 "3") (4/6=4 "4-6") (7/15=5 "7-15") (15/max=6 "15+"),gen(partners_life_grp) label(partners_life_grp)
replace partners_life_grp=. if partners_life==999999
label var partners_life_grp "Lifetime partners, grouped"




*** TACKLE PARTNER LOOP AND SUMMARISE

gen spouse_total=0
label var spouse_total "Total number of spouses had sex with in last year"
gen regular_total=0
label var regular_total "Total number of reg partners had sex with in last year"
gen casual_total=0
label var casual_total "Total number of casual partners had sex with in last year"
gen high_risk_total=0
label var high_risk_total "Total number of high risk partners had sex with in last year"


/* MANICALAND AND ANYWHERE ELSE WITH REF PERIOD THAT IS LONGER THAN 1 YEAR, NEED TO MAKE AN EXTRA SET OF VARIABLES TO COVER 1YEAR+ BEFORE SURVEY
gen sexlast${phistref}years=0
label var sexlast${phistref}years "Reported sex in last ${phistref} year(s) in partner history"
replace sexlast${phistref}years=1 if who1<.
*/


*** condom use and contraception by type of partner- spouse or non-spousal/non-cohabiting
gen condom_last_sex_spouse=.
label var condom_last_sex_spouse "Condom used at last sex with (most recent) spouse"

gen condom_last_sex_noncohab=.
label var condom_last_sex_noncohab "Condom used at last sex with (most recent) non-cohab"


gen contra_last_sex_spouse=.
label var contra_last_sex_spouse "Modern method of contraception used at last sex with (most recent) spouse"
gen contra_last_sex_noncohab=.
label var contra_last_sex_noncohab "Modern method of contraception used at last sex with (most recent) non-cohab"

*** CONCURRENCY
*overlap any last year
gen overlap_any=.
label var overlap_any "Any time in last  year with more than 1 partner ongoing"
*overlap length last year
gen overlap_weeks=.
label var overlap_weeks "Total weeks in last reference period with more than 1 partner ongoing"
*gap any last year
gen none_any=.
label var none_any "Any time in last reference period with no partner ongoing"
*gap length last year
gen none_weeks=.
label var none_weeks "Total weeks in last reference period with no partner ongoing"


** NEW PARTNERS

gen new_spouse=.
label var new_spouse "Got a new spouse in last year"

gen new_noncohab=.
label var new_noncohab "Got a new non-cohabiting/non-spousal in last year"

gen num_new_partners=0
label var num_new_partners "Number of new partners in last year"

gen pagegrp=.
label define pagegrp 0 "Partner within 5 years of age" 1 "Partner 5+ years older/younger"  2 "Partner 10+ years older/younger" 3 "Age not known/not given" 4 "No partner in ref period" 9 "No data",modify
label values pagegrp pagegrp
label var pagegrp "Age gaps across all partners in last year"

gen pagegrp_nsp=.
label values pagegrp_nsp pagegrp
label var pagegrp_nsp "Any non-spousal partner 5+ older/younger in last year"

gen coital_freq_current=0
label var coital_freq_current "Frequency of sex with all ongoing partners, times per week"

gen coital_freq_current_sp=0
label var coital_freq_current_sp "Frequency of sex with current spouses, times per week"

gen coital_freq_current_nsp=0
label var coital_freq_current_nsp "Frequency of sex with current non-spouses, times per week"

label define new_partner 0 "No" 1 "Yes" 3 "Unknown",modify

label define pstatus 1 "Known negative" 2 "Known positive" 0 "Not known",modify
label define disclosed 0 "No disclosure" 1 "Some disclosure" 9 "Not reported",modify
**** LOOP THROUGH RESPONSES FOR EACH PARTNER


forvalues x=1/`maxphistnum' {

	*TYPE OF PARTNER
	replace spouse_total=spouse_total+1 if who`x'>=10 & who`x'<=12 & dayslastsex`x'<=365.25
	replace regular_total=regular_total+1 if who`x'>=21 & who`x'<=22 & dayslastsex`x'<=365.25
	replace casual_total=casual_total+1 if ((who`x'>=30 & who`x'<=39) | (who`x'>=60 & who`x'<=73)) & dayslastsex`x'<=365.25
	replace high_risk_total=high_risk_total+1 if who`x'>=40 & who`x'<=59 & dayslastsex`x'<=365.25

	** CONDOM USE 
	*Pick up this loop results for condom use at last sex if this is the most recent spouse
	replace condom_last_sex_spouse=condom_lastsex`x' if  who`x'>=10 & who`x'<=12 & condom_last_sex_spouse==. & dayslastsex`x'<=365.25
	*Pick up this loop results for condmo use at last sex if this is the most recent non-cohabiting partner 
	replace condom_last_sex_noncohab=condom_lastsex`x' if  who`x'>19 & who`x'<=88 & condom_last_sex_noncohab==. & dayslastsex`x'<=365.25

	*Pick up this loop results for frequency of condom use if this is the a spouse
	gen condom_freq_spouse`x'=condom_freq`x' if  who`x'>=10 & who`x'<=12  & dayslastsex`x'<=365.25
	*Pick up this loop results for frequency of condom use if this is the a non-cohabiting partner
	gen condom_freq_noncohab`x'=condom_freq`x' if  who`x'>19 & who`x'<=88  & dayslastsex`x'<=365.25


	*** CONTRACEPTION
	*Pick up this loop results for contraception at last sex if this is the most recent spouse
	replace contra_last_sex_spouse=contra_lastsex`x' if contra_lastsex`x'~=1 &  who`x'>=10 & who`x'<=12 & contra_last_sex_spouse==.  & dayslastsex`x'<=365.25
	replace contra_last_sex_spouse=1 if contra_lastsex`x'==1 &  who`x'>=10 & who`x'<=12 & contra_last_sex_spouse==. & (contramethod_lastsex`x'<7 | contramethod_lastsex`x'==9 | contramethod_lastsex`x'==14) & dayslastsex`x'<=365.25

	*Pick up this loop results for contraception at last sex if this is the most recent non-cohabiting partner
	replace contra_last_sex_noncohab=contra_lastsex`x' if contra_lastsex`x'~=1 &  who`x'>19 & who`x'<88 & contra_last_sex_noncohab==.  & dayslastsex`x'<=365.25
	replace contra_last_sex_noncohab=1 if contra_lastsex`x'==1 &  who`x'>19 & who`x'<88 & contra_last_sex_noncohab==. & (contramethod_lastsex`x'<7 | contramethod_lastsex`x'==9 | contramethod_lastsex`x'==14) & dayslastsex`x'<=365.25

	*COITAL FREQUENCY with this partner, and cumulative summary variables
	gen pcoital_freq`x'=cf_actual_week`x' if cf_actual_week`x'<.
	replace  pcoital_freq`x'=cf_actual_month`x'/4 if pcoital_freq`x'==. & cf_actual_month`x'<.
	replace  pcoital_freq`x'=cf_actual_year`x'/52 if pcoital_freq`x'==. & cf_actual_year`x'<.
	label var pcoital_freq`x' "Weekly coital frequency with partner `x'"

	** for current partnerships, update the summary coital frequency variables
	*all types of partner
	*1st July- added in the & pcoital_freq`x'<96 because some sites have left in these codes and don't want them to count. 
	*have left for partner specific ones, as may decide to include a no answer category
	replace coital_freq_current= coital_freq_current + pcoital_freq`x' if ongoing`x'==1 & pcoital_freq`x'<96
	* spousal partners
	replace coital_freq_current_sp=coital_freq_current_sp + pcoital_freq`x' if ongoing`x'==1 & who`x'>=10 & who`x'<=12 
	*non-spousal partners
	replace coital_freq_current_nsp=coital_freq_current_nsp + pcoital_freq`x' if ongoing`x'==1 & who`x'>19 & who`x'<88


	*AGE GAPS
*this gap is 10+ years
	gen p_10_gap`x'=1 if abs(pexactage`x'-survey_age)>=10 & pexactage`x'<98 & dayslastsex`x'<=365.25 
	replace p_10_gap`x'=1 if ( page`x'==1 | page`x'==5) & dayslastsex`x'<=365.25 
	replace p_10_gap`x'=0 if (page`x'>=2 & page`x'<=4)  & dayslastsex`x'<=365.25 
	replace p_10_gap`x'=0 if abs(pexactage`x'-survey_age)<10 & pexactage`x'<98 & dayslastsex`x'<=365.25
	replace p_10_gap`x'=9 if page`x'>8 & pexactage`x'>97 & phist_asked_pexactage==1 & dayslastsex`x'<=365.25 
	replace p_10_gap`x'=9 if page`x'==9 & pexactage`x'>97 & phist_asked_pexactage~=1 & dayslastsex`x'<=365.25

*this gap is 5+ years
	gen p_5_gap`x'=1 if abs(pexactage`x'-survey_age)>=5 & pexactage`x'<98 & dayslastsex`x'<=365.25 
	replace p_5_gap`x'=1 if ( page`x'==1 | page`x'==2 | page`x'==4| page`x'==5) & dayslastsex`x'<=365.25 
	replace p_5_gap`x'=0 if (page`x'==3)  & dayslastsex`x'<=365.25 
	replace p_5_gap`x'=0 if abs(pexactage`x'-survey_age)<5 & pexactage`x'<98 & dayslastsex`x'<=365.25
	replace p_5_gap`x'=9 if page`x'>8 & pexactage`x'>97 & phist_asked_pexactage==1 & dayslastsex`x'<=365.25 
	replace p_5_gap`x'=9 if page`x'==9 & pexactage`x'>97 & phist_asked_pexactage~=1 & dayslastsex`x'<=365.25


	*** NEW PARTNER FLAG
	gen newp_flag`x'=0 if dayslastsex`x'<365.25
	replace newp_flag`x'=1 if daysfirstsex`x'<365.25
/*
	*Code 0 if partner within 5 years if age, and no previous partner was 5+ years older/younger
	replace pagegrp=0 if page`x'==3 & pagegrp==. & dayslastsex`x'<=365.25 
	replace pagegrp=0 if abs(pexactage`x'-survey_age)<5 & pagegrp==. & dayslastsex`x'<=365.25 

	*Code 1 if partner had big age gap
	replace pagegrp=1 if page`x'<3 | ( page`x'>3 & page`x'<=5) & dayslastsex`x'<=365.25 
	replace pagegrp=1 if abs(pexactage`x'-survey_age)>=5 & pexactage`x'<98 & pagegrp==. & dayslastsex`x'<=365.25 

	*code 2 if nothing known about this or previous partners' ages- if any partners ages unknown 
	*then make overall either 1 or unknown- not 0 for 'same age only'
	replace pagegrp=2 if (pagegrp==.| pagegrp==0) & pexactage`x'>=98 & dayslastsex`x'<=365.25  & phist_asked_pexactage==1
	replace pagegrp=2 if (pagegrp==.| pagegrp==0) & pexactage`x'>98 & study_name==3 & phist_asked_pexactage==1
	replace pagegrp=2 if (pagegrp==.| pagegrp==0) & page`x'>5 & page`x'<=10 & dayslastsex`x'<=365.25 
	replace pagegrp=2 if pagegrp==. & phist_asked_page==0 
	*code 3 if no partners were reported in the partner history
	replace pagegrp=3 if pagegrp==. & total_partners_in_history==0

	*AGE GAPS WITH NON-SPOUSAL PARTNERS
	*Code 0 if partner within 5 years if age, and no previous partner was 5+ years older/younger
	replace pagegrp_nsp=0 if page`x'==3 & pagegrp_nsp==. & dayslastsex`x'<=365.25  & int(who`x'/10~=1) & who`x'<97
	replace pagegrp_nsp=0 if abs(pexactage`x'-survey_age)<5 & pagegrp_nsp==. & dayslastsex`x'<=365.25  & int(who`x'/10~=1) & who`x'<97

	*Code 1 if partner had big age gap
	replace pagegrp_nsp=1 if page`x'<3 | ( page`x'>3 & page`x'<=5) & dayslastsex`x'<=365.25    & int(who`x'/10~=1) & who`x'<97
	replace pagegrp_nsp=1 if abs(pexactage`x'-survey_age)>=5 & pexactage`x'<98 & pagegrp_nsp==. & dayslastsex`x'<=365.25  & int(who`x'/10~=1) & who`x'<97

	*code 2 if nothing known about this or previous partners' ages- if any partners ages unknown 
	*then make overall either 1 or unknown- not 0 for 'same age only'
	replace pagegrp_nsp=2 if (pagegrp_nsp==.| pagegrp_nsp==0) & pexactage`x'>98 & dayslastsex`x'<=365.25 & phist_asked_pexactage==1
	replace pagegrp_nsp=2 if (pagegrp_nsp==.| pagegrp_nsp==0) & pexactage`x'>98 & study_name==3  & phist_asked_pexactage==1
	replace pagegrp_nsp=2 if (pagegrp_nsp==.| pagegrp_nsp==0) & page`x'>5 & page`x'<=10 & dayslastsex`x'<=365.25    & int(who`x'/10~=1) & who`x'<97
	replace pagegrp_nsp=2 if pagegrp_nsp==. & phist_asked_page==0
*/

	*CHARACTERISTICS OF PARTNERS
	** little point in recoding residence
	** marital status- most useful for partnerships analysis, so don't need a summary
	** HIV  disclosure- prob too much variation between sites. could make a summary here to indicate those who have had partners of various statuses
	** gifts, drugs, alcohol use, circumcision status partners, could all be included here if data.

	** HIV STATUS OF PARTNER IN LAST YEAR
	gen pstatus`x'=0 if (phiv_lastsex`x'==0 & dayslastsex`x'<365.25) | (phiv_firstsex`x'==0 & daysfirstsex`x'<365.25)
	replace pstatus`x'=1 if (phiv_lastsex`x'==1 & dayslastsex`x'<365.25) | (phiv_firstsex`x'==1 & daysfirstsex`x'<365.25)
	replace pstatus`x'=2 if (phiv_lastsex`x'==2 & dayslastsex`x'<365.25) | (phiv_firstsex`x'==2 & daysfirstsex`x'<365.25)
	label values pstatus`x' pstatus
	label var pstatus`x' "Respondent's knowledge of partner`x''s HIV status"

	** DISCLOSURE OF STATUS IN LAST YEAR
	*no disclosure from either partner, or only have info on one partner
	gen disclosed`x'=0 if (hiv_disc_r`x'==0 & hiv_disc_p`x'==0) | (hiv_disc_r`x'==0 & hiv_disc_p`x'>=9) | (hiv_disc_r`x'>=9 & hiv_disc_p`x'==0)
	*either or both disclosed
	replace disclosed`x'=1 if hiv_disc_r`x'==1 | hiv_disc_p`x'==1
	*don't know
	replace disclosed`x'=9 if hiv_disc_r`x'==9 & hiv_disc_p`x'==9
	label values disclosed`x' disclosed
	label var disclosed`x' "Any disclosure of HIV status with partner `x'"

	/* too complicated
	** NEW PARTNERS IN THE LAST YEAR
	* 0=no 1=yes  3=info missing 4=not collected
	replace new_partner_loop=1 if daysfirstsex`x'<365.25
	replace new_partner_loop=0 if daysfirstsex`x'>=365.25 & daysfirstsex`x'<. & new_partner_loop~=1
	*last sex more than a year ago, first sex not given- mainly Kisesa, Emma added June 2017, also Masaka
	replace new_partner_loop=0 if daysfirstsex`x'==. & dayslastsex`x'>=365.25 & dayslastsex`x'<.  & new_partner_loop~=1
	*In Masaka, first sex wasn't collected in loop if last sex was more than a year ago


	* don't know first sex date and don't already know this person had a new partner
	replace new_partner_loop=3 if daysfirstsex`x'==. & dayslastsex`x'<365.25 & new_partner_loop~=1 

	replace new_partner_loop=3 if daysfirstsex`x'==. & dayslastsex`x'==. & new_partner_loop~=1  & who`x'<88

	replace new_partner_loop=4 if daysfirstsex`x'==.  & phist_asked_dates==0
	*replace new_partner_loop=4 if study_name==9
*/
* also too complicated but don't want to break do file later on so leaving in
	replace new_spouse=1 if daysfirstsex`x'<365.25 & who`x'==1
	replace new_spouse=0 if daysfirstsex`x'>=365.25 & daysfirstsex`x'<.& new_spouse~=1  & who`x'==1

	replace new_noncohab=1 if daysfirstsex`x'<365.25 & who`x'>1 & who`x'<88
	replace new_noncohab=0 if daysfirstsex`x'>=365.25 & daysfirstsex`x'<. & new_noncohab~=1  & who`x'>1 & who`x'<88


	replace num_new_partners=num_new_partners+1 if daysfirstsex`x'<365.25

	} /*close partner loop forvalues x=1/`maxphistnum' */

egen n_newp_flags=rownonmiss(newp_flag*)
egen new_partner_loop=rowtotal(newp_flag*)
recode new_partner_loop 1/max=1
replace new_partner_loop=3 if n_newp_flags==0 & phist_asked_dates==1   & sexlastyear==1
replace new_partner_loop=3 if n_newp_flags<partners_with_any_info
replace new_partner_loop=4 if n_newp_flags==0 & phist_asked_dates==0  
replace new_partner_loop=3 if n_newp_flags==0 & sexlastyear>1 & sexlastyear<100
label define new_partner 0 "No new partners in last year" 1 "New partner in last year" 3 "Information missing" 4 "Not collected",modify
label values new_partner_loop new_partner
label var new_partner_loop "Got a new partner in last year-from loop"



label values new_partner new_partner
label var new_partner "Acquired a new partner in the 12m before survey"


*PARTNER AGE GROUP SUMMARY

*how many with 10+ year gap
egen page10gap=anycount(p_10_gap*),val(1)
recode page10gap 1/max=1
*how many with 5+ year gap
egen page5gap=anycount(p_5_gap*),val(1)
recode page5gap 1/max=1
*how many do we not know about
egen pagedkgap=anycount(p_10_gap*),val(9) /*should be the same for p_10_gap and p_5_gap */
recode pagedkgap 1/max=1

*SUMMARISE AGE GAPS ACROSS ALL PARTNERS
** no partners in last year in phist and said none in last year
replace pagegrp=4 if total_partners_in_history==0 & partners_lastyear==0 & phist_asked_page==1
*no age gaps
replace pagegrp=0 if total_partners_in_history>0 & page5gap==0 
*5 yr age gaps
replace pagegrp=1 if total_partners_in_history>0 & page5gap==1 
*10 yr age gaps
replace pagegrp=2 if total_partners_in_history>0 & page10gap==1 
* dk ages, 
replace pagegrp=3 if total_partners_in_history>0 & pagedkgap==1 
*no data- didn't report partners in phist
replace pagegrp=9 if total_partners_in_history==0 & pagegrp==.
*no data- on page data collected
replace pagegrp=9 if phist_asked_page~=1

*TOTAL NUMBER OF PARTNERSHIPS THAT HAVE ENDED IN last year

**** WAS THIS A PARTNER IN LAST YEAR- MOSTLY WHAT IS RELEVANT to ascertain denominator for several variables
forvalues x=1/`maxphistnum' {
	gen ended_partner`x'=ongoing`x' if dayslastsex`x'<365.25 
	label var ended_partner`x' "Ended partner `x' last sex in the year before the survey"

}

egen n_lost=anycount(ended_partner*),val(0)
egen n_still=anycount(ended_partner*),val(1)
egen n_ongoing_answers=rowtotal(n_lost n_still)

replace n_lost=9 if n_ongoing_answers<total_partners_in_history
replace n_lost=9 if phist_asked==0

bys survey_round_name:egen tmpminlost=min(ongoing1)

replace n_lost=9 if tmpminlost==.
replace n_lost=9 if n_lost==0 & sexlastyear==9 & n_still==0


gen anylost=0 if n_lost==0
replace anylost=1 if n_lost>0 & n_lost<9
replace anylost=9 if n_lost==9
label var anylost "Reported any partnerships that ended in the partnership history"
label define anylost 0 "No partnerships ended" 1 "Partnerships ended" 9 "No data",modify
label values anylost anylost
stop 
***************** ADD DISCLOSURE AND PARTNERS STATUS SUMMARY HERE- LIKE FOR AGE GROUPS
*BUT FIRST NEED TO FIX KISUMU DATA- SOME SURVEY ROUNDS HAVE NO DON'T KNOWS- LOOKS LIKE A FILTER HAS BEEN MISSED IN THE SPEC PREP




*** SOME SITES DIRECTLY COLLECT NUMBER OF PARTNERS IN THE LAST MONTH.
*IF NOT COLLECTED, WORK OUT FROM PARTNER LOOP 
cap summ partners_lastmonth
*partners_lastmonth exists but is empty
if _rc==0 {
if r(N)==0 {
	recode partners_lastmonth .=0
	forvalues x=1/`maxphistnum' {
		replace partners_lastmonth=partners_lastmonth+1 if dayslastsex`x'<=30.25
	}
} /*close r(N) if */
} /*close _rc if */
*partners_lastmonth doesn't exist
else  {
gen partners_lastmonth=0
	forvalues x=1/`maxphistnum' {
		replace partners_lastmonth=partners_lastmonth+1 if dayslastsex`x'<=30.25
	}
} /*close else */

*** FIX SEX LAST YEAR - 
*MANICALAND: SEX LAST YEAR COMES FROM # PARTNERS IN LAST YEAR AND THERE WAS NO SKIP- SUBSTANTIAL NOS REPORTED ON PARTNERS IN THE LAST YEAR AFTER SAYING 0
replace sexlastyear=1 if sexlastyear==0 & (sexlastmonth==1 | newpartners_lastyear>0 & newpartners_lastyear<999999 | new_partner_loop==1) & study_name==3
*Rakai -few stragglers who reported in partner history
replace sexlastyear=1 if sexlastyear==0 & ( new_partner==1) & study_name==5



gen active_last_year=sexlastyear
replace active_last_year=0 if sexever==0 & (active_last_year==. | active_last_year==9)
replace active_last_year=1 if dayslastsex1<=365.25
label var active_last_year "Had sex in last year, denom everyone"
label values active_last_year yesno



*put everyone in these denoms, even if sexual behaviour data is missing, will flag people with incomplete data later on
gen spouse=0 if sexlastyear<9 & phist_asked_who==1
label var spouse "Had sex with a spouse in last reference period"
replace spouse=1 if spouse_total>0 & spouse_total<.

gen regular=0 if sexlastyear<9  & phist_asked_who==1
label var regular "Had sex with a regular partner in last reference period"
replace regular=1 if regular_total>0 & regular_total<.

gen casual=0 if sexlastyear<9  & phist_asked_who==1
label var casual "Had sex with a casual partner in last reference period"
replace casual=1 if casual_total>0 & casual_total<.

gen high_risk=0 if sexlastyear<9  & phist_asked_who==1
label var high_risk "Had sex with a high_risk partner in last reference period"
replace high_risk=1 if high_risk_total>0 & high_risk_total<.


bys survey_round_name : egen temp_spouse_max=max(spouse)
bys survey_round_name : egen temp_casual_max=max(casual)
bys survey_round_name : egen temp_regular_max=max(regular)
bys survey_round_name : egen temp_high_risk_max=max(high_risk)

*some surveys have nobody reporting in these categories
replace spouse=9 if temp_spouse_max==0
replace casual=9 if temp_casual_max==0
replace regular=9 if temp_regular_max==0
replace high_risk=9 if temp_high_risk_max==0

*surveys which didn't collect who in phist
replace spouse=9 if phist_asked_who==0
replace casual=9 if phist_asked_who==0
replace regular=9 if phist_asked_who==0
replace high_risk=9 if phist_asked_who==0

*** FIX KISUMU HBTC1 - LOADS NOT ASKED PHIST, NOT CLEAR WHY
replace spouse=9 if spouse==. & study_name==8 & survey_round_name=="HBTC 1"
replace casual=9 if casual==. & study_name==8 & survey_round_name=="HBTC 1"
replace regular=9 if regular==. & study_name==8 & survey_round_name=="HBTC 1"
replace high_risk=9 if high_risk==. & study_name==8 & survey_round_name=="HBTC 1"


**** NEW PARTNER: INCLUDE INFORMATION FROM DIRECT QUESTION  ****
gen new_partner=newpartners_lastyear if study_name==1 | study_name==3
recode new_partner 0=0 1/900=1 999999=3 
replace new_partner=new_partner_loop if new_partner_loop<. & (new_partner==. ) & ( study_name==1 | study_name==3)
*no new partner reported in direct question but some identified in loop 
replace new_partner=1 if new_partner_loop==1  & (new_partner==0 ) & ( study_name==1 | study_name==3)

replace new_partner=1 if new_partner_loop==1 & (new_partner==. | new_partner==0) & ( study_name==1 | study_name==3)
replace new_partner=new_partner_loop if (study_name==2 | study_name==4 | study_name==5 | study_name==6 | study_name==8 | study_name==9  )
replace  new_partner=0 if new_partner==. & sexlastyear==0 & study_name~=9

bys survey_round_name : egen temp_newp=total(new_partner) if new_partner==1
bys survey_round_name: egen temp_new_p_max=max(temp_newp)
replace new_partner=3 if temp_newp==. & phist_asked_dates==0

*** CONDOM USE SUMMARY ACROSS ALL PARTNERS
*take the minimum value- ie. if more than one partner (of each type) take the least consistent use.
egen condom_freq_all_spouse=rowmin(condom_freq_spouse*)
label var condom_freq_all_spouse "Frequency of condom use with all spouses during last year"
label values condom_freq_all_spouse condomfreq
egen condom_freq_all_noncohab=rowmin(condom_freq_noncohab*)
label var condom_freq_all_noncohab "Frequency of condom use with all non-cohabiting partners during last year"
label values condom_freq_all_noncohab condomfreq
*across all partners - can't use egen and rowmin here as will include the summary variables- though it would be OK as they just duplicate info from elsewhere
egen condom_freq_all_=rowmin(condom_freq*)
label var condom_freq_all_ "Frequency of condom use with all partners during last year"
label values condom_freq_all_ condomfreq



* SUMMARISE CONDOM USE IN LAST YEAR ACROSS ALL PARTNERS

gen tmpclast=0
gen tmp_ptnrs=0
gen tmp_ever=0
gen tmp_always=0
gen tmp_miss=0
forvalues i=1/`maxphistnum' {
replace tmpclast=tmpclast+1 if condom_lastsex`i'==1 & dayslastsex`i'<366
replace tmp_ptnrs=tmp_ptnrs+1 if dayslastsex`i'<366 |  who`i'<.
replace tmp_ever=tmp_ever+1 if (condom_freq`i'==1 | condom_freq`i'==2) & dayslastsex`i'<366
replace tmp_always=tmp_always+1 if condom_freq`i'==2 & dayslastsex`i'<366
replace tmp_miss=tmp_miss+1 if condom_lastsex`i'==. & condom_freq`i'==.  & dayslastsex`i'<366
}
replace tmp_ptnrs=7 if partners_lastyear>6 & partners_lastyear<88

label define clastyr_summary 0 "No partners" 1 "No condom use" 2 "Some condom use (sometimes or some partners)" 3 "Complete condom use (all partners=always)" 4 "Not sure- 6+ptnrs or missing data" 9 "Not asked",modify
gen clastyr_summary=0 if tmp_ptnrs==0 
replace clastyr_summary=1 if tmp_ptnrs>0 & tmp_ptnrs<. & tmp_ever==0 & tmpclast==0
replace clastyr_summary=2 if tmp_ptnrs>0 & tmp_ptnrs<. & tmp_ever>=1  | tmpclast>=1
replace clastyr_summary=3 if tmp_ptnrs>0 & tmp_ptnrs<. & tmp_always==tmp_ptnrs & tmpclast==tmp_ptnrs
replace clastyr_summary=4 if tmp_ptnrs==7
replace clastyr_summary=4 if tmp_miss>0
replace clastyr_summary=9 if clastyr_summary==0 & phist_asked==0
replace clastyr_summary=0 if sexlastyear==0  & phist_asked==1 
label values clastyr clastyr_summary
*replace clastyr=. if survey_round_name=="Sero5"
label var clastyr "Condom use over last year, all partners"

*** *SUMMARISE THE TYPES OF PARTNERSHIPS OVER THE LAST YEAR
gen sumlastyear=.
label define sumlastyear 0 "No partners" 1 "One old partner" 2 "One new partner" 3 "one partner dk duration" 4 ">1 partner, none new" 5 ">1 partner, 1+ new" 6 ">1 partner, dk new" 9 "No data",modify

replace sumlastyear=0 if sexlastyear==0

replace sumlastyear=1 if morethan1==0 & sexlastyear==1 & new_partner==0
replace sumlastyear=2 if morethan1==0 & sexlastyear==1 & new_partner==1
replace sumlastyear=3 if morethan1==0 & sexlastyear==1 & new_partner>2 & new_partner<. 

replace sumlastyear=4 if morethan1==1 & sexlastyear==1 & new_partner==0
replace sumlastyear=5 if morethan1==1 & sexlastyear==1 & new_partner==1
replace sumlastyear=6 if morethan1==1 & sexlastyear==1 & new_partner>2 & new_partner<. 

replace sumlastyear=9 if sumlastyear==.  & (morethan1==9 | (sexlastyear>2 ) | (new_partner>2  ) )


label values sumlastyear sumlastyear

** NO CHANGE IN PARTNERS


** CONCURRENCY **
*  ? use spell_pstat? seems silly to waste it



*** Need to order surveys by date
*take the mean interview date for each round to make an ordered categorical variable
bys survey_round_name:egen mean_survey_date=mean(interview_date)
 bys survey_round_name:egen min_survey_date=pctile(interview_date),p(10)
label var min_survey_date "10th pctile of interview date to count back grey area from"
*want that coded 1 to x.
sort mean_survey_date
egen survey_sequence=group(mean_survey_date) 

drop  mean_survey_date


***** TIDY UP MISSING CODES
recode partners_lastyear 999999=.
recode partners_lastyear -9=.

recode partners_life 999999=.

*** label variables 

label var total_partners_in_history "Total number of partners reported in partner history"




****** LOOPS
forvalues x=1/`maxphistnum' {

label var who`x' "Relationship to partner `x'"
label values who`x' who

label var page`x' "Age of partner `x'"
label values page`x' page

label var pmstat`x' "Marital status of partner `x'"
label values pmstat`x' pmstat

label var phiv_lastsex`x' "HIV status of partner `x' at last sex"
label values phiv_lastsex`x' phiv
label var phiv_firstsex`x' "HIV status of partner `x' at first sex"
label values phiv_firstsex`x' phiv

label var condom_lastsex`x' "Used a condom at last sex with partner `x'"
label values condom_lastsex`x' yesnodk
label var condom_firstsex`x' "Used a condom at first sex with partner `x'"
label values condom_firstsex`x' yesnodk

label var condom_freq`x' "Consistency of condom use with partner `x'"
label values condom_freq`x' condomfreq

label var contra_lastsex`x' "Contraception used at last sex with partner `x'"
label values contra_lastsex`x' yesnodk
label var contramethod_lastsex`x' "Method of contraception used at last sex with partner `x'"
label values contramethod_lastsex`x' contramethod

label var contra_firstsex`x' "Contraception used at first sex with partner `x'"
label values contra_firstsex`x' yesnodk
label var contramethod_firstsex`x' "Method of contraception used at first sex with partner `x'"
*label values contramethod_firstsex`x' contramethod


label var ongoing`x' "Relationship ongoing with partner `x'"
label values ongoing`x' yesnodk

label var presidence`x' "Residence of partner `x'"

label var hiv_disc_r`x' "whether partner `x' disclosed their HIV status to the respondent"

label var hiv_disc_p`x' "whether respondent disclosed their HIV status to the partner `x'"

}

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


char _dta[thisid] "`id'"


** attach a note describing provenance to each NEW variable- spec variables already have a [source]
qui desc ,varlist sh
foreach v in `r(varlist)' {
local source:char `v'[source]
*if this is empty then
if "`source'"=="" {
char `v'[source] "`saves'"

char `v'[id] "`id'"

} /*close if */

} /*close var loop */

*===================================================================================
*  SAVE THE DATA AND CREATE A DOCUMENT WITH DATA INFO
*===================================================================================

save ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"





*** 
*===================================================================================
*  NOW CREATE WIDE FILE
*===================================================================================

use ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_${sitename},clear
*
*Sites with a partner history longer than 1 year will need more sets of variables to account for the >1 year before survey 

*MAKE A DATE AT THE START OF THE PARTNER HISTORY REFERENCE PERIOD
*no- for now am making it one year before as think Manicaland only site that has >1 year
gen  merge_date=interview_date-(1*365.25)
format merge_date %td

#delimit ;
keep idno interview_date survey_round_name sexever sexlastyear study_name 
 spouse_total regular_total casual_total high_risk_total condom_last_sex_spouse 
condom_last_sex_noncohab total_partners_in_history contra_last_sex_noncohab 
contra_last_sex_spouse coital_freq_current* pagegrp pagegrp_nsp
morethan1 spouse regular casual high_risk condom_freq_all_spouse 
condom_freq_all_noncohab  condom_freq_all_  num_new_partners new_partner  
new_spouse new_noncohab  merge_date partners_lastyear partners_life partners_life_grp survey_sequence 
circumcised age_at_circ clastyr_summary sumlastyear marever anylost ;


reshape wide sexever sexlastyear spouse_total regular_total casual_total high_risk_total condom_last_sex_spouse 
condom_last_sex_noncohab condom_freq_all_spouse condom_freq_all_noncohab  contra_last_sex_spouse 
contra_last_sex_noncohab  total_partners_in_history pagegrp pagegrp_nsp coital_freq_current 
coital_freq_current_sp coital_freq_current_nsp
morethan1 spouse regular casual high_risk  circumcised age_at_circ  
 condom_freq_all_  num_new_partners new_partner new_spouse new_noncohab 
 partners_lastyear partners_life partners_life_grp  clastyr_summary sumlastyear marever anylost merge_date interview_date survey_round_name,i(idno) j(survey_sequence) ;

 /* additional reshape here for sites with retrospective ref period longer than 1 year
 a, b, c, 
 */
 #delimit cr
 
*===================================================================================
*  SAVE THE DATA AND CREATE A DOCUMENT WITH DATA INFO
*===================================================================================

save ${alphapath}/ALPHA/prepared_data/${sitename}/sexual_behaviour_recoded_wide_${sitename},replace

*document the data
local oldcd=c(pwd)
cd ${alphapath}/ALPHA/prepared_data_documentation/
cap mkdir ${sitename}
cd ${sitename}
do ${alphapath}/ALPHA/dofiles/document/Make_dataset_dictionary_with_char.do
cd "`oldcd'"
























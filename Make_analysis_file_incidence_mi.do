

********** PREPARE THE IMPUTATIONS
*global sitelist="Agincourt Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude"
*global sitelist="Masaka"
global nimp=70

*foreach site in $sitelist {
*global sitename="`site'"


	**** GENERATE THE M0 FILE WITH THE SEROCONVERSION DATE SET TO MISSING (SO IT CAN BE IMPUTED)
	*STATA'S MI COMMANDS REQUIRE ONE DATASET WITH THE VARIABLE TO BE IMPUTED SET TO MISSING
	use  "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/incidence_ready_midpoint_${sitename}.dta", clear
	stdes

	replace end_ep_date=. if serocon_fail==1
	recode serocon_fail 1=.
	replace sero_conv_date=.

	bys study_name idno (start_ep_date):gen ep_num=_n
	gen persontag=.
	gen random=.


	cap mkdir "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data"
	stdes
	qui compress
	label data "ALPHA incidence analysis data for ${sitename}, imputation 0, only for use by Stata's MI commands"
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_mi_${sitename}_0",replace


	*** GENERATE LIST OF IDNO WITH WHICH TO GENERAGE A DATASET OF RANDOM NUMBERS FOR EACH PERSON
	*this is important because we need a number for each person not each record in the dataset
	keep study_name idno
	contract study_name idno
	drop _freq

	forvalues x=1/$nimp {
		set seed `x'
		gen double random`x'=uniform()
		}
	save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/random_numbers_${sitename}",replace






	**** generate the mi files with the seroconversion date randomly allocated within the interval
	*EACH DATASET CONTAINS ONE IMPUTATION OF THE SEROCONVERSION DATE, SO WE END UP WITH AS MANY DATASETS AS IMPUTATIONS
	*THE FILE NAMING IS IMPORTANT AND MUST FOLLOW A PATTERN WITH ONLY THE IMPUTATION NUMBER CHANGING FOR EACH FILE.
	quietly {
	forvalues x=1/$nimp {
		set seed `x'
		noi di "Imputation `x'"
		use "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/incidence_ready_midpoint_${sitename}.dta",clear

		merge m:1 study_name idno using "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/random_numbers_${sitename}"

		cap drop sero_conv_date
		gen double sero_conv_date=((first_pos_date-last_neg_date)*random`x')+last_neg_date if  first_pos_date<. & last_neg_date<. & first_pos_date>last_neg_date
		replace sero_conv_date = ((first_pos_date - fifteen)*random`x')+fifteen if tested_first_opportunity==1


		**count total number of people who were tested negative then later positive
		stdes if first_pos_date<. & last_neg_date<. & first_pos_date>last_neg_date
		stdes if sero_conv_date<.


		format %td last_neg_date first_pos_date sero_conv_date start_ep_date end_ep_date

		*put as not a failure if not resident at time
		replace serocon_fail=0
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
		*stset end_ep_date,fail(serocon_fail) id(idno) time0(start_ep_date) scale(365.25) origin(dob)
		stset end_ep_date,fail(serocon_fail) id(idno) time0(start_ep_date)  scale(365.25) origin(dob)
		replace _st=0 if start_ep_date>sero_conv_date & start_ep_date<.
		*noisily stdes



		bys study_name idno (start_ep_date):gen ep_num=_n


		*** SAVE FILE 
		label data "ALPHA incidence data for ${sitename},for multiple imputation- imputation `x'"
		drop random*
		qui compress
		save "${alphapath}/ALPHA\Incidence_ready_data/${sitename}/mi_data/incidence_ready_mi_${sitename}_`x'",replace

		} /* close imputations loop */

*	} /*close quietly*/ 

} /*close site loop */



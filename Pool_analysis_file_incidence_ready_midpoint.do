
cap mkdir ${alphapath}/ALPHA\Incidence_ready_data/pooled

local poolsites="Ifakara Karonga Kisesa Kisumu Manicaland Masaka Rakai uMkhanyakude"

quietly {
clear
local counter=1
foreach p in `poolsites' {
noi di "`p'"

append using ${alphapath}/ALPHA\Incidence_ready_data/`p'/incidence_ready_midpoint_`p'.dta,
}

}
rename idno idno_orig
gen double idno=study_name*1000000 + idno_orig

save ${alphapath}/ALPHA\Incidence_ready_data/pooled/incidence_ready_midpoint_pooled.dta,replace

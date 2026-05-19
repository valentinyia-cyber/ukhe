version 16.0
clear all
set more off

* ---------------------------------------------------------------
* Reduce HESA DTA file sizes.
*
* - Drops ref2021_institution_name where present.
* - Uses heprovider as the value label for ukprn, then drops heprovider.
* - Converts remaining string variables to numeric variables with value labels.
* - Compresses and saves each DTA in place.
* ---------------------------------------------------------------

local user = c(username)
local dta_dir "/Users/`user'/Dropbox/Akos/ukhe_data/hesa/dta"
local files : dir "`dta_dir'" files "*.dta"

local sort_1  "ukprn levelofstudy modeofstudy categorymarker category year"
local sort_6  "ukprn tuitionfeesandeducationcontracts v9 year"
local sort_7  "ukprn categorymarker category year"
local sort_8  "ukprn hesacostcentre academicdepartments activity year"
local sort_11 "ukprn contractmarker categorymarker category year"
local sort_12 "ukprn staffcosts unit year"
local sort_13 "ukprn categorymarker category year"
local sort_14 "ukprn kfiratiotitle year"
local sort_28 "ukprn levelofstudy modeofstudy regionofpermanentaddress countryofpermanentaddress year"

capture program drop encode_string_variables
program define encode_string_variables
    unab allvars : _all
    foreach v of local allvars {
        capture confirm string variable `v'
        if _rc {
            continue
        }

        local var_label : variable label `v'
        tempvar encoded source
        capture label drop `v'
        capture confirm strL variable `v'
        if !_rc {
            gen str244 `source' = substr(`v', 1, 244)
            encode `source', gen(`encoded') label(`v')
            drop `source'
        }
        else {
            encode `v', gen(`encoded') label(`v')
        }

        label variable `encoded' "`var_label'"
        order `encoded', after(`v')
        drop `v'
        rename `encoded' `v'
    }
end

capture program drop label_ukprn_from_heprovider
program define label_ukprn_from_heprovider
    capture confirm numeric variable ukprn
    if _rc {
        exit
    }

    capture confirm string variable heprovider
    if _rc {
        exit
    }

    preserve
    keep ukprn heprovider
    drop if missing(ukprn)
    drop if missing(heprovider)
    bysort ukprn (heprovider): keep if _n == 1
    sort ukprn

    quietly count
    local nproviders = r(N)
    forvalues i = 1/`r(N)' {
        local code`i' = ukprn[`i']
        local provider`i' = heprovider[`i']
        local provider`i' = subinstr(`"`provider`i''"', `"""', "'", .)
    }
    restore

    capture label drop ukprn_heprovider
    forvalues i = 1/`nproviders' {
        label define ukprn_heprovider `code`i'' `"`provider`i''"', add
    }
    label values ukprn ukprn_heprovider
    label variable ukprn "UKPRN (labelled by HE provider)"
    drop heprovider
end

foreach f of local files {
    local path "`dta_dir'/`f'"
    di as text "Reducing `path'"
    use "`path'", clear

    capture drop ref2021_institution_name
    label_ukprn_from_heprovider
    encode_string_variables

    local table_num = real(substr("`f'", 2, 2))
    local sort_vars "`sort_`table_num''"
    if "`sort_vars'" != "" {
        sort `sort_vars'
    }

    compress
    save "`path'", replace
    di as result "Saved reduced file: `path'"
}

di as text "Done. Reduced HESA DTA files are in `dta_dir'."

version 16.0
clear all
set more off

* ---------------------------------------------------------------
* REF 2021 THE-style replication tables
* - Institutional tables for Overall, Outputs, Impact, Environment
* - Excludes institutions with only one submitted UoA (THE main table rule)
* - GPA, raw research power, indexed research power (max=1000)
* - Market share reported for Overall table only
* ---------------------------------------------------------------

local url "https://results2021.ref.ac.uk/profiles/export-all"
local data_dir "/Users/user/Dropbox/Akos/ukhe_data/ref2021"
capture mkdir "`data_dir'"
local xlsx "`data_dir'/ref2021_results_all.xlsx"

copy "`url'" "`xlsx'", replace
import excel using "`xlsx'", sheet("Sheet1") clear

rename A ukprn
rename B institution_name
rename C institution_sort_order
rename D main_panel
rename E uoa_number
rename F uoa_name
rename G multiple_submission_letter
rename H multiple_submission_name
rename I joint_submission
rename J profile
rename K fte_submitted
rename L total_fte_joint_submission
rename M pct_eligible_staff_submitted
rename N pct_4star
rename O pct_3star
rename P pct_2star
rename Q pct_1star
rename R pct_unclassified

drop if ukprn == "Institution code (UKPRN)"
drop if missing(profile)

foreach v in ukprn institution_sort_order uoa_number fte_submitted total_fte_joint_submission {
    destring `v', replace ignore(",") force
}
foreach v in pct_eligible_staff_submitted pct_4star pct_3star pct_2star pct_1star pct_unclassified {
    destring `v', replace ignore(",%") force
}

keep if inlist(profile, "Overall", "Outputs", "Impact", "Environment")
keep if !missing(uoa_number) & !missing(fte_submitted)

tempfile base
save "`base'", replace

foreach p in Overall Outputs Impact Environment {
    use "`base'", clear
    keep if profile == "`p'"

    * Submission-level metrics
    gen double gpa_submission = (4*pct_4star + 3*pct_3star + 2*pct_2star + pct_1star) / 100
    gen double research_power_submission = gpa_submission * fte_submitted

    * THE market-share proxy: QR-style quality-weighted volume
    gen double qr_volume_submission = ((4*pct_4star) + pct_3star) / 100 * fte_submitted

    * Weighted star shares for institution-level profile display
    gen double w4 = pct_4star * fte_submitted
    gen double w3 = pct_3star * fte_submitted
    gen double w2 = pct_2star * fte_submitted
    gen double w1 = pct_1star * fte_submitted
    gen double wu = pct_unclassified * fte_submitted

    collapse (count) n_uoas=uoa_number ///
             (sum) total_fte_submitted=fte_submitted research_power_raw=research_power_submission ///
                   qr_volume=qr_volume_submission w4 w3 w2 w1 wu, ///
             by(ukprn institution_name)

    * THE main-table rule: exclude specialist institutions with only one UoA
    drop if n_uoas == 1

    gen double gpa = research_power_raw / total_fte_submitted

    gen double pct_4star_inst = w4 / total_fte_submitted
    gen double pct_3star_inst = w3 / total_fte_submitted
    gen double pct_2star_inst = w2 / total_fte_submitted
    gen double pct_1star_inst = w1 / total_fte_submitted
    gen double pct_unclassified_inst = wu / total_fte_submitted

    egen double max_power = max(research_power_raw)
    gen double research_power_indexed = 1000 * research_power_raw / max_power

    egen double total_qr_volume = total(qr_volume)
    gen double market_share_pct = 100 * qr_volume / total_qr_volume

    * Competition ranking (1,2,2,4...) with GPA ties at 2 d.p.
    gen double gpa_rank_key = round(gpa, 0.01)
    egen long gpa_rank = rank(-gpa_rank_key), track
    egen long rp_rank = rank(-research_power_indexed), track

    drop gpa_rank_key max_power total_qr_volume w4 w3 w2 w1 wu

    local p_lower = lower("`p'")
    local out_csv "`data_dir'/ref2021_the_`p_lower'_table.csv"
    local out_dta "`data_dir'/ref2021_the_`p_lower'_table.dta"

    if "`p'" != "Overall" {
        drop market_share_pct
    }

    order gpa_rank rp_rank ukprn institution_name n_uoas total_fte_submitted gpa ///
          research_power_raw research_power_indexed pct_4star_inst pct_3star_inst ///
          pct_2star_inst pct_1star_inst pct_unclassified_inst

    if "`p'" == "Overall" {
        order market_share_pct, last
    }

    sort gpa_rank rp_rank institution_name
    export delimited using "`out_csv'", replace
    save "`out_dta'", replace

    di as text "Created: `out_csv' and `out_dta'"
}

di as text "Done. THE-style replication tables created for Overall/Outputs/Impact/Environment."

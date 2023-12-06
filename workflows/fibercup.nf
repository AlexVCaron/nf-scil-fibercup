/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowFibercup.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DENOISING_MPPCA } from "../modules/nf-scil/denoising/mppca/main.nf"
include { UTILS_EXTRACTB0 } from "../modules/nf-scil/utils/extractb0/main.nf"
include { BETCROP_FSLBETCROP } from "../modules/nf-scil/betcrop/fslbetcrop/main.nf"
include { PREPROC_N4 } from "../modules/nf-scil/preproc/n4/main.nf"
include { RECONST_DTIMETRICS } from "../modules/nf-scil/reconst/dtimetrics/main.nf"
include { RECONST_FRF } from "../modules/nf-scil/reconst/frf/main.nf"
include { RECONST_FODF } from "../modules/nf-scil/reconst/fodf/main.nf"
//include { TRACKING_LOCALTRACKING } from "../modules/nf-scil/tracking/localtracking/main.nf"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FIBERCUP {

    ch_versions = Channel.empty()
    ch_dwi = Channel.empty()
    ch_bvec = Channel.empty()
    ch_bval = Channel.empty()
    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input)
    )
    ch_dwi = ch_versions.mix(INPUT_CHECK.out.dwi)
    ch_bval = ch_versions.mix(INPUT_CHECK.out.bval)
    ch_bvec = ch_versions.mix(INPUT_CHECK.out.bvec)

    // ** Denoising ** //
    DENOISING_MPPCA(ch_dwi)

    // ** Extract b0 ** //
    b0_channel = DENOISING_MPPCA.out.image
        .join(ch_bval)
        .join(ch_bvec)
    UTILS_EXTRACTB0(b0_channel)

        // ** Bet ** //
    bet_channel = DENOISING_MPPCA.out.image
        .join(ch_bval)
        .join(ch_bvec)
    BETCROP_FSLBETCROP(bet_channel)

    // ** N4 ** //
    n4_channel = BETCROP_FSLBETCROP.out.dwi
        .join(UTILS_EXTRACTB0.out.b0)
        .join(BETCROP_FSLBETCROP.out.mask)
    PREPROC_N4(n4_channel)

    // ** DTI ** //
    dti_channel = PREPROC_N4.out.dwi
        .join(ch_bval)
        .join(ch_bvec)
        .join(BETCROP_FSLBETCROP.out.mask)
    RECONST_DTIMETRICS(dti_channel)

    // ** FRF ** //
    frf_channel = PREPROC_N4.out.dwi
        .join(ch_bval)
        .join(ch_bvec)
        .join(BETCROP_FSLBETCROP.out.mask)
    RECONST_FRF(frf_channel)

    // ** FODF ** //
    fodf_channel = PREPROC_N4.out.dwi
        .join(ch_bval)
        .join(ch_bvec)
        .join(BETCROP_FSLBETCROP.out.mask)
        .join(RECONST_DTIMETRICS.out.fa)
        .join(RECONST_DTIMETRICS.out.md)
        .join(RECONST_FRF.out.frf)
    RECONST_FODF(fodf_channel)

    // ** Local Tracking ** //
    /*
    tracking_channel = RECONST_FODF.out.fodf
        .join(tracking_mask_channel)
        .join(seed_channel)
    TRACKING_LOCALTRACKING(tracking_channel)
*/
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

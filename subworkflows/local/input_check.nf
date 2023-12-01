//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

def fetch_id ( dir, dir_base ) {
    return [id:dir_base.relativize(dir)
    .collect{it.name}
    .join("_")]
}

workflow INPUT_CHECK {
    take:
    input_folder // file: /path/to/samplesheet.csv

    main:

    dwi_channel = Channel.fromFilePairs("$input_folder/**/*dwi.nii.gz", size: 1, flat: true)
        { fetch_id(it.parent, input_folder) }
    bval_channel = Channel.fromFilePairs("$input_folder/**/*bval", size: 1, flat: true)
        { fetch_id(it.parent, input_folder) }
    bvec_channel = Channel.fromFilePairs("$input_folder/**/*bvec", size: 1, flat: true)
        { fetch_id(it.parent, input_folder) }

    emit:       
    dwi  = dwi_channel
    bval = bval_channel
    bvec = bvec_channel
}

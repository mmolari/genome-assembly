// ------- Parameters definition -------

// 
params.run = "test"

// directory containing the basecalled reads
params.input_dir = file("runs/${params.run}/clustering")


// ------- processes -------

process msa {

    label 'q6h_16cores'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "3_msa.fasta"

    input:
        tuple val(code), file("2_all_seqs.fasta")

    output:
        tuple val(code), file("3_msa.fasta")

    script:
        """
        trycycler msa --threads 16 --cluster_dir .
        """
}

process partition {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "4_reads.fastq"

    input:
        tuple val(code), file(reads), file("2_all_seqs.fasta")

    output:
        tuple val(code), file("4_reads.fastq")

    script:
        """
        trycycler partition --threads 8 --reads $reads --cluster_dirs .
        """
}

// executes trycycler consensus and creates 7_final_consensus.fasta
process consensus {

    label 'q30m'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "7_final_consensus.fasta"

    input:
        tuple val(code), file("2_all_seqs.fasta"), file("3_msa.fasta"), file("4_reads.fastq")

    output:
        tuple val(code), file("7_final_consensus.fasta")

    script:
        """
        trycycler consensus --threads 8 --cluster_dir .
        """

}

// Process executed locally that takes care of installing the model r941_min_high_g360
// returns a dummy empty file to guarantee execution before medaka_polish
process medaka_setup {

    label 'medaka_setup'

    conda 'conda_envs/medaka_env.yml'

    output:
        file(".medaka_setup")

    script:
        """
        medaka tools download_models --models r941_min_high_g360
        touch .medaka_setup
        """
}

// polish using medaka. Creates a 8_medaka.fasta file
process medaka_polish {

    label 'q30m'

    conda 'conda_envs/medaka_env.yml'

    publishDir "$params.input_dir/$code",
        mode : 'copy',
        pattern : "8_medaka.fasta"

    input:
        tuple val(code), file(reads), file(consensus)
        file(".medaka_setup")

    output:
        tuple val(code), file("8_medaka.fasta")

    script:
        """
        medaka_consensus \
            -i 4_reads.fastq \
            -d 7_final_consensus.fasta \
            -o medaka \
            -m r941_min_high_g360 \
            -t 8
        mv medaka/consensus.fasta medaka_temp.fasta
        rm -r medaka
        echo ">${code.find(/(?<=\/)[^\/]+$/)}_consensus" > 8_medaka.fasta
        tail -n +2 medaka_temp.fasta >> 8_medaka.fasta
        """

}

// concatenates all medaka files with the same barcode
process concatenate {

    label 'q30m_1core'

    input:
        tuple val(sample_id), file("medaka_*.fasta")

    output:
        tuple val(sample_id), file("medaka_consensus.fasta")

    script:
    """
    cat medaka_*.fasta > medaka_consensus.fasta
    """

}

// executes prokka on the set of all medaka consensus for one barcode.
process prokka {

    label 'q30m'

    conda 'conda_envs/prokka_env.yml'

    publishDir "$params.input_dir/$sample_id",
        mode : 'copy'

    input:
        tuple val(sample_id), file("medaka_consensus.fasta")

    output:
        path("prokka", type: 'dir')

    script:
    """
    prokka \
        --outdir prokka \
        --prefix ${sample_id}_genome \
        --cpus 8 \
        medaka_consensus.fasta
    """
}

// -------- workflow ----------

channel.fromPath( "${params.input_dir}/*", type: 'dir')
    .ifEmpty { error "Cannot find directories matching: ${params.input_dir}/*" }
    .set { input_ch }


workflow {

    // performs three different operations:
    // - captures sample-id, filtlong_reads.fastq and list of clusters.
    // - transposes, to have one item per cluster with assigned barcode
    // - captures the label of destination folder barcodeXX/cluster_XXX,
    //     the filtlong_reads.fastq file and the 2_all_seqs.fasta file.
    cluster_ch = input_ch.map { [
            it.getSimpleName(),                             // sample-id
            file("$it/filtlong_reads.fastq", type: 'dir'),  // filtlong reads
            file("$it/cluster_*", type: 'dir')              // list of clusters
            ]}
        .transpose()    // emit one item per cluster
        .map {[ 
            "${it[0]}/${it[2].getSimpleName()}",            // which file
            it[1],                                          // filtlong reads
            file("${it[2]}/2_all_seqs.fasta", type: 'file') // capture 2_all_seqs.fasta file produced by reconcile
            ]}
    
    // creates 4_reads.fastq
    partition(cluster_ch)
    
    // create two channels with just label and 2_all_seqs.fasta
    // for msa and consensus.
    noreads_ch = cluster_ch.map { [it[0], it[2]] }

    // creates 3_msa.fasta
    msa(noreads_ch)

    // combine three channels, for files 2,3,4
    // to be used as input of consensus
    consensus_ch = noreads_ch.join(msa.out).join(partition.out)

    // creates 7_final_consensus.fasta
    consensus(consensus_ch)

    // join 7_final_consensus and 4_reads in a single channel
    medaka_ch = partition.out.join(consensus.out)

    // install medaka model locally
    medaka_setup()
    // creates 8_medaka.fasta
    medaka_polish(medaka_ch, medaka_setup.out)

    // groups 8_medaka output files by sample-id
    concatenate_ch = medaka_polish.out
        .map { ["${it[0]}".split('/')[0], it[1] ] }
        .groupTuple()

    // concatenate all medaka files with the same sample-id, create medaka_consensus.fasta
    concatenate(concatenate_ch)

    // execute prokka on all clusters for the same sample, create prokka_<sample-id> directory
    prokka(concatenate.out)

}
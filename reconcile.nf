
// ------ parameters -------

params.run = "test"

params.input_dir = file("runs/${params.run}/clustering")

// ------- process -------

// PROCESS -> reconcile
// - performs trycycle reconcile
// - produces and stores a reconcile_log.txt file, which contains the output of reconcile command.
//   This can be used to take decisions on which contigs to remove.
// - if reconcile is successful, saves the 2_all_seqs.fasta file
// - produces a summary_log.txt file. All of these files are later concatenated and saved
//   in the main directory, to have a summary of which contigs failed to reconcile.
process reconcile {

    label 'q30m_highmem'

    publishDir "$params.input_dir/$sample_id/$cl",
        mode: 'copy',
        pattern: '{reconcile_log.txt,2_all_seqs.fasta}'

    input:
        tuple val(sample_id), val(cl), file(reads), file(cl_dirs)

    output:
        path("reconcile_log.txt")
        path("2_all_seqs.fasta") optional true
        path("summary_log.txt"), emit: summary


    script:
        """
        # prepare cluster directory, put contigs inside
        mkdir $cl
        mv *_contigs $cl

        # run trycycle reconcile. Save stout and stderr to file. Escape possible errors
        trycycler reconcile \
            --reads $reads \
            --cluster_dir $cl \
            --threads 8 \
        > reconcile_log.txt 2>&1 \
        || echo process failed >> reconcile_log.txt

        # append to file the tag of barcode and cluster
        echo $sample_id $cl >> reconcile_log.txt

        # write on file whether reconcile was successful. If so, move generated file
        # to main directory for capture
        if [ -f $cl/2_all_seqs.fasta ]; then
            echo reconcile success >> reconcile_log.txt
            mv $cl/2_all_seqs.fasta 2_all_seqs.fasta
        else
            echo reconcile failure >> reconcile_log.txt
        fi

        # save only success state to summary_log.txt file
        tail -n 2 reconcile_log.txt > summary_log.txt
        """
}

// ------------ workflow -----------------

// input channel: one entry per sample
channel.fromPath( "${params.input_dir}/*", type: 'dir')
    .ifEmpty { error "Cannot find directories matching: ${params.input_dir}/*" }
    .set { input_ch }

workflow {
    
    
    reconcile_ch = input_ch.map { [
            it.getSimpleName(),                 // sample name
            file("$it/filtlong_reads.fastq"),   // filtered reads
            file("$it/cluster_*", type: 'dir')  // list of clusters
        ]}
        .transpose() // transpose to have one entry per cluster
        .map {[ 
            it[0],                                      // sample name
            it[2].getSimpleName(),                      // cluster name 
            it[1],                                      // filtlong_reads
            file("${it[2]}/*_contigs", type: 'dir')     // list of contigs of the cluster
            ]}

    // try to reconcile the cluster
    reconcile(reconcile_ch)
    
    // concatenate summary files and save in the input directory as reconcile_summary.txt
    reconcile.out.summary.collectFile(name: 'reconcile_summary.txt', storeDir: params.input_dir, newLine: true)

}
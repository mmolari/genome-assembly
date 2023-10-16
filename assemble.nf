// ------- Parameters definition -------

// run name
params.run = "test"
params.input_fastq = "runs/${params.run}/reads/*.fastq.gz" 
params.output_dir = file("runs/${params.run}/clustering")
params.n_threads = 16

// ------- processes -------

// pre-filtering step with fitlong
process filtlong {

    label 'q30m'

    input:
        path fastq_file

    output:
        tuple val("${fastq_file.getSimpleName()}"), file ("reads.fastq")

    script:
        """
        filtlong --min_length 1000 --keep_percent 95 $fastq_file > reads.fastq
        """
}

// subsamble the reads in 12 samples
process subsampler {

    label 'q6h_subsample'

    errorStrategy 'ignore'

    input:
        tuple val(sample_id), file("reads.fastq")

    output:
        tuple val(sample_id), file("${sample_id}/sample_*.fastq") optional true

    script:
        """
        trycycler subsample \
            --reads reads.fastq \
            --out_dir ${sample_id} \
            --threads $params.n_threads
        """
}

// assemble with flye
process assemble_flye {

    label 'q30m'

    input:
        tuple val(sample_id), val(sample_num), file(fq)

    output:
        tuple val(sample_id), file("assembly/assembly.fasta")

    script:
        """
        flye --nano-raw $fq \
            --threads $params.n_threads \
            --out-dir assembly
        """
}

// assemble with raven
process assemble_raven {

    label 'q30m'

    input:
        tuple val(sample_id), val(sample_num), file(fq)

    output:
        tuple val(sample_id), file("assembly.fasta")

    script:
        """
        raven --threads $params.n_threads $fq > assembly.fasta
        rm raven.cereal
        """
}

// assemble with miniasm and minipolish
process assemble_mini {

    label 'q30m'

    errorStrategy 'ignore'

    input:
        tuple val(sample_id), val(sample_num), file(fq)

    output:
        tuple val(sample_id), file("assembly.fasta")

    script:
        """
        minimap2 -x ava-ont -t $params.n_threads $fq $fq > overlaps.paf
        miniasm -f $fq overlaps.paf > unpolished_assembly.gfa
        minipolish --threads $params.n_threads $fq unpolished_assembly.gfa > assembly.gfa
        any2fasta assembly.gfa > assembly.fasta
        
        rm overlaps.paf unpolished_assembly.gfa
        rm assembly.gfa
        """
}


// trycicler cluster. Takes as input the assembly files for each sample_id,
// along with the fastq reads. Resulting clusters are saved in the
// clustering/sample_id` folder for further inspection.
process trycycler_cluster {

    label 'q6h_2h'

    publishDir params.output_dir, mode: 'copy'

    input:
        tuple val(sample_id), file("assemblies_*.fasta"), file("reads.fastq")

    output:
        file("$sample_id")

    script:
        """
        trycycler cluster \
            --reads reads.fastq \
            --assemblies assemblies_*.fasta \
            --out_dir $sample_id

        cp reads.fastq $sample_id/filtlong_reads.fastq
        """
}

// -------- workflow -----------

// capture input
channel.fromPath( params.input_fastq )
    .ifEmpty { error "Cannot find any fasta files matching: ${params.input_fastq}" }
    .set { input_samples }

workflow {

    // filter and subsample reads
    filtlong(input_samples)
    subsampler(filtlong.out)

    // turn the output pipe, in which items are in format [sample_id, [samples...]] 
    // into single items in the format [sample_id, sample number, file].
    // these samples are then sent into the three different subchannels destined
    // to different assemblers (flye, raven, minipolish)
    to_assemble = subsampler.out
          .transpose() // pair sample_id to each file
          .map { it -> [it[0], it[1].getSimpleName().find(/(?<=^sample_)\d+$/).toInteger(), it[1]] }
          .branch { 
            flye : it[1] <= 4
            raven : it[1] >= 9
            mini : true 
          }

    // assemble each set with a different assembler
    assemble_flye(to_assemble.flye)
    assemble_raven(to_assemble.raven)
    assemble_mini(to_assemble.mini)

    // collect all the assembled files. Items are collected in format
    // [sample_id, assembly.fasta] and are grouped by sample_ids in chunks of size 12
    // [sample_id, [assembly_01.fasta ... assembly_12.fasta]] to be sent to
    // trycycler cluster
    assembled = assemble_flye.out.mix(assemble_raven.out, assemble_mini.out)
        .groupTuple(size: 12)
        .join(filtlong.out)

    // cluster results with trycycler and export results
    trycycler_cluster(assembled)
}
process DIAMOND_BLASTX {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/diamond:2.1.12--hdb4b4cc_1' :
        'biocontainers/diamond:2.1.12--hdb4b4cc_1' }"

    input:
    tuple val(meta) , path(fasta)
    tuple val(meta2), path(db)
    val out_ext
    val blast_columns

    output:
    tuple val(meta), path('*.blast'), optional: true, emit: blast
    tuple val(meta), path('*.xml')  , optional: true, emit: xml
    tuple val(meta), path('*.txt')  , optional: true, emit: txt
    tuple val(meta), path('*.daa')  , optional: true, emit: daa
    tuple val(meta), path('*.sam')  , optional: true, emit: sam
    tuple val(meta), path('*.tsv')  , optional: true, emit: tsv
    tuple val(meta), path('*.paf')  , optional: true, emit: paf
    tuple val(meta), path("*.log")  , emit: log
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def is_compressed = fasta.getExtension() == "gz" ? true : false
    def fasta_name = is_compressed ? fasta.getBaseName() : fasta
    def columns = blast_columns ? "${blast_columns}" : ''
    switch ( out_ext ) {
        case "blast": outfmt = 0; break
        case "xml": outfmt = 5; break
        case "txt": outfmt = 6; break
        case "daa": outfmt = 100; break
        case "sam": outfmt = 101; break
        case "tsv": outfmt = 102; break
        case "paf": outfmt = 103; break
        default:
            outfmt = '6';
            out_ext = 'txt';
            log.warn("Unknown output file format provided (${out_ext}): selecting DIAMOND default of tabular BLAST output (txt)");
            break
    }
    """
    if [ "${is_compressed}" == "true" ]; then
        gzip -c -d ${fasta} > ${fasta_name}
    fi

    DB=`find -L ./ -name "*.dmnd" | sed 's/\\.dmnd\$//'`

    diamond \\
        blastx \\
        --threads ${task.cpus} \\
        --db \$DB \\
        --query ${fasta_name} \\
        --outfmt ${outfmt} ${columns} \\
        ${args} \\
        --out ${prefix}.${out_ext} \\
        --log

    mv diamond.log ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diamond: \$(diamond --version 2>&1 | tail -n 1 | sed 's/^diamond version //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    switch ( out_ext ) {
        case "blast": outfmt = 0; break
        case "xml": outfmt = 5; break
        case "txt": outfmt = 6; break
        case "daa": outfmt = 100; break
        case "sam": outfmt = 101; break
        case "tsv": outfmt = 102; break
        case "paf": outfmt = 103; break
        default:
            outfmt = '6';
            out_ext = 'txt';
            log.warn("Unknown output file format provided (${out_ext}): selecting DIAMOND default of tabular BLAST output (txt)");
            break
    }

    """
    touch ${prefix}.${out_ext}
    touch ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diamond: \$(diamond --version 2>&1 | tail -n 1 | sed 's/^diamond version //')
    END_VERSIONS
    """
}

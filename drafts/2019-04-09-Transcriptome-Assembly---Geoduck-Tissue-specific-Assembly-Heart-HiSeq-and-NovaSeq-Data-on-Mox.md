---
layout: post
title: Transcriptome Assembly - Geoduck Tissue-specific Assembly Heart HiSeq and NovaSeq Data on Mox
date: '2019-04-09 07:01'
tags:
  - Panopea generosa
  - geoduck
  - heart
  - trinity
  - assembly
  - mox
  - transcriptome
categories:
  - Miscellaneous
---
I previously assembled and annotated _P.generosa_ heart transcriptome ([20190318](https://robertslab.github.io/sams-notebook/2019/03/18/Transcriptome-Annotation-Geoduck-Heart-with-Trinotate-on-Mox.html)) using just our HiSeq data from our Illumina collaboration. This was a an oversight, as I didn't realize that we also had NovaSeq RNAseq data. So, I've initiated another _de novo_ assembly using Trinity incorporating both sets of data.

SBATCH script (GitHub):

- [20190409_trinity_pgen_heart_RNAseq.sh](https://github.com/RobertsLab/sams-notebook/blob/master/sbatch_scripts/20190409_trinity_pgen_heart_RNAseq.sh)

```shell
    #!/bin/bash
    ## Job Name
    #SBATCH --job-name=trin_heart
    ## Allocation Definition
    #SBATCH --account=coenv
    #SBATCH --partition=coenv
    ## Resources
    ## Nodes
    #SBATCH --nodes=1
    ## Walltime (days-hours:minutes:seconds format)
    #SBATCH --time=30-00:00:00
    ## Memory per node
    #SBATCH --mem=120G
    ##turn on e-mail notification
    #SBATCH --mail-type=ALL
    #SBATCH --mail-user=samwhite@uw.edu
    ## Specify the working directory for this job
    #SBATCH --workdir=/gscratch/scrubbed/samwhite/outputs/20190409_trinity_pgen_heart_RNAseq    

    # Exit script if a command fails
    set -e    

    # Load Python Mox module for Python module availability
    module load intel-python3_2017    

    # Document programs in PATH (primarily for program version ID)
    date >> system_path.log
    echo "" >> system_path.log
    echo "System PATH for $SLURM_JOB_ID" >> system_path.log
    echo "" >> system_path.log
    printf "%0.s-" {1..10} >> system_path.log
    echo ${PATH} | tr : \\n >> system_path.log    

    # User-defined variables
    reads_dir=/gscratch/srlab/sam/data/P_generosa/RNAseq/heart
    threads=28
    assembly_stats=assembly_stats.txt    

    # Paths to programs
    trinity_dir="/gscratch/srlab/programs/Trinity-v2.8.3"
    samtools="/gscratch/srlab/programs/samtools-1.9/samtools"    


    ## Inititalize arrays
    R1_array=()
    R2_array=()    

    # Variables for R1/R2 lists
    R1_list=""
    R2_list=""    

    # Create array of fastq R1 files
    R1_array=(${reads_dir}/*_R1_*.gz)    

    # Create array of fastq R2 files
    R2_array=(${reads_dir}/*_R2_*.gz)    

    # Create list of fastq files used in analysis
    ## Uses parameter substitution to strip leading path from filename
    for fastq in ${reads_dir}/*.gz
    do
      echo ${fastq##*/} >> fastq.list.txt
    done    

    # Create comma-separated lists of FastQ reads
    R1_list=$(echo ${R1_array[@]} | tr " " ",")
    R2_list=$(echo ${R2_array[@]} | tr " " ",")    


    # Run Trinity
    ${trinity_dir}/Trinity \
    --trimmomatic \
    --seqType fq \
    --max_memory 120G \
    --CPU ${threads} \
    --left \
    ${R1_list} \
    --right \
    ${R2_list}    

    # Assembly stats
    ${trinity_dir}/util/TrinityStats.pl trinity_out_dir/Trinity.fasta \
    > ${assembly_stats}    

    # Create gene map files
    ${trinity_dir}/util/support_scripts/get_Trinity_gene_to_trans_map.pl \
    trinity_out_dir/Trinity.fasta \
    > trinity_out_dir/Trinity.fasta.gene_trans_map    

    # Create FastA index
    ${samtools} faidx \
    trinity_out_dir/Trinity.fasta
```

Oof, after running for over _two weeks_ the Mox node crashed this past weekend:

![Screencap of Trinity node failure notification.](https://github.com/RobertsLab/sams-notebook/blob/master/images/screencaps/20190607_trinity_node_fail.png?raw=true)


Have restarted the job...

---

#### RESULTS

Output folder:

- []()

Trinity FastA:

- []()

Trinity FastA index file:

- []()

Trinity Gene Trans Map file:

- [20190409_trinity_pgen_heart_RNAseq/trinity_out_dir/Trinity.fasta.gene_trans_map](http://gannet.fish.washington.edu/Atumefaciens/20190409_trinity_pgen_heart_RNAseq/trinity_out_dir/Trinity.fasta.gene_trans_map)


Assembly stats (text):

- [20190409_trinity_pgen_heart_RNAseq/assembly_stats.txt](http://gannet.fish.washington.edu/Atumefaciens/20190409_trinity_pgen_heart_RNAseq/assembly_stats.txt)

```

```

List of input FastQs (text):

- [20190409_trinity_pgen_heart_RNAseq/fastq.list.txt](http://gannet.fish.washington.edu/Atumefaciens/20190409_trinity_pgen_heart_RNAseq/fastq.list.txt)

```

```

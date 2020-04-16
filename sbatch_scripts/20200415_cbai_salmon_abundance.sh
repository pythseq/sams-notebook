#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_salmon_abundance_estimates
## Allocation Definition
#SBATCH --account=srlab
#SBATCH --partition=srlab
## Resources
## Nodes
#SBATCH --nodes=1
## Walltime (days-hours:minutes:seconds format)
#SBATCH --time=04-00:00:00
## Memory per node
#SBATCH --mem=120G
##turn on e-mail notification
#SBATCH --mail-type=ALL
#SBATCH --mail-user=samwhite@uw.edu
## Specify the working directory for this job
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200415_cbai_salmon_abundance

## Script to get gene abundance estimates via salmon alignment-free
## Specifically for Grace, per this GitHub issue: https://github.com/RobertsLab/resources/issues/902


# Exit script if any command fails
set -e

# Load Python Mox module for Python module availability

module load intel-python3_2017

# Document programs in PATH (primarily for program version ID)

{
date
echo ""
echo "System PATH for $SLURM_JOB_ID"
echo ""
printf "%0.s-" {1..10}
echo "${PATH}" | tr : \\n
} >> system_path.log

wd="$(pwd)"
threads=28

samples=samples.txt

fasta_prefix="20200408.C_bairdi.megan.Trinity"


## Set input file locations
trimmed_reads_dir="/gscratch/srlab/sam/data/C_bairdi/RNAseq"
transcriptome_dir="/gscratch/srlab/sam/data/C_bairdi/transcriptomes"
transcriptome="${transcriptome_dir}/${fasta_prefix}.fasta"

trinotate_feature_map="${transcriptome_dir}/20200409.cbai.trinotate.annotation_feature_map.txt"
gene_map="${transcriptome_dir}/${fasta_prefix}.fasta.gene_trans_map"

# Standard output/error files
matrix_stdout="matrix_stdout.txt"
matrix_stderr="matrix_stderr.txt"
salmon_stdout="salmon_stdout.txt"
salmon_stderr="salmon_stderr.txt"


#programs
trinity_home=/gscratch/srlab/programs/trinityrnaseq-v2.9.0
trinity_annotate_matrix="${trinity_home}/Analysis/DifferentialExpression/rename_matrix_feature_identifiers.pl"
trinity_abundance=${trinity_home}/util/align_and_estimate_abundance.pl
trinity_matrix=${trinity_home}/util/abundance_estimates_to_matrix.pl

# Create salmon index of Trinity FastA
# Useful for saving time if needed in future for
# additional runs.
${trinity_abundance} \
--transcripts ${transcriptome} \
--est_method salmon \
--prep_reference \
--thread_count "${threads}" \
--output_dir "${wd}"


# Rsync trimmed reads
rsync \
--archive \
--verbose \
${trimmed_reads_dir}/3297*trim*.gz .

# Populate array with unique sample names
## NOTE: Requires Bash >=v4.0
mapfile -t samples_array < <( for fastq in 3297*.gz; do echo "${fastq}" | awk -F"_" '{print $1}'; done | sort -u )

# Loop to concatenate same sample R1 and R2 reads
# Also create sample list file
for sample in "${!samples_array[@]}"
do
  # Concatenate R1 reads for each sample
  for fastq in *R1*.gz
  do
    fastq_sample=$(echo "${fastq}" | awk -F"_" '{print $1}')
    if [ "${samples_array[sample]}" == "${fastq_sample}" ]; then
      echo "${fastq}" >> fastq.list.txt
      reads_1=${samples_array[sample]}_reads_1.fq
      gunzip --to-stdout "${fastq}" >> "${reads_1}"
    fi
  done

  # Concatenate R2 reads for each sample
  for fastq in *R2*.gz
  do
    fastq_sample=$(echo "${fastq}" | awk -F"_" '{print $1}')
    if [ "${samples_array[sample]}" == "${fastq_sample}" ]; then
      echo "${fastq}" >> fastq.list.txt
      reads_2=${samples_array[sample]}_reads_2.fq
      gunzip --to-stdout "${fastq}" >> "${reads_2}"
    fi
  done

  # Create tab-delimited samples file.
  printf "%s\t%s\t%s\t%s\n" "${samples_array[sample]}" "${samples_array[sample]}_01" "${reads_1}" "${reads_2}" \
  >> ${samples}
done

# Runs salmon and stranded library option
${trinity_abundance} \
--transcripts ${transcriptome} \
--seqType fq \
--left reads_1.fq \
--right reads_2.fq \
--SS_lib_type RF \
--est_method salmon \
--samples_file "${samples}" \
--gene_trans_map "${gene_map}" \
--thread_count "${threads}" \
--output_dir "${wd}" \
1> ${salmon_stdout} \
2> ${salmon_stderr}


# Convert abundance estimates to matrix
${trinity_matrix} \
--est_method salmon \
--gene_trans_map ${gene_map} \
--out_prefix salmon \
quant.sf \
1> ${matrix_stdout} \
2> ${matrix_stderr}

# Integrate functional Trinotate functional annotations
"${trinity_annotate_matrix}" \
"${trinotate_feature_map}" \
salmon.gene.counts.matrix \
> salmon.gene.counts.annotated.matrix

# Clean up
rm ./*trim*.gz
rm ./*.fq

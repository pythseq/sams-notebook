#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_detonate_transcriptome_evaluations
## Allocation Definition
#SBATCH --account=srlab
#SBATCH --partition=srlab
## Resources
## Nodes
#SBATCH --nodes=1
## Walltime (days-hours:minutes:seconds format)
#SBATCH --time=15-00:00:00
## Memory per node
#SBATCH --mem=500G
##turn on e-mail notification
#SBATCH --mail-type=ALL
#SBATCH --mail-user=samwhite@uw.edu
## Specify the working directory for this job
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200616_cbai_detonate_transcriptome_evaluations


###################################################################################
# These variables need to be set by user

# Assign Variables
## frag_size is guesstimate of library fragment sizes
frag_size=500
reads_dir=/gscratch/srlab/sam/data/C_bairdi/RNAseq
transcriptomes_dir=/gscratch/srlab/sam/data/C_bairdi/transcriptomes
threads=28

# Array of the various comparisons to evaluate
# Each condition in each comparison should be separated by a "-"
transcriptomes_array=(
"${transcriptomes_dir}"/cbai_transcriptome_v1.0.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v1.5.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v1.6.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v1.7.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v2.0.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v2.1.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v3.0.fasta \
"${transcriptomes_dir}"/cbai_transcriptome_v3.1.fasta
)


###################################################################################

# Exit script if any command fails
set -e

# Load Python Mox module for Python module availability

module load intel-python3_2017


# Programs array
declare -A programs_array
programs_array=(
[bowtie2]="/gscratch/srlab/programs/bowtie2-2.3.5.1-linux-x86_64" \
[detonate_trans_length]="/gscratch/srlab/programs/detonate-1.11/rsem-eval/rsem-eval-estimate-transcript-length-distribution" \
[detonate]="/gscratch/srlab/programs/detonate-1.11/rsem-eval/rsem-eval-calculate-score"
)




# Loop through each comparison
for transcriptome in "${!transcriptomes_array[@]}"
do

  ## Inititalize arrays
  R1_array=()
  R2_array=()
  reads_array=()

  # Variables
  R1_list=""
  R2_list=""

  transcriptome_name="${transcriptomes_array[$transcriptome]##*/}"


  rsem_eval_dist_mean_sd="${transcriptome_name}_true_length_dis_mean_sd.txt"

  # Capture FastA checksums for verification
  echo "Generating checksum for ${transcriptome_name}"
  md5sum "${transcriptomes_array[transcriptome]}" >> fasta.checksums.md5
  echo "Finished generating checksum for ${transcriptome_name}"
  echo ""

	if [[ "${transcriptome_name}" == "cbai_transcriptome_v1.0.fasta" ]]; then

    reads_array=("${reads_dir}"/20200[15][13][138]*megan*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/20200[15][13][138]*megan*R1.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/20200[15][13][138]*megan*R2.fq)



  elif [[ "${transcriptome_name}" == "cbai_transcriptome_v1.5.fasta" ]]; then

    reads_array=("${reads_dir}"/20200[145][13][138]*megan*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/20200[145][13][138]*megan*R1.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/20200[145][13][138]*megan*R2.fq)

  elif [[ "${transcriptome_name}" == "cbai_transcriptome_v1.6.fasta" ]]; then

    reads_array=("${reads_dir}"/*megan*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/*megan*R1.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/*megan*R2.fq)

  elif [[ "${transcriptome_name}" == "cbai_transcriptome_v1.7.fasta" ]]; then

    reads_array=("${reads_dir}"/20200[145][13][189]*megan*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/20200[145][13][189]*megan*R1.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/20200[145][13][189]*megan*R2.fq)

  elif [[ "${transcriptome_name}" == "cbai_transcriptome_v2.0.fasta" ]] \
  || [[ "${transcriptome_name}" == "cbai_transcriptome_v2.1.fasta" ]]; then

    reads_array=("${reads_dir}"/*fastp-trim*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/*R1*fastp-trim*.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/*R2*fastp-trim*.fq)

  elif [[ "${transcriptome_name}" == "cbai_transcriptome_v3.0.fasta" ]] \
  || [[ "${transcriptome_name}" == "cbai_transcriptome_v3.1.fasta" ]]; then

    reads_array=("${reads_dir}"/*fastp-trim*20[12][09][01][24]1[48]*.fq)

    # Create array of fastq R1 files
    R1_array=("${reads_dir}"/*R1*fastp-trim*20[12][09][01][24]1[48]*.fq)

    # Create array of fastq R2 files
    R2_array=("${reads_dir}"/*R2*fastp-trim*20[12][09][01][24]1[48]*.fq)


  fi

  # Create list of fastq files used in analysis
  ## Uses parameter substitution to strip leading path from filename
  printf "%s\n" "${reads_array[@]##*/}" >> "${transcriptome_name}".fastq.list.txt

  # Create comma-separated lists of FastQ reads
  R1_list=$(echo "${R1_array[@]}" | tr " " ",")
  R2_list=$(echo "${R2_array[@]}" | tr " " ",")

  # Determine transcript length
  ${programs_array[detonate_trans_length]} \
  "${transcriptomes_array[$transcriptome]}" \
  "${rsem_eval_dist_mean_sd}"


  # Run rsem-eval
  # Use bowtie2 and paired-end options
  ${programs_array[detonate]} \
  --bowtie2 \
  --bowtie2-path "${programs_array[bowtie2]}" \
  --num-threads ${threads} \
  --transcript-length-parameters "${rsem_eval_dist_mean_sd}" \
  --paired-end \
  "${R1_list}" \
  "${R2_list}" \
  "${transcriptomes_array[$transcriptome]}" \
  "${transcriptome_name}" \
  ${frag_size}



done

# Document programs in PATH (primarily for program version ID)
{
date
echo ""
echo "System PATH for $SLURM_JOB_ID"
echo ""
printf "%0.s-" {1..10}
echo "${PATH}" | tr : \\n
} >> system_path.log

# Capture program options
for program in "${!programs_array[@]}"
do
	{
  echo "Program options for ${program}: "
	echo ""
	${programs_array[$program]} --help
	echo ""
	echo ""
	echo "----------------------------------------------"
	echo ""
	echo ""
} &>> program_options.log || true
done

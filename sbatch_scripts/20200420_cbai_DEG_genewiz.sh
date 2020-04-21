#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_DEG_basic
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
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200421_cbai_DEG_basic_comparisons

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
timestamp=$(date +%Y%m%d)
species="cbai"
threads=28

fastq_dir=/gscratch/srlab/sam/data/C_bairdi/RNAseq/

# Array of the various comparisons to evaluate
# Each condition in each comparison should be separated by a "-"
comparisons_array=(
infected-uninfected \
D9-D12 \
D9-D26 \
D12-D26 \
ambient-cold \
ambient-warm \
cold-warm
)

# Functions
# Expects input (i.e. "$1") to be in the following format:
# e.g. 20200413.C_bairdi.113.D9.uninfected.cold.megan_R2.fq
get_day () { day=$(echo "$1" | awk -F"." '{print $4}'); }
get_inf () { inf=$(echo "$1" | awk -F"." '{print $5}'); }
get_temp () { temp=$(echo "$1" | awk -F"." '{print $6}'); }
get_sample_id () { sample_id=$(echo "$1" | awk -F"." '{print $3}'); }

for comparison in "${!comparisons_array[@]}"
do

  # Assign variables
  cond1_count=0
  cond2_count=0
  comparison=${comparisons_array[${comparison}]}
  samples="${comparison}.samples.txt"
  comparison_dir="${wd}/${comparison}/"

  # Extract each comparison from comparisons array
  # Conditions must be separated by a "-"
  cond1=$(echo "${comparison}" | awk -F"-" '{print $1}')
  cond2=$(echo "${comparison}" | awk -F"-" '{print $2}')



  mkdir "${comparison}"


  cd "${comparison}" || exit

  # Series of if statements to identify which FastQ files to rsync to working directory
  if [[ "${comparison}" == "infected-uninfected" ]]; then

    rsync --archive --verbose ${fastq_dir}*.fq .
  fi

  if [[ "${comparison}" == "D9-D12" ]]; then

    for fastq in "${fastq_dir}"*.fq
    do
      get_day "${fastq}"
      if [[ "${day}" == "D9" || "${day}" == "D12" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  if [[ "${comparison}" == "D9-D26" ]]; then
    for fastq in "${fastq_dir}"*.fq
    do
      get_day "${fastq}"
      if [[ "${day}" == "D9" || "${day}" == "D26" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  if [[ "${comparison}" == "D12-D26" ]]; then
    for fastq in "${fastq_dir}"*.fq
    do
      get_day "${fastq}"
      if [[ "${day}" == "D12" || "${day}" == "D26" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  if [[ "${comparison}" == "ambient-cold" ]]; then
    #statements
    for fastq in "${fastq_dir}"*.fq
    do
      get_temp "${fastq}"
      if [[ "${temp}" == "ambient" || "${temp}" == "cold" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  if [[ "${comparison}" == "ambient-warm" ]]; then
    for fastq in "${fastq_dir}"*.fq
    do
      get_temp "${fastq}"
      if [[ "${temp}" == "ambient" || "${temp}" == "warm" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  if [[ "${comparison}" == "cold-warm" ]]; then
    for fastq in "${fastq_dir}"*.fq
    do
      get_temp "${fastq}"
      if [[ "${temp}" == "cold" || "${temp}" == "warm" ]]; then
        rsync --archive --verbose "${fastq}" .
      fi
    done
  fi

  # Create reads array
  reads_array=(*.fq)

  # Loop to create sample list file
  for (( i=0; i<${#reads_array[@]} ; i+=2 ))
  do

    get_day "${reads_array[i]}"
    get_inf "${reads_array[i]}"
    get_temp "${reads_array[i]}"

    if [[ "${cond1}" == "${day}" || "${cond1}" == "${inf}" || "${cond1}" == "${temp}" ]]; then
      #statements
      ((cond1_count++))
      # Create tab-delimited samples file.
      printf "%s\t%s%02d\t%s\t%s\n" "${cond1}" "${cond1}_" "${cond1_count}" "${reads_array[i]}" "${reads_array[i+1]}" \
      >> "${samples}"
    elif [[ "${cond2}" == "${day}" || "${cond2}" == "${inf}" || "${cond2}" == "${temp}" ]]; then
      ((cond2_count++))
      printf "%s\t%s%02d\t%s\t%s\n" "${cond2}" "${cond2}_" "${cond2_count}" "${comparison_dir}${reads_array[i]}" "${comparison_dir}${reads_array[i+1]}" \
      >> "${samples}"
    fi
  done


  # Create directory/sample list for ${trinity_matrix} command
  trin_matrix_list=$(awk '{printf "%s%s", $2, "/quant.sf " }' "${samples}")

  cd ${trimmed_reads_dir}
  time ${trinity_abundance} \
  --output_dir "${salmon_out_dir}" \
  --transcripts ${transcriptome} \
  --seqType fq \
  --samples_file "${samples}" \
  --SS_lib_type RF \
  --est_method salmon \
  --aln_method bowtie2 \
  --gene_trans_map "${gene_map}" \
  --prep_reference \
  --thread_count "${threads}" \
  1> "${salmon_out_dir}"/${salmon_stdout} \
  2> "${salmon_out_dir}"/${salmon_stderr}

  # Move output folders
  mv ${trimmed_reads_dir}/[iu]* \
  "${salmon_out_dir}"

  cd "${salmon_out_dir}"

  # Convert abundance estimates to matrix
  ${trinity_matrix} \
  --est_method salmon \
  --gene_trans_map ${gene_map} \
  --out_prefix salmon \
  --name_sample_by_basedir \
  ${trin_matrix_list} \
  1> ${matrix_stdout} \
  2> ${matrix_stderr}

  # Integrate functional Trinotate functional annotations
  "${trinity_annotate_matrix}" \
  "${trinotate_feature_map}" \
  salmon.gene.counts.matrix \
  > salmon.gene.counts.annotated.matrix


  # Generate weighted gene lengths
  "${trinity_tpm_length}" \
  --gene_trans_map "${gene_map}" \
  --trans_lengths "${fasta_seq_lengths}" \
  --TPM_matrix "${salmon_iso_matrix}" \
  > Trinity.gene_lengths.txt \
  2> ${tpm_length_stderr}

  # Differential expression analysis
  cd ${transcriptome_dir}
  ${trinity_DE} \
  --matrix "${salmon_out_dir}"/salmon.gene.counts.matrix \
  --method edgeR \
  --samples_file "${samples}" \
  1> ${trinity_DE_stdout} \
  2> ${trinity_DE_stderr}

  mv edgeR* "${salmon_out_dir}"


  # Run differential expression on edgeR output matrix
  # Set fold difference to 2-fold (ie. -C 1 = 2^1)
  # P value <= 0.05
  # Has to run from edgeR output directory

  # Pulls edgeR directory name and removes leading ./ in find output
  cd "${salmon_out_dir}"
  edgeR_dir=$(find . -type d -name "edgeR*" | sed 's%./%%')
  cd "${edgeR_dir}"
  mv "${transcriptome_dir}/${trinity_DE_stdout}" .
  mv "${transcriptome_dir}/${trinity_DE_stderr}" .
  ${diff_expr} \
  --matrix "${salmon_gene_matrix}" \
  --samples "${samples}" \
  --examine_GO_enrichment \
  --GO_annots "${go_annotations}" \
  --include_GOplot \
  --gene_lengths "${salmon_out_dir}"/Trinity.gene_lengths.txt \
  -C 1 \
  -P 0.05 \
  1> ${diff_expr_stdout} \
  2> ${diff_expr_stderr}



  cd "${wd}"
done

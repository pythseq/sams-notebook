#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_nanoplot_nanopore-data
## Allocation Definition
#SBATCH --account=coenv
#SBATCH --partition=coenv
## Resources
## Nodes
#SBATCH --nodes=1
## Walltime (days-hours:minutes:seconds format)
#SBATCH --time=10-00:00:00
## Memory per node
#SBATCH --mem=120G
##turn on e-mail notification
#SBATCH --mail-type=ALL
#SBATCH --mail-user=samwhite@uw.edu
## Specify the working directory for this job
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200914_cbai_nanoplot_nanopore-data




###################################################################################
# These variables need to be set by user

# Load Anaconda
# Uknown why this is needed, but Anaconda will not run if this line is not included.
. "/gscratch/srlab/programs/anaconda3/etc/profile.d/conda.sh"


# Activate the NanoPlot Anaconda environment
conda activate nanoplot_env

# Set number of CPUs to use
threads=28

# Paths to reads
raw_reads_dir_array=(
"/gscratch/srlab/sam/data/C_bairdi/DNAseq/ont_FAL58500_04bb4d86_20102558-2729" \
"/gscratch/srlab/sam/data/C_bairdi/DNAseq/ont_FAL58500_94244ffd_20102558-2729" \
"/gscratch/srlab/sam/data/C_bairdi/DNAseq/ont_FAL86873_d8db260e_cbai_6129_403_26"
)

# Paths to programs
nanoplot=NanoPlot


###################################################################################


# Exit script if any command fails
set -e


# Capture this directory
wd=$(pwd)

# Inititalize array
programs_array=()


# Programs array
programs_array=("${nanoplot}")


# Loop through NanoPore data directories
# to run NanoPlot, FastQC, and MultiQC
for directory in "${!raw_reads_dir_array[@]}"
do


  # Capture NanoPore directory name
  dir_name=${raw_reads_dir_array[directory]##*/}

  # Make new directory and change to that directory
  mkdir "${dir_name}" && cd "$_"

  current_dir=$(pwd)


  # Run NanoPlot
  ## Sets readtype to 1D (default)
  ## Shows N50 on histograms
  ## Analysis perfomred using the sequencing summary file generated by
  ## guppy when converting from Fast5 to FastQ
  ${programs_array[nanoplot]} \
  --threads ${threads} \
  --outdir ${current_dir} \
  --readtype 1D \
  --N50 \
  --summary "${raw_reads_dir_array[directory]}"/sequencing_summary.txt

  # Change back to working directory
  cd "${wd}"

done


# Capture program options
for program in "${!programs_array[@]}"
do
	{
  echo "Program options for ${programs_array[program]}: "
	echo ""
	${programs_array[program]} -h
	echo ""
	echo ""
	echo "----------------------------------------------"
	echo ""
	echo ""
} &>> program_options.log || true
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

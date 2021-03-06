#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_nanofilt_Q7_6129_403_26_nanopore-data
## Allocation Definition
#SBATCH --account=coenv
#SBATCH --partition=coenv
## Resources
## Nodes
#SBATCH --nodes=1
## Walltime (days-hours:minutes:seconds format)
#SBATCH --time=10-00:00:00
## Memory per node
#SBATCH --mem=200G
##turn on e-mail notification
#SBATCH --mail-type=ALL
#SBATCH --mail-user=samwhite@uw.edu
## Specify the working directory for this job
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200928_cbai_nanofilt_Q7_6129_403_26_nanopore-data




###################################################################################
# These variables need to be set by user

# Load Anaconda
# Uknown why this is needed, but Anaconda will not run if this line is not included.
. "/gscratch/srlab/programs/anaconda3/etc/profile.d/conda.sh"


# Activate the NanoPlot Anaconda environment
conda activate nanofilt_2.6.0_env


# Declare array
raw_reads_dir_array=()

# Paths to reads
raw_reads_dir_array=(
"/gscratch/srlab/sam/data/C_bairdi/DNAseq/ont_FAL86873_d8db260e_cbai_6129_403_26"
)

# FastQ concatenation filename
fastq_cat=20200928_cbai_nanopore_6129_403_26.fastq

fastq_filtered=20200928_cbai_nanopore_6129_403_26_quality-7.fastq

# Paths to programs
nanofilt=NanoFilt

# Set mean quality filter (integer)
quality=7

###################################################################################


# Exit script if any command fails
set -e

# Inititalize array
programs_array=()

# Programs array
programs_array=("${nanofilt}")


# Loop through NanoPore data directories
# to run NanoPlot, FastQC, and MultiQC
for directory in "${raw_reads_dir_array[@]}"
do

  # Find all FastQ files and concatenate into singel file
  while IFS= read -r -d '' filename
  do
    # Concatenate all FastQ files into single file
    # for NanoFilt and generate MD5 checksums
    echo "Now concatenating ${filename} to ${fastq_cat}..."
    cat "${filename}" >> ${fastq_cat}
    echo "Concatenation of ${filename} to ${fastq_cat} complete."

    # Create checksums file
    echo "Now generating checksum for ${filename}..."
    echo ""
    md5sum "${filename}" >> fastq_checksums.md5
    echo "Checksum for ${filename} complete."
    echo ""

  done < <(find "${directory}" -name "*.fastq" -type f -print0)

done

# Generate MD5 checksum for concatenated FastQ file
echo "Now generating checksum for ${fastq_cat}..."
echo ""
md5sum "${fastq_cat}" >> fastq_checksums.md5
echo "checksum for ${fastq_cat} complete."
echo ""

# Run NanoFilt
## Sets readtype to 1D (default)
## Filters on mean quality >= 7 (ONT "standard")
## FYI: seems to require piping stdin (i.e. cat fastq |)to NanoFilt...
echo "Running ${programs_array[nanofilt]}"
echo ""
cat ${fastq_cat} \
| ${programs_array[nanofilt]} \
--readtype 1D \
--quality ${quality} \
> ${fastq_filtered}
echo "${programs_array[nanofilt]} complete."
echo ""

# Generate MD5 checksum for concatenated FastQ file
echo "Now generating checksum for ${fastq_filtered}..."
echo ""
md5sum "${fastq_filtered}" >> fastq_checksums.md5
echo "checksum for ${fastq_filtered} complete."
echo ""

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

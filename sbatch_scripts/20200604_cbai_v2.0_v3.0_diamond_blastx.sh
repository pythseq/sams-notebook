#!/bin/bash
## Job Name
#SBATCH --job-name=cbai_blastx_DIAMOND
## Allocation Definition
#SBATCH --account=coenv
#SBATCH --partition=coenv
## Resources
## Nodes
#SBATCH --nodes=1
## Walltime (days-hours:minutes:seconds format)
#SBATCH --time=1-00:00:00
## Memory per node
#SBATCH --mem=120G
##turn on e-mail notification
#SBATCH --mail-type=ALL
#SBATCH --mail-user=samwhite@uw.edu
## Specify the working directory for this job
#SBATCH --chdir=/gscratch/scrubbed/samwhite/outputs/20200604_cbai_v2.0_v3.0_diamond_blastx

## Perform DIAMOND BLASTx on Chionoecetes bairdi (Tanner crab) transcriptome assemblies:
## v2.0 and v3.0 for subsequent taxonomic filtering with MEGAN6.

# Exit script if any command fails
set -e

# Load Python Mox module for Python module availability

module load intel-python3_2017

# SegFault fix?
export THREADS_DAEMON_MODEL=1

# Document programs in PATH (primarily for program version ID)

{
date
echo ""
echo "System PATH for $SLURM_JOB_ID"
echo ""
printf "%0.s-" {1..10}
echo "${PATH}" | tr : \\n
} >> system_path.log



# Program paths
diamond=/gscratch/srlab/programs/diamond-0.9.29/diamond

# DIAMOND NCBI nr database
dmnd=/gscratch/srlab/blastdbs/ncbi-nr-20190925/nr.dmnd

# Capture program options
{
echo "Program options for DIAMOND: "
echo ""
"${diamond}" help
echo ""
echo ""
echo "----------------------------------------------"
echo ""
echo ""
} &>> program_options.log || true

# Transcriptomes directory
transcriptome_dir=/gscratch/srlab/sam/data/C_bairdi/transcriptomes/


# Loop through transcriptome FastA files, log filenames to fasta_list.txt.
# Run DIAMOND on each FastA
for fasta in ${transcriptome_dir}cbai_transcriptome_v[23]*.fasta
do
	# Record md5 checksums
	md5sum "${fasta}" >> transcriptomes_checkums.md5

	# Strip leading path and extensions
	no_path=$(echo "${fasta##*/}")

	# Run DIAMOND with blastx
	# Output format 100 produces a DAA binary file for use with MEGAN
	${diamond} blastx \
	--db ${dmnd} \
	--query "${fasta}" \
	--out "${no_path}".blastx.daa \
	--outfmt 100 \
	--top 5 \
	--block-size 15.0 \
	--index-chunks 4
done

Process Input/Output Summary and Connection Audit

  1. Core Workflow (Pre-processing & Alignment)


  ┌──────────────────────┬───────────────────┬─────────────────────────────┬─────────────────────────────────────┬──────────────┐
  │ Process              │ Input (Source)    │ Output (Emit)               │ Next Process (Target)               │ Audit Result │
  ├──────────────────────┼───────────────────┼─────────────────────────────┼─────────────────────────────────────┼──────────────┤
  │ INPUT_CHECK          │ ch_input (Params) │ .reads                      │ CAT_FASTQ                           │ PASS         │
  │ PREPARE_GENOME       │ Reference Params  │ Various Indices             │ Alignment Subworkflows              │ PASS         │
  │ CAT_FASTQ            │ ch_fastq.multiple │ .reads                      │ Trimming (TrimGalore/Fastp)         │ PASS         │
  │ TRIMGALORE / FASTP   │ ch_cat_fastq      │ .reads                      │ BBMAP_BBSPLIT / SORTMERNA           │ PASS         │
  │ BBMAP_BBSPLIT        │ .reads (Trimmed)  │ .primary_fastq              │ SORTMERNA / Aligner                 │ PASS         │
  │ SORTMERNA            │ .reads (Filtered) │ .reads                      │ ALIGN_STAR / QUANTIFY_RSEM          │ PASS         │
  │ ALIGN_STAR           │ .reads (Clean)    │ .bam, .bai, .bam_transcript │ BAM_DEDUP_..., QUANTIFY_STAR_SALMON │ PASS         │
  │ QUANTIFY_STAR_SALMON │ .bam_transcript   │ .counts_gene                │ DESEQ2_DIFFERENTIAL, WGCNA          │ PASS         │
  └──────────────────────┴───────────────────┴─────────────────────────────┴─────────────────────────────────────┴──────────────┘


  2. Advanced Analysis (New Modules)


  ┌───────────────────┬─────────────────────────────┬───────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Process           │ Input (Source)              │ Output (Emit) │ Audit Result / Notes                                                                                 │
  ├───────────────────┼─────────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ DEEPVARIANT       │ .bam, .bai (Aligned)        │ .vcf, .tbi    │ PASS (Local SIF confirmed)                                                                           │
  │ SNPEFF            │ .vcf (DeepVariant), db      │ .vcf          │ POTENTIAL ISSUE: vep_species is a string param, SNPEFF module expects path db. May need              │
  │                   │ (vep_species)               │ (Annotated)   │ file(params.vep_species).                                                                            │
  │ MAFTOOLS          │ .vcf (Annotated)            │ .plots        │ PASS                                                                                                 │
  │ RMATS             │ cond1, bams1, cond2, bams2, │ .txt          │ CRITICAL: The grouping logic in rnaseq.nf (lines 1150-1175) is a heuristic meta.id.split('_')[0].    │
  │                   │ gtf                         │               │ This depends strictly on naming conventions.                                                         │
  │ SASHIMIPLOT       │ .txt (RMATS), bams          │ .pdf          │ PASS                                                                                                 │
  │ DESEQ2_DIFF       │ .counts_gene, samplesheet   │ .results      │ PASS                                                                                                 │
  │ CLUSTERPROFILER   │ .results (DESEQ2)           │ .pdf, .csv    │ PASS                                                                                                 │
  │ REGULATORY_MINING │ .results (DESEQ2)           │ .pdf, .csv    │ PASS                                                                                                 │
  │ WGCNA             │ .counts_gene                │ .pdf, .csv    │ PASS                                                                                                 │
  │ STAR_FUSION       │ reads, genome_dir           │ .results      │ POTENTIAL ISSUE: Script assumes reads[0] and reads[1] (paired-end). Will fail on single-end samples. │
  └───────────────────┴─────────────────────────────┴───────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────┘

  ---

  Detailed Connection "Double-Check"

  1. Data Type Consistency:
   - Most processes correctly use tuple val(meta), path(file) or just path(file).
   - Warning: SNPEFF in workflows/rnaseq.nf is called with params.vep_species. In modules/local/snpeff.nf, it's defined as input: path db. If params.vep_species is just
     "homo_sapiens", Nextflow will try to find a file named "homo_sapiens".

  2. Channel Splitting/Joining:
   - DEEPVARIANT uses ch_genome_bam.join(ch_genome_bam_index, by: [0]). This is correct as it ensures the BAM and BAI for the same sample are paired.
   - RMATS input construction in rnaseq.nf uses a .groupTuple() which might collect many samples into one condition. The module RMATS then joins these paths with commas
     (bams1.join(',')), which is the correct format for rMATS --b1.

  3. Optional Outputs:
   - CLUSTERPROFILER and REGULATORY_MINING have optional: true for .csv outputs. This is safe.

  ---

  Suggestions for Improvement

   1. SNPEFF Fix: In workflows/rnaseq.nf, ensure the database input is handled correctly (either as a string or a file path depending on how snpEff is configured in your
      environment).
   2. STAR_FUSION Guard: Add a check to only run STAR_FUSION on paired-end reads, or update the module to handle single-end.
   3. RMATS Conditions: The condition parsing meta.id.split('_')[0] should ideally be based on a column in the samplesheet rather than ID parsing to be more robust.

  Do you want me to apply any fixes based on these observations (e.g., the SNPEFF path or STAR_FUSION paired-end check)?


  # conda environments:
#
base                     /mnt/gpfs/Users/yangjinxurong/software/miniconda3
gemini_env               /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/gemini_env
jdk17                    /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/jdk17
nextflow                 /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/nextflow
nf                       /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/nf
rnaseq                   /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq
rnaseq_advanced          /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq_advanced
rnaseq_final             /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq_final
rnaseq_gatk4             /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq_gatk4
rnaseq_rmats             /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq_rmats
rseqc                    /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rseqc
unicycler                /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/unicycler

/mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/rnaseq_advanced/lib/R/library


-[nf-core/rnaseq] Pipeline completed successfully -
WARN: Access to undefined parameter `email` -- Initialise it to a default value eg. `params.email = some_value`
WARN: Access to undefined parameter `email_on_fail` -- Initialise it to a default value eg. `params.email_on_fail = some_value`
Completed at: 23-Apr-2026 16:47:44
Duration    : 3m 5s
CPU hours   : 23.3 (98% cached)
Succeeded   : 9
Cached      : 70


+ STATUS=0
+ rm .sge_queue.config
+ echo ''

+ echo ======================================
======================================
++ date '+%Y-%m-%d %H:%M:%S'
+ echo '  结束时间: 2026-04-23 16:47:44'
  结束时间: 2026-04-23 16:47:44
+ [[ 0 -eq 0 ]]
+ echo '  状态: ✅ 成功'
  状态: ✅ 成功
+ echo ''

+ echo '  主要输出:'
  主要输出:
+ echo '  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/star/          比对 BAM'
  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/star/          比对 BAM
+ echo '  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/salmon/        Salmon 定量'
  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/salmon/        Salmon 定量
+ echo '  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/tximeta/       表达矩阵 (counts + TPM)'
  ├── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/tximeta/       表达矩阵 (counts + TPM)
+ echo '  └── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/multiqc/       综合 QC 报告'
  └── /mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent//results/20260423/multiqc/       综合 QC 报告
+ echo ======================================
======================================
+ exit 0

[07/89242e] process > NFCORE_RNASEQ:RNASEQ:PREPARE_GENOME:GUNZIP_GTF (gencode.v47.annotation.gtf.gz)                        [100%] 1 of 1, cached: 1 ✔
[f6/808dcf] process > NFCORE_RNASEQ:RNASEQ:PREPARE_GENOME:GTF2BED (gencode.v47.annotation.gtf)                              [100%] 1 of 1, cached: 1 ✔
[4c/09fe95] process > NFCORE_RNASEQ:RNASEQ:PREPARE_GENOME:CUSTOM_GETCHROMSIZES (hg38.fa)                                    [100%] 1 of 1, cached: 1 ✔
[12/86a552] process > NFCORE_RNASEQ:RNASEQ:INPUT_CHECK:SAMPLESHEET_CHECK (samplesheet_nfcore.csv)                           [100%] 1 of 1, cached: 1 ✔
[-        ] process > NFCORE_RNASEQ:RNASEQ:CAT_FASTQ                                                                        -
[de/6fa815] process > NFCORE_RNASEQ:RNASEQ:FASTQ_SUBSAMPLE_FQ_SALMON:FQ_SUBSAMPLE (CUDI50)                                  [100%] 1 of 1, cached: 1 ✔
[02/8ab45b] process > NFCORE_RNASEQ:RNASEQ:FASTQ_SUBSAMPLE_FQ_SALMON:SALMON_QUANT (CUDI50)                                  [100%] 1 of 1, cached: 1 ✔
[bd/cdba4b] process > NFCORE_RNASEQ:RNASEQ:FASTQ_FASTQC_UMITOOLS_TRIMGALORE:FASTQC (CUDI50)                                 [100%] 2 of 2, cached: 2 ✔
[cc/72a445] process > NFCORE_RNASEQ:RNASEQ:FASTQ_FASTQC_UMITOOLS_TRIMGALORE:TRIMGALORE (CUDI50)                             [100%] 2 of 2, cached: 2 ✔
[39/ff9e4c] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (CUDI50)                                                   [100%] 2 of 2, cached: 2 ✔
[ac/8d883a] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:BAM_SORT_STATS_SAMTOOLS:SAMTOOLS_SORT (CUDI50)                        [100%] 2 of 2, cached: 2 ✔
[72/034e56] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:BAM_SORT_STATS_SAMTOOLS:SAMTOOLS_INDEX (CUDI64)                       [100%] 2 of 2, cached: 2 ✔
[4a/b072b1] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:BAM_SORT_STATS_SAMTOOLS:BAM_STATS_SAMTOOLS:SAMTOOLS_STATS (CUDI50)    [100%] 2 of 2, cached: 2 ✔
[93/584d7b] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:BAM_SORT_STATS_SAMTOOLS:BAM_STATS_SAMTOOLS:SAMTOOLS_FLAGSTAT (CUDI64) [100%] 2 of 2, cached: 2 ✔
[0b/513e95] process > NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:BAM_SORT_STATS_SAMTOOLS:BAM_STATS_SAMTOOLS:SAMTOOLS_IDXSTATS (CUDI64) [100%] 2 of 2, cached: 2 ✔
[3a/5253c8] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_QUANT (CUDI50)                                       [100%] 2 of 2, cached: 2 ✔
[42/a0ce2e] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_TX2GENE (gencode.v47.annotation.gtf)                 [100%] 1 of 1, cached: 1 ✔
[28/30b3c7] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_TXIMPORT                                             [100%] 1 of 1, cached: 1 ✔
[21/4a24f6] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_SE_GENE (salmon_tx2gene.tsv)                         [100%] 1 of 1 ✔
[6c/08246b] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_SE_GENE_LENGTH_SCALED (salmon_tx2gene.tsv)           [100%] 1 of 1 ✔
[14/85f29d] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_SE_GENE_SCALED (salmon_tx2gene.tsv)                  [100%] 1 of 1 ✔
[06/2cb0d9] process > NFCORE_RNASEQ:RNASEQ:QUANTIFY_STAR_SALMON:SALMON_SE_TRANSCRIPT (salmon_tx2gene.tsv)                   [100%] 1 of 1 ✔
[dc/8ba8fe] process > NFCORE_RNASEQ:RNASEQ:DESEQ2_QC_STAR_SALMON                                                            [100%] 1 of 1 ✔
[11/ac1aac] process > NFCORE_RNASEQ:RNASEQ:BAM_MARKDUPLICATES_PICARD:PICARD_MARKDUPLICATES (CUDI50)                         [100%] 2 of 2, cached: 2 ✔
[85/93b42f] process > NFCORE_RNASEQ:RNASEQ:BAM_MARKDUPLICATES_PICARD:SAMTOOLS_INDEX (CUDI64)                                [100%] 2 of 2, cached: 2 ✔
[6e/89ed54] process > NFCORE_RNASEQ:RNASEQ:BAM_MARKDUPLICATES_PICARD:BAM_STATS_SAMTOOLS:SAMTOOLS_STATS (CUDI50)             [100%] 2 of 2, cached: 2 ✔
[3e/b94df5] process > NFCORE_RNASEQ:RNASEQ:BAM_MARKDUPLICATES_PICARD:BAM_STATS_SAMTOOLS:SAMTOOLS_FLAGSTAT (CUDI50)          [100%] 2 of 2, cached: 2 ✔
[7f/5e3035] process > NFCORE_RNASEQ:RNASEQ:BAM_MARKDUPLICATES_PICARD:BAM_STATS_SAMTOOLS:SAMTOOLS_IDXSTATS (CUDI64)          [100%] 2 of 2, cached: 2 ✔
[03/4e118f] process > NFCORE_RNASEQ:RNASEQ:STRINGTIE_STRINGTIE (CUDI50)                                                     [100%] 2 of 2, cached: 2 ✔
[17/218450] process > NFCORE_RNASEQ:RNASEQ:GFFCOMPARE (Boundary_Optimization)                                               [100%] 2 of 2 ✔
[cb/ef11ef] process > NFCORE_RNASEQ:RNASEQ:SUBREAD_FEATURECOUNTS (CUDI50)                                                   [100%] 2 of 2, cached: 2 ✔
[6d/b20c74] process > NFCORE_RNASEQ:RNASEQ:MULTIQC_CUSTOM_BIOTYPE (CUDI64)                                                  [100%] 2 of 2, cached: 2 ✔
[49/e7fe1c] process > NFCORE_RNASEQ:RNASEQ:BEDTOOLS_GENOMECOV (CUDI50)                                                      [100%] 2 of 2, cached: 2 ✔
[af/117ac7] process > NFCORE_RNASEQ:RNASEQ:BEDGRAPH_BEDCLIP_BEDGRAPHTOBIGWIG_FORWARD:UCSC_BEDCLIP (CUDI64)                  [100%] 2 of 2, cached: 2 ✔
[3f/a1169b] process > NFCORE_RNASEQ:RNASEQ:BEDGRAPH_BEDCLIP_BEDGRAPHTOBIGWIG_FORWARD:UCSC_BEDGRAPHTOBIGWIG (CUDI64)         [100%] 2 of 2, cached: 2 ✔
[09/2d6927] process > NFCORE_RNASEQ:RNASEQ:BEDGRAPH_BEDCLIP_BEDGRAPHTOBIGWIG_REVERSE:UCSC_BEDCLIP (CUDI50)                  [100%] 2 of 2, cached: 2 ✔
[10/6e89ea] process > NFCORE_RNASEQ:RNASEQ:BEDGRAPH_BEDCLIP_BEDGRAPHTOBIGWIG_REVERSE:UCSC_BEDGRAPHTOBIGWIG (CUDI50)         [100%] 2 of 2, cached: 2 ✔
[b9/750c57] process > NFCORE_RNASEQ:RNASEQ:QUALIMAP_RNASEQ (CUDI50)                                                         [100%] 2 of 2, cached: 2 ✔
[57/d64621] process > NFCORE_RNASEQ:RNASEQ:DUPRADAR (CUDI50)                                                                [100%] 2 of 2, cached: 2 ✔
[35/ff5c0b] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_BAMSTAT (CUDI50)                                                 [100%] 2 of 2, cached: 2 ✔
[35/2aeeda] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_INNERDISTANCE (CUDI64)                                           [100%] 2 of 2, cached: 2 ✔
[92/a4e35b] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_INFEREXPERIMENT (CUDI64)                                         [100%] 2 of 2, cached: 2 ✔
[17/d0f052] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_JUNCTIONANNOTATION (CUDI64)                                      [100%] 2 of 2, cached: 2 ✔
[96/fae899] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_JUNCTIONSATURATION (CUDI50)                                      [100%] 2 of 2, cached: 2 ✔
[be/adb5c0] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_READDISTRIBUTION (CUDI50)                                        [100%] 2 of 2, cached: 2 ✔
[57/16d1d2] process > NFCORE_RNASEQ:RNASEQ:BAM_RSEQC:RSEQC_READDUPLICATION (CUDI50)                                         [100%] 2 of 2, cached: 2 ✔
[d3/1e6532] process > NFCORE_RNASEQ:RNASEQ:CUSTOM_DUMPSOFTWAREVERSIONS (1)                                                  [100%] 1 of 1 ✔
[87/525065] process > NFCORE_RNASEQ:RNASEQ:MULTIQC (1) 
#!/bin/bash
# =============================================================================
# submit_sge.sh  —  sge/Torque 集群提交 RNA-seq 流程（无容器模式）
#


set -ex pipefail
mkdir -p logs

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                    == 用户配置区（必须修改）==                       ║
# ╚══════════════════════════════════════════════════════════════════════╝

# 流程目录（本文件所在目录的绝对路径）
PIPELINE_DIR="/mnt/gpfs/Users/yangjinxurong/projects/rnaseq_subsequent/"  # ← 修改为实际路径

# 样品表
INPUT="${PIPELINE_DIR}/assets/samplesheet.csv"
NFCORE_INPUT="${PIPELINE_DIR}/assets/samplesheet_nfcore.csv"

# 输出目录
OUTDIR="${PIPELINE_DIR}/results/20260423"   # ← 修改为实际路径

# sge 队列名（与 #sge -q 保持一致）
sge_QUEUE="RAM"                                # ← 修改

# ── 打印运行信息 ──────────────────────────────────────────────────────────────
echo "======================================"
echo "  RNA-seq Pipeline - sge 集群投递"
echo "======================================"
echo "  作业 ID   : ${sge_JOBID:-'(本地运行)'}"
echo "  节点      : $(hostname)"
echo "  开始时间  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  流程目录  : ${PIPELINE_DIR}"
echo "  样品表    : ${INPUT}"
echo "  输出目录  : ${OUTDIR}"
echo "======================================"

# ── 构建 Nextflow 可选参数 ────────────────────────────────────────────────────
export NXF_PLUGINS_DIR="$(pwd)/.nextflow_plugins"
# ── 准备适配 nf-core 标准的 samplesheet ───────────────────────────────────────
source /mnt/gpfs/Users/yangjinxurong/software/miniconda3/bin/activate /mnt/gpfs/Users/yangjinxurong/software/miniconda3/envs/nextflow
# python3 "${PIPELINE_DIR}/scripts/prep_nfcore_samplesheet.py" "${INPUT}" "${NFCORE_INPUT}"

# ── 启动 Nextflow ─────────────────────────────────────────────────────────────
# 创建临时配置文件以适配不同 Shell（解决 sh 不支持 <() 的问题）
echo "process.queue = '${sge_QUEUE}'" > .sge_queue.config

nextflow run main.nf \
    -resume \
    -offline \
    -params-file "${PIPELINE_DIR}/params.yaml" \
    -w "${PIPELINE_DIR}/work" \
    -c "${PIPELINE_DIR}/conf/nfcore_custom.config" \
    -c "${PIPELINE_DIR}/softwaredb.config" \
    -c .sge_queue.config \
    -with-trace 

STATUS=$?
rm .sge_queue.config
echo ""
echo "======================================"
echo "  结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
if [[ $STATUS -eq 0 ]]; then
    echo "  状态: ✅ 成功"
    echo ""
    echo "  主要输出:"
    echo "  ├── ${OUTDIR}/star/          比对 BAM"
    echo "  ├── ${OUTDIR}/salmon/        Salmon 定量"
    echo "  ├── ${OUTDIR}/tximeta/       表达矩阵 (counts + TPM)"
    echo "  └── ${OUTDIR}/multiqc/       综合 QC 报告"
else
    echo "  状态: ❌ 失败 (exit $STATUS)"
    echo "  运行日志: ${OUTDIR}/pipeline_info/"
    echo "  错误定位: nextflow log 或 work/ 目录下对应任务的 .command.err"
fi
echo "======================================"
exit $STATUS

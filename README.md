<div align="center">

# 🔊 Acoustic Monitoring in Laser Additive Manufacturing

<a href="#en">
<img src="https://img.shields.io/badge/lang-English-blue?style=for-the-badge" alt="English">
</a>
<a href="#zh">
<img src="https://img.shields.io/badge/lang-中文-red?style=for-the-badge" alt="中文">
</a>

</div>

---

<!-- ==================== ENGLISH VERSION ==================== -->

<details open id="en">
<summary><h2>🇬🇧 English Version (Click to expand/collapse)</h2></summary>

## Project Overview

> **NUS ME5106 Mini Project — Option 3**

This project investigates the relationship between **manufacturing parameters** (laser power & scan speed) and **acoustic signals** captured during laser powder bed fusion (LPBF) additive manufacturing. Using data-driven / machine learning approaches, we extract features from acoustic waveforms and build regression models to **predict unknown Power and Speed values** from the acoustic signal alone.

**Goal:** Average prediction error < 20% with a reasonable, reproducible methodology.

## Data Description

| Item | Detail |
|------|--------|
| Raw acoustic signals | 40 single-track segments: A1–A13, B1–B13, C1–C14 |
| Sampling rate | 128 kHz |
| Known labels | Power (W) and Speed (mm/s) for most segments |
| Unknown — Power | C9, C13, C14 |
| Unknown — Speed | B10, C14 |
| Source files | `SingleTrack_RawData.mat`, `SingleTrack_Denoise.mat`, `SingleTrack_Division.mat` |

## Pipeline

```
┌──────────────────┐     ┌─────────────────────┐     ┌──────────────────────────┐
│  params.csv      │     │ SingleTrack_Division │     │  Extract_Features.m      │
│  (Power & Speed) │     │       .mat           │     │  → features.mat / .csv   │
└────────┬─────────┘     └──────────┬───────────┘     └────────────┬─────────────┘
         │                         │                               │
         │                         └──────────┐                    │
         │                                    ▼                    │
         │                         ┌─────────────────────┐         │
         └────────────────────────►│  Merge_Features.m   │◄────────┘
                                   │  → merged_features  │
                                   │    .mat / .csv      │
                                   └──────────┬──────────┘
                                              │
                                              ▼
                                   ┌──────────────────────────────┐
                                   │ Feature_Select_TopK_Grid.m   │
                                   │ → top_combos_power_k3.csv    │
                                   │ → top_combos_speed_k3.csv    │
                                   └──────────┬───────────────────┘
                                              │
                                   ┌──────────┴───────────┐
                                   ▼                      ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ Regression     │    │ Regression     │
                          │ Learner App    │    │ Learner App    │
                          │ (Power model)  │    │ (Speed model)  │
                          └───────┬────────┘    └───────┬────────┘
                                  │                     │
                                  ▼                     ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ Predict_Power  │    │ Predict_Speed  │
                          │ .m             │    │ .m             │
                          └───────┬────────┘    └───────┬────────┘
                                  │                     │
                                  ▼                     ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ pred_power.csv │    │ pred_speed.csv │
                          └────────────────┘    └────────────────┘
```

## Step-by-Step Workflow

### Step 1 — Prepare Labels (`params.csv`)

Manually create `params.csv` containing `Signal`, `Power`, and `Speed` columns. Leave cells blank for unknown values (e.g., C9 Power, B10 Speed, C14 both).

### Step 2 — Extract Features (`Extract_Features.m`)

Loads each segment from `SingleTrack_Division.mat`, applies:
- DC removal (detrend)
- 6th-order Butterworth high-pass filter (cutoff 800 Hz)
- Auto-trim to active region (amplitude threshold 10%)

Then computes **19 features** per segment:

| Category | Features |
|----------|----------|
| **Time-domain** | Duration, RMS, Peak-to-Peak, Crest Factor, Skewness, Kurtosis, Zero-Crossing Rate |
| **Frequency-domain** | Main Frequency, Peak Amplitude, Spectral Centroid, Bandwidth, Total Energy, Spectral Entropy |
| **Band Energies** | 0–5 kHz, 5–10 kHz, 10–20 kHz, 20–40 kHz, 40–64 kHz, High/Low Band Ratio |

**Outputs:** `features.mat`, `features.csv`

### Step 3 — Merge Features with Labels (`Merge_Features.m`)

Left-joins `featuresTbl` with `params.csv` on `Signal`, producing a unified table `T` where unlabelled samples have `NaN` in Power/Speed.

**Outputs:** `merged_features.mat`, `merged_features.csv`

### Step 4 — Feature Selection (`Feature_Select_TopK_Grid.m`)

Exhaustive grid search over all 3-feature combinations:
- Pre-screens candidates by correlation with target, retains top 16
- De-collinearization (removes pairs with |r| > 0.90)
- 5-fold cross-validation with robust linear regression
- Ranks combos by RMSE

**Best 3-feature subsets:**

| Target | Features | CV RMSE | CV MAPE (%) | CV R² |
|--------|----------|---------|-------------|-------|
| **Power** | `Duration_s`, `PeakToPeak`, `ZeroCrossRate_Hz` | 57.35 | 17.43 | 0.524 |
| **Speed** | `PeakAmp`, `Bandwidth_Hz`, `SpectralEntropy` | 227.88 | 29.39 | 0.806 |

**Outputs:** `top_combos_power_k3.csv`, `top_combos_speed_k3.csv`, `top_combo_results.mat`

### Step 5 — Train Models (MATLAB Regression Learner App)

1. Open **Apps → Regression Learner → New Session → From Workspace**
2. Select `T` (from `merged_features.mat`), set Response to `Power` (or `Speed`)
3. Choose only the 3 selected features as Predictors
4. Enable **Standardize**, set Validation to **5-Fold**
5. Train a **Linear** model; export the best model to workspace (e.g., `mdlPower`, `mdlSpeed`)
6. Save sessions: `RegressionLearnerSession_48_power.mat`, `RegressionLearnerSession_141_speed.mat`

### Step 6 — Predict Unknown Samples

**`Predict_Power.m`** — Predicts Power for C9, C13, C14:

| Signal | Predicted Power (W) |
|--------|---------------------|
| C9     | 312.85              |
| C13    | 398.59              |
| C14    | 330.94              |

**`Predict_Speed.m`** — Predicts Speed for B10, C14:

| Signal | Predicted Speed (mm/s) |
|--------|------------------------|
| B10    | 1021.62                |
| C14    | 819.39                 |

**Outputs:** `pred_power.csv`, `pred_speed.csv`, `merged_features_with_preds.csv`, `merged_features_with_preds.mat`

## File Structure

```
acoustic monitoring/
├── SingleTrack_RawData.mat          # Raw acoustic waveforms
├── SingleTrack_Denoise.mat          # Denoised waveforms
├── SingleTrack_Division.mat         # Segmented single-track signals
│
├── params.csv                       # Ground-truth Power & Speed labels
├── Extract_Features.m               # Feature extraction script
├── features.mat / .csv              # Extracted features (19 per segment)
│
├── Merge_Features.m                 # Merge features with labels
├── merged_features.mat / .csv       # Merged table
│
├── Feature_Select_TopK_Grid.m       # Grid-search feature selection
├── top_combos_power_k3.csv          # Ranked Power feature combos
├── top_combos_speed_k3.csv          # Ranked Speed feature combos
├── top_combo_results.mat            # Feature selection results
│
├── RegressionLearnerSession_48_power.mat   # Saved Regression Learner session (Power)
├── RegressionLearnerSession_141_speed.mat  # Saved Regression Learner session (Speed)
│
├── Predict_Power.m                  # Predict unknown Power values
├── Predict_Speed.m                  # Predict unknown Speed values
├── pred_power.csv                   # Power predictions
├── pred_speed.csv                   # Speed predictions
│
├── merged_features_with_preds.mat   # Final table with predictions filled in
├── merged_features_with_preds.csv   # Final table (CSV export)
└── README.md                        # This file
```

## Requirements

- **MATLAB** R2020b or later
- **Statistics and Machine Learning Toolbox** (for `fitlm`, Regression Learner App)
- **Signal Processing Toolbox** (for `butter`, `filtfilt`)

## How to Reproduce

```matlab
% 1. Place all .mat data files in the working directory
% 2. Prepare params.csv with known Power & Speed values

% 3. Extract features
run('Extract_Features.m')

% 4. Merge features with labels
run('Merge_Features.m')

% 5. Feature selection (grid search)
run('Feature_Select_TopK_Grid.m')

% 6. Open Regression Learner App, train models, export mdlPower & mdlSpeed

% 7. Predict unknown samples
run('Predict_Power.m')
run('Predict_Speed.m')
```

## Methodology Summary

- **Signal preprocessing:** High-pass filtering (800 Hz cutoff) + auto-trimming to active regions
- **Feature engineering:** 19 time/frequency-domain features per acoustic segment
- **Feature selection:** Exhaustive K=3 combinatorial search with 5-fold CV robust linear regression
- **Model training:** MATLAB Regression Learner (standardized linear models, 5-fold CV)
- **Prediction:** Exported trained models applied to unlabelled segments

</details>

---

<!-- ==================== CHINESE VERSION ==================== -->

<details id="zh">
<summary><h2>🇨🇳 中文版本（点击展开/折叠）</h2></summary>

## 项目概述

> **NUS ME5106 Mini Project — Option 3**

本项目研究**激光粉末床熔融（LPBF）增材制造**过程中，**制造参数**（激光功率 Power & 扫描速度 Speed）与**声学信号**之间的关系。通过数据驱动/机器学习方法，从声学波形中提取特征并构建回归模型，**仅凭声学信号预测未知的 Power 和 Speed 值**。

**目标：** 平均预测误差 < 20%，方法合理、可复现。

## 数据说明

| 项目 | 详情 |
|------|------|
| 原始声学信号 | 40 段单道信号：A1–A13、B1–B13、C1–C14 |
| 采样率 | 128 kHz |
| 已知标签 | 大部分信号段的 Power (W) 和 Speed (mm/s) |
| 未知 — Power | C9、C13、C14 |
| 未知 — Speed | B10、C14 |
| 数据源文件 | `SingleTrack_RawData.mat`、`SingleTrack_Denoise.mat`、`SingleTrack_Division.mat` |

## 处理流程

```
┌──────────────────┐     ┌─────────────────────┐     ┌──────────────────────────┐
│  params.csv      │     │ SingleTrack_Division │     │  Extract_Features.m      │
│  (Power & Speed) │     │       .mat           │     │  → features.mat / .csv   │
└────────┬─────────┘     └──────────┬───────────┘     └────────────┬─────────────┘
         │                         │                               │
         │                         └──────────┐                    │
         │                                    ▼                    │
         │                         ┌─────────────────────┐         │
         └────────────────────────►│  Merge_Features.m   │◄────────┘
                                   │  → merged_features  │
                                   │    .mat / .csv      │
                                   └──────────┬──────────┘
                                              │
                                              ▼
                                   ┌──────────────────────────────┐
                                   │ Feature_Select_TopK_Grid.m   │
                                   │ → top_combos_power_k3.csv    │
                                   │ → top_combos_speed_k3.csv    │
                                   └──────────┬───────────────────┘
                                              │
                                   ┌──────────┴───────────┐
                                   ▼                      ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ Regression     │    │ Regression     │
                          │ Learner App    │    │ Learner App    │
                          │ (Power 模型)   │    │ (Speed 模型)   │
                          └───────┬────────┘    └───────┬────────┘
                                  │                     │
                                  ▼                     ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ Predict_Power  │    │ Predict_Speed  │
                          │ .m             │    │ .m             │
                          └───────┬────────┘    └───────┬────────┘
                                  │                     │
                                  ▼                     ▼
                          ┌────────────────┐    ┌────────────────┐
                          │ pred_power.csv │    │ pred_speed.csv │
                          └────────────────┘    └────────────────┘
```

## 详细步骤

### 第 1 步 — 准备标签文件 (`params.csv`)

手动创建 `params.csv`，包含 `Signal`、`Power`、`Speed` 三列。未知值留空（如 C9 的 Power、B10 的 Speed、C14 两者均未知）。

### 第 2 步 — 提取特征 (`Extract_Features.m`)

从 `SingleTrack_Division.mat` 加载每段信号，依次进行：
- 去直流（detrend）
- 6 阶 Butterworth 高通滤波（截止频率 800 Hz）
- 自动裁剪至有效区域（幅值阈值 10%）

然后计算每段信号的 **19 个特征**：

| 类别 | 特征 |
|------|------|
| **时域** | 持续时间、RMS、峰峰值、峰值因子、偏度、峰度、过零率 |
| **频域** | 主频率、峰值幅度、频谱质心、带宽、总能量、频谱熵 |
| **频段能量** | 0–5 kHz、5–10 kHz、10–20 kHz、20–40 kHz、40–64 kHz、高低频段能量比 |

**输出：** `features.mat`、`features.csv`

### 第 3 步 — 合并特征与标签 (`Merge_Features.m`)

以 `Signal` 为键，将 `featuresTbl` 与 `params.csv` 进行左连接，生成统一表 `T`。未标注的样本在 Power/Speed 列为 `NaN`。

**输出：** `merged_features.mat`、`merged_features.csv`

### 第 4 步 — 特征选择 (`Feature_Select_TopK_Grid.m`)

对所有 3 特征组合进行穷举网格搜索：
- 按与目标的相关性预筛选，保留前 16 个候选
- 去共线性（剔除 |r| > 0.90 的冗余特征对）
- 5 折交叉验证 + 鲁棒线性回归
- 按 RMSE 从小到大排序

**最优 3 特征组合：**

| 目标 | 特征组合 | CV RMSE | CV MAPE (%) | CV R² |
|------|----------|---------|-------------|-------|
| **Power** | `Duration_s`、`PeakToPeak`、`ZeroCrossRate_Hz` | 57.35 | 17.43 | 0.524 |
| **Speed** | `PeakAmp`、`Bandwidth_Hz`、`SpectralEntropy` | 227.88 | 29.39 | 0.806 |

**输出：** `top_combos_power_k3.csv`、`top_combos_speed_k3.csv`、`top_combo_results.mat`

### 第 5 步 — 训练模型（MATLAB Regression Learner App）

1. 打开 **Apps → Regression Learner → New Session → From Workspace**
2. 选择 `T`（来自 `merged_features.mat`），Response 设为 `Power`（或 `Speed`）
3. Predictors 仅勾选上面选出的 3 个特征
4. 勾选 **Standardize**，Validation 设为 **5-Fold**
5. 训练 **Linear** 模型，导出最佳模型到工作区（如 `mdlPower`、`mdlSpeed`）
6. 保存会话：`RegressionLearnerSession_48_power.mat`、`RegressionLearnerSession_141_speed.mat`

### 第 6 步 — 预测未知样本

**`Predict_Power.m`** — 预测 C9、C13、C14 的功率：

| 信号 | 预测功率 (W) |
|------|-------------|
| C9   | 312.85      |
| C13  | 398.59      |
| C14  | 330.94      |

**`Predict_Speed.m`** — 预测 B10、C14 的速度：

| 信号 | 预测速度 (mm/s) |
|------|----------------|
| B10  | 1021.62        |
| C14  | 819.39         |

**输出：** `pred_power.csv`、`pred_speed.csv`、`merged_features_with_preds.csv`、`merged_features_with_preds.mat`

## 文件结构

```
acoustic monitoring/
├── SingleTrack_RawData.mat          # 原始声学波形
├── SingleTrack_Denoise.mat          # 降噪后波形
├── SingleTrack_Division.mat         # 切分后的单道信号
│
├── params.csv                       # 已知 Power & Speed 标签
├── Extract_Features.m               # 特征提取脚本
├── features.mat / .csv              # 提取的特征（每段 19 个）
│
├── Merge_Features.m                 # 合并特征与标签
├── merged_features.mat / .csv       # 合并后的表
│
├── Feature_Select_TopK_Grid.m       # 网格搜索特征选择
├── top_combos_power_k3.csv          # Power 特征组合排名
├── top_combos_speed_k3.csv          # Speed 特征组合排名
├── top_combo_results.mat            # 特征选择结果
│
├── RegressionLearnerSession_48_power.mat   # Regression Learner 会话（Power）
├── RegressionLearnerSession_141_speed.mat  # Regression Learner 会话（Speed）
│
├── Predict_Power.m                  # 预测未知 Power
├── Predict_Speed.m                  # 预测未知 Speed
├── pred_power.csv                   # Power 预测结果
├── pred_speed.csv                   # Speed 预测结果
│
├── merged_features_with_preds.mat   # 包含预测值的最终表
├── merged_features_with_preds.csv   # 最终表（CSV 导出）
└── README.md                        # 本文件
```

## 运行环境

- **MATLAB** R2020b 或更高版本
- **Statistics and Machine Learning Toolbox**（`fitlm`、Regression Learner App）
- **Signal Processing Toolbox**（`butter`、`filtfilt`）

## 如何复现

```matlab
% 1. 将所有 .mat 数据文件放在工作目录下
% 2. 准备 params.csv（填入已知的 Power & Speed 值）

% 3. 提取特征
run('Extract_Features.m')

% 4. 合并特征与标签
run('Merge_Features.m')

% 5. 特征选择（网格搜索）
run('Feature_Select_TopK_Grid.m')

% 6. 打开 Regression Learner App，训练模型，导出 mdlPower & mdlSpeed

% 7. 预测未知样本
run('Predict_Power.m')
run('Predict_Speed.m')
```

## 方法总结

- **信号预处理：** 高通滤波（800 Hz 截止）+ 自动裁剪至有效区域
- **特征工程：** 每段声学信号提取 19 个时域/频域特征
- **特征选择：** K=3 穷举组合搜索 + 5 折交叉验证鲁棒线性回归
- **模型训练：** MATLAB Regression Learner（标准化线性模型，5 折 CV）
- **预测：** 导出训练好的模型，应用于未标注信号段

</details>

# 🏥 CCG & GP Professional Dashboard

本项目是一个基于 **R Shiny** 构建的交互式可视化仪表板，用于展示各地区（CCG）及诊所（GP / Practice）在不同年度的健康指标表现，包括 **患病率（Prevalence）**、**达标率（Achievement）** 和 **COPD 指标详情**。

---

## 📦 1. 项目结构

```
📁 project/
│
├── shiny_dashboard_full_data.R    # 主应用脚本（运行此文件即可）
├── Full_Data.csv                  # 原始数据集
├── ccg map/                       # 存放 CCG 边界 shapefile（用于地图）
└── www/
    └── static/gp_tmap.html        # 地图文件（自动生成）
```

---

## 🚀 2. 运行方式

### 方法一：在 RStudio 中直接运行
1. 打开 `111.R`  
2. 确保最后一行是：
   ```r
   shinyApp(ui = ui, server = server)
   ```
3. 点击 **Run App** 或运行命令：
   ```r
   source('shiny_dashboard_full_data.R')
   ```
4. 浏览器将自动打开：
   ```
   http://127.0.0.1:xxxx
   ```
   （xxxx 是端口号）

### 方法二：命令行运行
```r
shiny::runApp('路径到你的项目文件夹')
```

---

## 🧭 3. 界面说明

### 🔹 左侧导航栏
| 菜单项 | 功能 |
|--------|------|
| **CCG** | 查看各 CCG 的患病率分布（2020–2021 与 2021–2022 年） |
| **GP** | 查看诊所层面的达标率变化与 COPD 指标详情 |
| **Map** | 显示各 CCG 的 GP 数量地图（交互式） |
| **Table** | 查看核心指标数据表并支持筛选过滤 |

---

## 🧩 4. 各页面详细说明

### 🏢 CCG 页面
- 选择 CCG 代码（`CCG-Code`）后，会显示该区域内所有诊所的 **患病率分布**。
- 每个点表示一个诊所。
- 盒须图展示中位数与四分位差。
- 鼠标悬停可查看诊所代码。

### 🩺 GP 页面
- `Achivement Score` 图展示诊所达标率的年度变化。
- `COPD 008` 图展示三项 COPD 相关指标的最低值诊所：
  - Achievement Score  
  - Achievement Net of PCA  
  - Patients Receiving Intervention %

### 🗺️ Map 页面
- 显示各 CCG 的 GP 数量空间分布。
- 颜色越深表示 GP 数量越多。
- 点击区域可查看 CCG 名称。

### 📊 Table 页面
- 可交互筛选数据（顶部 filter 即为筛选器）。
- 支持分页、搜索、列过滤。

---

## 🔍 5. Filter（筛选器）说明

| 筛选器名称 | 说明 |
|-------------|------|
| **CCG-Code (CCG 页面)** | 选择要展示的 CCG（可多选） |
| **CCGs-Code (GP 页面)** | 选择参与达标率比较的 CCG（可多选） |
| **CCG-Code (GP 页面)** | 选择单个 CCG 查看 COPD 指标（单选） |

🧠 **Filter 的本质：**
> 在 Shiny 中，filter 是让用户在前端筛选要看的数据，后端用 `filter()` 函数只保留符合条件的行再绘图。  
> 这样图表是动态更新的，不同选择对应不同结果。

---

## 📈 6. 数据来源与字段说明

数据文件：`Full_Data.csv`  
关键字段：

| 字段名 | 含义 |
|---------|------|
| `CCG Code` / `CCG Name` | 区域代码与名称 |
| `Practice_code` | 诊所代码 |
| `Prevalence_2020_21` / `Prevalence_2021_22` | 各年度患病率 |
| `Achievement_2020_21` / `Achievement_2021_22` | 各年度达标率 |
| `COPD008_Achievement_Score` | COPD008 得分 |
| `COPD008_Achievement_net_of_PCA` | COPD008 扣除 PCA 后的得分 |
| `COPD008_Patients_receiving_Intervention_percentage` | 接受干预患者比例 |

---

## ⚙️ 7. 依赖包

运行前需安装以下包：
```r
install.packages(c(
  "tidyverse", "readr", "janitor", "plotly",
  "patchwork", "DT", "sf", "tmap",
  "shiny", "shinydashboard", "htmltools"
))
```

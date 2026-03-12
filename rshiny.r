# Shiny 仪表盘脚本（适配 Full_Data.csv，主维度为 CCG）

library(tidyverse)
library(readr)
library(janitor)
library(plotly)
library(patchwork)
library(DT)
library(sf)
library(tmap)
library(shiny)
library(shinydashboard)
library(htmltools)



# -----------------------------
# 1. 读取数据（CSV）
# -----------------------------
data <- read_csv("Full_Data.csv", na = c("NA", "")) %>%
  clean_names()

# -----------------------------
# 2. 列名标准化 + 基础字段准备
# -----------------------------
data <- data %>%
  rename(
    ccg_code = ccg_code,
    ccg_name = ccg_name,
    practice_code = practice_code,
    practice_name = practice_name
  ) %>%
  
  arrange(ccg_code, ccg_name) %>%
  group_by(ccg_code) %>%
  fill(ccg_name, .direction = "down") %>%
  ungroup() %>%
  
  mutate(
    ccg_name = str_remove(ccg_name, " CCG$"),
    ccg = str_c(ccg_code, ccg_name, sep = "-")
  )

# -----------------------------
# 3. 构建长表（Prevalence & Achievement）
# -----------------------------
prevalence_data <- data %>%
  select(practice_code, ccg_code, ccg, prevalence_2020_21, prevalence_2021_22) %>%
  pivot_longer(cols = c(prevalence_2020_21, prevalence_2021_22), names_to = 'year', values_to = 'value') %>%
  mutate(year = case_when(
    year == 'prevalence_2020_21' ~ '2020-2021',
    year == 'prevalence_2021_22' ~ '2021-2022'
  ),
  year = as.factor(year))

achievement_data <- data %>%
  select(ccg_code, ccg, practice_code, achievement_2020_21, achievement_2021_22) %>%
  pivot_longer(cols = c(achievement_2020_21, achievement_2021_22), names_to = 'year', values_to = 'value') %>%
  mutate(year = case_when(
    year == 'achievement_2020_21' ~ '2020-2021',
    year == 'achievement_2021_22' ~ '2021-2022'
  ),
  year = as.factor(year))

# -----------------------------
# 4. COPD008 数据
# -----------------------------
copd008_data <- data %>%
  select(
    practice_code,
    ccg_code,
    copd008_achievement_score,
    copd008_achievement_net_of_pca,
    copd008_patients_receiving_intervention_percentage
  )

# -----------------------------
# 5. UI
# -----------------------------
ui <- dashboardPage(
  
  # -----------------------------
  # 1. Header：NHS Digital 风格
  # -----------------------------
  header = dashboardHeader(
    title = div(
      class = "app-title",
      span("Professional Dashboard")         # 主标题
    ),
    titleWidth = 0
  ),
  
  # -----------------------------
  # 2. Sidebar：只做导航
  # -----------------------------
  sidebar = dashboardSidebar(
    width = 160,
    sidebarMenu(
      id = "tabs",
      menuItem("CCG",   tabName = "ccg",   icon = icon("users-cog")),
      menuItem("GP",    tabName = "gp",    icon = icon("user-md")),
      menuItem("MAP",   tabName = "map",   icon = icon("map-marked-alt")),
      menuItem("TABLE", tabName = "table", icon = icon("table"))
    )
  ),
  
  # -----------------------------
  # 3. Body：样式 + 各个 tab
  # -----------------------------
  body = dashboardBody(
    
    # ===== 全局样式（包括“删除浅蓝条”和 NHS 风格） =====
    tags$head(tags$style(HTML("
    
      .content-wrapper, .right-side {
        background-color: #EDFFF0 !important;
      }
      
      /* 顶部 header 整体高度和阴影 */
      .main-header {
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }

      /* 只保留 logo 区域，居中显示标题 */
      .main-header .logo {
        background-color: #005EB8 !important;
        width: 100% !important;
        text-align: center !important;
        float: none !important;
        padding: 8px 0;
        height: 40px !important;   /* 从 54px 改成 40px */
        line-height: 24px;         /* 让标题垂直居中 */
      }

      /* 删除下面多出来的浅蓝 navbar */
      .main-header .navbar {
        display: none !important;
      }

      /* 隐藏左上角汉堡按钮 */
      .main-header .navbar .sidebar-toggle {
        display: none !important;
      }

      /* 标题文字样式（主标题 + 副标题） */
      .app-title {
        color: #ffffff;
        line-height: 1.2;
      }
      .app-title span {
        font-size: 20px;
        font-weight: 600;
        letter-spacing: 0.5px;
      }
      .app-title small {
        font-size: 12px;
        font-weight: 400;
        opacity: 0.9;
      }

      /* 内容区域背景 */
      .content-wrapper, .right-side { 
        background-color: #f3f4f8;
      }

      /* Box 头部 NHS 蓝 + 轻盈外观 */
      .box.box-solid.box-success > .box-header { 
        color: #ffffff; 
        background: #005EB8;
      }
      .box.box-solid.box-success { 
        border: none; 
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
      }

      /* 侧边栏样式（暗色 + 高亮选中项） */
      .main-sidebar { 
        background-color: #111827;   /* 深灰接近 NHS UI */
      }
      .sidebar-menu > li > a { 
        color: #e5e7eb; 
        font-size: 20px;
      }
      .sidebar-menu > li.active > a,
      .sidebar-menu > li > a:hover {
        background-color: #1f2937;
        color: #ffffff;
      }

      /* Tab 选项卡（如果你之后加 tabBox 用得到） */
      .nav-tabs-custom > .nav-tabs > li.active > a {
        background-color: #0072CE; 
        color: #ffffff; 
        border: none;
      }
      .nav-tabs-custom > .nav-tabs > li > a {
        border: none;
      }
    "))),
    
    # ===== 各个 tab 的布局 =====
    tabItems(
      
      # ---------- CCG Tab ----------
      tabItem(
        tabName = "ccg",
        fluidRow(
          box(
            title = "Filters",
            status = "success", solidHeader = TRUE,
            width = 3,
            selectInput(
              "ccg_ccg_code", "CCG-Code:",
              choices  = unique(na.omit(data$ccg_code)),
              selected = head(unique(na.omit(data$ccg_code)), 4),
              multiple = TRUE
            )
          ),
          box(
            title = "Prevalence by CCG",
            status = "success", solidHeader = TRUE,
            width = 9,
            plotlyOutput("prevalence", height = "700px")
          )
        )
      ),
      
      # ---------- GP Tab ----------
      tabItem(
        tabName = "gp",
        fluidRow(
          box(
            title = "Filters",
            status = "success", solidHeader = TRUE,
            width = 3,
            height = "410px",
            selectInput(
              "gp_ccgs_code", "CCGs-Code (Achievement):",
              choices  = unique(na.omit(data$ccg_code)),
              selected = head(unique(na.omit(data$ccg_code)), 4),
              multiple = TRUE
            ),
            
            div(
              style = "margin-top: 100px;",
              selectInput(
                "gp_ccg_code", "CCG-Code (COPD 008):",
                choices  = unique(na.omit(data$ccg_code)),
                selected = unique(na.omit(data$ccg_code))[1],
                multiple = FALSE
              )
          )),
          box(
            title = "Achievement Score (Patient Satisfaction)",
            status = "success", solidHeader = TRUE,
            width = 9,
            plotlyOutput("achievement_score", height = "350px")
          )
        ),
        fluidRow(
          box(
            title = "COPD 008 (Bottom 5 Practices for Each Metric)",
            status = "success", solidHeader = TRUE,
            width = 12,
            plotOutput("copd008", height = "350px")
          )
        )
      ),
      
      # ---------- Map Tab ----------
      tabItem(
        tabName = "map",
        fluidRow(
          box(
            title = "GP Map by CCG",
            status = "success", solidHeader = TRUE,
            width = 12,
            tmapOutput("gp_map", height = "700px")
          )
        )
      ),
      
      # ---------- Table Tab ----------
      tabItem(
        tabName = "table",
        fluidRow(
          box(
            title = "Data Table",
            status = "success", solidHeader = TRUE,
            width = 12,
            DTOutput("table")
          )
        )
      )
    )
  ),
  
  title = "Professional Dashboard",
  skin  = "blue"
)

# -----------------------------
# 7. CCG 地图数据
# -----------------------------
library(sf)
library(tmap)

# 读取 shapefile
ccg_map <- st_read("ccg map/", quiet = TRUE)

# 把名称字段转大写，确保能匹配数据
sf_ccg_map <- ccg_map %>%
  st_as_sf() %>%
  mutate(CCG21NM = str_to_upper(CCG21NM))

# 统计每个 CCG 有多少个 GP（practice）
n_gp_data <- data %>%
  count(ccg_name, name = "n_gp") %>%
  mutate(ccg_name = str_c(ccg_name, " CCG") |> str_to_upper())

# 左连接地图与统计数据
n_gp_map_data <- sf_ccg_map %>%
  left_join(n_gp_data, by = c("CCG21NM" = "ccg_name"))
# ✅ 全局设置 tmap 为交互模式
tmap_mode("view")

# -----------------------------
# 6. Server
# -----------------------------
server <- function(input, output) {
  # Prevalence
  output$prevalence <- renderPlotly({
    plot_prevalence_data <- prevalence_data %>% filter(ccg_code %in% input$ccg_ccg_code)
    p <- ggplot(plot_prevalence_data, aes(x = year, y = value)) +
      geom_point(aes(color = year, text = practice_code), position = position_jitter(width = 0.4, seed = 123), alpha = 1, size = 0.5) +
      geom_boxplot(aes(fill = year), alpha = 0.5) +
      scale_fill_manual(values = c(
        "2020-2021" = "#016B61",  # 年份1的箱线图颜色
        "2021-2022" = "#B7A3E3"   # 年份2的箱线图颜色
      )) +
      scale_color_manual(values = c(
        "2020-2021" = "#016B61",
        "2021-2022" = "#B7A3E3"
      )) +
      facet_wrap(~ccg) +
      labs(x = NULL, y = 'Prevalence') + theme_light() + theme(legend.position = 'none')
    
    
    ggplotly(p, tooltip = c('text', 'y'))
  })
  
  # Achievement
  output$achievement_score <- renderPlotly({
    plot_achievement_data <- achievement_data %>% filter(ccg_code %in% input$gp_ccgs_code)
    p <- ggplot(plot_achievement_data, aes(x = year, y = value)) +
      geom_point(aes(text = practice_code), alpha = 0.6, size = 1) +
      geom_line(aes(group = practice_code), alpha = 0.5) +
      facet_wrap(~ccg) +
      labs(x = NULL, y = 'Achievement') + theme_light() + theme(legend.position = 'none')
    ggplotly(p, tooltip = c('text', 'y'))
  })
  
  # COPD 008
  output$copd008 <- renderPlot({
    plot_copd008_data <- copd008_data %>%
      filter(ccg_code == input$gp_ccg_code) %>%
      pivot_longer(cols = -c(practice_code, ccg_code), names_to = 'name', values_to = 'value') %>%
      mutate(name = case_when(
        name == 'copd008_achievement_score' ~ 'Achievement Score',
        name == 'copd008_achievement_net_of_pca' ~ 'Achievement Net of PCA',
        name == 'copd008_patients_receiving_intervention_percentage' ~ 'Patients Receiving Intervention %'
      )) %>%
      group_by(name) %>% slice_min(order_by = value, n = 5) %>% ungroup()
    
    # 添加标题 & 数值标签
    make_plot <- function(df, title) {
      ggplot(df %>% mutate(practice_code = fct_reorder(practice_code, value)),
             aes(x = practice_code, y = value, fill = value)) +
        geom_col() +
        geom_text(aes(label = round(value, 2)), hjust = -0.2, size = 3) +  # 数值显示
        coord_flip() +
        scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
        labs(
          x = NULL, y = NULL,
          title = title
        ) +
        theme_light() +
        theme(
          legend.position = "none",
          plot.title = element_text(size = 14, face = "bold", hjust = 0.5)
        )
    }
    p1 <- make_plot(filter(plot_copd008_data, name == 'Achievement Score'), 'Achievement Score')
    p2 <- make_plot(filter(plot_copd008_data, name == 'Achievement Net of PCA'), 'Achievement Net of PCA')
    p3 <- make_plot(filter(plot_copd008_data, name == 'Patients Receiving Intervention %'), 'Patients Receiving Intervention %')
    
    p1 | p2 | p3
  })
  # GP Map 输出
  output$gp_map <- renderTmap({
    tmap_mode("view")
    
    tm_shape(n_gp_map_data) +
      tm_polygons(
        fill = "n_gp",
        fill.scale = tm_scale(values = "brewer.blues", value.na = "grey80"), # ✅ 新语法
        fill.legend = tm_legend(title = "Number of GPs"),                    # ✅ 新语法
        border.col = "grey70",
        id = "CCG21NM",
        popup.vars = c("Number of GPs" = "n_gp")
      ) +
      tm_layout(
        legend.outside = TRUE,
        basemap.server = NULL,  # ✅ 新语法
        frame = FALSE
      )
  })
  
  # Table
  output$table <- renderDT({
    data %>% select(practice_code, ccg_code, ccg_name, prevalence_2021_22, achievement_2021_22, pca_rate_2021_22, copd008_achievement_score, copd008_achievement_net_of_pca, copd008_patients_receiving_intervention_percentage) %>%
      datatable(filter = 'top', options = list(lengthMenu = c('5','10','15','20','30'), lengthChange = TRUE, pageLength = 10, autoWidth = FALSE, scrollX = TRUE))
  })
}

shinyApp(ui = ui, server = server)


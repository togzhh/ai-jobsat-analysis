# =============================================================================
# analysis.R
# Does AI Tool Usage Relate to Developer Job Satisfaction?
# Analysis of the 2025 Stack Overflow Developer Survey
#
# Input:  data/raw/so_survey_subset.csv
# Output: data/processed/*.csv, figures/*.png, report/stats_results.txt
# =============================================================================

required_packages <- c("dplyr", "readr", "stringr", "forcats", "ggplot2", "rstatix", "coin", "car")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing_packages) > 0) {
  cat("Installing missing packages:", paste(missing_packages, collapse = ", "), "\n")
  install.packages(missing_packages)
}

library(dplyr)
library(readr)
library(stringr)
library(forcats)
library(ggplot2)
library(rstatix)
library(car)

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", recursive = TRUE, showWarnings = FALSE)
dir.create("report", recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# PART 1: CLEAN
# =============================================================================

raw <- read_csv("data/raw/so_survey_subset.csv", show_col_types = FALSE)
cat("Raw rows read:", nrow(raw), "\n")

# JobSat is only asked of professional developers (confirmed: 100% missing for
# every other MainBranch category) -- restricting to this group isn't an
# arbitrary choice, it matches the survey's own skip logic.
df <- raw %>% filter(MainBranch == "I am a developer by profession")
cat("Rows after restricting to professional developers:", nrow(df), "\n")

# Order AISelect as a meaningful ordinal factor (No -> daily) for consistent
# plotting and interpretation
ai_levels <- c(
  "No, and I don't plan to",
  "No, but I plan to soon",
  "Yes, I use AI tools monthly or infrequently",
  "Yes, I use AI tools weekly",
  "Yes, I use AI tools daily"
)
df <- df %>%
  mutate(AISelect = factor(AISelect, levels = ai_levels, ordered = TRUE))

# Flag (not remove) implausible experience values (>60 years -- a handful of
# joke/error entries, confirmed only 18/30 rows out of ~35k)
df <- df %>%
  mutate(
    WorkExp_extreme = !is.na(WorkExp) & WorkExp > 60,
    YearsCode_extreme = !is.na(YearsCode) & YearsCode > 60
  )

before_drop <- nrow(df)
df_clean <- df %>% filter(!is.na(JobSat), !is.na(AISelect))
cat("Dropped", before_drop - nrow(df_clean), "rows missing JobSat or AISelect\n")
cat("Final analysis-ready dataset:", nrow(df_clean), "rows\n")

cat("\nJobSat summary:\n")
print(summary(df_clean$JobSat))

write_csv(df_clean, "data/processed/so_survey_clean.csv")
cat("Wrote data/processed/so_survey_clean.csv\n")

# =============================================================================
# PART 2: EXPLORATORY ANALYSIS & FIGURES
# =============================================================================

theme_set(theme_minimal(base_size = 12))

# --- Fig 1: overall JobSat distribution ---
p1 <- ggplot(df_clean, aes(x = JobSat)) +
  geom_histogram(binwidth = 1, fill = "#2c7fb8", color = "white") +
  geom_vline(aes(xintercept = median(JobSat)), linetype = "dashed", color = "firebrick") +
  labs(
    title = "Distribution of developer job satisfaction (0-10 scale)",
    subtitle = paste0("n = ", nrow(df_clean), " professional developers; dashed line = median (",
                       median(df_clean$JobSat), ")"),
    x = "Job satisfaction (0 = not at all, 10 = extremely)", y = "Number of respondents"
  )
ggsave("figures/01_jobsat_distribution.png", p1, width = 8, height = 5, dpi = 150)

# --- Fig 2: JobSat by AI usage frequency ---
p2 <- ggplot(df_clean, aes(x = AISelect, y = JobSat)) +
  geom_boxplot(fill = "#41b6c4", outlier.alpha = 0.2) +
  coord_flip() +
  labs(title = "Job satisfaction by AI tool usage frequency",
       x = NULL, y = "Job satisfaction (0-10)")
ggsave("figures/02_jobsat_by_ai_usage.png", p2, width = 8, height = 5, dpi = 150)

cat("\nEDA complete. Figures written to figures/\n")
cat("JobSat skew check -- mean:", round(mean(df_clean$JobSat), 2),
    "median:", median(df_clean$JobSat), "\n")

# =============================================================================
# PART 3: STATISTICAL TEST
# =============================================================================
# JobSat is heavily left-skewed (median 8, long tail down toward 0), violating
# the normal/equal-variance assumptions ANOVA needs -- same reasoning as the
# DOAJ project's right-skewed turnaround time, just flipped direction. Using
# Kruskal-Wallis + effect size for the same principled reason.

sink("report/stats_results.txt", split = TRUE)

cat("=============================================================\n")
cat("RQ: Does job satisfaction differ by AI tool usage frequency?\n")
cat("=============================================================\n")

print(df_clean %>% kruskal_test(JobSat ~ AISelect))
cat("\nEffect size (epsilon-squared):\n")
print(df_clean %>% kruskal_effsize(JobSat ~ AISelect))

cat("\nMedian/mean JobSat by AI usage group:\n")
print(df_clean %>% group_by(AISelect) %>%
        summarise(n = n(), median_jobsat = median(JobSat), mean_jobsat = mean(JobSat)))

cat("\nPost-hoc pairwise Wilcoxon (BH-adjusted):\n")
print(df_clean %>% wilcox_test(JobSat ~ AISelect, p.adjust.method = "BH") %>%
        select(group1, group2, p.adj, p.adj.signif))

sink()
cat("\nStatistical test complete. Output in report/stats_results.txt\n")

# =============================================================================
# PART 4: CONFOUND CHECK -- does the (tiny) AI-usage effect hold across
# experience levels, or is it just a proxy for seniority?
# =============================================================================

sink("report/stats_results.txt", append = TRUE, split = TRUE)

cat("\n\n=============================================================\n")
cat("Confound check: JobSat by AI usage, within experience bands\n")
cat("=============================================================\n")

df_exp <- df_clean %>%
  filter(!is.na(WorkExp), !WorkExp_extreme) %>%
  mutate(
    experience_band = case_when(
      WorkExp < 5 ~ "Junior (<5 yrs)",
      WorkExp < 15 ~ "Mid (5-15 yrs)",
      TRUE ~ "Senior (15+ yrs)"
    ),
    experience_band = factor(experience_band,
                              levels = c("Junior (<5 yrs)", "Mid (5-15 yrs)", "Senior (15+ yrs)"))
  )

band_summary <- df_exp %>%
  group_by(experience_band, AISelect) %>%
  summarise(n = n(), median_jobsat = median(JobSat), mean_jobsat = round(mean(JobSat), 2), .groups = "drop")
print(band_summary, n = Inf)

sink()

# =============================================================================
# PART 5: ROBUSTNESS CHECK -- MULTIVARIATE MODEL
# =============================================================================
# Does AI usage predict JobSat after controlling for experience, company
# size, and remote-work setup simultaneously?

sink("report/stats_results.txt", append = TRUE, split = TRUE)

cat("\n\n=============================================================\n")
cat("ROBUSTNESS CHECK: AISelect effect controlling for confounds\n")
cat("=============================================================\n")

df_model <- df_clean %>%
  filter(!is.na(WorkExp), !is.na(OrgSize), !is.na(RemoteWork), !WorkExp_extreme)

cat("Model dataset n:", nrow(df_model), "\n")

m_ai_only <- lm(JobSat ~ AISelect, data = df_model)
m_full <- lm(JobSat ~ AISelect + WorkExp + OrgSize + RemoteWork, data = df_model)

cat("\nR-squared, AISelect only:", round(summary(m_ai_only)$r.squared, 4), "\n")
cat("R-squared, full model:   ", round(summary(m_full)$r.squared, 4), "\n")

cat("\nType II ANOVA on the full model:\n")
print(Anova(m_full, type = 2))

sink()
cat("\nRobustness check complete. Appended to report/stats_results.txt\n")
cat("\n=== analysis.R finished ===\n")




# Does AI Tool Usage Relate to Developer Job Satisfaction?

Public discourse about AI and developer wellbeing pulls in two opposite directions:
AI tools are either framed as a productivity boost that makes work more enjoyable,
or as a source of frustration, distrust, and job-security anxiety. The 2025 Stack Overflow
Developer Survey publishes detailed breakdowns of AI adoption and job satisfaction. 
This project asks:
**does how often a developer uses AI tools actually relate to how satisfied they are with 
their job?**

## Research Question

Does job satisfaction differ by AI tool usage frequency (daily / weekly / monthly /
planning to / not using and not planning to), and if so, does that relationship survive
controlling for experience, company size, and remote-work setup?

## Data

- **Source**: 2025 Stack Overflow Developer Survey, publicly downloadable from
  [survey.stackoverflow.co](https://survey.stackoverflow.co/) (raw CSV + schema also
  mirrored on Kaggle)
- **Scope**: 49,191 total responses, 172 columns in the full export; this project uses an
  18-column subset covering AI usage, job satisfaction, and relevant confounds
- **Population restriction**: analysis is restricted to respondents who selected
  `MainBranch == "I am a developer by profession"` — confirmed via the schema that
  `JobSat` is only asked of this group (100% missing for every other respondent
  category), so this isn't an arbitrary filter, it matches the survey's own skip logic
- **Analysis-ready n**: 24,918 professional developers with both `JobSat` and `AISelect`
  present

### Known limitations

- **Cross-sectional, self-reported, single time point.** This cannot establish causality
  in either direction, it's equally consistent with "AI usage changes satisfaction" and
  "already-satisfied developers are more inclined to adopt new tools."
- **JobSat is a 0-10 self-rating**, not a validated psychometric wellbeing or burnout
  instrument. It measures stated job satisfaction, not mental health.
- **Self-selection**: respondents are Stack Overflow's own user base, skewing toward
  professional, English-literate, internet-active developers rather than the full global
  developer population.

## Methodology

1. **Clean** (`analysis.R`, Part 1): restrict to professional developers, order
   `AISelect` as an ordinal factor, flag (not remove) implausible experience values.
2. **Explore** (Part 2): visualize the distribution of job satisfaction and its
   relationship to AI usage frequency.
3. **Test** (Part 3): `JobSat` is heavily left-skewed (median 8, long tail down toward
   0), violating the assumptions ANOVA needs — the same reasoning that drove the
   non-parametric test choice in the companion DOAJ bibliometrics project, just with the
   skew running the opposite direction. Kruskal-Wallis + epsilon-squared effect size is
   used for the same principled reason.
4. **Confound check** (Part 4): does the AI-usage/satisfaction relationship hold up
   consistently across junior, mid-level, and senior experience bands, or is it an
   artifact of experience composition?
5. **Robustness check** (Part 5): a multivariate linear model with AI usage, experience,
   company size, and remote-work setup as simultaneous predictors, with a Type II ANOVA
   to test whether AI usage remains significant once the others are controlled for.

## Results

**n = 24,918.** Job satisfaction is measured 0-10; median 8, mean 7.21.

| Test | Result | Effect size | 
|---|---|---|---|
| Kruskal-Wallis, JobSat ~ AI usage | H=40.2, df=4, p=3.9×10⁻⁸ | ε²=0.00145 (small) | 

- **Group medians barely move**: 7.11-7.29 mean JobSat across all five AI-usage
  categories, on a 0-10 scale. The boxplot (Figure 2) shows near-total overlap across
  groups.
- **Confound check**: the pattern holds inside every experience band (junior, mid,
  senior) — no hidden relationship unlocked by controlling for seniority; if anything,
  daily AI users trend marginally higher within each band, but the gap stays small
  throughout.
- **Robustness check**: in a full model with experience, company size, and remote-work
  setup, AI usage remains statistically significant (F=11.88, p=1.2×10⁻⁹) but contributes
  far less than the other predictors — its sum of squares (172) is roughly 3.6× smaller
  than remote-work setup's (299) and 3.6× smaller than experience's (627). R² rises from
  0.0017 (AI usage alone) to 0.0182 (full model) — meaning the other predictors do almost
  all of the real explanatory work.

**Headline finding**: contrary to public narratives claiming AI tools are either a major
boost or a major drag on developer wellbeing, this data says usage frequency has close to
no practical bearing on stated job satisfaction. Tenure and work setup matter 
substantially more.


## Reproducibility

Open `ai-jobsat-analysis.Rproj` in RStudio (sets the working directory automatically —
no `setwd()` needed), then run:

```r
source("analysis.R")
```

Dependencies (`dplyr`, `readr`, `stringr`, `forcats`, `ggplot2`, `rstatix`, `coin`, `car`)
are checked and installed automatically at the top of the script if missing.


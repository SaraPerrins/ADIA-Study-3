# nlscya
# https://nlsinfo.org/weights/nlscya


#Second, and of most fundamental importance, any researcher using this data set must be continually conscious
#of the fact the children are not representative of a full cross-section of American children. When appropriate
#weights are applied to the sample, the children are approximately typical of children who have been born to a
#nationally representative sample of American women (who were 14-22 as of January 1, 1979)

#https://www.nlsinfo.org/sites/default/files/attachments/121214/NLSYChildren1992Evaluation.pdf

#library(devtools)
#install_github("susanathey/causalTree")
#https://doi.org/10.48550/arXiv.1504.01132
rm(list=ls(all=TRUE))
library(tidyverse)
library(survey)
library(survival)
library(gt)

options(digits = 3)
options(scipen = 10^3)

#i <- 'RES'
i   <- 'discrim_reason'
#out <- 'preshlth'
out <- 'depress'

user <- 54137
setwd(paste0("C:/Users/", user, "/ICF/CDC ADIA Project - ICF Private Channel - ICF Private Channel/Study 1+3/Study 3/Analysis/")) 

#dat <- readRDS("C:/Users/21983/OneDrive - ICF/ADIA/study 1/data/NLS.tree.unconditional.w.Rds")
#dat <- readRDS("C:/Users/21983/OneDrive - ICF/ADIA/study 1/data/NLS.tree.unconditional.w.notres.Rds")
file_name <- paste0("./QC/Data/NLS.tree_", out, ".Rds")
dat <- readRDS(file_name)

#======================================================================================
#1.- unconditional
#======================================================================================
table(dat$node.cls)
tapply(dat$y, dat$node.cls,function(x){round(c("mean" = mean(x, na.rm = TRUE),
                                               "median" = median(x, na.rm = TRUE)), digits = 1)})

df1 <-
  dat %>%
  filter(training.sample == 0)
summary(df1$w)

sd.w     <- svydesign(id = ~id, weights = ~w, data = df1)
fit.cls  <- svyglm(y ~ node.cls, design = sd.w)

summary(fit.cls)
anova(fit.cls, update(fit.cls, . ~ 1))
test.cls <- anova(fit.cls, update(fit.cls, . ~ 1))

pred.cls <- predict(fit.cls,
                    newdata = data.frame(node.cls = unique(dat$node.cls)), type = c("response"))

cbind(unique(dat$node.cls), pred.cls, confint(pred.cls))[order(unique(dat$node.cls)),]

#get sample size
ss.cls <- as.data.frame(table(df1$node.cls[!is.na(df1$y)])) %>% rename(Node = Var1, n=Freq)
#using code with updated node labels
tb <- data.frame(unique(dat$node.cls), pred.cls, confint(pred.cls))[order(unique(dat$node.cls)),] %>% rename(Node = unique.dat.node.cls.)
tb <- merge(tb, ss.cls, by = c("Node"))
tb <- tb[ , c(1, 6, 2:5)]

#saving the output in nice format
tb <- tb %>%
  mutate(SE = round(SE, digits = 3)) %>%
  mutate(Node = case_when(
    Node == "bneedin < 0.5" ~ "Basic needs instability = No", 
    Node == "bneedin >= 0.5" ~ "Basic needs instability = Yes"
  ))

tb %>%
  gt %>%
  tab_header(title = "Predicted values") %>%
  #tab_footnote(footnote = paste0("P-value=", round(test.cls$p, digits = 6)
                                 #, "; df=", test.cls$df
                                 #, "; denominator df=", test.cls$ddf
  #                      ),  
  #                      cells_stubhead()) %>% # added to save p-value 
  fmt_number(
    columns = 3:6,
    rows = everything(),
    decimals = 3,
    use_seps = FALSE
  ) %>%
  gtsave(paste0("./Regression Tree Output/", out, "/predicted_cls", out, i, "_Study 3.html"))

tb

#to find sample size
table(df1$node.cls[!is.na(df1$y)])
#with(df1,ftable(ACEmentalill,female,ACEphysharm,node.cls))

#======================================================================================
#2.- conditional
#======================================================================================

#dat <- readRDS("C:/Users/21983/OneDrive - ICF/ADIA/study 1/data/NLS.tree.conditional.nw.Rds")

#dat$w <- 1 #why would be overide the weights ??

### Since we did not find any predictor condtional
# we will test what we found using classical tree 
#controlling for  other covariates (excluding those detected from regression tree search)
dat$node.cnd  <- dat$node.cls
df1   <-  dat %>%  filter(training.sample == 0)
sd.w  <- svydesign(id = ~id, weights = ~ w, data = df1)

fit.cnd <- svyglm(y ~ node.cnd
                  + female 
                  + agegrp
                  + black + white + hisp + asian + asian_nhpi + othrace +
                    + mhighgd_bin
                  + rural + mixur
                  #+ mhhinco no longer using as a covariate 02/18/2023
                  ,
                  design = sd.w)
summary(fit.cnd)
anova(fit.cnd, update(fit.cnd, . ~ . - node.cnd))

summary(fit.cnd$data)
unique(dat$node.cnd)

summary(dat[, all.vars(formula(fit.cnd))])
table(dat$urbnrur)

pred.cnd <- predict(fit.cnd,
                    newdata = data.frame(node.cnd = unique(dat$node.cnd),
                                         female = 1,
                                         agegrp = mean(dat$agegrp, na.rm = TRUE),
                                         black = 0,
                                         white = 0,
                                         hisp = 1,
                                         asian = 0,
                                         asian_nhpi = 0,
                                         othrace = 0,
                                         mhighgd_bin = 0,
                                         rural = 0,
                                         mixur = 0
                                         #,
                                         #mhhinco = mean(dat$mhhinco, na.rm = TRUE) removing income as covariate 02/18/2023
                    )
)

cbind(unique(dat$node.cnd), pred.cnd, confint(pred.cnd))[order(unique(dat$node.cnd)),]
#to find sample size
#those with missing covariates are going to be dropped
table(df1$node.cnd[complete.cases(df1[,all.vars(formula(fit.cnd))])])

#======================================================================================
#3.- Causal tree
#======================================================================================
df1 <-  dat %>% filter(training.sample == 0)

sdw    <- svydesign(id = ~id, weights = ~ wb, data = df1) #! use balanced weights
fit0   <- svyglm(as.numeric(y) ~ anyACE_T,
                 design = sdw, family = gaussian) #!!use gaussian even for binnary

# Is the difference in outcome
# between kids who experience ACE_T and kids who  did not
# statistically significant?
coef(fit0)["anyACE_T"]
confint(fit0)["anyACE_T", ]
anova(fit0, update(fit0, . ~ . - anyACE_T))

fit1 <- svyglm(as.numeric(y) ~ anyACE_T:node.cau + node.cau  - 1,
               design = sdw, family = gaussian)#use gaussian even for binnary

anova(fit0, fit1)
test.cau <- anova(fit0, fit1)

cbind(unique(dat$node.cau),
      coef(fit1)[grep("anyACE_T:", names(coef(fit1)))],
      confint(fit1)[grep("anyACE_T:", names(coef(fit1))), ]
)[order(unique(dat$node.cau)), ]

#adding node labels
tb_coef <- data.frame(coef(fit1)[grep("anyACE_T:", names(coef(fit1)))]) 
tb_coef <- tb_coef %>%
  mutate(Node = sub(".*anyACE_T:node.cau", "", rownames(tb_coef)))
tb_ci <- data.frame(confint(fit1)[grep("anyACE_T:", names(coef(fit1))), ]) 
tb_ci <- tb_ci %>%
  mutate(Node = sub(".*anyACE_T:node.cau", "", rownames(tb_ci)))

#get sample size
ss.cau <- as.data.frame(table(df1$node.cau[complete.cases(df1[,all.vars(formula(fit1))])])) %>% 
  rename(Node = Var1, n = Freq)
#merge
tb <- merge(tb_coef, tb_ci, by=c("Node")) %>% merge(ss.cau, by = c("Node"))
tb <- tb[ , c(1, 5, 2:4)]
colnames(tb) <- c("Node", "n", "Est.", "CI_LL", "CI_UL")

#saving the output in nice format
tb <- tb %>%
  mutate(Est. = round(Est., digits = 3), 
         CI_LL = round(CI_LL, digits = 3), 
         CI_UL = round(CI_UL, digits = 3))

tb %>%
  gt %>%
  tab_header(title = "Predicted values") %>%
  #tab_footnote(footnote = paste0("P-value=", round(test.cau$p, digits = 6)
                                 #, "; df=", test.cau$df, "; denominator df=", test.cau$ddf
  #             ),  cells_stubhead()) %>% # added to save p-value 
  fmt_number(
    columns = 3:5,
    rows = everything(),
    decimals = 3,
    use_seps = FALSE
  ) %>%
  gtsave(paste0("./Regression Tree Output/", out, "/predicted_cau", out, i, "_Study 3.html"))

#to find sample size
table(df1$node.cau[complete.cases(df1[,all.vars(formula(fit1))])])
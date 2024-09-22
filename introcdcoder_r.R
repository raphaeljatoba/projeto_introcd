library(readr)

data <- read_csv("star_classification.csv")

library(dplyr)

data %>%
  count(class) %>%
  arrange(desc(n))

library(ggplot2)

ggplot(data, aes(x = class)) +
  geom_bar() +
  ggtitle("Class") +
  theme(plot.title = element_text(size = 10))

data <- data %>%
  mutate(class = ifelse(class == "GALAXY", 0,
                        ifelse(class == "STAR", 1, 2)))

data <- data %>% select(-rerun_ID)


shape_antes <- nrow(data)

for (col in names(data)) {
  if (is.numeric(data[[col]])) {
    quartil_1 <- quantile(data[[col]], 0.25)
    quartil_3 <- quantile(data[[col]], 0.75)
    iqr <- quartil_3 - quartil_1
    superior <- quartil_3 + (1.5 * iqr)
    inferior <- quartil_1 - (1.5 * iqr)
    
    #outliers
    data <- data %>% 
      filter(data[[col]] >= inferior & data[[col]] <= superior)
  }
}

data <- data %>% select(-alpha, -run_ID, -obj_ID, -cam_col, -fiber_ID, -delta, -field_ID)

correlacao <- cor(data, method = "pearson")

sorted_correlacao <- sort(correlacao[, "class"], decreasing = FALSE)

sorted_correlacao

library(reshape2)

corr_melted <- melt(correlacao)

ggplot(corr_melted, aes(Var1, Var2, fill = value)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", value)), color = "white") +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1, 1), space = "Lab", 
                       name="Correlation") +
  theme_minimal() +
  labs(title = "Matriz de correlação", x = "", y = "") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#######
library(tidymodels)

set.seed(123)

data_split <- initial_split(data, prop = 0.7)
treino <- training(data_split)
teste <- testing(data_split)

#####

set.seed(123)

treino$class <- as.factor(treino$class)

recipe <- recipe(class ~ ., data = treino) %>%
  step_normalize(all_numeric_predictors())

model_spec <- rand_forest(mtry = 3, trees = 50, min_n = 5) %>%
  set_engine("ranger") %>%
  set_mode("classification")

floresta <- workflow() %>%
  add_recipe(recipe) %>%
  add_model(model_spec) %>%
  fit(data = treino)

floresta
#######
treino$class <- as.factor(treino$class)
teste$class <- as.factor(teste$class)

predictions <- floresta %>%
  predict(new_data = teste) %>%
  bind_cols(teste)  

predictions <- predictions %>%
  rename(predicted_class = .pred_class)

predictions$predicted_class <- as.factor(predictions$predicted_class)

accuracy <- predictions %>%
  metrics(truth = class, estimate = predicted_class) %>%
  filter(.metric == "accuracy")

print(accuracy)

library(yardstick)

conf_matrix <- conf_mat(predictions, truth = class, estimate = predicted_class)

print(conf_matrix)

class_report <- predictions %>%
  metrics(truth = class, estimate = predicted_class)

print(class_report)

autoplot(conf_matrix) +
  labs(title = "Matriz de confusão RF", fill = "Prediction") + theme_light()



library(xgboost)
treino$class <- as.factor(treino$class)
teste$class <- as.factor(teste$class)

recipe <- recipe(class ~ ., data = treino) %>%
  step_normalize(all_numeric_predictors())

xgb_model_spec <- boost_tree(
  trees = 100,
  min_n = 5,
  tree_depth = 3,
  learn_rate = 0.1
) %>%
  set_engine("xgboost") %>%
  set_mode("classification")

xgb_workflow <- workflow() %>%
  add_recipe(recipe) %>%
  add_model(xgb_model_spec)

xgb_fit <- xgb_workflow %>%
  fit(data = treino)

predictions <- xgb_fit %>%
  predict(new_data = teste) %>%
  bind_cols(teste)

predictions <- predictions %>%
  rename(predicted_class = .pred_class)

accuracy <- predictions %>%
  metrics(truth = class, estimate = predicted_class) %>%
  filter(.metric == "accuracy")

print(accuracy)
###########


conf_matrix <- conf_mat(predictions, truth = class, estimate = predicted_class)

print(conf_matrix)

class_report <- predictions %>%
  metrics(truth = class, estimate = predicted_class)

print(class_report)

autoplot(conf_matrix) +
  labs(title = "Matriz de confusão XGBoost", x="Classe Real", y = "Classe prevista", fill = "Prediction") + theme_light()
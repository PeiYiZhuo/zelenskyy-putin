library(tidyverse)
library(lubridate)
library(polite)
library(rvest)
library(glue)
library(here)

bow("https://www.president.gov.ua/en/news")

# Grabs links to articles published from 10/24/2021 to 6/24/2022
start = "24-10-2021"
end = "24-06-2022"
links <- NULL
i <- 1
repeat {
  cat(glue("Getting page {i} links"), "\n")
  url <- glue(
    "https://www.president.gov.ua/en/news/all?",
    "date-from={start}&date-to={end}&page={i}"
  )
  pg_links <- url %>%
    read_html() %>%
    html_elements(".item_stat_headline a") %>%
    html_attr("href")
  if (is_empty(pg_links)) break
  links <- c(links, pg_links)
  i <- i + 1
}

# Function that scrapes an article's webpage and returns a list of info
get_info_from <- function(url) {
  html <- read_html(url)
  list(
    link = url,
    headline = html %>%
      html_elements("h1") %>%
      html_text2(),
    date = html %>%
      html_elements("h1+ .date") %>%
      html_text2(),
    text = html %>%
      html_elements(".article_content p") %>%
      html_text2() %>%
      .[. != ""] %>% # Remove empty strings
      # https://stackoverflow.com/questions/9314328/how-to-collapse-a-list-of-characters-into-a-single-string-in-r
      paste(collapse = " ")
  )
}

# Scrape every article's webpage to produce list of lists
article_list <- rep(list(NA), length(links))
for (i in seq_along(links)) {
  cat(glue("Getting link {i}"), "\n")
  article_list[[i]] <- get_info_from(links[[i]])
}

# Convert into data frame
zelenskyy <- article_list %>%
  tibble(article = .) %>%
  unnest_wider(article) %>%
  mutate(
    headline = str_replace_all(headline, "’",  "'"),
    date = dmy_hm(date),
    text = str_replace_all(text, "’",  "'")
  )

dir.create(here("press_release_data"))
save(zelenskyy, file = here("press_release_data", "zelenskyy.RData"))
write_csv(zelenskyy, file = here("press_release_data", "zelenskyy.csv"))

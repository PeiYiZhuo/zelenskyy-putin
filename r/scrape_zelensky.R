library(tidyverse)
library(lubridate)
library(polite)
library(rvest)
library(glue)
library(here)

bow("https://www.president.gov.ua/en/news")

# Grabs links to articles published from 2/24/2022 to 4/27/2022
# Article links are spread across 33 pages
links <- NULL
i <- 1
repeat {
  cat(glue("Getting page {i} links"), "\n")
  url <- glue(
    "https://www.president.gov.ua/en/news/all?",
    "date-from=24-02-2022&date-to=27-04-2022&page={i}"
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
    headline = html %>%
      html_elements("h1") %>%
      html_text2(),
    date = html %>%
      html_elements("h1+ .date") %>%
      html_text2(),
    text = html %>%
      html_elements(".article_content p") %>%
      html_text2() %>%
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
zelensky <- article_list %>%
  tibble(article = .) %>%
  unnest_wider(article) %>%
  mutate(date = dmy_hm(date))

dir.create(here("press_release_data"))
saveRDS(zelensky, file = here("press_release_data", "zelensky.rds"))

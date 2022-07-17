library(tidyverse)
library(lubridate)
library(polite)
library(rvest)
library(glue)
library(here)

bow("http://en.kremlin.ru/events/president/news")

# Grabs links to articles published from start to end
start <- ymd("2021-10-24")
end <- ymd("2022-06-24")
links <- NULL
i <- 1
repeat {
  cat(glue("Getting page {i} links"), "\n")
  url <- glue("http://en.kremlin.ru/events/president/news/page/{i}")
  repeat{
    html <- try(read_html(url))
    if (any(class(html) != "try-error")) {
      break
    } else {
      cat("Sleeping for 10 seconds\n")
      Sys.sleep(10)
    }
  }
  pg_links <- html %>%
    html_elements("h3>a[href]") %>%
    html_attr("href")
  dates <- html %>%
    html_elements("span>time[itemprop=datePublished]") %>%
    html_attr("datetime") %>%
    ymd()
  links <- c(links, pg_links[dates <= end & dates >= start])
  if (any(dates < start)) break
  i <- i + 1
}

# Function that scrapes an article's webpage and returns a list of info
get_info_from <- function(url) {
  html <- read_html(url)
  list(
    headline = html %>%
      html_elements("h1.entry-title.p-name") %>%
      html_text2(),
    date = html %>%
      html_elements("p>time[datetime]") %>%
      html_text2(),
    location = html %>%
      html_elements("div.read__place.p-location") %>%
      html_text2(),
    summary = html %>%
      html_elements("div[role=heading]") %>%
      html_text2(),
    text = html %>%
      html_elements("div[itemprop]>p") %>%
      html_text2() %>%
      .[. != ""] %>% # Remove empty strings
      paste(collapse = " ")
  )
}

# Scrape every article's webpage to produce list of lists
article_list <- list()
for (i in seq_along(links)) {
  # https://stackoverflow.com/questions/32429325/r-redo-iteration-for-loop
  url <- glue("http://en.kremlin.ru", links[[i]])
  # Repeat loop is used because some links take multiple tries
  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403
  repeat{
    cat(glue("Trying link {i}"), "\n")
    article <- try(get_info_from(url))
    if (class(article) != "try-error") {
      article_list[[length(article_list) + 1]] <- article
      break
    } else {
      cat("Sleeping for 10 seconds\n")
      # https://statisticsglobe.com/execution-pause-for-x-seconds-in-r
      Sys.sleep(10)
    }
  }
}

# Convert into data frame
putin <- article_list %>%
  tibble(article = .) %>%
  unnest_wider(article) %>%
  mutate(
    headline = str_replace_all(headline, "’",  "'"),
    date = mdy_hm(date),
    location = str_replace_all(location, "’",  "'"),
    summary = str_replace_all(summary, "’",  "'"),
    text = str_replace_all(text, "’",  "'")
  )

dir.create(here("press_release_data"))
save(putin, file = here("press_release_data", "putin.RData"))
write_csv(putin, file = here("press_release_data", "putin.csv"))

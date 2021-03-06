library(rcrossref)
library(usethis)
library(tidyverse)
library(rorcid)
# library(curl)

# list review -------------------------------------------------------------

# pepper shaker example
x <- list("a" = c(1, 2, 3, 4))
x[1]
x[[1]]
x[[1]][[1]]

# pluck allows you to index deeply and flexibly into data structures
pluck(x, 1)
pluck(x, 1, 1)

y <- list("a" = list("b" = list("c" = "hello")))
pluck(y, "a", "b", "c")


z <- list("a" = c(1, 2, 3, 4),
          "b" = c("one", "two", "three", "four", "five"))

map(z, pluck(1))



# rorcid review -----------------------------------------------------------

carberry <- orcid_search(given_name = 'josiah',
                         family_name = 'carberry')

carberry_orcid_id <- carberry$orcid

carberry_person <- orcid_person(carberry_orcid_id)

carberry_person %>%
  map(pluck, "name", "given-names", "value", .default = NA)
carberry_data <- carberry_person %>% {
  tibble(
    created_date = map_dbl(., pluck, "name", "created-date", "value", .default=NA_character_),
    given_name = map_chr(., pluck, "name", "given-names", "value", .default=NA_character_),
    family_name = map_chr(., pluck, "name", "family-name", "value", .default=NA_character_),
    credit_name = map_chr(., pluck, "name", "credit-name", "value", .default=NA_character_),
    other_names = map(., pluck, "other-names", "other-name", "content", .default=NA_character_),
    orcid_identifier_path = map_chr(., pluck, "name", "path", .default = NA_character_),
    biography = map_chr(., pluck, "biography", "content", .default=NA_character_),
    researcher_urls = map(., pluck, "researcher-urls", "researcher-url", .default=NA_character_),
    emails = map(., pluck, "emails", "email", "email", .default=NA_character_),
    keywords = map(., pluck, "keywords", "keyword", "content", .default=NA_character_),
    external_ids = map(., pluck, "external-identifiers", "external-identifier", .default=NA_character_)
  )}

clarke_employment <- orcid_employments(orcid = "0000-0002-9260-8456")

# Again it comes in a series of nested lists, but we'll just `pluck()` what we need and use `flatten_dfr()` to flatten the lists into a data frame.

clarke_employment_data <- clarke_employment %>%
  map(., pluck, "affiliation-group", "summaries") %>% 
  flatten_dfr() %>%
  clean_names()



# works -------------------------------------------------------------------

carberry_orcid <- c("0000-0002-1825-0097")

# get a person's works
carberry_works <- works(carberry_orcid) %>%
  clean_names()

# unnest external IDs
carberry_works_ids <- carberry_works %>%
  unnest(external_ids_external_id) %>%
  clean_names()

my_orcids <- c("0000-0002-1825-0097", "0000-0002-9260-8456", "0000-0002-2771-9344")
my_works <- orcid_works(my_orcids)


# rcrossref ---------------------------------------------------------------

options(roadoi_email = "name@example.com")

usethis::edit_r_environ()

crossref_email=name@example.com

# Then Session > Restart R

# `cr_journals()` takes either an ISSN or a general keyword query, and returns metadata for articles published in the journal, including DOI, title, volume, issue, pages, publisher, authors, etc

# See what metadata the journal has provided
plosone_issn <- '1932-6203'
plosone_details <- rcrossref::cr_journals(issn = plosone_issn,
                                          works = FALSE) 

plosone_details <- plosone_details %>%
  purrr::pluck("data")

# make it easier to view by transposing with t()
View(t(plosone_details))

### Who is the publisher?
plosone_details$publisher

### Does the publisher have their funder data current?


### How many total dois are on file?


# Set works = TRUE to get publication metadata
plosone_publications <- rcrossref::cr_journals(issn = plosone_issn, works = T, limit = 10) %>%
  purrr::pluck("data")

### Use %>% and arrange() to sort this by the highest number of publications



# pass multiple ISSNs to `cr_journals`
jama_issn <- '1538-3598'
jah_issn <- '0021-8723'
jama_jah_issn <- c(jama_issn, jah_issn)
jah_jama_publications <- rcrossref::cr_journals(issn = jama_jah_issn, works = T, limit = 10) %>%
  purrr::pluck("data")

# View the fields at https://github.com/CrossRef/rest-api-doc/blob/master/api_format.md#work


### Use filter to get articles from Volume 44, Issue 4 of the Journal of American History


# Filtering ---------------------------------------------------------------

# you can use the `filter` argument within `cr_journals` to specify some parameters as the query is executing. See more at https://github.com/CrossRef/rest-api-doc#filter-names

# filter by publication year
jlsc_issn <- "2162-3309"
jlsc_pubs17 <- cr_journals(issn = jlsc_issn,
                           works = T,
                           limit = 10,
                           filter = c(from_pub_date='2017-08-01')) %>%
  purrr::pluck("data")


# filter by license information
plosone_license <- cr_journals(issn = plosone_issn,
                               works = T,
                               limit = 10,
                               filter = c(`has_license` = TRUE)) %>% 
  pluck("data")


# Getting works from a typed citation in a Word document/text file
my_references <- readr::read_csv(url("https://raw.githubusercontent.com/ciakovx/rorcid.workshop/master/rcrossref/data/raw/sample_references.csv"))
my_references

my_references$reference[1]

# cr_works is not vectorized.
# we have to build a loop:
my_references_works_list <- purrr::map(
  my_references$reference,
  function(x) {
    print(x)
    my_works <- rcrossref::cr_works(query = x, limit = 5) %>%
      purrr::pluck("data")
  })

# The Crossref API assigns a score to each item returned within each query, giving a measure of the API's confidence in the match. The item with the highest score is returned first in the datasets. We can return the first result in each item in the `my_references_works_list` by using `map_dfr()`, which is like `map()` except it returns the results into a data frame rather than a list:
my_references_works_df <- my_references_works_list %>%
  purrr::map_dfr(., function(x) {
    x[1, ]
  })


# The process is much easier and more accurate if we already have DOIs.

my_references_dois <- c("10.2139/ssrn.2697412", "10.1016/j.joi.2016.08.002", "10.1371/journal.pone.0020961", "10.3389/fpsyg.2018.01487", "10.1038/d41586-018-00104-7", "10.12688/f1000research.8460.2", "10.7551/mitpress/9286.001.0001")
my_references_dois_works <- rcrossref::cr_works(doi = my_references_dois) %>%
  pluck("data")


# Funder data -------------------------------------------------------------

# You can use the cr_funder() function to get funder data by DOI

my_funder <- cr_funders(dois='10.13039/100000001')

funder_data <- my_funder %>% 
  pluck("data", "data")
funder_hierarchy <- my_funder %>%
  pluck("data", "hierarchy")


# citation data -----------------------------------------------------------

# Citation counts per article are not returned with `cr_journals`, but you can get them with `cr_citation_count`.
my_references_dois <- c("10.2139/ssrn.2697412", "10.1016/j.joi.2016.08.002", "10.1371/journal.pone.0020961", "10.3389/fpsyg.2018.01487", "10.1038/d41586-018-00104-7", "10.12688/f1000research.8460.2", "10.7551/mitpress/9286.001.0001")

my_references_citation_count <- rcrossref::cr_citation_count(doi = my_references_dois)

joined <- my_references_dois_works %>%
  left_join(my_references_citation_count, by = "doi") %>%
  arrange(desc(count))


# roadoi ------------------------------------------------------------------

options(roadoi_email = "email@example.edu")


# Use oadoi_fetch() to check OA status
my_references_dois <- c("10.2139/ssrn.2697412", "10.1016/j.joi.2016.08.002", "10.1371/journal.pone.0020961", "10.3389/fpsyg.2018.01487", "10.1038/d41586-018-00104-7", "10.12688/f1000research.8460.2", "10.7551/mitpress/9286.001.0001")

my_reference_dois_oa <- roadoi::oadoi_fetch(dois = my_references_dois)

my_reference_dois_oa <- my_reference_dois_oa %>%
  filter(is_oa == TRUE)

oa_dois <- my_reference_dois_oa$doi

install.packages("fulltext")
library(fulltext)

k <- ft_get(oa_dois[1])
k <- fulltext(oa_dois[1])

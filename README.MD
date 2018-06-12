# Corpwatch API Backend

This is the backend data processing code that fetches, parses, processes, and stores SEC 10-k filings for use by the CorpWatch API: http://api.corpwatch.org/

_Please note that this project is currently unfunded, and that the developers have not actively worked on the code since 2010_


## How to run
These instructions have note fully been tested. If you find something is missing, please file an issue.

```
# Install dependencies - here's a (possibly incomplete) list of packages required by the project to run on `Ubuntu 18.04`.
apt-get update
apt-get install mysql-server libwww-mechanize-perl libdbi-perl libcompress-raw-zlib-perl libdatetime-format-builder-perl libdatetime-format-iso8601-perl libdatetime-format-strptime-perl libhtml-element-extended-perl libparallel-forkmanager-perl libhtml-tableextract-perl libhtml-treebuilder-xpath-perl liblwp-protocol-https-perl liblwp-mediatypes-perl libtext-unidecode-perl libtime-modules-perl libxml-simple-perl libdbd-mysql-perl

# Create a mysql database schema (see below on how to override default db settings):
sudo mysql -u root -e "create database edgarapi_live; grant all on edgarapi_live.* to 'edgar'@'localhost' identified by 'edgar'"

# Populate the schema with the table definitions:
mysql -u edgar -p edgarapi_live < mysql_database_structure.sql

# Import the static data tables:
mysql -u edgar -p edgarapi_live < data_tables.sql

# Run the update script and be very patient
./update_data.sh
```
By default, the code will fetch all filings from Q1 2003 to the present. This can be modified  by adjusting `@years_available` in `common.pl`

The following environment variables can be used to configure the db connection, or just set your schema/user to use the defaults:

Environment Variable | Default Value
-------- | -------
EDGAR_DB_HOST | localhost
EDGAR_DB_NAME | edgarapi_live
EDGAR_DB_USER | edgar
EDGAR_DB_PASSWORD | edgar  

## Data processing overview
* `cleanup_state.pl` - Clean up database state, remove any orphaned data from incomplete runs, etc.
* `fetch_10ks.pl` - download SEC filings
* `fetch_filer_headers.pl` - fetches html header files for filings, to be parsed by parse_headers.pl
* `parse_headers.pl` - extracts company meta data from the headers of 10-K filings
* `update_cik_name_lookup.pl` - downloads a list of former and alternative names for companies and stores them in the table `cik_name_lookup`
* `relationship_wrapper.pl` - manages the execution of multiple copies of the section21Header processing script in order to get around a memory leak in a perl library, and at the same time take advantage of multiple processors on the host machine. The script it executes, `sec21_headers.pl`, is the core of the subsidiary parser - it processes the Exhibit 21 filings to try to pull out subsidiary names, locations, and hierarchy using a bunch of crazy regexs and stopwords
* `clean_relationships.pl` - cleans the subsidiary relationships data that has been parsed from the 10-K Section 21 filings.  It also cleans the names in the filers and cik_name_lookup table.  The names of companies in each of the tables are normalized so that they can be matched, and the location codes are mapped to UN country codes where possible.
* `populate_companies.pl` - repopulate the companies_* tables using the information that has been parsed from the filings.

## Table descriptions (incomplete)
### Primary Tables

Table Name | Description
---------- | ------------
companies | meta information about company entities (defines cw_id)
company_locations | address or location tags for companies
company_names | company name variants
company_relations | parent-child relationships between companies
filings | info about filing records

### Intermediate tables used in processing

Table Name | Description
---------- | ------------
filers | companies that appeared as filers on 10-K forms
filing_tables | information about the parsing of the filings
relationships | raw relationships as parsed from Section 21 filings
croc_companies | lists of companies from Crocodyl, matched to cik ids
cik_name_lookup | master list names and CIK ids from EDGAR
not_company_names | strings that appear in parsed data that are definitely NOT companies

### Static data tables

Table Name | Description
---------- | ------------
sic_codes | definitions of ~500 SIC industry codes
sic_sectors | definition of middle level SIC industry sectors
stock_codes | ticker symbol and name for 3354 companies
un_countries | official list of UN country names and codes
un_country_aliases | alternate country and location names
un_country_subdivisions | list of UN states, provinces, etc
region_codes | translation table for SEC to UN country and region codes
unlocode | other locations (metropolitan areas, etc)
word_freq | table of frequencies of words appearing in company names to help fuzzy matching

## Known issues
* There is a query in parse_headers.pl (second query after 'Hiding bad ciks' that takes a *very* long time to run, even with minimal data. I'm guessing that we need to populate the tables with some additional data maybe to minimize the number of joins, as it seems to not long on a populated database
* sec21_headers.pl outputs a *lot* of errors relating to the html table extraction library. It *seems* to still be parsing the tables, though I have not tested thoroughly. 

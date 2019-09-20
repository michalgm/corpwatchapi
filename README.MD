# Corpwatch API Backend

This is the backend data processing code that fetches, parses, processes, and stores SEC 10-k filings for use by the CorpWatch API: http://api.corpwatch.org/

_Please note that this project is currently unfunded, and that the developers have not actively worked on the code since 2010_


## Setup
These instructions have not fully been tested. If you find something is missing, please file an issue.
### Install Dependencies
Choose one of the following.
#### If you have superuser access...
```bash
# Install dependencies - here's a (possibly incomplete) list of packages required by the project to run on `Ubuntu 18.04`.
apt-get update
apt-get install mysql-server libwww-mechanize-perl libdbi-perl libcompress-raw-zlib-perl libdatetime-format-builder-perl libdatetime-format-iso8601-perl libdatetime-format-strptime-perl libhtml-element-extended-perl libparallel-forkmanager-perl libhtml-tableextract-perl libhtml-treebuilder-xpath-perl liblwp-protocol-https-perl liblwp-mediatypes-perl libtext-unidecode-perl libtime-modules-perl libxml-simple-perl libdbd-mysql-perl

# Create a mysql database schema (see below on how to override default db settings):
sudo mysql -u root -e "create database edgarapi_live; grant all on edgarapi_live.* to 'edgar'@'localhost' identified by 'edgar'"
```
#### If you prefer to install dependencies in your home directory...
1. [Install Miniconda](https://docs.conda.io/en/latest/miniconda.html) and then execute:
   ```shell
   conda create -n cwapi              # Create a conda environment
   conda activate cwapi               # Activate into this environment
   conda install -c anaconda mysql -y # Install MySQL
   ```
2. **Set up MySQL server.**
   1. Add environment variables. You can customize the paths as you want:
      ```shell
      export MYSQL_HOME=~/ex21/data/mysql
      export MYSQL_UNIX_PORT=$MYSQL_HOME/socket
      export MYSQL_TCP_PORT=3306
      ```
   2. Initialize MySQL server:
      ```shell
      mysqld --user=$(whoami) --datadir=$MYSQL_HOME --basedir=$MYSQL_HOME --log-error=$MYSQL_HOME/mysql.err --pid-file=$MYSQL_HOME/mysql.pid --socket=$MYSQL_HOME/socket --port=3306 --initialize 
      ```
      The last line will contain a randomly-generated password for the `root` user in MySQL:
      ```
      2019-09-12T06:04:42.207964Z 1 [Note] A temporary password is generated for root@localhost: fob!Ao6cpgGD
      ```
      If you are experiencing error `/usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.21' not found`, you need to first set one more environment variable. 
      First, find a C++ standard library file in your conda installation directory. In my case of using `miniconda3` at `~/miniconda3`, I execute: 
      ```shell
      find ~/miniconda3/ -name "libstdc++.so*"
      ```
      which gives me a list of file paths, many of which are residing in `~/miniconda3/pkgs/libstdcxx-ng-8.2.0-hdf63c60_1/lib`. 
      Thus, I set the environment variable as:
      ```shell
      export LD_LIBRARY_PATH=~/miniconda3/pkgs/libstdcxx-ng-8.2.0-hdf63c60_1/lib:$LD_LIBRARY_PATH
      ```
      and then repeat the `mysqld` command.
   3. Spin up MySQL server:
      ```shell
      mysqld
      ```
      Now open another terminal (tmux pane).
   4. MySQL requires root password to be changed upon first login. Do this by:
      ```shell
      mysqladmin --socket=$MYSQL_HOME/socket --user root --password fob!Ao6cpgGD password
      ```
   and follow the prompts.
   5. Connect to MySQL server as `root`:
      ```shell
      mysql --socket=$MYSQL_HOME/socket --verbose -u root -p
      ```
   and then enter the password you just set to.
   6. Under the `mysql>` prompt, execute the following commands:
   ```sql
   CREATE DATABASE edgarapi_live; --  Create a database for CorpWatch API to use
   CREATE USER 'edgar'@'localhost' IDENTIFIED BY 'edgar'; -- Add a user to the MySQL server
   GRANT ALL PRIVILEGES ON edgarapi_live.* TO 'edgar'@'localhost';
   FLUSH PRIVILEGES;
   exit;
   ```
3. **Set up Perl.**
   1. Install `Perlbrew` via `\curl -L https://install.perlbrew.pl | bash`.
   2. Follow instructions to add the line to your `~/.bashrc`, then restart the shell.
   3. Prepare Perl environment:
      ```shell
      perlbrew install    perl-5.16.0
      perlbrew switch     perl-5.16.0
      perlbrew lib create perl-5.16.0@cwapi # Like creating a virtual env, but for Perl.
      perlbrew use        perl-5.16.0@cwapi
      perlbrew install-cpanm
      cpanm install HTML::TableExtract HTML::Parser HTML::TreeBuilder HTML::ElementTable DBI DBD::mysql JSON Time::ParseDate Term::ProgressBar Parallel::ForkManager Text::Unidecode IO::Socket::SSL
      ```
## Usage

You can parse EX-21s from scratch, or you can pre-populate your MySQL database with the _CorpWatch DB dumps_.

### Pre-populate with CorpWatch DB dumps
Simply,

```shell
wget http://api.corpwatch.org/documentation/db_dump/corpwatch_api_tables_mysql.tar.gz
tar -xvzf corpwatch_api_tables_mysql.tar.gz # Unzip the archive file
pv corpwatch_api_tables_mysql/*.sql | mysql --socket=$MYSQL_HOME/socket -u edgar -p edgarapi_live
```

and enter password for MySQL user `edgar` (in this example of mine, it's `edgar`) when prompted.

Alternatively, you can...

### Parse Filings from Scratch

```bash
# Populate the schema with the table definitions:
mysql -u edgar -p edgarapi_live < mysql_database_structure.sql

# Import the static data tables:
mysql -u edgar -p edgarapi_live < data_tables.sql

# Run the update script and be very patient
./update_data.sh
```

By default, the code will fetch all filings from Q1 2003 to the present. This can be modified  by adjusting `@years_available` in `common.pl`

## Environment Variables
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

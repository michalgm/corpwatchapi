# Corpwatch API Backend

This is the backend data processing code that fetches, parses, processes, and stores SEC 10-k filings for use by the CorpWatch API: http://api.corpwatch.org/

_Please note that this project is currently unfunded, and that the developers have not actively worked on the code since 2010_


## How to run
These instructions have note fully been tested. If you find something is missing, please file an issue.

* Install dependencies - here's a (possibly incomplete) list of packages required by the project to run on `Ubuntu 14.04`.
```
RUN apt-get update
RUN apt-get install -y \
	mysql-server \
	libwww-mechanize-perl \
	libdbi-perl \
	libcompress-raw-zlib-perl \
	libdatetime-format-builder-perl \
	libdatetime-format-iso8601-perl \
	libdatetime-format-strptime-perl \
	libhtml-element-extended-perl \
	libparallel-forkmanager-perl \
	libhtml-tableextract-perl \
	libhtml-treebuilder-xpath-perl \
	liblwp-protocol-https-perl \
	liblwp-mediatypes-perl \
	libtext-unidecode-perl \
	libtime-modules-perl \
	libxml-simple-perl
```

* Create a mysql database schema. The following environment variables can be used to configure the db connection, or just set your schema/user to use the defaults:

Variable | Default
-------- | -------
EDGAR_DB_HOST | localhost
EDGAR_DB_NAME | edgarapi_live
EDGAR_DB_USER | edgar
EDGAR_DB_PASSWORD | edgar  

* Populate the schema with the table definitions: `mysql -u edgar -p edgarapi_live < mysql_database_structure.sql`

* Run `bash update_data.sh` and be very patient. By default, the code will fetch all filings from Q1 2003 to the present. This can be modified  by adjusting `@years_available` in `common.pl`

# Corpwatch API Backend

This is the backend data processing code that fetches, parses, processes, and stores SEC 10-k filings for use by the CorpWatch API: http://api.corpwatch.org/

_Please note that this project is currently unfunded, and that the developers have not actively worked on the code since 2010_


## How to run
These instructions have note fully been tested. If you find something is missing, please file an issue.

1. Install dependencies - here's a (possibly incomplete) list of packages required by the project to run on `Ubuntu 18.04`.
```
apt-get update
apt-get install mysql-server libwww-mechanize-perl libdbi-perl libcompress-raw-zlib-perl libdatetime-format-builder-perl libdatetime-format-iso8601-perl libdatetime-format-strptime-perl libhtml-element-extended-perl libparallel-forkmanager-perl libhtml-tableextract-perl libhtml-treebuilder-xpath-perl liblwp-protocol-https-perl liblwp-mediatypes-perl libtext-unidecode-perl libtime-modules-perl libxml-simple-perl libdbd-mysql-perl
```

2. Create a mysql database schema (see below on how to override default db settings): `sudo mysql -u root -e "create database edgarapi_live; grant all on edgarapi_live.* to 'edgar'@'localhost' identified by 'edgar'"`
3. Populate the schema with the table definitions: `mysql -u edgar -p edgarapi_live < mysql_database_structure.sql`

4. Run `bash update_data.sh` and be very patient. By default, the code will fetch all filings from Q1 2003 to the present. This can be modified  by adjusting `@years_available` in `common.pl`

The following environment variables can be used to configure the db connection, or just set your schema/user to use the defaults:

Environment Variable | Default Value
-------- | -------
EDGAR_DB_HOST | localhost
EDGAR_DB_NAME | edgarapi_live
EDGAR_DB_USER | edgar
EDGAR_DB_PASSWORD | edgar  

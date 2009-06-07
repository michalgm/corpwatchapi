
Readme.txt for CorpWatch API Backend Code

June 6, 2009

The CorpWatch API uses automated parsers to extract the subsidiary relationship information from Exhibit 21 of companies' 10-K filings with the SEC and provides a free, well-structured interface for programs to query and process the data.

This file is intended to give a brief outline of the parsing processes, and quick overview of the various parsing scripts.  

THIS IS OUT DATED, DESCRIBES THE PROCESS AS OF Febuary 10, 2009.  The current version of the code is set up to parse multiple years of data. 

-----------------------------

The backend code is written mostly in perl for speed and efficiency parsing thousands of text files.  Much of the code interacts with a MySQL database.  The final "API" facing tables are available for download, but some of the intermediate processing tables are not included.  If you would like a copy of the schema and auxiliary data tables, please contact support@api.corpwatch.org

-----------------------------

Fetch and process the 10-Ks (fetch_10ks.pl)

   1. Download and unzip the indexes of filings for each Quarter from ftp://ftp.sec.gov/edgar/full-index/2008/QTR4/master.gz
   2. Load all the filings listings into the database.
   3. Download all the filings with type 10-K or 10-K/A
   4. Locate the header within then 10-K by xml tag and save to disk.
   5. Locate the Section 21 filing within the 10-K by the xml tag, and save it to disk.

Note: in some cases multiple filers share the same "physical" filing at the SEC.

Parse the information about the filers from the 10-Ks (parse_10ks.pl)

Parse and load the information about filers into the database. Each filing can contain information about multiple filers, we don't try to resolve this.

Try to parse subsidiary information from the Section 21s (sec21_headers.pl)

Here begins an incredibly complicated process of trying to identify how the section is formatted, if single or multiple columns, if it is in html, the column order, how it is split over pages. Keeps trying different techniques and falling back if it unable to get data. Only those results that appear to contain both a company name and location data are inserted in the database, as subsidiaries of the parent filer.

To deal with a painful memory leak in a perl html parsing library, this actually run as a forked process by relationship_wrapper.pl

Cleaning and matching (clean_relationships.pl)

   1. If we can identify that the "company name" is definitly a location (matches with country or state name) then the parser presumably got it wrong, so we swap company_name and location.
   2. Punctuation and abbreviations are standardized to try to match the SEC conformation spec and entered into a database as a "match_name". This is done for both the filing and subsidiary companies.
   3. For the subsidiary company names we also replace non-ascii characters (accents and UTF8 codes) with their closest ascii equivalents and store both versions. Some stop words and types of formatting that often surround company names and locations are removed, such as "" and ().
   4. Not all of the names in EDGAR correctly follow the the SEC's own conformation spec, so we create match_names for them as well.
   5. Subsidiary company names that match the EDGAR master list are tagged with the EDGAR CIK id.

populating the API-facing database tables (populate_companies.pl)

   1. Because of many-to-many relations between companies and names, and between companies and locations they are loaded into multiple tables.
   2. All of the filers (companies that have 10-Ks and CIK ids) are loaded into the companies table and given cw_ids.
   3. All of the names and locations associated with the filing companies are stored in the respective tables.
   4. Locations with countries and state codes in the SEC format are converted to the UN format
   5. All of the subsidiary companies that are tagged with a CIK are loaded into companies table.
   6. All of the un-matched subsidiary companies are added to the companies table.
   7. Names and locations of subsidiary companies are added to respective tables.
   8. Locations are coded with country and subdivision codes by matching to the tables of UN-names and location aliases.
   9. The subsidiary relationships, expressed as a pair of cw_ids for parent and child, are transferred to company_relations table.



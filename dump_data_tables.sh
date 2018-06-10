#/bin/bash
mysqldump -u root edgarapi_live word_freq sic_codes sic_sectors  stock_codes  not_company_names parsing_stop_terms un_countries un_country_aliases un_country_subdivisions region_codes unlocode > data_tables.sql

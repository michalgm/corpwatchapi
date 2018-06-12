#!/bin/sh
time perl cleanup_state.pl
time perl fetch_10ks.pl
time perl fetch_filer_headers.pl
time perl parse_headers.pl
time perl update_cik_name_lookup.pl
time perl relationship_wrapper.pl;
time perl clean_relationships.pl;
time perl populate_companies.pl;

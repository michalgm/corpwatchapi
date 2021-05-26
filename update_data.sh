#!/bin/bash

perl cleanup_state.pl | ts
perl fetch_10ks.pl | ts
perl fetch_filer_headers.pl | ts
perl parse_headers.pl | ts
perl update_cik_name_lookup.pl | ts
perl relationship_wrapper.pl | ts
perl clean_relationships.pl | ts
perl populate_companies.pl | ts

#!/usr/bin/perl -w


require "common.pl";

#The purpose of this is to repopulate the companies_* tables using the information that has been parsed from the filings. 

#TODO: figure out system to magically preserve ids for companies across db updates
#reset the tables so that the ids restart from zero

&cleanTables();
&insertFilers();
&matchRelationships();
&createRelationshipCompanies();
&insertNamesAndLocations();
&insertRelationships();
exit;

#clear out the tables and preparse for receiving new data
sub cleanTables() {
	print "Updating cw_id_lookup...\n";
	$db->do("insert ignore into cw_id_lookup (cw_id, company_name, cik) select a.cw_id, a.company_name, a.cik from companies a");
	print "Resetting tables...\n";
	$db->do("delete from companies");
# 	We shouldn't ever reset the auto_increment on companies anymore	$db->do("alter table companies auto_increment=0");
	$db->do("delete from company_names");
	$db->do("alter table company_names auto_increment=0");
	$db->do("delete from company_locations");
	$db->do("alter table company_locations auto_increment=0");
	$db->do("delete from company_relations");
	$db->do("alter table company_relations auto_increment=0");
	$db->do("update relationships set cw_id = NULL, parent_cw_id = null");
	$db->do("update filers set cw_id = NULL");
	#Repair table state, if we lft it in a bad state
	$db->do("alter table relationships add key cw_id (cw_id)");
	$db->do("alter table companies enable keys");
	$db->do("alter table relationships add key parent_cw_id (parent_cw_id)");
}

#The filers are the companies that we have at least some info from the SEC about, not just 10-k filers
sub insertFilers() {

	print "Inserting Filers...\n";

	# fill in cw_ids for filers from cw_id_lookup
	$db->do("update filers a join cw_id_lookup b on company_name = match_name and a.cik = b.cik set a.cw_id = b.cw_id");
	$db->do("update filers a join cw_id_lookup b on company_name = match_name and a.cik is null and b.cik is null set a.cw_id = b.cw_id");
	# ---- make company entries for each of the filers ----
	$db->do("insert into companies (cw_id, row_id, cik, company_name, irs_number, sic_category, source_type, source_id) select cw_id, replace(cw_id, 'cw_', ''), cik, match_name, max(irs_number), max(sic_code), 'filers', filer_id from filers group by cik");
	$db->do("update companies set cw_id = concat('cw_',row_id)");

	#TODO: need to collapse dupes, using irs id? Or collapse some of the match_name dupes?

	#put the match names of the filers in the names table

	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,filers.cw_id, match_name, filing_date, 'filer_match_name', filer_id from filers join filings using (filing_id) join companies on filers.cik = companies.cik group by companies.cik"); 

	#put in  the edgar "conformed" name if it is differnt from the match_name
	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,filers.cw_id, conformed_name, filing_date, 'filer_conformed_name', filer_id from filers join filings using (filing_id) join companies on filers.cik = companies.cik where conformed_name != match_name group by companies.cik"); 

	#insert former names of filers into the names table (if there are any)
	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,filers.cw_id, former_name,date(name_change_date), 'filer_former_name', filer_id from filers join companies using (cik) where former_name is not null");

	#if we are using the html forms as the source, we won't have former names of filers.  So instead, get them from the cik_name_lookup.  Only problem is that we don't have the name change date :-(
	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,cw_id,cik_name_lookup.match_name,null as date,'cik_former_name',cik_name_lookup.row_id from company_names join companies using (cw_id) join cik_name_lookup using (cik) where source = 'filer_match_name' and name != cik_name_lookup.match_name group by cw_id,match_name");

	#now process the locations of the filers

	print "Inserting Filer Location and SIC info...\n";
	#/* put the biz address, mail address, and name state suffix in locations with id*/
	$db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, street_1, street_2, city, state, postal_code) select null,companies.cw_id,filing_date,"business",concat_ws(", ",business_street_1, business_street_2,business_city,business_state,business_zip) raw, business_street_1, business_street_2,business_city,business_state,business_zip from filers join companies using (cik) join filings using (filing_id) where business_street_1 is not null');
	$db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, street_1, street_2, city, state, postal_code) select null,companies.cw_id,filing_date,"mailing",concat_ws(", ",mail_street_1, mail_street_2,mail_city,mail_state,mail_zip) raw, mail_street_1, mail_street_2,mail_city,mail_state,mail_zip from filers join companies using (cik) join filings using (filing_id) where mail_street_1 is not null');

#add in locations for the state of incorporation of filers.  This query maybe not quite correct, as info was scraped, not from filings?
    $db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, country_code, subdiv_code) select null,companies.cw_id,filing_date,"state_of_incorp",state_of_incorporation raw, incorp_country_code,incorp_subdiv_code from filers join companies using (cik) join filings using (filing_id) where state_of_incorporation is not null');

	#/* fill in un country and subdiv codes o the filers where possible */
	#TODO; this should now be done in clean relationships script
	$db->do("update company_locations,region_codes set company_locations.country_code = region_codes.country_code, company_locations.subdiv_code = region_codes.subdiv_code where company_locations.state = region_codes.code");

	#fill in the sic hierarchy where we have sic codes
	$db->do("update companies, (select cw_id,sic_category, sic_codes.industry_name, sic_sectors.sic_sector, sic_sectors.sector_name from companies join sic_codes on sic_category=sic_code join sic_sectors on sic_codes.sic_sector = sic_sectors.sic_sector) sic set companies.industry_name = sic.industry_name, companies.sic_sector = sic.sic_sector, companies.sector_name = sic.sector_name where companies.cw_id = sic.cw_id");
}

#this section processes the companies that we have scraped out of the filer's section 21 filings, in many cases we don't have SEC info
sub matchRelationships() {
	#----- create companies for the relationship companies -------
	#try to assign CIKs to relationship companies
	#WARNING: SOME NAMES HAVE MULTIPLE CIKs, and some CIKs have multiple names
	print "-----Matching relationship companies...\n";
	print "\tChecking against parent companies...\n";

	#match cases where relationship company matches with filers name,cik, and location, these will be discarded later
	$db->do("update relationships a join filings b on a.filing_id = b.filing_id and b.has_sec21 =1 join filers c on b.cik = c.cik and a.clean_company = c.match_name and a.country_code = c.incorp_country_code and a.subdiv_code = c.incorp_subdiv_code set a.cik = c.cik");

	#also tag the cases where one side of the location is missing
	$db->do("update relationships a join filings b on a.filing_id = b.filing_id and b.has_sec21 =1 join filers c on b.cik = c.cik and a.clean_company = c.match_name and (a.country_code is null or c.incorp_country_code is null) set a.cik=c.cik");

	#this query gives a list of companies that we didn't match to parents, but maybe we should have if a human could verify:
	#select a.company_name,c.conformed_name,a.country_code,a.subdiv_code,c.incorp_country_code,c.incorp_subdiv_code,c.business_state from relationships a join filings b on a.filing_id = b.filing_id and b.has_sec21 =1 and a.cik is null join filers c on b.cik = c.cik and a.clean_company = c.match_name 
	# set these cik of these to '-1' so that they won't be matched and can be reviewed by a human?
	$db->do("update relationships a join filings b on a.filing_id = b.filing_id and b.has_sec21 =1 and a.cik is null join filers c on b.cik = c.cik and a.clean_company = c.match_name set a.cik = -1");


	# exact match against filers, assuming they are more recent, less dupes, and have locations to match  against
	print "\tMatching relationship companies against filers (some filers are confuseable on match_name)..\n";
	#chose randomly between filers with the same match name
	$db->do("update relationships a join filers b on clean_company = match_name and a.country_code = b.incorp_country_code and a.subdiv_code = b.incorp_subdiv_code and a.cik is null set a.cik = b.cik");

	#then exact match the relationship companies against the master list of EDGAR CIK names to see if we can assign any ciks that way
	#WARNING:  SOME MATCH AGAINST MULTIPLE NAMES, CIK CHOSEN RANDOMLY
	$db->do("update relationships a join cik_name_lookup b on clean_company = match_name and a.cik is null set a.cik = b.cik");
	#Fill in cw_ids for relationships from cw_id_lookup
	$db->do("update relationships a join cw_id_lookup b on clean_company = b.company_name and a.cik = b.cik and a.cik is not null and a.cw_id is null set a.cw_id = b.cw_id");
	$db->do("update relationships a join cw_id_lookup b on clean_company = b.company_name and a.cik is null and b.cik is null and a.cw_id is null set a.cw_id = b.cw_id");
}

sub createRelationshipCompanies() {
	#fuzzy matcch company names. 
	#resolve dupes on relationship companies
	print "creating relationship companies...\n";
	#create companies for relationship companies that are not from the filers list
	$db->do("insert into companies (cik, row_id, company_name, source_type, source_id) select a.cik, replace(a.cw_id, 'cw_', ''), clean_company, 'relationships', relationship_id from relationships a left join companies b on clean_company = b.company_name and a.cik = b.cik where b.cw_id is null and a.cw_id is not null group by a.cw_id");
	my $sth = $db->prepare("select cik, clean_company, relationship_id from relationships left join companies using (cik) where companies.cik is null and relationships.cw_id is null");
	$sth->execute();
	$db->do("alter table relationships drop key cw_id");
	$db->do("alter table companies disable keys");
	my $inserted_companies;
	while (my $relate = $sth->fetchrow_hashref()) {
		my $existing_cw_id;
		#my $sth2 = $db->prepare_cached("select row_id from companies where company_name = ? and source_type = 'relationships' limit 1");
		#$sth2->execute($relate->{clean_company});
		if ($inserted_companies->{uc($relate->{clean_company})}) {
			$existing_cw_id = $inserted_companies->{uc($relate->{clean_company})};
		} else {
			$db->prepare_cached("insert into companies (cik, company_name, source_type, source_id) values (?,?,'relationships',?)")->execute($relate->{cik}, $relate->{clean_company}, $relate->{relationship_id});
			$existing_cw_id = $db->last_insert_id(undef, 'edgarapi', 'companies', 'row_id');	
			$inserted_companies->{uc($relate->{clean_company})} = $existing_cw_id;
		}
		#print "$relate->{relationship_id} : $existing_cw_id\n";
		#$sth2->finish;
		$db->prepare_cached("update relationships set cw_id = ? where relationship_id = ?")->execute("cw_".$existing_cw_id, $relate->{relationship_id});
	}
	#$db->do("insert into companies (row_id, cik, company_name, source_type, source_id) select null, cik, clean_company, 'relationships', relationship_id from relationships left join companies using (cik) where companies.cik is null group by clean_company,country_code,subdiv_code, cik");
	$db->do("update companies set cw_id = concat('cw_',row_id) where cw_id not like 'cw_%' or cw_id is null");
	$db->do("alter table relationships add key cw_id (cw_id)");
	$db->do("alter table companies enable keys");
	$db->do("update relationships a join companies b using (cik) set a.cw_id = b.cw_id where a.cw_id is null and b.cik is not null");
}

sub insertNamesAndLocations() {
	print "inserting names and locations...\n";
	#put those names into the names table
	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,b.cw_id, a.company_name, filing_date, 'relationships_company_name', relationship_id from relationships a join companies b on b.cw_id = a.cw_id join filings c using(filing_id) where b.source_type = 'relationships' group by b.cw_id, company_name collate 'utf8_bin'");
   #if the original name is differnt than the clean name, put that in. 
	$db->do("insert into company_names (name_id, cw_id, name, date, source, source_row_id) select null,b.cw_id, clean_company, filing_date, 'relationships_clean_company', relationship_id from relationships a join companies b on b.cw_id = a.cw_id join filings c using(filing_id) where b.source_type = 'relationships' and a.company_name collate 'utf8_bin' != clean_company collate 'utf8_bin' group by b.cw_id, clean_company collate 'utf8_bin'");


	#put the relationships' locations that have been sucessfully tagged into the locations table
	$db->do("insert into company_locations (location_id,cw_id,date,type,raw_address,country_code,subdiv_code) select null,a.cw_id,filing_date,'relation_loc',location, country_code,subdiv_code from companies a join relationships on source_type = 'relationships' and a.source_id = relationships.relationship_id and location is not null
	join filings using (filing_id)");


	# --- FIGURE OUT WHAT THE BEST (MOST COMPLETE) ADDRESS INFO IS
	#first choice is business address, but if that is null, using mailing, if that is null, use the location with both country and state, if that is null use whatever is left. 
	$db->do("update companies, 
	(select cw_id, 
	if (a is not null,a,
	  if (b is not null, b, 
		if (c is not null, c,d)
	  )
	)
	best_id from
	(select cw_id, max(biz_loc) a,max(mail_loc) b,max(rel_loc) c,max(s_rel_loc) d from (select cw_id,if ((type = 'business' and street_1 is not null),location_id,null) biz_loc, 
	if ((type = 'mailing' and street_1 is not null),location_id,null) mail_loc,
	if ((type = 'relation_loc' and subdiv_code is not null),location_id,null) rel_loc,
	if ((type = 'relation_loc'),location_id,null) s_rel_loc
	from company_locations ) merged group by cw_id) best) best_loc
	set companies.best_location_id = best_loc.best_id
	where companies.cw_id = best_loc.cw_id");
}

sub insertRelationships() {
	# --- PUT THE RELATIONS IN THE COMPANY RELATIONS TABLE -------
	print "Setting up hierarchies...\n";
	$db->do("alter table relationships drop key parent_cw_id");
	$db->do("update relationships set hierarchy = 0 where hierarchy is null");
	my $filings = $db->selectall_arrayref('select filing_id from relationships group by filing_id having min(hierarchy) != max(hierarchy)');
	foreach my $filing (@$filings) {
		my ($filing_id) = @$filing;
		#print "$filing_id\n";
		my $relates = $db->selectall_arrayref("select cw_id, hierarchy from relationships where filing_id = '$filing_id' order by relationship_id");
		my $parents = [{hierarchy=>0, id=>0}];
		my $level = 0;
		foreach my $relate (@$relates) {
			my ($cw_id, $hierarchy) = @$relate;
			unless ($hierarchy) { 
				$hierarchy = 0; 
			}
			if ($hierarchy > $parents->[$level]->{'hierarchy'}) {
				$level++;
			} elsif ($hierarchy <= $parents->[$level]->{'hierarchy'}) {
				while ($hierarchy < $parents->[$level]->{'hierarchy'} && $level > 0) {
					$level--;
				}
			}
			$parents->[$level] = {id=>$cw_id, hierarchy=>$hierarchy};
			my $parent_id = $parents->[$level-1]->{id};
			if ($level == 0) { $parent_id = 0; } 
			if ($parent_id ne $cw_id && $parent_id ne 0) {	
				my $sth = $db->prepare_cached("update relationships set parent_cw_id = ? where cw_id = ?");
				#print "\t$cw_id: $parent_id\n";
				$sth->execute($parent_id, $cw_id) || die "this died";
			}
		}
	}

	# Give relationships that have no parent_cw_id the cw_id of the filer as the parent
	$db->do("update relationships a join filings b using (filing_id) join companies c on b.cik = c.cik set parent_cw_id = c.cw_id where (parent_cw_id is null or parent_cw_id = '0')");
	$db->do("alter table relationships add key parent_cw_id (parent_cw_id)");

	# Insert relationship into company_relations table, ignoring dupes
	print "inserting relationships...\n";
	$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id) select null,parent_cw_id, cw_id, 'relationships', relationship_id from relationships where cw_id != parent_cw_id group by cw_id, parent_cw_id");

	print "updating company meta data...\n";
	# update the companies table with the counts of parents and children
	$db->do("update companies, (select companies.cw_id,
	 count(distinct parents.source_cw_id) num_parents ,count(distinct kids.target_cw_id) num_children 
	from companies
	left join company_relations kids on companies.cw_id = kids.source_cw_id
	left join company_relations parents on companies.cw_id = parents.target_cw_id
	group by companies.cw_id) relcount
	set companies.num_parents = relcount.num_parents,
	companies.num_children = relcount.num_children
	where companies.cw_id = relcount.cw_id");


}
exit;

#$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id) select null, c.cw_id, d.cw_id, 'relationships', a.relationship_id from relationships a join filings b using (filing_id) join companies c on b.cik = c.cik join companies d on a.cik = d.cik and a.cik is not null where c.cw_id != d.cw_id group by c.cw_id,d.cw_id");

#insert the rest of the relationships, matching against the clean company name
#make sure not to insert relations that have already been inserted
#TODO:  THIS QUERY IS WRONG, INSERTS TOO MANY COMPANIES!
#$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id) select null,c.cw_id, d.cw_id, 'relationships', a.relationship_id from relationships a join filings b using (filing_id) join companies c on b.cik = c.cik join companies d on a.clean_company = d.company_name left join company_relations e on origin_id = relationship_id and relation_origin = 'relationships' where c.cw_id != d.cw_id and e.origin_id is null group by c.cw_id,d.cw_id");



# ------ SUBROUTINE FOR MATCHING RELATIONSHIP LOCATIONS ---

__END__;

#everything below is not run, notes  and cruft included here for reference
/* add locations to company names */

/* collapse all redundant company names entries */

/* put the stripped-off locations from the company names as locations also */

insert into company_locations select null,cw_id,filing_date,"name_state", null,null,null,null, (CASE
WHEN conformed_name like "%/__/"  THEN left(right(conformed_name,3),2)
WHEN conformed_name like "%\\\__\\"  THEN left(right(conformed_name, 3),2)
WHEN conformed_name like "%/__" THEN right(conformed_name, 2)
ELSE null
END) as state,null,null,null,null from filers join companies using (cik) join filings using (filing_id)  having state is not null;







#!/usr/bin/perl -w
require "./common.pl";
$| = 1;
our $db;

my @tables = ('relationships', 'filers', 'companies', 'company_relations', 'company_names', 'company_locations', 'company_info', 'filings_lookup', 'company_filings');
foreach my $table (@tables) { 
	$db->do("delete from $table");
	$db->do("alter table $table auto_increment 0");
}


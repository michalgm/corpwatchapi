#!/usr/bin/perl

    # Copyright 2009 CorpWatch.org 
    # San Francisco, CA | 94110, USA | Tel: +1-415-641-1633
    # Developed by Greg Michalec and Skye Bender-deMoll
    
    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU General Public License as published by
    # the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU General Public License for more details.

    # You should have received a copy of the GNU General Public License
    # along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
#---------------------------------------
# This script is used to extract company meta data from SEC filings and store in db
#---------------------------------------


use Data::Dumper;

require './common.pl';

my $keys;
if ($ARGV[0]) { $where = " and filing_id = $ARGV[0] "; }

#prepare insert and update queries
my $sth = $db->prepare("insert into filers (filer_id, filing_id, cik, irs_number, conformed_name, fiscal_year_end, sic_code, business_street_1, business_street_2, business_city, business_state, business_zip, mail_street_1, mail_street_2, mail_city, mail_state, mail_zip, form_type, sec_act, sec_file_number, film_number, former_name, name_change_date, business_phone, state_of_incorporation) values (NULL ". ", ?" x 24 .")") || die "$!";
my $sth2 = $db->prepare("update filings set period_of_report=?, date_filed=?, date_changed=? where filing_id = ?") || die "$!";

$db->do("delete from filers");
$db->do("alter table filers auto_increment= 0");

my $filings = $db->selectall_arrayref("select filing_id, filename, quarter, year, cik, company_name from filings where has_sec21 = 1 $where order by filing_id") || die "$!";

foreach my $filing (@$filings) {
	my $filing_id = $filing->[0];
	&parse10k("$datadir/$filing->[3]/$filing->[2]/$filing_id.hdr", $filing_id);
}

sub parse10k { 
	my $file = shift;
	my $filing_id = shift;
	unless (-f $file) { return; }
	my $content;
	open(FILE, $file) || die "$!";
	while (<FILE>) { $content .= $_; }
	close FILE;
	$content =~ /^<SEC-HEADER>(.+?)(FILER.+)<\/SEC-HEADER>$/s;
	my ($header, $filers) = ($1, $2);

	my @values;
	my $filing_data;
	foreach my $line (split("\n", $header)) {
		my ($key, $value) = split(/:\s+/, $line);
		$filing_data->{$key} = $value;
	}
	foreach my $key ('CONFORMED PERIOD OF REPORT', 'FILED AS OF DATE', 'DATE AS OF CHANGE') {
		push(@values, $filing_data->{$key});
	}
	push (@values, $filing_id);
	$sth2->execute(@values) || die $!;
	&parse_filers($filers, $filing_id);
	return;
}

sub parse_filers {
	my $filers = shift;
	my $filing_id = shift;
	print "$filing_id - ";
	foreach my $filer (split("FILER:", $filers)) {
		if ($filer) { 
			print ".";
			my $filer_data;
			my $section;
			my $key;
			foreach my $line (split("\n", $filer)) {
				my ($key, $value) = split(/:\s+/, $line, 2);
				$key =~ s/(\s\s+|\t)//g;
				if ($key eq "STANDARD INDUSTRIAL CLASSIFICATION") { 
					$value =~ s/.*\[(\d+)\]/$1/;
				} 
				if (! $value && $key) { $section = $key; next; }
				$filer_data->{"$section\_$key"} = $value;
			}
			my @values = ($filing_id);

			foreach my $key ('COMPANY DATA_CENTRAL INDEX KEY', 'COMPANY DATA_IRS NUMBER', 'COMPANY DATA_COMPANY CONFORMED NAME', 'COMPANY DATA_FISCAL YEAR END', 'COMPANY DATA_STANDARD INDUSTRIAL CLASSIFICATION', 'BUSINESS ADDRESS_STREET 1', 'BUSINESS ADDRESS_STREET 2', 'BUSINESS ADDRESS_CITY', 'BUSINESS ADDRESS_STATE', 'BUSINESS ADDRESS_ZIP', 'MAIL ADDRESS_STREET 1', 'MAIL ADDRESS_STREET 2', 'MAIL ADDRESS_CITY', 'MAIL ADDRESS_STATE', 'MAIL ADDRESS_ZIP', 'FILING VALUES:_FORM TYPE', 'FILING VALUES:_SEC ACT', 'FILING VALUES:_SEC FILE NUMBER', 'FILING VALUES:_FILM NUMBER', 'FORMER COMPANY_FORMER CONFORMED NAME', 'FORMER COMPANY_DATE OF NAME CHANGE', 'BUSINESS ADDRESS_BUSINESS PHONE', 'COMPANY DATA_STATE OF INCORPORATION') { 
				push (@values, $filer_data->{$key});
			}
			$sth->execute(@values) || die "$!: ".$db->errstr."\n";
		}
	}
	print "\n";
}


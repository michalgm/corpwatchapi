#!/usr/bin/perl 
chdir "/home/dameat/edgarapi/backend/";
print "content-type: text/html\n\n";
#print `pwd`;
#exit;
use CGI qw/:standard/;
require "common.pl";

our $db;
our $datadir;
my $cgi = CGI->new();
my $action = param('action');

print "<html>";

if ($action eq 'index') {
	$checked = param('onlycroc') eq 'on' ? 'checked': '';
	$badchecked = param('bad') eq 'on' ? 'checked': '';
	$emptychecked = param('empty') eq 'on' ? 'checked': '';
	print "<div id='search' style='position: fixed; padding: 10px; right: 20px; top: 20px; background: #9999EE;'><form action='links.pl' method='get'>
	<input type='checkbox' name='onlycroc' $checked>Only show Crocodyl Companies<br/>
	<input type='checkbox' name='bad' $badchecked>Only show badly parsed<br/>
	<input type='checkbox' name='empty' $emptychecked>Only show filings w/o relationships<br/>
	<input type='hidden' name='action' value='index'><input name='search'><input type='submit'></form></div>";
	if ($checked || $badchecked) { 
		$join = " join croc_companies b on b.cik = a.cik and type like '10-K%' ";
		if ($badchecked) { $where = " and parsed_badly = 1 "; }
	}
	if ($emptychecked) {
		$join .= " left join (select filing_id from relationships group by filing_id) r using (filing_id) ";
	}
	if (param('search')) { 
		$search = param('search');
		if ($search =~ /^\d+$/) { 
			$where = " and (filing_id = $search or cik = $search) "
		} else { 
			$where = " and company_name like '%$search%'";
		}
	}
	if ($emptychecked) { $where .= "and r.filing_id is null"; }
	$query = "select filing_id, filename, quarter, year, a.cik, a.company_name from filings a $join where has_sec21 = 1 $where order by company_name limit 1000";
	print "$query<br>";
	$filing = $db->selectall_arrayref("$query") || die "$!";
	foreach my $filing (@$filing) {
		open(FILE, "$datadir/$filing->[3]/$filing->[2]/$filing->[0].sec21");
		my $filename;
		#scan through the Section 21 to locate the file name
		while (<FILE>) { 
			if ($_ =~ /^<FILENAME>(.+)/) {
				$filename = $1;
				last;
			}
		}
		my $path = $filing->[1];
		$path =~ s/\-//g;
		$path =~ s/.{4}$//;
		$onclick = "javascript: parent.htmlsrc.location=\"http://idea.sec.gov/Archives/$path/$filename\"; parent.relates.location=\"links.pl?action=lookup&id=$filing->[0]\"; return false;";
		$link = "<a onclick ='$onclick' href='http://idea.sec.gov/Archives/$path/$filename'>$filing->[5] ($filing->[4] / $filing->[0])</a><br>\n";
		print $link;
	}
} elsif ($action eq 'lookup') {
	$relates = $db->selectall_arrayref("select * from relationships where filing_id = ".param('id')." order by relationship_id") || die "$!";
	print "<table border=1>";
	if (! $relates->[0]) { print "no relationships found"; }
	foreach $relate (@$relates) {
		print "<tr><td>$relate->[1]</td><td>$relate->[2]</td><td>$relate->[9]</td></tr>\n";
	}
	print "</table>";
} else {
 print "<frameset rows='30%, 70%'>
			<frame name='index' frameborder=1 src='links.pl?action=index'>
			<frameset cols='50%,50%'>
			<frame name='htmlsrc'  frameborder=1 src=''>
			<frame name='relates' frameborder=1 src=''>
			</frameset>
		</frameset>";
}

print "</html>";


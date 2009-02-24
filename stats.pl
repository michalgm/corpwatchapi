#!/usr/bin/perl 
use CGI;
print CGI::header();
#chdir("/home/dameat/edgarapi/backend/"); 
#require "common.pl";
my $db = dbconnect;
my $query = "

select count(*)  from filings where has_sec21 =1 union select  count(distinct filing_id) from relationships union select num2/num1*100 from (select count(*) as num1 from filings a where has_sec21 =1) a  join (select  count(distinct filing_id) as num2 from relationships) b union select count(*) from relationships union select concat(num1/num2*100, ' ', num2-num1) from (select count(*) as num1 from relationships a where country_code is not null) a  join (select  count(*) as num2 from relationships) b

";
print "<table>";
foreach my $row (@{$db->selectall_arrayref($query)}) {
	print "<tr>";
	foreach my $cell (@$row) {
		print "<td>$cell</td>";
	}
	print "</tr>";
}


print "</table>";
sub dbconnect {
	my $db = shift;
	unless($db) { $db = 'edgarapi';}
	my $dsn = "dbi:mysql:$db:localhost;mysql_compression=1";
	my $dbh;
	while (!$dbh) {
		$dbh = DBI->connect($dsn, 'edgar', 'edgar', {'mysql_enable_utf8'=>1});
		unless ($dbh) {
			print("Unable to Connect to database\n");
			sleep(10);
		}
	}
	$dbh->{'mysql_auto_reconnect'} = 1;
	return $dbh;
}


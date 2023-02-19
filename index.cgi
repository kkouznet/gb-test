#!/usr/bin/perl -T

use strict;
use warnings;

use DBI;
use CGI;

# DB Settings
my $db         = 'testdb';
my $host       = 'localhost';
my $port       = 5432;
my $dbusername = 'testuser';
my $dbpassword = 'testsecret';
my $filelog    = 'out';


# Set Limit of records
my $limit = 100;

# CGI
my $q = new CGI;

# DB
my $dbstr = "dbi:Pg:dbname=$db;host=$host;port=$port";
my $dbh = DBI->connect( $dbstr, $dbusername, $dbpassword );
if ( !$dbh ) { die "Could not connect to database: " . DBI->errstr; }

# Table tempate for output records
my $tbl = qq{<table border="0" cellspacing="2" width="95%">
[TABLE_ROWS]
</table>
};

my $tbl_ = '';
my $nrecords = '';

my $address = $q->param("address") || '';
$address =~ s/^\s+//;
$address =~ s/\s+$//;
$address = lc($address);

if ( $address && $address =~ /([a-z0-9]([a-z0-9.]+[a-z0-9])?\@[a-z0-9.-]+)/ ) {

  # PG quoted
  $address =~ s/'/''/g;  

  # SQL main request
  my $sql_ = qq{select * from (select m.created, m.int_id, m.str from message m where m.str like '%$address%' union all \ 
                select l.created, l.int_id, l.str from log l where l.address='$address') a \
                order by int_id COLLATE "C", created};

  my $sth = $dbh->prepare($sql_);
  $sth->execute();

  my $srows = $sth->rows;
  if ($srows == 0) { $nrecords = 'There is not any record by your request'; }
  else {
    $nrecords = '<p>Found ' . $srows . ' ';
    $nrecords .= $srows == 1 ?  'record.' : 'records.';
    if ($srows > $limit) {
      $nrecords .= ' <b>Only first ' . $limit . ' records are showed.</b>'  
    }
    $nrecords .= '</p>';
  }

  my $rcounter = 0;
  while (my $row = $sth->fetchrow_hashref) {
    $rcounter++;
    if ($rcounter > $limit) { last; }
    my $str = htmlEncode($row->{str});
    $tbl_ .= qq{<tr><td style="text-align:right;">$rcounter</td><td style="width:10%;padding: 0 10px;cursor:pointer;white-space: nowrap;" title="$row->{int_id}">$row->{created}</td><td style="white-space:nowrap;">$str</td></tr>
};
  }
}
elsif ($address) {
  $nrecords = '<p><b>Incorrect address format</b></p>';
}

if ($tbl_) {
  $tbl =~ s/\[TABLE_ROWS\]/$tbl_/;
}
else {
  $tbl = '';
}

$dbh->disconnect();

# HTML output
print "Content-type: text/html\n\n";

# Templating
open( TEMPLATE, "index.tmpl" ) || die "Cannot read index.tmpl: $!\n";
while (<TEMPLATE>) {
    s/\[ADDRESS\]/$address/;
    s/\[NRECORDS\]/$nrecords/;
    s/\[TBL\]/$tbl/;
    
    print $_;
}
close TEMPLATE;

sub htmlEncode {
    my $text = $_[0];
    return undef unless defined($text);
    $text =~ s/\&/&amp;/g;
    $text =~ s/\"/&quot;/g;
    $text =~ s/\'/&#39;/g;
    $text =~ s/\</&lt;/g;
    $text =~ s/\>/&gt;/g;
    return $text || '';
}

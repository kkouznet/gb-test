#!/usr/bin/perl -T

use strict;
use warnings;

use 5.9.5;
use DBI;
use Time::Piece;

# DB Settings
my $db         = 'testdb';
my $host       = 'localhost';
my $port       = 5432;
my $dbusername = 'testuser';
my $dbpassword = 'testsecret';
my $filelog    = 'out';

# Reassigning date and time format here
my $timestamp_format = qq(%Y-%m-%d %H:%M:%S);

# Result stats counters
my $ltotal;
my $lprocessed;
my $lfailed;

# Logs
my $lfailedLog = 'failed.log';

# Log message addons
my %aoMessages = (
    '1' => 'Unable to parse          ',
    '2' => 'Missed INT ID            ',
    '3' => 'Problem with SQL Insert  ',
    '4' => 'Unable to extract Int ID ',
    '5' => 'Unable to extract address',
);

# DB
my $dbstr = "dbi:Pg:dbname=$db;host=$host;port=$port";
my $dbh = DBI->connect( $dbstr, $dbusername, $dbpassword );

if ( !$dbh ) { die "Could not connect to database: " . DBI->errstr; }

# Processing log file
open my $fh, '<', $filelog or die "Could not open $filelog: $!";
while ( my $line = <$fh> ) {
    $ltotal++;

    if ( $line =~ /^([\d\-\.]+)\s+([\d\-\:]+)\s+(([\w\-]+)\s+(.*))$/ ) {
        my $str      = $3;
        my $int_id   = $4;
        my $datetime = $1 . ' ' . $2;
        my $other    = $5;
        my $tp       = Time::Piece->strptime( $datetime, $timestamp_format );
        my $ttime    = $tp->datetime;

        # PG quoted
        $str =~ s/'/''/g;
        $int_id =~ s/'/''/g;

        # Test int_id for correct format
        unless ( $int_id =~ /^\w{6}-\w{6}-\w{2}/ ) {
            $lfailed++;
            dlog( $line, 2, $ltotal );
            next;
        }

        # Detect incoming and other log
        if ( $other =~ /^\<\=/ ) {

            # Process incomming message for message table
            if ( $other =~ /^\<\=\s+.*\s+id\=(.*)\s*/ ) {

                # Extract ID
                my $id = $1;

                my $sth = $dbh->prepare(
"INSERT INTO message (created, id, int_id, str) VALUES (?, ?, ?, ?)"
                );
                my $res = $sth->execute( $ttime, $id, $int_id, $str );
                if ($res) {
                    $lprocessed++;
                }
                else {
                    $lfailed++;
                    dlog( $line, 3, $ltotal );
                }
            }
            else {

                # Bad record for incomming message. Skip it
                $lfailed++;
                dlog( $line, 4, $ltotal );
                next;
            }
        }
        else {

            # Process other message for log table
            if ( $other =~ /([a-z0-9]([a-z0-9.]+[a-z0-9])?\@[a-z0-9.-]+)/ ) {
                my $address = $1;

                if ($address) {
                    my $sth = $dbh->prepare(
"INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)"
                    );
                    my $res = $sth->execute( $ttime, $int_id, $str, $address );
                    if ($res) {
                        $lprocessed++;
                    }
                    else {
                        $lfailed++;
                        dlog( $line, 3, $ltotal );
                    }
                }
                else {

                    # Bad record for other message. Skip it
                    $lfailed++;
                    dlog( $line, 5, $ltotal );
                    next;
                }
            }
            else {
                # Bad record -unabele find address. Skip it
                $lfailed++;
                dlog( $line, 5, $ltotal );
                next;
            }
        }
    }
    else{
          $lfailed++;
          dlog( $line, 1, $ltotal );
    }
}

print "Total records in log file: $ltotal\n";
print "Processed records in log file: $lprocessed\n";
print "Failed records in log file: $lfailed\n";

$dbh->disconnect();

# Output to processing log file
sub dlog {
    my ( $str, $messType, $logLine ) = @_;
    chomp $str;

    open DLOG, ">>$lfailedLog";
    print DLOG "$aoMessages{$messType} ($logLine):\t$str\n";
    close DLOG;
}

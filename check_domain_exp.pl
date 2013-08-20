#!/usr/bin/perl
#
# check_domain_exp v1.0 plugin for nagios
#
# checks domain exiration date from WHOIS databese
#
# Copyright Notice: GPL
#
# History:
# v1.0 Maxim Odinintsev
#
#
use Net::Domain::ExpireDate;
use Data::Dumper;
use Time::Piece;
use Time::Seconds;
use Getopt::Std;

use strict;
use lib '/usr/lib64/nagios/plugins';
use utils qw(%ERRORS);

my $PROGNAME = "check_domain_exp.pl";
my $PROGVERSION = '1.0';

### Opts ###
my %opts =(
      d => '',   ### ip name servera, kotoriy proveryaem
      c => 14,
      w => 21,
      D => 0
);

getopts('d:c:w:D',\%opts);
my $domain = lc($opts{'d'});
my $warn = $opts{'w'};
my $crit = $opts{'c'};
my $DEBUG = $opts{'D'};


### Startup errors ###
# domain not set
usage() unless $domain;

# domain syntax incorrect
if ($domain !~ /^[a-z|\-|\d]+\..{2,4}(\..{2})?$/) {
        print "Domain syntax error, must be: domain.tld\n";
        exit($ERRORS{'CRITICAL'});
}

# other opts not digits
if ($warn !~ /\d+/) {
        print "Warning must be a integer value\n";
        usage();
} elsif ($crit !~ /\d+/ ) {
        print "Critical must be a integer value\n";
        usage();
}

# Warning must be more then critial
if ($warn <= $crit) {
        print "Warning must be more then critial\n";
        usage();
}

######################
$Net::Domain::ExpireDate::USE_REGISTRAR_SERVERS = 0;
# 0 - make queries to registry server
# 1 - make queries to registrar server
# 2 - make queries to registrar server and in case of fault make query to registry server
#


### Local VARs ###
my $loc_date = localtime;

my $res;
my $exp_date;
my $days;

######################

error() unless($exp_date = expire_date( $domain ));

$res = $exp_date - $loc_date;
$days = int($res->days);

if ($days > $warn) {
        print "OK: domain $domain expired in $days day(s) - Exp. date: ".$exp_date->ymd."\n";
        exit($ERRORS{'OK'});
} elsif ($days > $crit) {
        print "WARNING: domain $domain expired in $days day(s) - Exp. date: ".$exp_date->ymd."\n";
        exit($ERRORS{'WARNING'});
} elsif ($days <= $crit) {
        print "CRITICAL: domain $domain expired in $days day(s) - Exp. date: ".$exp_date->ymd."\n";
        exit($ERRORS{'CRITICAL'});
} elsif ($days < 0) {
        $days = ($days * (-1));
        print "FATAL: domain $domain expired $days days ago\n";
        exit($ERRORS{'CRITICAL'});
} else {
        print "UNKNOWN: unhandled error for domain $domain\n";
        exit($ERRORS{'UNKNOWN'});
}

print int($res->days);
sub usage() {
        print "check_domain_exp <-d domain name> [-w days] [-c days] [-D]\n";
        exit($ERRORS{'CRITICAL'});
}

sub error() {
        print "CRITICAL: Domain not registerd or can't get any parseble info\n";
        if ($DEBUG > 0) {print $Net::Domain::ExpireDate::errmsg};
        exit ($ERRORS{'CRITICAL'});
}

exit($ERRORS{'OK'});

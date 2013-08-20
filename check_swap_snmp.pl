#!/usr/bin/perl -w

use Getopt::Std;
use SNMP::Simple;
use Data::Dumper;

$ENV{MIBS} = 'ALL';

### NAGIOS
use lib '/usr/lib64/nagios/plugins';
use utils qw(%ERRORS);
###
#
# -------------------------------------------------------
sub error_crit($) {
   print 'ERROR ' . $_[0] . "\n";
   exit($ERRORS{'CRITICAL'});
}
sub error_unk($) {
   print 'UNKNOWN ' . $_[0] . "\n";
   exit($ERRORS{'UNKNOWN'});
}

###
my %opts =(
             i => '',           ### server ip
             g => 'percent',    ### get percent or capacity of SWAP
             c => 'public',     ### set SNMP community
             t => 6000000,      ### timeout
             C => 0,            ### Critic SWAP usage (in Mb)
             w => 0,            ### Warning SWAP usage (in Mb)
        );

getopts('i:g:c:t:C:w:',\%opts);
$get_by = $opts{'g'};
$ip = $opts{'i'};
$timeout = $opts{'t'};
$community = $opts{'c'};

### SNMP objects
my $swapFreeOID = '.1.3.6.1.4.1.2021.4.4.0';
my $swapTotalOID = '.1.3.6.1.4.1.2021.4.3.0';

### Default Threshhold values
$crit_precents = 50;   ### default 50%
$crit_space = 2048;    ### default 2048 (or 2Gb)
$warn_precents = 35;   ### default 35%
$warn_space = 1024 ;   ### default 1024 (or 1Gb);

if ($get_by eq 'percent') {
  if (($opts{'C'} == 0) and ($opts{'w'} == 0)) {
     $crit = $crit_precents;
     $warn = $warn_precents;
  } else {
     $crit = $opts{'C'};
     $warn = $opts{'w'};
  }
} elsif (($get_by eq 'capacity') and ($opts{'C'} > 0) and ($opts{'w'} > 0)) {
  if (($opts{'C'} == 0) and ($opts{'w'} == 0)) {
     $crit = $crit_space;
     $warn = $warn_space;
  } else {
     $crit = $opts{'C'};
     $warn = $opts{'w'};
  }
}

### Set default message
$message = 'OK';

### Usage
if (!$ip) {
   print "Usage: -i server_ip [-c snmp_community] [-g percent|capacity|both] [-t timeout] [-C critical capacity Mb] [-w warn capacity Mb]\n\n";
   exit($ERRORS{'CRITICAL'});
}

### Create SNMP object
$snmp = SNMP::Simple->new(DestHost => $ip, Community => $community, Version => 1, Timeout => $timeout, UseEnums => 0);

### Get total SWAP Allocation
eval {
        $result = $snmp->get($swapTotalOID);
};
# detect timeout error
error_unk('SNMP session timeout!') if (!defined($result) and $@ =~ /Timeout/i);
#
# Detect zero swap
error_unk('SNMP problem or SWAP is disabled - total swap is zero. Is swap enabled on this host?') if (0 == $result);
my $swapTotal = $result;
#convert to Mb
$swapTotal = $swapTotal/1024;

### Get free SWAP Allocation
eval {
        $result = $snmp->get($swapFreeOID);
};

# detect timeout error
error_unk('SNMP session timeout!') if (!defined($result) and $@ =~ /Timeout/i);
#
my $swapFree = $result;
$swapFree = $swapFree/1024;

my $realPercent = sprintf("%.2f", (($swapTotal - $swapFree) / $swapTotal) * 100);
my $swapUsage = $swapTotal-$swapFree;
my $status_str = sprintf("Free => %.2f Mb, Total => %.2f Mb", $swapFree, $swapTotal);
my $perfdata = "Swap usage = $realPercent%";

if ($get_by eq 'percent') {
   if (($crit >= 100) or ($warn >= 100) or ($warn > $crit)) {
     error_unk('Illegal threshhold values');
   }
   if ($realPercent >= $crit) {
        $message = 'CRITICAL';
   } elsif (($realPercent >= $warn) and ($message ne 'CRITICAL')) {
        $message = 'WARNING';
   }
} elsif ($get_by eq 'capacity') { # if check free space value
   if (($crit >= $swapTotal) or ($warn >= $swapTotal) or ($warn > $crit)) {
     error_unk('Illegal threshhold values');
   }
   if ($swapUsage >= $crit) {
      $message = 'CRITICAL';
   } elsif (($swapUsage >= $warn) and ($message ne 'CRITICAL')) {
      $message = 'WARNING';
   }
}


print "$message SWAP. $status_str. ";
print $perfdata."\n";
exit($ERRORS{$message});

1;

#! /usr/bin/perl -w
###################################################################
# Oreon is developped with GPL Licence 2.0 
#
# GPL License: http://www.gnu.org/licenses/gpl.txt
#
# Developped by : Julien Mathis - Romain Le Merlus 
#                 Christophe Coraboeuf
#
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#    For information : contact@merethis.com
####################################################################
#
# Script init
#

use strict;
use Net::SNMP qw(:snmp);
use FindBin;
use lib "$FindBin::Bin";
use lib "@NAGIOS_PLUGINS@";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
if (eval "require oreon" ) {
    use oreon qw(get_parameters);
    use vars qw($VERSION %oreon);
    %oreon=get_parameters();
} else {
	print "Unable to load oreon perl module\n";
    exit $ERRORS{'UNKNOWN'};
}
use vars qw($PROGNAME);
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_v $opt_C $opt_H $opt_c $opt_w $opt_D $snmp $opt_k $opt_u $opt_p @critical @warning);

# Plugin var init

my($return_code);

$PROGNAME = "check_graph_load_average";
sub print_help ();
sub print_usage ();

Getopt::Long::Configure('bundling');
GetOptions
    ("h"   => \$opt_h, "help"         => \$opt_h,
     "u=s"   => \$opt_u, "username=s"     => \$opt_u,
     "p=s"   => \$opt_p, "password=s"     => \$opt_p,
     "k=s"   => \$opt_k, "key=s"          => \$opt_k,
     "V"   => \$opt_V, "version"      => \$opt_V,
     "v=s" => \$opt_v, "snmp=s"       => \$opt_v,
     "C=s" => \$opt_C, "community=s"  => \$opt_C,
     "w=s" => \$opt_w, "warning=s"  => \$opt_w,
     "c=s" => \$opt_c, "critical=s"  => \$opt_c,
     "H=s" => \$opt_H, "hostname=s"   => \$opt_H);

if ($opt_V) {
    print_revision($PROGNAME,'$Revision: 1.2 $');
    exit $ERRORS{'OK'};
}

if ($opt_h) {
    print_help();
    exit $ERRORS{'OK'};
}

if (!$opt_H) {
print_usage();
exit $ERRORS{'OK'};
}

my $snmp = "1";
if ($opt_v && $opt_v =~ /^[0-9]$/) {
$snmp = $opt_v;
}

@critical = ('2', '4', '6');
if ($opt_c && $opt_c =~ /^([0-9]+),([0-9]+),([0-9]+)$/) {
@critical = ($1,$2,$3);
}else {
print "Specify three critical treshold separated with a coma\n";
exit $ERRORS{'OK'};
}

@warning = ('1', '3', '5');
if ($opt_w && $opt_w =~ /^([0-9]+),([0-9]+),([0-9]+)$/) {
@warning = ($1,$2,$3);
}else {
print "Specify three warning treshold separated with a coma\n";
exit $ERRORS{'OK'};
}

for (my $i = 0; $i < scalar(@warning); $i++) {
if ($warning[$i] >= $critical[$i]) {
print "Critical tresholds must be superior to warning tresholds.\n";
exit $ERRORS{'OK'};
}
}

if ($snmp eq "3") {
if (!$opt_u) {
print "Option -u (--username) is required for snmpV3\n";
exit $ERRORS{'OK'};
}
if (!$opt_p && !$opt_k) {
print "Option -k (--key) or -p (--password) is required for snmpV3\n";
exit $ERRORS{'OK'};
}elsif ($opt_p && $opt_k) {
print "Only option -k (--key) or -p (--password) is needed for snmpV3\n";
exit $ERRORS{'OK'};
}
}

if (!$opt_C) {
$opt_C = "public";
}

my $name = $0;
$name =~ s/\.pl.*//g;

# Plugin snmp requests

my $OID_CPULOAD_1 =$oreon{UNIX}{CPU_LOAD_1M};
my $OID_CPULOAD_5 =$oreon{UNIX}{CPU_LOAD_5M};
my $OID_CPULOAD_15 =$oreon{UNIX}{CPU_LOAD_15M};

my ($session, $error);
if ($snmp eq "1" || $snmp eq "2") {
($session, $error) = Net::SNMP->session(-hostname => $opt_H, -community => $opt_C, -version => $snmp);
if (!defined($session)) {
    print("UNKNOWN: SNMP Session : $error\n");
    exit $ERRORS{'UNKNOWN'};
}
}elsif ($opt_k) {
    ($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authkey => $opt_k);
if (!defined($session)) {
    print("UNKNOWN: SNMP Session : $error\n");
    exit $ERRORS{'UNKNOWN'};
}
}elsif ($opt_p) {
    ($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp,  -username => $opt_u, -authpassword => $opt_p);
if (!defined($session)) {
    print("UNKNOWN: SNMP Session : $error\n");
    exit $ERRORS{'UNKNOWN'};
}
}

my $result = $session->get_request(
                                -varbindlist => [$OID_CPULOAD_1, $OID_CPULOAD_5, $OID_CPULOAD_15 ]
                                   );
if (!defined($result)) {
    printf("UNKNOWN: %s.\n", $session->error);
    $session->close;
    exit $ERRORS{'UNKNOWN'};
}

my $un =  $result->{$OID_CPULOAD_1};
my $cinq  =  $result->{$OID_CPULOAD_5};
my $quinze  =  $result->{$OID_CPULOAD_15};

# Plugin return code
my $status = "OK";
if ($warning[0] <= $un || $warning[1] <= $cinq || $warning[2] <= $quinze) {
    $status = "WARNING";
}
if ($critical[0] <= $un || $critical[1] <= $cinq || $critical[2] <= $quinze) {
    $status = "CRITICAL";
}

print "load average: ".$un.", ".$cinq.", ".$quinze.".|load1=".$un."%;;;0;100 load5=".$cinq."%;;;0;100 load15=".$quinze."%;;;0;100\n";
exit $ERRORS{$status};

sub print_usage () {
    print "\nUsage:\n";
    print "$PROGNAME\n";
    print "   -H (--hostname)   Hostname to query - (required)\n";
    print "   -C (--community)  SNMP read community (defaults to public,\n";
    print "   -C (--community)  SNMP read community (defaults to public,\n";
    print "   -c (--critical)   Three critical tresholds (defaults : 2,4,6)\n";
    print "   -w (--warning)   Three warning tresholds (defaults : 1,3,5)\n";
    print "   -v (--snmp_version)  1 for SNMP v1 (default)\n";
    print "                        2 for SNMP v2c\n";
    print "   -V (--version)    Plugin version\n";
    print "   -h (--help)       usage help\n";
}

sub print_help () {
    print "######################################################\n";
    print "#      Copyright (c) 2004-2007 Oreon-project         #\n";
	print "#      Bugs to http://www.oreon-project.org/         #\n";
	print "######################################################\n";
    print_usage();
    print "\n";
}

#!/usr/bin/env perl
# EPN, Tue Mar  1 15:40:13 2016
# 
# An example script that demonstrates some of the capabilities of the 
# epn-options.pm perl module. Someone interested in learning how to use
# epn-options.pm or how it works can run this script and look at it's
# source code and comments.
#
# This script prints out numbers from 1 to <n>, where <n> is the single 
# command line argument.
# 
use strict;
use warnings;
use Getopt::Long;

require "epn-options.pm";

#########################################################
# Command line and option processing using epn-options.pm
#
# opt_HH: 2D hash:
#         1D key: option name (e.g. "-h")
#         2D key: string denoting type of information 
#                 (one of "type", "default", "group", "requires", "incompatible", "preamble", "help")
#         value:  string explaining 2D key:
#                 "type":          "boolean", "string", "int" or "real"
#                 "default":       default value for option
#                 "group":         integer denoting group number this option belongs to
#                 "requires":      string of 0 or more other options this option requires to work, each separated by a ','
#                 "incompatiable": string of 0 or more other options this option is incompatible with, each separated by a ','
#                 "preamble":      string describing option for preamble section (beginning of output from script)
#                 "help":          string describing option for help section (printed if -h used)
#                 "setby":         '1' if option set by user, else 'undef'
#                 "value":         value for option, can be undef if default is undef
#
# opt_order_A: array of options in the order they should be processed
# 
# opt_group_desc_H: key: group number (integer), value: description of group for help output
my %opt_HH = ();      
my @opt_order_A = (); 
my %opt_group_desc_H = ();

# Add all options to %opt_HH and @opt_order_A.
# This section needs to be kept in sync (manually) with the &GetOptions call below
$opt_group_desc_H{"1"} = "basic options";
#     option            type       default               group   requires incompat   preamble-output   help-output    
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,     undef,            "display this help",                  \%opt_HH, \@opt_order_A);
opt_Add("-r",           "boolean", 0,                        1,    undef, undef,     "reverse order",  "print numbers in reverse order",     \%opt_HH, \@opt_order_A);
opt_Add("-1",           "boolean", 0,                        1,    undef, undef,     "single line",    "print all numbers on a single line", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "options affecting difference (step size) between successive numbers (only 1 allowed)";
#     option            type       default               group   requires incompat                        preamble-output                                       help-output                      
opt_Add("--step",       "integer", 1,                        2,    undef,"--realstep,--mult,--realmult",  "integer step size between numbers",                  "set integer step size between numbers to <n>",                     \%opt_HH, \@opt_order_A);
opt_Add("--realstep",   "real",    undef,                    2,    undef,"--step,--mult,--realmult",      "step size between numbers",                          "set (real value) step size between numbers to <x>",                \%opt_HH, \@opt_order_A);
opt_Add("--mult",       "integer", undef,                    2,    undef,"--step,--realstep,--realmult",  "multiplicative step size between numbers (integer)", "set multiplicative step size between numbers to <n>",              \%opt_HH, \@opt_order_A);
opt_Add("--realmult",   "real",    undef,                    2,    undef,"--step,--realstep,--mult",      "integer step size between numbers (real)",           "set multiplicative (real value) step size between numbers to <x>", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"3"} = "options affecting where output goes";
#     option            type       default               group   requires incompat   preamble-output           help-output    
opt_Add("--outfile",    "string",  undef,                    3,    undef, undef,     "saving output to file",  "saving output to file <s>", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $usage    = "example.pl: print numbers up until a maximum ceiling\n\n";
   $usage   .= "Usage: example.pl [-options] <ceiling: no numbers above this value will be printed>\n";
   $usage   .= "\nFor example:\nperl example.pl 10\n";

my $options_okay = 
    &GetOptions('h'            => \$GetOptions_H{"-h"}, 
# basic options
                'r'            => \$GetOptions_H{"-r"},
                '1'            => \$GetOptions_H{"-1"},
# options affecting difference between successive numbers
                'step=s'       => \$GetOptions_H{"--step"},
                'realstep=s'   => \$GetOptions_H{"--realstep"},
                'mult=s'       => \$GetOptions_H{"--mult"},
                'realmult=s'   => \$GetOptions_H{"--realmult"},
# options affecting output
                'outfile=s'    => \$GetOptions_H{"--outfile"});

# print help and exit if necessary
if((! $options_okay) || ($GetOptions_H{"-h"})) { 
  opt_OutputHelp(*STDOUT, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if(! $options_okay) { die "ERROR, unrecognized option;"; }
  else                { exit 0; } # -h, exit with 0 status
}

# check that number of command line args is correct
if(scalar(@ARGV) != 1) {   
  print "Incorrect number of command line arguments.\n";
  print $usage;
  print "\nTo see more help on available options, do example.pl -h\n\n";
  exit(1);
}
my ($max) = (@ARGV);

# verify we actually have a number
if(! verify_real($max)) { 
  die "ERROR, the ceiling value (the one command line argument) must be a positive real number, got $max";
}
# verify $max is positive
if($max =~ m/^\-/) { 
  die "ERROR, the ceiling value (the one command line argument) must be a positive real number, got $max";
}

# set options in opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# set up output
my $FH = undef;
if(opt_IsUsed("--outfile", \%opt_HH)) { 
  my $outfile = opt_Get("--outfile", \%opt_HH);
  open($FH, ">", $outfile) || die "ERROR unable to open $outfile for writing";
}
else { 
  $FH = *STDOUT;
}

# determine step size and type (default (additive) or multiplicative)
my $step = 1; # default value
my $do_mult = 0; # set to '1' if --mult or --realmult used on command line
# opt_ValidateSet has already enforced that at most one of --step, --realstep, --mult, and --realstep
# was set on the cmdline, by using the 'incompatible' column in the opt_Add() calls above.
if(opt_IsUsed("--step", \%opt_HH)) { 
  $step = opt_Get("--step", \%opt_HH);
}
elsif(opt_IsUsed("--realstep", \%opt_HH)) { 
  $step = opt_Get("--realstep", \%opt_HH);
}
elsif(opt_IsUsed("--mult", \%opt_HH)) { 
  $step = opt_Get("--mult", \%opt_HH);
  $do_mult = 1;
}
elsif(opt_IsUsed("--realmult", \%opt_HH)) { 
  $step = opt_Get("--realmult", \%opt_HH);
  $do_mult = 1;
}

# are we going in reverse order?
my $do_rev = opt_Get("-r", \%opt_HH);

# set first value;
my $cur = ($do_rev) ? $max : 0;

my $keep_going = 1; # set to '0' when we should stop in loop below
while($keep_going) { 
  print $FH $cur;

  # determine next value for $cur
  if($do_rev) { 
    if($do_mult) { $cur /= $step; }
    else         { $cur -= $step; }
    if($cur < 0) { $keep_going = 0; }
  }
  else { # $do_rev is false
    if($do_mult)    { $cur *= $step; }
    else            { $cur += $step; }
    if($cur > $max) { $keep_going = 0; }
  }

  if(opt_Get("-1", \%opt_HH)) { 
    printf $FH ("%s", ($keep_going) ? " " : "\n"); 
  }
  else { 
    print $FH "\n";
  }
} # end of 'while($keep_going)'


if(opt_IsUsed("--outfile", \%opt_HH)) { 
  close $FH;
  printf("Output saved to %s.\n", opt_IsUsed("--outfile", \%opt_HH));
}

exit 0;



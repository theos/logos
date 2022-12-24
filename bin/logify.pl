#!/usr/bin/env perl
# logify.pl
############
# Converts an Objective-C header file (or anything containing an @interface and method definitions)
# into a Logos input file which causes all function calls to be logged.
#
# Accepts input on stdin or via filename specified on the commandline.
#
# Lines are only processed if we're in an @interface, so you can run this on a file containing
# an @implementation, as well.
############
use strict;

use FindBin;
use Getopt::Long;
use lib "$FindBin::RealBin/lib";

use Logos::Method;
use Logos::Util;
$Logos::Util::errorhandler = sub {
	die "$ARGV:$.: error: missing closing parenthesis$/"
};

my $script = $FindBin::Script;
my $usage = <<"EOF";
Usage: $script [options] filename ...
Options:
  [-e|--exclude]	Comma-separated list of methods to exclude
	 -e "launchedTaskWithLaunchPath:arguments:,arguments" (for example)
  [-f|--filter]		Comma-separated list of methods to exclude
	 -f "launchedTaskWithLaunchPath:arguments:,arguments" (for example)
  [-h|--help]		Display this page
EOF

die "Usage: $script <filename>\nRun $script --help for more details\n" if (@ARGV == 0 && -t STDIN);

my ($opt_exclude, $opt_filter, $opt_help);
GetOptions(
	"exclude|e=s" 	=> \$opt_exclude,
	"filter|f=s" 	=> \$opt_filter,
	"help|h"	=> \$opt_help,
);
if ($opt_help) {
	print $usage;
	exit 0;
}

die "Error: --filter and --exclude are mutually exclusive\nRun $script --help for more details\n" if (defined $opt_exclude && defined $opt_filter);

my $interface = 0;
while (my $line = <>) {
	if ($line =~ m/^[+-]\s*\((.*?)\).*?(?=;)/ && $interface == 1) {
		# regular methods
		print logLineForDeclaration($&);
	} elsif ($line =~ m/^\s*\@property\s*\((.*?)\)\s*(.*?)\b([\$a-zA-Z_][\$_a-zA-Z0-9]*)(?=;)/ && $interface == 1) {
		# properties (setter/getter)
		my @attributes = smartSplit(qr/\s*,\s*/, $1);
		my $propertyName = $3;
		my $type = $2;
		my $readonly = scalar(grep(/readonly/, @attributes));
		my %methods = ("setter" => "set".ucfirst($propertyName).":", "getter" => $propertyName);
		foreach my $attribute (@attributes) {
			next if ($attribute !~ /=/);
			my @x = smartSplit(qr/\s*=\s*/, $attribute);
			$methods{$x[0]} = $x[1];
		}
		if ($readonly == 0) {
			print logLineForDeclaration("- (void)".$methods{"setter"}."($type)$propertyName");
		}
		print logLineForDeclaration("- ($type)".$methods{"getter"});
	} elsif ($line =~ m/^\@interface\s+(.*?)\s*[:(]/ && $interface == 0) {
		# start (%Hook)
		print "%hook $1\n";
		$interface = 1;
	} elsif ($line =~ m/^\@end/ && $interface == 1) {
		# end (%end)
		print "%end\n";
		$interface = 0;
	}
}

sub logLineForDeclaration {
	my $declaration = shift;
	$declaration =~ m/^[+-]\s*\((.*?)\).*?/;

	# if user only wants specific methods logified,
	# either find those or exclude ones specified
	if (defined $opt_exclude || defined $opt_filter) {
		# remove anything within parenthesis (inclusive)
		(my $str = $declaration) =~ s/\([^()]*\)//g;
		# remove method type from start of method
		$str =~ s/[^[:alnum:]:\s]//g;

		my $opt;
		if (defined $opt_exclude){
			$opt = $opt_exclude;
		} else {
			$opt = $opt_filter;
		}

		my @filters = ($opt);

		# multiple methods passed
		if ($opt =~ /,/) {
			# remove filter str
			pop(@filters);

			# reassign as individual filters
			@filters = split(',', $opt);
		}

		# if the desired method(s) and current method have params
		if (grep(/:/, @filters) && $str =~ /:/) {
			# append space after colons
			$str =~ s/:/: /g;

			# split array at space
			my @arr = split(' ', $str);
			# remove elements w/o a colon
			@arr = grep(/:/, @arr);
			# make string from remaining bits
			$str = join('', @arr);
		}

		# strip any remaining whitespace
		# (kept it around earlier for the split)
		$str =~ s/\s//g;

		block: {
			foreach my $filter (@filters) {
				# check to see if we've got it
				if (defined $opt_exclude && $filter eq $str) {
					return "";
				}
				elsif ($filter eq $str) {
					last block;
				}
			}
			if(defined $opt_filter){
				# nope
				return "";
			}
		}
	}

	my $rtype = $1;
	my $innards = "%log; ";
	if ($rtype ne "void") {
		if ($rtype eq "instancetype") {
			$rtype = "id";
		}
		$innards .= "$rtype r = %orig; ";
		$innards .= "NSLog(@\" = ".Logos::Method::formatCharForArgType($rtype)."\", ".Logos::Method::printArgForArgType($rtype, "r")."); " if defined Logos::Method::printArgForArgType($rtype, "r");
		$innards .= "return r; ";
	} else {
		$innards .= "%orig; ";
	}

	return "$declaration { $innards}\n";
}

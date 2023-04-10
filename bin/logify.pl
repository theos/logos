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
  [-i|--include]	Comma-separated list of methods to include
	 -i "launchedTaskWithLaunchPath:arguments:,arguments" (for example)
  [-e|--exclude]	Comma-separated list of methods to exclude
	 -e "launchedTaskWithLaunchPath:arguments:,arguments" (for example)
  [-h|--help]		Display this page
EOF

die "Usage: $script <filename>\nRun $script --help for more details\n" if (@ARGV == 0 && -t STDIN);

my ($opt_include, $opt_exclude, $opt_help);
GetOptions(
	"include|i=s" 	=> \$opt_include,
	"exclude|e=s" 	=> \$opt_exclude,
	"help|h"	=> \$opt_help,
);
if ($opt_help) {
	print $usage;
	exit 0;
}

die "Error: --include and --exclude are mutually exclusive\nRun $script --help for more details\n" if (defined $opt_include && defined $opt_exclude);

my $interface = 0;
my @loggedMethods;
while (my $line = <>) {
	if ($line =~ m/^[+-]\s*\((.*?)\).*?(?=;)/ && $interface == 1) {
		# regular methods
		print logLineForDeclaration($&) if (!isLogged($&));
	} elsif ($line =~ m/^\s*\@property\s*\((.*?)\)\s*(.*?)\b([\$a-zA-Z_][\$_a-zA-Z0-9]*)(?=;)/ && $interface == 1) {
		# properties (setter/getter)
		my @attributes = smartSplit(qr/\s*,\s*/, $1);
		my $propertyName = $3;
		(my $type = $2) =~ s/\s+$//;
		my $readonly = scalar(grep(/readonly/, @attributes));
		my %methods = ("setter" => "set".ucfirst($propertyName).":", "getter" => $propertyName);
		foreach my $attribute (@attributes) {
			next if ($attribute !~ /=/);
			my @x = smartSplit(qr/\s*=\s*/, $attribute);
			$methods{$x[0]} = $x[1];
		}
		if ($readonly == 0) {
			my $setter = "- (void)".$methods{"setter"}."($type)$propertyName";
			print logLineForDeclaration($setter) if (!isLogged($setter));
		}
		my $getter = "- ($type)".$methods{"getter"};
		print logLineForDeclaration($getter) if (!isLogged($getter));
	} elsif ($line =~ m/^\@interface\s+(.*?)\s*[:(]/ && $interface == 0) {
		print "%hook $1\n";
		$interface = 1;
	} elsif ($line =~ m/^\@end/ && $interface == 1) {
		print "%end\n";
		$interface = 0;
	}
}

sub isLogged {
	(my $str = shift) =~ s/\s//g;
	if (!@loggedMethods || !grep($str eq $_, @loggedMethods)) {
		push(@loggedMethods, $str);
		return;
	} else {
		return 1;
	}
}

sub logLineForDeclaration {
	my $declaration = shift;
	$declaration =~ m/^[+-]\s*\((.*?)\).*?/;

	if ((defined $opt_include || defined $opt_exclude) && !shouldLogDeclaration($declaration)) {
		# line != $opt_include || line == $opt_exclude
		return "";
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

sub shouldLogDeclaration {
	# remove anything within parenthesis (inclusive)
	(my $str = shift) =~ s/\([^()]*\)//g;
	# remove instance/class method prefix
	$str =~ s/[^[:alnum:]:\s]//g;

	my $opt = $opt_include;
	$opt = $opt_exclude if (defined $opt_exclude);

	my @filters = ($opt);
	# if multiple methods passed
	@filters = split(',', $opt) if ($opt =~ /,/);

	# if the desired method(s) and current method have params
	if (grep(/:/, @filters) && $str =~ /:/) {
		# append space after colons
		$str =~ s/:/: /g;

		my @arr = split(' ', $str);
		# remove bits w/o a colon
		# (e.g., parameter names)
		@arr = grep(/:/, @arr);
		$str = join('', @arr);
	}

	# strip any remaining whitespace
	# (kept around earlier for the split)
	$str =~ s/\s//g;

	# check to see if we've got a match
	foreach my $filter (@filters) {
		if (defined $opt_exclude && $filter eq $str) {
			# don't logify
			return;
		} elsif ($filter eq $str) {
			# do logify
			return 1;
		}
	}

	# cases when no filter matched
	if (defined $opt_exclude) {
		return 1;
	} else {
		return;
	}
}

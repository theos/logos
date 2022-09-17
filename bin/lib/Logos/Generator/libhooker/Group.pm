package Logos::Generator::libhooker::Group;
use strict;
use parent qw(Logos::Generator::Base::Group);

sub initializers {
	my $self = shift;
	my $group = shift;
	my $return = "{";
	foreach(@{$group->classes}) {
		$return .= Logos::Generator::for($_)->initializers if $_->initRequired;
	}
	my @structs = map { Logos::Generator::for($_)->initializers } @{$group->functions};
	my $functionCount = @{$group->functions};
	$return .= "LHHookFunctions(".join(",", @structs).", ".$functionCount.");";
	$return .= "}";
	return $return;
}

1;

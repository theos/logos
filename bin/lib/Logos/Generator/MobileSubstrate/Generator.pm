package Logos::Generator::MobileSubstrate::Generator;
use strict;
use parent qw(Logos::Generator::Base::Generator);

sub findPreamble {
	my $self = shift;
	my $aref = shift;
	my @matches = grep(/\s*#\s*(import|include)\s*[<"]substrate\.h[">]/, @$aref);
	return $self->SUPER::findPreamble($aref) && @matches > 0;
}

sub preamble {
	my $self = shift;
	my $skipIncludes = shift;
	if ($skipIncludes) {
		return $self->SUPER::preamble();
	} else {
		return join("\n", ($self->SUPER::preamble(), "#include <substrate.h>"));
	}
}

sub staticDeclarations {
	my $self = shift;
	return join("\n", ($self->SUPER::staticDeclarations(),
		"__asm__(\".linker_option \\\"-framework\\\", \\\"CydiaSubstrate\\\"\");",
		"" # extra line break for readability
	));
}

1;

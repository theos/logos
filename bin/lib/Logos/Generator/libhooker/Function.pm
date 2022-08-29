package Logos::Generator::libhooker::Function;
use strict;
use parent qw(Logos::Generator::Base::Function);

sub initializers {
	my $self = shift;
	my $function = shift;

	my $return = "";
	$return .= "{".$self->_initExpression($function);
	$return .= ", (void *)&".$self->newFunctionName($function);
	$return .= ", (void **)&".$self->originalFunctionName($function);
	$return .= "}";

	return $return;
}

1;

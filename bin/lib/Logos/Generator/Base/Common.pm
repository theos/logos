package Logos::Generator::Base::Common;
use strict;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub deleteLine {
	return "";
}

1;

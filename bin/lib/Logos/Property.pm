package Logos::Property;
use strict;

##################### #
# Setters and Getters #
# #####################

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	$self->{CLASS} = undef;
	$self->{GROUP} = undef;
	$self->{NAME} = undef;
	$self->{TYPE} = undef;
	$self->{READONLY} = undef;
	$self->{ASSOCIATIONPOLICY} = undef;
	$self->{GETTER} = undef;
	$self->{SETTER} = undef;
	$self->{RETAIN_F} = undef;
	$self->{COPY_F} = undef;
	$self->{NONATOMIC_F} = undef;
	bless($self, $class);
	return $self;
}

sub class {
	my $self = shift;
	if(@_) { $self->{CLASS} = shift; }
	return $self->{CLASS};
}

sub group {
	my $self = shift;
	if(@_) { $self->{GROUP} = shift; }
	return $self->{GROUP};
}

sub name {
	my $self = shift;
	if(@_) { $self->{NAME} = shift; }
	return $self->{NAME};
}

sub type {
	my $self = shift;
	if(@_) { $self->{TYPE} = shift; }
	return $self->{TYPE};
}

sub readonly {
	my $self = shift;
	if(@_) { $self->{READONLY} = shift; }
	return $self->{READONLY};
}

sub associationPolicy {
	my $self = shift;
	if(@_) { $self->{ASSOCIATIONPOLICY} = shift; }
	return $self->{ASSOCIATIONPOLICY};
}

sub getter {
	my $self = shift;
	if(@_) { $self->{GETTER} = shift; }
	return $self->{GETTER};
}

sub setter {
	my $self = shift;
	if(@_) { $self->{SETTER} = shift; }
	return $self->{SETTER};
}

sub retainFlag {
	my $self = shift;
	if(@_) { $self->{RETAIN_F} = shift; }
	return $self->{RETAIN_F};
}

sub copyFlag {
	my $self = shift;
	if(@_) { $self->{COPY_F} = shift; }
	return $self->{COPY_F};
}

sub nonatomicFlag {
	my $self = shift;
	if(@_) { $self->{NONATOMIC_F} = shift; }
	return $self->{NONATOMIC_F};
}

##### #
# END #
# #####

1;

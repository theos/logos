package Logos::Generator::Base::Class;
use Logos::Generator;
use strict;

sub _initExpression {
	my $self = shift;
	my $class = shift;
	return $class->expression if $class->expression;
	return "objc_getClass(\"".$class->name."\")";
}

sub _metaInitExpression {
	my $self = shift;
	my $class = shift;
	return $class->metaexpression if $class->metaexpression;
	return "object_getClass(".$self->variable($class).")";
}

sub _symbolName {
	my $self = shift;
	my $tag = shift;
	my $class = shift;
	return Logos::sigil($tag, $class->group->name, $class->name);
}

sub variable {
	my $self = shift;
	my $class = shift;
	return $self->_symbolName("class", $class);
}

sub metaVariable {
	my $self = shift;
	my $class = shift;
	return $self->_symbolName("metaclass", $class);
}

sub declarations {
	my $self = shift;
	my $class = shift;
	my $return = "";
	for(@{$class->methods}) {
		$return .= Logos::Generator::for($_)->declarations;
	}
	return $return;
}

sub initializers {
	my $self = shift;
	my $class = shift;
	my $return = "";
	for(@{$class->properties}) {
		$return .= Logos::Generator::for($_)->initializers;
	}
	for(@{$class->methods}) {
		$return .= Logos::Generator::for($_)->initializers;
	}
	return $return;
}

1;

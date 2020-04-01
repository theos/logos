package Logos::StaticClassGroup;
use Logos::Group;
our @ISA = ('Logos::Group');

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = Logos::Group->new();
	$self->name("_staticClass");
	$self->explicit(0);
	$self->{DECLAREDONLYCLASSES} = {};
	$self->{USEDCLASSES} = {};
	$self->{USEDMETACLASSES} = {};
	$self->{UNESCAPEDNAMES} = {};
	bless($self, $class);
	return $self;
}

sub addUsedClass {
	my $self = shift;
	my $class = shift;
	my $unescapedClassName = shift;
	$self->{USEDCLASSES}{$class}++;
	$self->{UNESCAPEDNAMES}{$class} = $unescapedClassName;
}

sub addUsedMetaClass {
	my $self = shift;
	my $class = shift;
	my $unescapedClassName = shift;
	$self->{USEDMETACLASSES}{$class}++;
	$self->{UNESCAPEDNAMES}{$class} = $unescapedClassName;
}

sub addDeclaredOnlyClass {
	my $self = shift;
	my $class = shift;
	$self->{DECLAREDONLYCLASSES}{$class}++;
}

sub declaredOnlyClasses {
	my $self = shift;
	return $self->{DECLAREDONLYCLASSES};
}

sub usedClasses {
	my $self = shift;
	return $self->{USEDCLASSES};
}

sub usedMetaClasses {
	my $self = shift;
	return $self->{USEDMETACLASSES};
}

sub unescapedClassNameForClass {
	my $self = shift;
	my $class = shift;
	return $self->{UNESCAPEDNAMES}{$class}
}

1;

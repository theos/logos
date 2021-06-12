package Logos::Generator::Base::Group;
use strict;

sub declarations {
	my $self = shift;
	my $group = shift;
	my $return = "";
	foreach(@{$group->classes}) {
		$return .= Logos::Generator::for($_)->declarations if $_->initRequired;
	}
	return $return;
}

sub initializers {
	my $self = shift;
	my $group = shift;
	my $return = "{typedef void (*LOGOS_objchookfunc_ptr_t)(Class, SEL, IMP, IMP *);void *LOGOS_TMP_MESSAGE_PTR = dlsym(((void *) 0), \"LBHookMessage\"); LOGOS_objchookfunc_ptr_t LOGOS_HOOK_FUNC = LOGOS_TMP_MESSAGE_PTR != NULL ? (LOGOS_objchookfunc_ptr_t)LOGOS_TMP_MESSAGE_PTR : &MSHookMessageEx;";
	foreach(@{$group->classes}) {
		$return .= Logos::Generator::for($_)->initializers if $_->initRequired;
	}
	foreach(@{$group->functions}) {
		$return .= Logos::Generator::for($_)->initializers;
	}
	$return .= "}";
	return $return;
}

1;

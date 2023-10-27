package Logos::Generator::internal::Generator;
use strict;
use parent qw(Logos::Generator::Base::Generator);

sub findPreamble {
	my $self = shift;
	my $aref = shift;
	my @matches = grep(/\s*#\s*(import|include)\s*[<"]objc\/message\.h[">]/, @$aref);
	return $self->SUPER::findPreamble($aref) && @matches > 0;
}

sub preamble {
	my $self = shift;
	return join("\n", (
		$self->SUPER::preamble(),
		"#include <objc/message.h>"
	));
}

sub staticDeclarations {
	my $self = shift;
	return join("\n", ($self->SUPER::staticDeclarations(),
		"__attribute__((unused)) static void ".Logos::sigil("register_hook")."(Class _class, SEL _cmd, IMP _new, IMP *_old) {",
		"Method meth = class_getInstanceMethod(_class, _cmd);",
		"if (!meth) { return; }",
		"*_old = class_replaceMethod(_class, _cmd, _new, method_getTypeEncoding(meth));",
	"}"));
}

1;

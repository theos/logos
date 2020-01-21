package Logos::Generator::internal::Method;
use strict;
use parent qw(Logos::Generator::Base::Method);

sub _originalMethodPointerDeclaration {
	my $self = shift;
	my $method = shift;
	if(!$method->isNew) {
		my $build = "static ";
		my $classargtype = $self->selfTypeForMethod($method);
		my $name = "(*".$self->originalFunctionName($method).")(".$classargtype.", SEL";
		my $argtypelist = join(", ", @{$method->argtypes});
		$name .= ", ".$argtypelist if $argtypelist;
		$name .= ", ..." if $method->variadic;
		$name .= ")";
		$build .= Logos::Method::declarationForTypeWithName($self->returnTypeForMethod($method), $name);
		$build .= $self->functionAttributesForMethod($method);
		return $build;
	}
	return undef;
}

sub originalCallParams {
	my $self = shift;
	my $method = shift;
	my $customargs = shift;
	return "" if $method->isNew;

	my $build = "(self, _cmd";
	if(defined $customargs && $customargs ne "") {
		$build .= ", ".$customargs;
	} elsif($method->numArgs > 0) {
		$build .= ", ".join(", ",@{$method->argnames});
	}
	$build .= ")";
	return $build;
}

sub definition {
	my $self = shift;
	my $method = shift;
	my $classargtype = $self->selfTypeForMethod($method);
	my $arglist = "";
	map $arglist .= ", ".Logos::Method::declarationForTypeWithName($method->argtypes->[$_], $method->argnames->[$_]), (0..$method->numArgs - 1);
	my $name = $self->newFunctionName($method);
	my $parameters = "(".$classargtype." __unused self, SEL __unused _cmd".$arglist;
	$parameters .= ", ..." if $method->variadic;
	$parameters .= ")";
	my $build = "static ";
	$build .= Logos::Method::declarationForTypeWithName($self->returnTypeForMethod($method), $name.$parameters);
	$build .= $self->functionAttributesForMethod($method);
	return $build;
}

sub originalCall {
	my $self = shift;
	my $method = shift;
	my $customargs = shift;
	my $cgen = Logos::Generator::for($method->class);
	my $classref = ($method->scope eq "+") ? $cgen->superMetaVariable : $cgen->superVariable;
	my $build = "(".$self->originalFunctionName($method)." ? ".$self->originalFunctionName($method)." : (__typeof__(".$self->originalFunctionName($method)."))class_getMethodImplementation(".$classref.", ".$self->selectorRef($method->selector)."))"
	$build .= $self->originalCallParams($method, $customargs);
	return $build;
}

sub _hooker_function {
	return Logos::sigil("register_hook");
}

sub declarations {
	my $self = shift;
	my $method = shift;
	my $build = "";
	my $orig = $self->_originalMethodPointerDeclaration($method);
	$build .= $orig."; " if $orig;
	return $build;
}

sub initializers {
	my $self = shift;
	my $method = shift;
	my $cgen = Logos::Generator::for($method->class);
	my $classvar = ($method->scope eq "+" ? $cgen->metaVariable : $cgen->variable);
	my $r = "{ ";
	if(!$method->isNew) {
		$r .= $self->_hooker_function()."(";
		$r .= $classvar;
		$r .= ", ".$self->selectorRef($method->selector);
		$r .= ", (IMP)&".$self->newFunctionName($method);
		$r .= ", (IMP *)&".$self->originalFunctionName($method);
		$r .= ");";
	} else {
		if(!$method->type) {
			$r .= "char _typeEncoding[1024]; unsigned int i = 0; ";
			for ($method->return, "id", "SEL", @{$method->argtypes}) {
				my $typeEncoding = Logos::Method::typeEncodingForArgType($_);
				if(defined $typeEncoding) {
					my @typeEncodingBits = split(//, $typeEncoding);
					my $i = 0;
					for my $char (@typeEncodingBits) {
						$r .= "_typeEncoding[i".($i > 0 ? " + $i" : "")."] = '$char'; ";
						$i++;
					}
					$r .= "i += ".(scalar @typeEncodingBits)."; ";
				} else {
					$r .= "memcpy(_typeEncoding + i, \@encode($_), strlen(\@encode($_))); i += strlen(\@encode($_)); ";
				}
			}
			$r .= "_typeEncoding[i] = '\\0'; ";
		} else {
			$r .= "const char *_typeEncoding = \"".$method->type."\"; ";
		}
		$r .= "class_addMethod(".$classvar.", ".$self->selectorRef($method->selector).", (IMP)&".$self->newFunctionName($method).", _typeEncoding); ";
	}
	$r .= "}";
	return $r;
}

1;

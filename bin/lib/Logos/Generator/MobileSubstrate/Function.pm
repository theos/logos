package Logos::Generator::MobileSubstrate::Function;
use strict;
use parent qw(Logos::Generator::Base::Function);

sub initializers {
	my $self = shift;
	my $function = shift;

	my $return = "{typedef void (*LOGOS_hookfuncs_ptr_t)(const struct LHFunctionHook *, int);LOGOS_hookfuncs_ptr_t LOGOS_C_HOOK_FUNC = (LOGOS_hookfuncs_ptr_t)dlsym(((void *)0), \"LHHookFunctions\");";
	$return .= "if(LOGOS_C_HOOK_FUNC == NULL) {void * ".$self->variable($function)." = ".$self->_initExpression($function).";";
	$return .= " MSHookFunction((void *)".$self->variable($function);
	$return .= ", (void *)&".$self->newFunctionName($function);
	$return .= ", (void **)&".$self->originalFunctionName($function);
	$return .= ");}else{";
	$return .= "void * ".$self->variable($function)." = ".$self->_initExpression($function).";";
	## TODO: Add the LHFunctionHook struct to an array and then call LHHookFunctions only once
	$return .= "LHFunctionHook hook;hook.function = (void *)".$self->variable($function);
	$return .= ";hook.replacement = (void *)&".$self->newFunctionName($function);
	$return .= ";hook.oldptr = (void **)&".$self->originalFunctionName($function);
	$return .= ";const struct LHFunctionHook *hooks = {&hook};LOGOS_C_HOOK_FUNC(hooks, 1);}}";

	return $return;
}

1;

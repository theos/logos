package Logos::Generator::Base::Property;
use strict;
use Logos::Util;

sub getterName {
	my $self = shift;
	my $property = shift;
	return Logos::sigil("property", $property->group->name, $property->class->name, $property->getter);
}

sub setterName {
	my $self = shift;
	my $property = shift;
	return Logos::sigil("property", $property->group->name, $property->class->name, $property->setter);
}

# addAttribute(attributeList, attributeCount, attributeName, attributeValue)
#
# attributeName is one of the property attribute characters, it will be "stringified" for you
# attribute value must be a variable or something else; it will NOT be "stringified" for you; omit it to use ""
sub addAttribute {
	my $self = shift;
	my $attrList = shift;
	my $counter = shift;
	my $name = shift;
	my $value = shift // '""';
	return " ".$attrList."[$counter++] = (objc_property_attribute_t) { \"$name\", $value };";
}

sub definition {
	my $self = shift;
	my $property = shift;

	my $readonly = $property->readonly;
	my $propertyType = $property->type;
	my $propertyClass = $property->class->name;
	my $propertyGetter = $property->getter;
	my $propertyGetterName = $self->getterName($property);
	my $propertySetter = $property->setter;
	my $propertySetterName = $self->setterName($property);
	my $propertyAssociationPolicy = $property->associationPolicy;
	my $wrapValue = !($propertyAssociationPolicy =~ /RETAIN|COPY/);

	if (!$readonly) {
		# Build getter
		my $getter_func = "__attribute__((used)) "; # If the property is never accessed, clang's optimizer will remove the getter/setter if this attribute isn't specified
		$getter_func .= "static $propertyType $propertyGetterName($propertyClass * __unused self, SEL __unused _cmd) ";
		if($wrapValue) {
			$getter_func .= "{ NSValue * value = objc_getAssociatedObject(self, (void *)$propertyGetterName); $propertyType rawValue; [value getValue:&rawValue]; return rawValue; }";
		} else {
			$getter_func .= "{ return ($propertyType)objc_getAssociatedObject(self, (void *)$propertyGetterName); }";
		}

		# Build setter
		my $setter_func = "__attribute__((used)) "; # If the property is never accessed, clang's optimizer will remove the getter/setter if this attribute isn't specified
		$setter_func .= "static void $propertySetterName($propertyClass * __unused self, SEL __unused _cmd, $propertyType rawValue) ";
		if($wrapValue) {
			$setter_func .= "{ NSValue * value = [NSValue valueWithBytes:&rawValue objCType:\@encode($propertyType)]; objc_setAssociatedObject(self, (void *)$propertyGetterName, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }";
		} else {
			$setter_func .= "{ objc_setAssociatedObject(self, (void *)$propertyGetterName, rawValue, $propertyAssociationPolicy); }";
		}

		return "$getter_func; $setter_func";
	} else {
		# Only add methods if not readonly. Readonly properties do not
		# have a getter synthesized for them since ivars cannot be added.
		# The programmer is expected to implement the getter himself.
		return "";
	}
}

sub initializers {
	my $self = shift;
	my $property = shift;

	my $className = $property->class->name;
	my $logosClassVar = Logos::sigil("class", $property->group->name, $className);
	my $readonly = $property->readonly;
	my $retain = $property->retainFlag;
	my $copy = $property->copyFlag;
	my $nonatomic = $property->nonatomicFlag;
	my $name = $property->name;
	my $propertyType = $property->type;
	my $propertyGetter = $property->getter;
	my $propertyGetterName = $self->getterName($property);
	my $propertySetter = $property->setter;
	my $propertySetterName = $self->setterName($property);

	$propertyType =~ /([^ \*<]+).+/;
	my $propertyClassName = $1;
	
	my $build = "{ objc_property_attribute_t _attributes[16]; unsigned int attrc = 0;";

	# Property attributes
	if ($retain) {
		# Type encoding of objet properties should be `@"ClassName"`
		$build .= $self->addAttribute("_attributes", "attrc", "T", '"@\\"'.$propertyClassName.'\\""');
		$build .= $self->addAttribute("_attributes", "attrc", "&");
	} else {
		# Type encoding of non-object properties should be
		$build .= $self->addAttribute("_attributes", "attrc", "T", "\@encode($propertyType)");
	}
	if ($readonly) {
		$build .= $self->addAttribute("_attributes", "attrc", "R");
	}

	if ($copy) {
		$build .= $self->addAttribute("_attributes", "attrc", "C");
	}
	if ($nonatomic) {
		$build .= $self->addAttribute("_attributes", "attrc", "N");
	}

	# class_addProperty
	$build .= " class_addProperty($logosClassVar, \"$name\", _attributes, attrc);";

	# Only add methods if not readonly. Readonly properties do not
	# have a getter synthesized for them since ivars cannot be added.
	# The programmer is expected to implement the getter himself.
	if (!$readonly) {
		$build .= " size_t _nBytes = 1024;";
		$build .= " char _typeEncoding[_nBytes];";
		# Getter
		$build .= " snprintf(_typeEncoding, _nBytes, \"%s\@:\", \@encode($propertyType));";
		$build .= " class_addMethod($logosClassVar, \@selector($propertyGetter), (IMP)&$propertyGetterName, _typeEncoding);";

		# Setter
		$build .= " snprintf(_typeEncoding, _nBytes, \"v\@:%s\", \@encode($propertyType));";
		$build .= " class_addMethod($logosClassVar, \@selector($propertySetter:), (IMP)&$propertySetterName, _typeEncoding);";
	}

	$build .= " } ";

	return $build;
}

1;

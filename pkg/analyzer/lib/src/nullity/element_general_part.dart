/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// Generally, in all nullity/element_*_part.dart files, functions whose names
/// end with 0 (zero) have no effect when [isDEP30] is false and so it is safe 
/// to use them without an [isDEP30] guard.

part of engine.element;

/// Global compile-time switch to enable/disable DEP30 semantics.
const bool isDEP30 = const String.fromEnvironment("DEP_NNBD") != null;
const bool _doSanityChecks = true;

ifDEP30(value, [_default = true]) => isDEP30 ? value : _default;

// Take our own medicine: this is used internally as a nullable annotation.
const nullable = 0;

/// Used in DEP30 code to wrap a function argument when the corresponding parameter should be
/// declared nullable (but we don't want to change the declation yet).
paramIsNullableDEP30(o) => o as dynamic;

/// Flag controlling whether annotations must originate from dart:core or not.
const annoMustBeFromDartCore = false; 

throwNI() => throwSNO('Feature is not implemented');

throwSNO([String msg = '']) =>
    throw new IllegalStateException('Should not occur: $msg');
sanityCheckDEP30(value, [bool pred(value)]) => (!isDEP30 ||
    !_doSanityChecks ||
    pred == null ||
    pred(value)) ? value : throwSNO('Sanity check failed');


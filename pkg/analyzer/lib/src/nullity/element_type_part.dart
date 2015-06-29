/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// [DartType] related declarations. None of the features in this part are
/// relevant, or should be used, if ![isDEP30].
///
/// [NonNullType] and [UnionWithNullType] are model elements not [AstNode]s.

part of engine.element;

// ----------------------------------------------------------------------------
// Nullity member definitions for use in [DartType] and [TypeImpl].

abstract class DartTypeNullity {

  /// True iff this represents the [Null] Dart type.
  bool get isNull;

  /// A nullable instance of this type.
  UnionWithNullType asNullable(TypeProvider typeProvider);

  /// A non-null instance of this type.
  DartType get asNonNull;
}

/// [TypeImpl] mixin for nullity features.
abstract class TypeImplNullity implements DartType {

  /// See [TypeImpl.element].
  Element get element;

  bool isNull = false;
  DartType get asNonNull => this;

  // The nullable type of [this] type, if any (this field is lazily initialized).
  @nullable UnionWithNullType _nullableType;

  @nullable UnionWithNullType asNullable(TypeProvider typeProvider) {
    if (element == null) return null;
    if (_nullableType == null) {
      _nullableType = new UnionWithNullTypeImpl.from(this, typeProvider);
    }
    return _nullableType;
  }

  bool isNullType(DartType type) {
    if (type == null || type.name != "Null") return false;
    Element element = type.element;
    if (element is! ClassElement) // Element not resolved yet; let's be optimistic.
        return true;
    return (element as ClassElement).supertype == null &&
        (element.library == null || // Some test env don't set the library
            element.library.isDartCore);
  }
}

bool isNullType(DartType type) {
  return type != null && type.isNull;
  // TODO: reinstate if/once nullities become part of the dart:core.
  //  if (type == null || type.name != "Null") return false;
  //  Element element = type.element;
  //  if (element is! ClassElement) // Element not resolved yet; let's be optimistic.
  //      return true;
  //  return (element as ClassElement).supertype == null &&
  //      (element.library == null || // Some test env don't set the library
  //          element.library.isDartCore);
}

// ----------------------------------------------------------------------------
//

/// A normalized (E.1.2) non-null [DartType].
abstract class NonNullType extends DartType {

  /// True iff [type] would be a valid type argument for a [NonNullType].
  static bool isValidArg(DartType type) => type != null &&
      type is! UnionWithNullType &&
      (type.isDynamic ||
          type is TypeParameterType || /*E.1.1(a)*/ type is InterfaceType &&
              !type.isNull);

  /// Can only be either [DynamicType] or a [TypeParameterType].
  DartType get typeArgument;
  DartType get asNonNull => typeArgument;

  /// [typeArgument.element]
  Element get element;

  /// Returns type.isMoreSpecificThan(this,withDynamic,visitedElements)
  bool invIsMoreSpecificThan(DartType otherType,
      [bool withDynamic = false, Set<Element> visitedElements]);

  static bool isValidType(DartType type) =>
      type != null && (type.isDynamic || type is TypeParameterType);
}

/// Implementation of a [NonNullType].
class NonNullTypeImpl extends TypeImpl implements NonNullType {
  final DartType typeArgument;

  NonNullTypeImpl(DartType _typeArgument, [Element element])
      : super(element == null ? _typeArgument.element : element,
          "$NON_NULL_TYPE_OP_NAME${_typeArgument.name}"),
        typeArgument = _typeArgument {
    assert(NonNullType.isValidArg(_typeArgument));
  }

  @override
  @nullable Element get element => typeArgument == null ? null : typeArgument.element;

  @override
  bool operator ==(o) => o is NonNullTypeImpl && o.typeArgument == typeArgument;

  @override
  int get hashCode => typeArgument.hashCode;

  /// Returns ![typeArgument] << [s].
  @override
  bool isMoreSpecificThan(DartType s,
      [bool withDynamic = false, Set<Element> visitedElements]) {
    // Let this = !T and s = S.

    if (this == s) return true;
    if (s.isDynamic) return true;
    if (s.isObject) return true;

    // !T << !U if T << U
    if (s is NonNullType &&
        (typeArgument as TypeImpl).isMoreSpecificThan(
            s.typeArgument, withDynamic, visitedElements)) return true;

    // !T << S if T << S since !T << T
    if ((typeArgument as TypeImpl).isMoreSpecificThan(
        s, withDynamic, visitedElements)) return true;

    return false;
  }

  /// Returns: [s] << ![typeArgument].
  @override
  bool invIsMoreSpecificThan(DartType s,
      [bool withDynamic = false, Set<Element> visitedElements]) {
    // Uninstantiated parameter types are incomparable. To avoid infinite
    // recursion, just return false when [typeArgument] is a parameter type.
    if (typeArgument is TypeParameterType) return false;
    // TODO: (D.2.1) - T << !dynamic iff T << Object.
    // if (typeArgument.isDynamic) return s.isMoreSpecificThan(objectType)
    return s.isMoreSpecificThan(this);
  }

  @override
  TypeImpl pruned(List<FunctionTypeAliasElement> prune) {
    if (prune == null || typeArgument is! TypeImpl) return this;
    return new NonNullTypeImpl(
        (typeArgument as TypeImpl).pruned(prune), element);
  }

  @override
  DartType substitute2(
      List<DartType> argumentTypes, List<DartType> parameterTypes,
      [List<FunctionTypeAliasElement> prune]) {
    TypeImpl newTypeArgument = typeArgument is TypeImpl
        ? (typeArgument as TypeImpl).substitute2(
            argumentTypes, parameterTypes, prune)
        : typeArgument.substitute2(argumentTypes, parameterTypes);

    if (newTypeArgument == typeArgument) return typeArgument;

    // Normalize (E.1.2)
    if (newTypeArgument is UnionWithNullType) {
      return (newTypeArgument as UnionWithNullType).typeArgument;
    } else if (newTypeArgument.isNull) {
      return DynamicTypeImpl.instance; // (B.3.2) - !Null is malformed
    }
    if (!NonNullType.isValidArg(newTypeArgument)) return newTypeArgument;

    return newTypeArgument is InterfaceType
        ? newTypeArgument // Under DEP30 an interface type is non-null.
        : new NonNullTypeImpl(newTypeArgument, element);
  }
}

// ----------------------------------------------------------------------------
// Union types with union-with-null as a special case.

abstract class UnionType extends DartType {}

/// A normalized (E.1.2) nullable [DartType].
abstract class UnionWithNullType extends UnionType {
  /// Operands of the Null | T "union type".
  InterfaceType get nullType;
  DartType get typeArgument;

  /// Returns type.isMoreSpecificThan(this,withDynamic,visitedElements)
  bool invIsMoreSpecificThan(DartType otherType,
      [bool withDynamic = false, Set<Element> visitedElements]);

  /// True iff [type] would be a valid type argument for a [UnionWithNullType].
  static bool isValidArg(DartType type) => !(type == null ||
      type.isDynamic ||
      isNullType(type) ||
      identical(type, VoidTypeImpl.instance) ||
      type.isUndefined ||
      type is UnionWithNullType);

  /// See [InterfaceType.getGetter].
  PropertyAccessorElement getGetter(String name);

  /// See [InterfaceType.getMethod].
  MethodElement getMethod(String name);

  /// See [InterfaceType.getSetter].
  PropertyAccessorElement getSetter(String name);

  /// See [InterfaceType.lookUpGetter].
  PropertyAccessorElement lookUpGetter(String name, LibraryElement library);

  /// See [InterfaceType.lookUpMethod].
  MethodElement lookUpMethod(String name, LibraryElement library);

  /// See [InterfaceType.lookUpSetter].
  PropertyAccessorElement lookUpSetter(String name, LibraryElement library);

  /// See [TypeSystemImpl.getLeastUpperBound].
  DartType getLUB(DartType type, TypeSystem typeSystem);
}

/// Implementation of a [UnionWithNullType].
class UnionWithNullTypeImpl extends /*Interface*/ TypeImpl implements UnionWithNullType {

  /// The type for [Null].
  final InterfaceType nullType;

  /// The type being nulled.
  // Note: we considered the name argumentType but it is just one letter different from
  // [argumentTypes]; hence to avoid quick-read confusion, we chose a remarkably different name.
  final TypeImpl typeArgument;

  UnionWithNullTypeImpl(
      UnionWithNullElementImpl element, TypeImpl _typeArgument)
      : super(element, "$NULLABLE_TYPE_OP_NAME${_typeArgument.name}"),
        nullType = element.nullClassElement.type,
        typeArgument = _typeArgument == null
            ? element.argumentType
            : _typeArgument {
    // TODO: Sometimes typeArgument is null. Ensure that it is not at call sites.
    assert(typeArgument == null || UnionWithNullType.isValidArg(typeArgument));
    assert(UnionWithNullType.isValidArg(typeArgument));
  }

  factory UnionWithNullTypeImpl.from(DartType type, TypeProvider typeProvider) {
    if (type is UnionWithNullType) return type;
    assert(UnionWithNullType.isValidArg(type));
    UnionWithNullElementImpl e = new UnionWithNullElementImpl(
        typeProvider.nullType.element, type.element,
        typeProvider.functionType.element, typeProvider.objectType.element);
    UnionWithNullType newType = new UnionWithNullTypeImpl(e, type);
    e.type = newType;
    return newType;
  }

  @override
  String get displayName => "$NULLABLE_TYPE_OP_NAME${typeArgument.displayName}";

  @override
  void appendTo(StringBuffer buffer) {
    buffer.write(NULLABLE_TYPE_OP_NAME);
    buffer.write(typeArgument);
  }

  @override
  UnionWithNullElementImpl get element =>
      super.element as UnionWithNullElementImpl;

  @override
  bool operator ==(o) =>
      o is UnionWithNullTypeImpl && o.typeArgument == typeArgument;

  @override
  int get hashCode => typeArgument.hashCode;

  @override
  bool isAssignableTo(DartType type) {
    return super.isAssignableTo(type);
  }

  @override
  bool isSubtypeOf(DartType type) {
    return super.isSubtypeOf(type);
  }

  /// Returns ?[typeArgument] << [s].
  @override
  bool isMoreSpecificThan(DartType s,
      [bool withDynamic = false, Set<Element> visitedElements]) {
    // Let this be ?T. ?T << S iff T << S && Null << S.

    // Optimizations:
    if (this == s) return true;
    if (s.isDynamic) return true;

    // We don't optimize out the Null << S so that it will work if ever
    // we adopt _Anything as a root.
    return nullType.isMoreSpecificThan(s) &&
        typeArgument.isMoreSpecificThan(s, withDynamic, visitedElements);

    // return s.isDynamic || // or U << type
    //   typeArgument.isMoreSpecificThan(s, withDynamic, visitedElements);
  }

  /// Returns: [s] << ?[typeArgument]; i.e.,
  /// iff [s] is [Null] || [s] << [typeArgument].
  @override
  bool invIsMoreSpecificThan(DartType s,
          [bool withDynamic = false, Set<Element> visitedElements]) =>
      s == nullType || s.isMoreSpecificThan(typeArgument);

  @override
  PropertyAccessorElement lookUpGetter(
          String getterName, LibraryElement library) =>
      element.lookUpGetter(getterName, library);

  @override
  PropertyAccessorElement lookUpSetter(
          String setterName, LibraryElement library) =>
      element.lookUpSetter(setterName, library);

  @override
  MethodElement lookUpMethod(String methodName, LibraryElement library) =>
      element.lookUpMethod(methodName, library);

  @override
  TypeImpl pruned(List<FunctionTypeAliasElement> prune) {
    if (prune == null || prune.length == 0) return this;
    TypeImpl newTypeArgument = typeArgument.pruned(prune);
    // Normalize
    UnionWithNullTypeImpl newType = UnionWithNullType
            .isValidArg(newTypeArgument)
        ? new UnionWithNullTypeImpl(element, newTypeArgument)
        : newTypeArgument;
    return newType;
  }

  @override
  DartType substitute2(
      List<DartType> argumentTypes, List<DartType> parameterTypes,
      [List<FunctionTypeAliasElement> prune]) {
    TypeImpl newTypeArgument =
        typeArgument.substitute2(argumentTypes, parameterTypes, prune);
    // Normalize
    TypeImpl newType = UnionWithNullType.isValidArg(newTypeArgument)
        ? new UnionWithNullTypeImpl(element, newTypeArgument)
        : newTypeArgument;
    return newType;
  }

  @override
  PropertyAccessorElement getGetter(String name) =>
      element == null ? null : element.getGetter(name);

  @override
  MethodElement getMethod(String name) =>
      element == null ? null : element.getMethod(name);

  @override
  PropertyAccessorElement getSetter(String name) =>
      element == null ? null : element.getSetter(name);

  DartType getLUB(DartType type, TypeSystem typeSystem) {
    DartType lubWithTypeArg =
        typeSystem.getLeastUpperBound(this.typeArgument, type);
    return UnionWithNullType.isValidArg(lubWithTypeArg)
        ? new UnionWithNullTypeImpl.from(
            lubWithTypeArg, typeSystem.typeProvider)
        : lubWithTypeArg;
  }
}

// ----------------------------------------------------------------------------

// class AnonymousFunctionTypeAliasTypeFromElement  extends DartType {}

class AnonymousFunctionTypeImpl extends FunctionTypeImpl {
  static const String ANON_TYPEDEF_NAME = "<anonymous-typedef>";

  AnonymousFunctionTypeImpl.forTypedef(FunctionTypeAliasElement element)
      : super._(element, element == null
          ? null
          : element.name == null || element.name.isEmpty
              ? ANON_TYPEDEF_NAME
              : element.name, paramIsNullableDEP30(null));
}

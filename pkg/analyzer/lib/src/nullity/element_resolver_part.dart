/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// Functions whose names end with 0 (zero) have no effect when [isDEP30] is false.

part of engine.resolver.element_resolver;

/// [ElementResolver] nullity mixin.
abstract class ElementResolverNullity {

  // --------------------------------------------------------------------------
  // Members defined in [ElementResolver].
  //

  /// See [ElementResolver._enableHints].
  bool get _enableHints;

  /// See [ElementResolver._resolver].
  ResolverVisitor get _resolver;

  /// See [ElementResolver._isExecutableType].
  bool _isExecutableType(DartType type);

  /// See [ElementResolver._resolveTypeParameter].
  DartType _resolveTypeParameter(DartType type);

  /// See [ElementResolver._getStaticType].
  DartType _getStaticType(Expression expression);

  /// See [ElementResolver._recordUndefinedNode].
  void _recordUndefinedNode(Element declaringElement, ErrorCode errorCode,
      AstNode node, List<Object> arguments);

  /// See [ElementResolver._recordUndefinedToken].
  void _recordUndefinedToken(Element declaringElement, ErrorCode errorCode,
      sc.Token token, List<Object> arguments);

  // --------------------------------------------------------------------------
  // New mixin members.
  //

  bool _enableNonNullTypes = false;
  bool _reportMissingUnionTypeMemberAsHint = true;

  /// True iff DEP30 is enabled and [element] has a promoted type that is
  /// [ElementResolver._isExecutableType].
  bool _isPromotedTypeExecutable0(Element element) {
    DartType type = _resolver.promoteManager.getType(element);
    return _enableNonNullTypes && type != null && _isExecutableType(type);
  }

  /// DEP30 (C.3.1), (C.3.3). If [type] is not a non-null or nullable qualified type
  /// parameter T, then return null; otherwise return an correspondingly qualified
  /// type with type that T resolves to.
  @nullable DartType _resolveTypeParameter0(
      DartType type, TypeProvider typeProvider) {
    if (!_enableNonNullTypes) return null;
    if (type is UnionWithNullType && type.typeArgument is TypeParameterType) {
      DartType resolvedTypeArgument = _resolveTypeParameter(type.typeArgument);
      if (UnionWithNullType.isValidArg(resolvedTypeArgument)) {
        return new UnionWithNullTypeImpl.from(
            resolvedTypeArgument, typeProvider);
      }
      return resolvedTypeArgument;
    } else if (type is NonNullType && type.typeArgument is TypeParameterType) {
      DartType resolvedTypeArgument = _resolveTypeParameter(type.typeArgument);
      if (NonNullType.isValidArg(resolvedTypeArgument)) {
        return new NonNullTypeImpl(resolvedTypeArgument);
      }
      return resolvedTypeArgument;
    } else if (type is TypeParameterType && type.element.bound == null) {
      //DEP30(C.3.4)
      return _resolver.typeProvider.objectType
          .asNullable(_resolver.typeProvider);
    }
    return null;
  }

  /// DEP30 (B.2.8). True iff the UnionWithNull member [element] is missing
  /// definitions (there should be two, one for Null and one for the other type.
  bool _shouldReportMissingUnionWithNullMember(
      Element element, Element propagatedElement) {
    if (element is! MultiplyInheritedExecutableElement ||
        !(element as ExecutableElementImpl)
            .hasModifier(ModifierDep30.UNION_OF_MEMBERS) ||
        propagatedElement != null &&
            propagatedElement is! MultiplyInheritedExecutableElement) return false;

    MultiplyInheritedExecutableElement mie =
        element as MultiplyInheritedExecutableElement;

    // Since we currently only support union types with Null: if num elements
    // is 0 then warnings will be reported elsewhere; if num is 2 then there
    // is no problem to report.
    return getElements(mie).length == 1;
  }

  /// DEP30 (B.2.8). If the UnionWithNull member [staticElement] is missing
  /// definitions (there should be two), then report a problem.
  void reportUnionTypeOperatorInvocationErrors(Expression target,
      String methodName, sc.Token operator, Element staticElement,
      Element propagatedElement) {
    if (!_shouldReportMissingUnionWithNullMember(
        staticElement, propagatedElement)) return;
    DartType targetType = _getStaticType(target);
    String targetTypeName = targetType == null ? null : targetType.name;
    if (_reportMissingUnionTypeMemberAsHint && !_enableHints) return;

    ErrorCode errorCode = _reportMissingUnionTypeMemberAsHint
        ? HintCode.UNDEFINED_OPERATOR
        : StaticTypeWarningCode.UNDEFINED_OPERATOR;

    _recordUndefinedToken(
        staticElement, errorCode, operator, [methodName, targetTypeName]);
  }

  /// DEP30(B.3.6). If the UnionWithNull member [staticElement] is missing
  /// definitions (there should be two), then report a problem.
  void reportUnionTypeMethodInvocationErrors(Expression target,
      SimpleIdentifier methodName, Element staticElement, Element propagatedElement) {
    if (!_shouldReportMissingUnionWithNullMember(staticElement, propagatedElement)) return;
    DartType targetType = _getStaticType(target);
    String targetTypeName = targetType == null ? null : targetType.name;
    if (_reportMissingUnionTypeMemberAsHint && !_enableHints) return;

    ErrorCode errorCode = _reportMissingUnionTypeMemberAsHint
        ? HintCode.UNDEFINED_METHOD
        : StaticTypeWarningCode.UNDEFINED_METHOD;
    _recordUndefinedNode(
        staticElement, errorCode, methodName, [methodName.name, targetTypeName]);
  }
}

/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// [Element] related declarations.

part of engine.element;

// ----------------------------------------------------------------------------
// Model elements in support of DEP30 (E.1.1.1): a dual view for optional
// function parameters.
//

/// Mixin interface adding a callee view.
abstract class DefaultParameterElementWithCalleeViewImpl {

  /// A synthetic parameter element counterpart to [this] when [this]
  /// is nullable from the callee's body scope (DEP 30, E.1.1.1).
  @nullable DefaultCalleeViewParameterElementImpl calleeViewParamElement;

  /// Create [calleeViewParamElement]. Must be created during the [ElementBuilder]
  /// phase since variable occurrences in the function body will be bound to it.
  void createCalleeViewParamElement() {
    calleeViewParamElement = new DefaultCalleeViewParameterElementImpl(this);
  }

  /// Adjust the callee view type based on the semantics of DEP30(E.1.1).
  /// - [node] if not null, should be the [DefaultFormalParameter] of [this].
  /// - [typeOrId] is the child of [node] to which a [NullityElement] would be attached, if any.
  void adjustCalleeViewTypeIfNecessary(@nullable AstNode node,
                                       @nullable AstNode typeOrId,
                                       TypeProvider typeProvider) {
    calleeViewParamElement.adjustTypeIfNecessary(node, typeOrId, typeProvider);
  }
}

/// Synthetic model element for a default parameter's callee view.
/// Delegates to [delegate] except for a the [isSynthetic] test and a
/// possibly different [type]; see DEP30 (E.1.1.1) for details.
class DefaultCalleeViewParameterElementImpl
    implements ParameterElementImpl, ConstVariableElement {

  /// Default parameter element for which this is the callee view element.
  DefaultParameterElementImpl get delegate => _delegate;

  final DefaultParameterElementImpl _delegate;

  DefaultCalleeViewParameterElementImpl(this._delegate) {
    _delegate.calleeViewParamElement = this;
  }

  @nullable DartType _type;
  DartType get type => _type == null ? _delegate.type : _type;
  void set type(DartType t) { _type = t; }

  /// Adjust the type of [this] callee view parameter according to the
  /// semantics of DEP30(E.1.1).
  /// - [node] if not null, should be the [DefaultFormalParameter] of [_delegate].
  /// - [typeOrId] is the child of [node] to which a [NullityElement] would be attached, if any.
  void adjustTypeIfNecessary(@nullable AstNode node,
                             @nullable AstNode typeOrId,
                             TypeProvider typeProvider) {
    // By default, any optional parameter, under callee view, will have a nullable type.
    // There are exceptions to this default; these cases are explored below.

    DartType callerViewParamType = _delegate.type;
    // Determine if special cases apply that would make the callee view type match caller view type.

    // Case A. callerViewParamType is already nullable.
    if (callerViewParamType == null // we take it to mean it is dynamic
        || callerViewParamType.isAssignableTo(typeProvider.nullType)
        || !UnionWithNullType.isValidArg(callerViewParamType) // this should be redundant
      ) {
      return; // paramType is already nullable.
    }

    // Case B. Parameter type explicitly marked with non-null meta type annotation.
    NullityElement nullity = typeOrId == null ? null : typeOrId.getProperty(NULLITY_ELEMENT_KEY);
    if (nullity != null && nullity.nonNullAnnoCount > 0) return;

    // Case C. Parameter has a default value. This case only applies to [SimpleFormalParameter].
    // Is there a default value? If so, assume it is non-null. If we reach this point then
    // null is _not_ assignable to [callerViewParamType], hence if our assumption is wrong, then
    // a static type warning will be reported (by some other part of the code).
    if (node is DefaultFormalParameter && node.defaultValue != null) return;

    // Default case. Callee view is nullable type of [_delegate].
    assert(nullity == null || nullity.nullableAnnoCount <= 0);
    _type = callerViewParamType.asNullable(typeProvider);
  }

  @override
  void appendTo(StringBuffer buffer) => _delegate.appendTo(buffer);
  @override
  String toString() => _delegate.toString();
  @override
  Element get enclosingElement => _delegate.enclosingElement;
  @override
  LibraryElement get library => _delegate.library;
  @override
  ElementKind get kind => _delegate.kind;
  @override
  bool get isDeprecated => _delegate.isDeprecated;
  @override
  bool get isPotentiallyMutatedInClosure =>
      _delegate.isPotentiallyMutatedInClosure;
  @override
  bool get isPotentiallyMutatedInScope => _delegate.isPotentiallyMutatedInScope;
  @override
  void markPotentiallyMutatedInScope() =>
      _delegate.markPotentiallyMutatedInScope();
  @override
  void markPotentiallyMutatedInClosure() =>
      _delegate.markPotentiallyMutatedInClosure();
  @override
  bool get isConst => _delegate.isConst;
  @override
  bool get isFinal => _delegate.isFinal;
  @override
  EvaluationResultImpl get evaluationResult => _delegate.evaluationResult;
  @override
  bool get isSynthetic => true;

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ----------------------------------------------------------------------------
// Model elements for union (with null) types.
//

typedef ExecutableElement MemberFetchFunc(ClassElementImpl);

/// Element for a union of [argumentElement] with Null. [E] must be
/// TypeParameterElement|TypeDefiningElement.
abstract class UnionWithNullElement<E extends Element> implements Element {
  E get argumentElement;
  ClassElement get nullClassElement;
}

/// Element for a union of [argumentElement] with Null. [E] must be
/// TypeParameterElement|TypeDefiningElement.
class UnionWithNullElementImpl<E extends Element> extends ElementImpl
    implements UnionWithNullElement<E> {

  /// True iff e is a valid value for [argumentElement].
  static bool isValidArgElt(Element e) =>
      e is TypeParameterElement || e is TypeDefiningElement;

  final E argumentElement;
  final ClassElementImpl nullClassElement;

  // Temporarily needed fields (for this prototype implementation).
  final ClassElementImpl objectClassElement; // tmp until Null is properly unrooted
  final ClassElementImpl functionClassElement; // tmp for DartC bug workaround
  @nullable DartType type;

  /// Caller must initialize [this.type].
  UnionWithNullElementImpl(this.nullClassElement, this.argumentElement,
      this.functionClassElement, this.objectClassElement)
      : super.forNode(paramIsNullableDEP30(null)) {
    assert(isValidArgElt(argumentElement));
    synthetic = true;
    type = argumentType;
    fixFuncTypeAliasTypeIfNecessary();
  }

  void fixFuncTypeAliasTypeIfNecessary() {
    if (argumentElement is! FunctionTypeAliasElementImpl) return;
    FunctionTypeAliasElementImpl arg =
        argumentElement as FunctionTypeAliasElementImpl;
    if (arg.type != null) return;
    // This is necessary in order to support type overrides; e.g., see
    // [ResolverVisitor.overrideExpression].
    arg.type = new AnonymousFunctionTypeImpl.forTypedef(arg);
  }

  @nullable ClassElementImpl get argAsClassElt =>
      argumentElement is ClassElementImpl
          ? argumentElement
          : argumentElement is FunctionTypeAliasElementImpl
              ? functionClassElement
              : null;

  @nullable DartType get argumentType => argumentElement is TypeDefiningElement
      ? (argumentElement as TypeDefiningElement).type
      : argumentElement is TypeParameterElement
          ? (argumentElement as TypeParameterElement).type
          : null;

  @override
  bool operator ==(o) =>
      o is UnionWithNullElementImpl && o.argumentElement == argumentElement;

  @override
  int get hashCode => argumentElement.hashCode;

  @nullable PropertyAccessorElement getGetter(String getterName) =>
      getMember((c) => c.getGetter(name, library));

  @nullable MethodElement getMethod(String methodName) =>
      getMember((c) => c.getMethod(name, library));

  @nullable PropertyAccessorElement getSetter(String name) =>
      getMember((c) => c.getSetter(name, library));

  @nullable PropertyAccessorElement lookUpGetter(String name, LibraryElement library) =>
      getMember((c) => c.lookUpGetter(name, library));

  @nullable PropertyAccessorElement lookUpSetter(String name, LibraryElement library) =>
      getMember((c) => c.lookUpSetter(name, library));

  @nullable MethodElement lookUpMethod(String name, LibraryElement library) {
    List<ExecutableElement> list = <ExecutableElement>[];
    MemberFetchFunc fetch = (c) => c.lookUpMethod(name, library);
    MemberFetchFunc fetchFromObjectIfNull = (c) {
      ExecutableElement element = fetch(c);
      return element == null ? fetch(objectClassElement) : element;
    };
    // "Temporary" until [Null] is properly re-rooted.
    _safeAdd(list, fetchFromObjectIfNull, nullClassElement);
    _safeAdd(list, fetch, argAsClassElt);
    return mergeExecutableElements(list);
  }

  @nullable ExecutableElement getMember(MemberFetchFunc fetch) {
    List<ExecutableElement> list = <ExecutableElement>[];
    _safeAdd(list, fetch, nullClassElement);
    _safeAdd(list, fetch, argAsClassElt);
    return mergeExecutableElements(list);
  }

  @nullable ExecutableElement mergeExecutableElements(
      List<ExecutableElement> list) {
    if (list.length == 0) return null;
    ExecutableElement element =
        InheritanceManager.computeMergedExecutableElement(list);
    (element as ExecutableElementImpl).setModifier(
        ModifierDep30.UNION_OF_MEMBERS, true);
    return element;
  }

  static void _safeAdd(List<ExecutableElement> list, MemberFetchFunc fetch,
      ClassElementImpl classElement) {
    if (classElement == paramIsNullableDEP30(null)) return;
    ExecutableElement element = fetch(classElement);
    if (element != null) list.add(element);
  }

  @override
  accept(ElementVisitor visitor) => argumentElement.accept(visitor);

  @override
  ElementKind get kind => argumentElement.kind; // TODO: define our own kind.
}

// ----------------------------------------------------------------------------
// Union class member elements (B.3.6)
//
// TODO: create peer classes to [MultiplyInheritedMethodElementImpl]
// and [MultiplyInheritedPropertyAccessorElementImpl]. Say:
//
// class MethodUnionElementImpl extends SOME_COMMON_SUPERTYPE {}
// class PropertyAccessorUnionElementImpl extends SOME_COMMON_SUPERTYPE {}
//
// In the meantime we simply use the Multiply*ElementImpl classes, but tag
// instances so that we can recognize them later for special processing.

class ModifierDep30 extends Modifier {
  const ModifierDep30(String name, int ordinal) : super(name, ordinal);

  static const Modifier UNION_OF_MEMBERS =
      const Modifier('UNION_OF_MEMBERS', /*SYNTHETIC +*/ 30);
}

List<ExecutableElement> getElements(MultiplyInheritedExecutableElement e) =>
    e.inheritedElements;

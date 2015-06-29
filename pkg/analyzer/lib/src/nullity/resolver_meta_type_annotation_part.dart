/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null

part of engine.resolver;

final String NULLITY_ELEMENT_KEY = "nullityElement";

/**
 * (B.4.6) In DartC, annotations are processed only after types. For
 * DartNNBD we need the nullity annotation resolved early so that we can
 * implement non-null types. This class is a resolver for annotations.
 */
class AnnotationResolver extends RecursiveAstVisitor<dynamic> {
  final Library library;

  AnnotationResolver(this.library);

  @override
  visitAnnotation(Annotation node) {
    Identifier identifier = node.name;
    LibraryScope libraryScope = library.libraryScope;
    Element element = libraryScope.lookup(identifier, library.libraryElement);
    if (element != null &&
        (!annoMustBeFromDartCore || element.library.isDartCore) &&
        element is PropertyAccessorElement) {
      NullityElementAnnotationImpl elementAnnotation =
          new NullityElementAnnotationImpl(element);
      node.elementAnnotation = elementAnnotation;
    }
  }
}

/**
 * DEP30 (B.4.6). Also see comments in (II.2.1(a), II.2.1(c)1(b)).
 * 
 * Design note: meta type annotations derived from comments must *only* be consumed
 * at the appropriate level of node; namely *only* for [TypeName] and 
 * [SimpleFormalParameter]. The latter is only for parameters using the function 
 * signature syntax.
 * 
 * In the absence of concrete syntax for meta type annotations we use metadata
 * and comments. Once processed, metadata and comments get attached to an [AstNode]
 * in the form of a [NullityElement]. A [NullityElement] can be though of an
 * an inherited (grammar) attribute with final adjustment done at the final node
 * level based on its individual meta type annotations. The nullity attribute in
 * inherited in that it is influenced by:
 * 
 * - The global const feature enabling flag [isDEP30].
 * - [AnalysisOptions.enableNonNullTypes]
 * - @nullable_by_default annotations, if any, associated with
 *   a class declaration or, a directive (library, part, or part of).
 * 
 * Note that [NullityElement]s get attached to [AstNode]s as a node property
 * with key [NULLITY_ELEMENT_KEY].
 */
class ComputeInheritedNullityAttribute extends RecursiveAstVisitor<dynamic> {
  final AnalysisContext analysisContext;
  final Library library;

  @nullable NullityElement _ancestorNullity;
  @nullable CompilationUnit _unit;
  CompilationUnitElementImpl get unitElement =>
      _unit.element is CompilationUnitElementImpl ? _unit.element : throwSNO();

  ComputeInheritedNullityAttribute(this.analysisContext, this.library) {
    assert(analysisContext.analysisOptions.enableNonNullTypes);
  }

  @override
  visitClassDeclaration(ClassDeclaration node) => _push_VisitChildren_Pop(
      node, _nullityFromMetadataBasedOnAncestorOrArg(node));

  /// This is visited first. It can be a library or a part.
  /// The fields [_unit] and [_ancestorNullity] are initialized.
  @override
  visitCompilationUnit(CompilationUnit node) {
    _unit = node;
    _ancestorNullity = new NullityElement();
    node.visitChildren(this);
  }

  @override
  visitFunctionDeclaration(FunctionDeclaration node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    _safelyPush_VisitChild_Pop(node.returnType, nullity);
    _safelyPush_VisitChild_Pop(node.functionExpression);
  }

  @override
  visitLibraryDirective(LibraryDirective node) {
    // If this directive has a @nullable_by_default annotation
    // then this default applies to all in the library (including parts).
    // Hence, don't push/pop ancestorNullity, just override it.
    _ancestorNullity.setFromNode(node);
  }

  @override
  visitPartDirective(PartDirective node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    String uri = node.uri.stringValue;
    if (uri == null || uri is StringInterpolation) return;

    CompilationUnitElementImpl element = unitElement;
    Source partSource =
        element.context.sourceFactory.resolveUri(element.source, uri);
    CompilationUnitElement partCUE = element.library.parts
        .firstWhere((CompilationUnitElement c) => c.source == partSource);
    if (partCUE is CompilationUnitElementImpl) {
      partCUE.isNullableByDefault =
          (nullity == null ? _ancestorNullity : nullity).defaultIsNullable;
    }
  }

  @override
  visitPartOfDirective(PartOfDirective node) {
    _ancestorNullity.setFromNode(node);
    if (unitElement.isNullableByDefault) {
      _ancestorNullity.nullableByDefaultAnnoCount++;
    }
  }

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    _safelyPush_VisitChild_Pop(node.returnType, nullity);
    _safelyPush_VisitChild_Pop(node.name);
    _safelyPush_VisitChild_Pop(node.parameters);
    _safelyPush_VisitChild_Pop(node.body);
  }

  // Nothing special to be done since a [DefaultFormalParameter]
  // has a [NormalFormalParameter] as a child. [NormalFormalParameter]
  // are handled by the specific cases below.
  // @override
  // visitDefaultFormalParameter(DefaultFormalParameter node) =>
  //    super.visitDefaultFormalParameter(node);

  @override
  visitFieldFormalParameter(FieldFormalParameter node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    _safelyPush_VisitChild_Pop(node.type, nullity);
    _safelyPush_VisitChild_Pop(node.identifier);
    _safelyPush_VisitChild_Pop(node.parameters);
  }

  @override
  visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    _safelyPush_VisitChild_Pop(node.returnType, nullity);
    var id = node.identifier;
    _getOrInitNodeNullityProperty(id, _ancestorNullity); // (B.2.6)
    _safelyPush_VisitChild_Pop(id, nullity);
    _safelyPush_VisitChild_Pop(node.parameters);
  }

  @override
  visitSimpleFormalParameter(SimpleFormalParameter node) =>
      _push_VisitChildren_Pop(
          node, _nullityFromMetadataBasedOnAncestorOrArg(node));

  /// ... also handles the cases for
  /// [FieldDeclaration] and [TopLevelVariableDeclaration].
  @override
  visitVariableDeclarationList(VariableDeclarationList node) {
    var nullity = _nullityFromMetadataBasedOnAncestorOrArg(node);
    if (node.parent is AstNodeWithMetadata) {
      nullity = _nullityFromMetadataBasedOnAncestorOrArg(node.parent, nullity);
    }
    _safelyPush_VisitChild_Pop(node.type, nullity);
    node.variables.accept(this);
  }

  @override
  visitTypeName(TypeName node) {
    // If ever [TypeName]s get metadata, this would be processed here.
    var nullity = _getOrInitNodeNullityProperty(node, _ancestorNullity);
    _safelyPush_VisitChild_Pop(node.name, nullity);
    _safelyPush_VisitChild_Pop(node.typeArguments);
  }

  /// Does nothing if [node] is null. If [nullity] is null, then simply does
  /// visits [node] with [this];  otherwise it:
  /// - does a push: saves [_ancestorNullity], then sets it to [nullity];
  /// - visits [node] with [this]
  /// - pops: restores [_ancestorNullity].
  void _safelyPush_VisitChild_Pop(@nullable AstNode node,
      [NullityElement nullity]) {
    if (node == null) return;
    if (nullity == null) {
      node.accept(this);
    } else {
      NullityElement savedNullity = _ancestorNullity;
      _ancestorNullity = nullity;
      node.accept(this);
      _ancestorNullity = savedNullity;
    }
  }

  /// Like [_safelyPush_VisitChild_Pop], but visits the [children] of [node].
  void _push_VisitChildren_Pop(AstNode node, [NullityElement nullity]) {
    if (nullity != null) {
      NullityElement savedNullity = _ancestorNullity;
      _ancestorNullity = nullity;
      node.visitChildren(this);
      _ancestorNullity = savedNullity;
    } else {
      node.visitChildren(this);
    }
  }

  /// If this node has no metadata then return [nullity]. Otherwise,
  /// if [nullity] is non-null, update [nullity] with  [node.metadata] nullity;
  /// if [nullity] is null, then create a new nullity from
  /// [_ancestorNullity] and add [node.metadata] nullity to it.
  @nullable NullityElement _nullityFromMetadataBasedOnAncestorOrArg(
      AstNodeWithMetadata node, [NullityElement nullity]) {
    if (node.metadata.length > 0) {
      if (nullity == null) nullity = new NullityElement.from(_ancestorNullity);
      nullity.setFromMetadata(node.metadata);
    }
    return nullity;
  }

  /// Get nullity element stored as a property in [node] or, if there is no
  /// such property, then create one initialized from [init], and set it
  /// as a property of [node].
  NullityElement _getOrInitNodeNullityProperty(AstNode node,
      [NullityElement init]) {
    NullityElement nullity = node.getProperty(NULLITY_ELEMENT_KEY);
    if (nullity == null) {
      nullity =
          init == null ? new NullityElement() : new NullityElement.from(init);
      node.setProperty(NULLITY_ELEMENT_KEY, nullity);
    }
    return nullity..addAnnoFromComments(getComment(node));
  }
}

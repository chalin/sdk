/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null

part of engine.resolver;

/**
 * Extra top-level [LibraryResolver] phases.
 */
abstract class LibraryNullityResolverMixin {
  InternalAnalysisContext get analysisContext;
  Set<Library> get _librariesInCycles;

  bool _enableNonNullTypes = false;

  /**
   * (B.4.6) Library resolution phase used to adjust nullities of elements:
   * - Processes nullity metadata annotations.
   * - Propagates down the inherited nullity attributes.
   */
  void _processNullityAnnotations0() {
    if (!_enableNonNullTypes) return;

    for (Library library in _librariesInCycles) {
      AnnotationResolver annotationResolver = new AnnotationResolver(library);
      ComputeInheritedNullityAttribute computeNullityAttribute =
          new ComputeInheritedNullityAttribute(analysisContext, library);

      // Visit the library before its parts so that it's part directive
      // annotations can be processed.
      Source librarySource = library.librarySource;
      library.getAST(librarySource)
        ..accept(annotationResolver)
        ..accept(computeNullityAttribute);

      // Now we can visit the parts.
      for (Source source in library.compilationUnitSources) {
        if (identical(source, librarySource)) continue;
        library.getAST(source)
          ..accept(annotationResolver)
          ..accept(computeNullityAttribute);
      }
    }
  }

  /// B.3.4.c
  void _verifyNonNullLocalVarReadBeforeWrite0() {
    // if (!_enableNonNullTypes) return;
    //   TypeProvider typeProvider = analysisContext.typeProvider;
    //
    // for (Library library in _librariesInCycles) {
    //   LibraryScope libraryScope = library.libraryScope;
    //   AnalysisErrorListener errorListener = libraryScope.errorListener;
    //   for (Source source in library.compilationUnitSources) {
    //     ErrorReporter errorReporter = new ErrorReporter(errorListener, source);
    //     CompilationUnit unit = library.getAST(source);
    //     NonNullLocalVariableRbwVerifier visitor =
    //       new NonNullLocalVariableRbwVerifier(typeProvider,errorReporter);
    //     unit.accept(visitor);
    //   }
    // }
  }

}

/** 
 * Mixin for [ResolverVisitor] in support of type promotion. See DEP30 (B.3.7) for details.
 */
abstract class ResolverVisitorNullityMixin {

  /// See [ResolverVisitor._promote].
  void _promote(Expression expression, DartType potentialType);

  /// See [ResolverVisitor._promoteTypes].
  void _promoteTypes(Expression condition);

  /// See [ResolverVisitor._clearTypePromotionsIfPotentiallyMutatedIn].
  void _clearTypePromotionsIfPotentiallyMutatedIn(AstNode target);

  /// See [ResolverVisitor._clearTypePromotionsIfAccessedInClosureAndProtentiallyMutated].
  void _clearTypePromotionsIfAccessedInClosureAndProtentiallyMutated(
      AstNode target);

  /// DEP30(B.3.7). Subfunction used in [ResolverVisitor._promoteTypes].
  void _promoteTypesTrueAnd0(Expression condition) {
    if (!isDEP30) return;
    BinaryExpression binary = condition as BinaryExpression;
    var test = binaryExprNullTestTruthValue(binary);
    if (test == null) return;
    Expression uwnTypedOperand =
        binary.leftOperand.staticType is UnionWithNullType
            ? binary.leftOperand
            : binary.rightOperand;
    UnionWithNullType t = uwnTypedOperand.staticType;
    _promote(uwnTypedOperand, test ? t.nullType : t.typeArgument);
  }

  /// DEP30(B.3.7). Counterpart to [ResolverVisitor._promoteTypes] which deals with
  /// the cases where the given condition is [false].
  void _promoteTypesFalseCond0(Expression condition) {
    if (!isDEP30) return;
    if (condition is BinaryExpression) {
      BinaryExpression binary = condition;
      if (binary.operator.type == sc.TokenType.BAR_BAR) {
        _promoteTypesFalseCond0(binary.leftOperand);
        _promoteTypesFalseCond0(binary.rightOperand);
        _clearTypePromotionsIfPotentiallyMutatedIn(condition);
      } else if (isDEP30) {
        @nullable
        bool test = binaryExprNullTestTruthValue(binary);
        if (test != null) {
          Expression uwnTypedOperand =
              binary.leftOperand.staticType is UnionWithNullType
                  ? binary.leftOperand
                  : binary.rightOperand;
          UnionWithNullType t = uwnTypedOperand.staticType;
          _promote(uwnTypedOperand, test ? t.typeArgument : t.nullType);
        }
      }
    } else if (condition is IsExpression) {
      IsExpression is2 = condition;
      if (is2.notOperator != null) {
        _promote(is2.expression, is2.type.type);
      }
    } else if (condition is PrefixExpression) {
      PrefixExpression prefix = condition;
      if (prefix.operator.type == sc.TokenType.BANG) {
        _promoteTypes(prefix.operand);
      }
    } else if (condition is ParenthesizedExpression) {
      _promoteTypesFalseCond0(condition.expression);
    }
  }

  // DEP30(B.3.7)
  void _safelyPromoteTypesFalseCond0(Expression condition, AstNode stmt) {
    _promoteTypesFalseCond0(condition);
    _clearTypePromotionsIfPotentiallyMutatedIn(stmt);
    _clearTypePromotionsIfAccessedInClosureAndProtentiallyMutated(stmt);
  }

  /// Returns [null] if the operands of [binary] are not: one of type
  /// [UnionWithNullType] and the other has a static or propagated type
  /// of [Null]. Otherwise, returns [true] if the operator is
  /// "==" and [false] if it is "!=".
  @nullable bool binaryExprNullTestTruthValue(BinaryExpression binary) {
    var op = binary.operator.type;
    Expression leftOperand = binary.leftOperand;
    Expression rightOperand = binary.rightOperand;
    if (op == sc.TokenType.EQ_EQ) {
      return _arg1NullableAndArg2IsNull(leftOperand, rightOperand) ||
          _arg1NullableAndArg2IsNull(rightOperand, leftOperand) ? true : null;
    } else if (op == sc.TokenType.BANG_EQ) {
      return _arg1NullableAndArg2IsNull(leftOperand, rightOperand) ||
          _arg1NullableAndArg2IsNull(rightOperand, leftOperand) ? false : null;
    }
    return null;
  }

  /// Return true iff [e1] is of type [UnionWithNullType] and either
  /// the static or propagated type of [e2] is Null.
  bool _arg1NullableAndArg2IsNull(Expression e1, Expression e2) =>
      e1.staticType is UnionWithNullType &&
          (isNullType(e2.staticType) || isNullType(e2.propagatedType));
}

/**
 * DEP30(B.2.2, B.2.3, B.3.1, B.3.2). Returns the possibly adjusted [type] of [node]
 * based on the nullity attributes associated with [node]. This does not take 
 * optional function parameter function body scope (E.1.1.1) into consideration
 * since this is handled separately. It is assumed that the nullity attributes
 * of [node] have been normalized.(?).
 * 
 * Use by [TypeResolverVisitor].
 * 
 * TODO later: make this a private member of [TypeResolverVisitor].
 */
DartType _nullityAdjustedType0(
    TypeName node, DartType type, TypeProvider typeProvider) {
  if (!isDEP30) return type;

  NullityElement nullity = node.getProperty(NULLITY_ELEMENT_KEY);
  if (nullity == null) return type;

  if (nullity.defaultIsNullable &&
      nullity.nonNullAnnoCount <= 0 &&
      nullity.nullableAnnoCount <= 0 &&
      (node.parent is ConstructorName ||
          node.parent is CatchClause ||
          node.parent is IsExpression)) return type;

  if (type is InterfaceType && !type.isNull || type is FunctionType) {
    return nullity.nullableAnnoCount > 0 ||
            nullity.defaultIsNullable && nullity.nonNullAnnoCount <= 0
        ? new UnionWithNullTypeImpl.from(type, typeProvider)
        : type;
  }

  if (type is TypeParameterType) {
    return nullity.nonNullAnnoCount > 0
        ? new NonNullTypeImpl(type)
        : nullity.nullableAnnoCount > 0
            ? new UnionWithNullTypeImpl.from(type, typeProvider)
            : type;
  }

  if (type.isDynamic) {
    return nullity.nonNullAnnoCount > 0 ? new NonNullTypeImpl(type) : type;
  }

  return type;
}

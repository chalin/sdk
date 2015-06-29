/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null

part of engine.resolver.error_verifier;

/**
 * (B.3.4) [ErrorVerifier] mixin implementing instance variable initialization checks.
 */
abstract class ErrorVerifierNullityMixin {

  bool _enableNonNullTypes = false;

  /// See [ErrorVerifier._typeProvider].
  TypeProvider _typeProvider;
  /// See [ErrorVerifier._errorReporter].
  ErrorReporter _errorReporter;
  /// See [ErrorVerifier._isInNativeClass].
  bool _isInNativeClass;
  /// See [ErrorVerifier._initialFieldElementsMap].
  HashMap<FieldElement, INIT_STATE> _initialFieldElementsMap;

  /// (B.3.4.a.2) Ensure that non-null instance fields are explicitly initialized.
  /// Note that (B.3.4.a.1) is checked by [ErrorVerifier._checkForAllFinalInitializedErrorCodes].
  bool _checkForAllNonNullInitializedErrorCodes0(ConstructorDeclaration constructor) {
    if (!isDEP30 || _isInNativeClass ||
    constructor.factoryKeyword != null ||
    constructor.redirectedConstructor != null ||
    constructor.externalKeyword != null ||
    (constructor.element != null &&
     constructor.element.enclosingElement != null &&
     constructor.element.enclosingElement.isAbstract)
    ) {
      return false;
    }

    HashMap<FieldElement, INIT_STATE> fieldElementsMap =
    new HashMap<FieldElement, INIT_STATE>.from(_initialFieldElementsMap);

    // Visit all of the field formal parameters
    NodeList<FormalParameter> formalParameters =
    constructor.parameters.parameters;
    for (FormalParameter formalParameter in formalParameters) {
      FormalParameter parameter = formalParameter;
      if (parameter is DefaultFormalParameter) {
        parameter = (parameter as DefaultFormalParameter).parameter;
      }
      if (parameter is FieldFormalParameter) {
        FieldElement fieldElement =
        (parameter.element as FieldFormalParameterElementImpl).field;
        INIT_STATE state = fieldElementsMap[fieldElement];
        if (state == INIT_STATE.NOT_INIT) {
          fieldElementsMap[fieldElement] = INIT_STATE.INIT_IN_FIELD_FORMAL;
        }
      }
    }

    // Visit all of the initializers
    NodeList<ConstructorInitializer> initializers = constructor.initializers;
    for (ConstructorInitializer constructorInitializer in initializers) {
      if (constructorInitializer is RedirectingConstructorInvocation) {
        return false;
      }
      if (constructorInitializer is ConstructorFieldInitializer) {
        ConstructorFieldInitializer constructorFieldInitializer =
        constructorInitializer;
        SimpleIdentifier fieldName = constructorFieldInitializer.fieldName;
        Element element = fieldName.staticElement;
        if (element is FieldElement) {
          FieldElement fieldElement = element;
          INIT_STATE state = fieldElementsMap[fieldElement];
          if (state == INIT_STATE.NOT_INIT) {
            fieldElementsMap[fieldElement] = INIT_STATE.INIT_IN_INITIALIZERS;
          }
        }
      }
    }

    // (B.3.4.a) Prepare a list of non-final and non-const non-null fields.
    List<FieldElement> nonNullFieldsImplicitlyNullInit = <FieldElement>[];
    fieldElementsMap.forEach((FieldElement fieldElement, INIT_STATE state) {
      if (state == INIT_STATE.NOT_INIT
      && !fieldElement.isFinal
      && !fieldElement.isConst
      && !fieldElement.type.isAssignableTo(_typeProvider.nullType)
      ) {
        nonNullFieldsImplicitlyNullInit.add(fieldElement);
      }
    });
    nonNullFieldsImplicitlyNullInit.forEach((FieldElement fieldElement) {
      AnalysisErrorWithProperties analysisError = _errorReporter.newErrorWithProperties(
          StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED,
          constructor.returnType, [fieldElement.name]);
      analysisError.setProperty(
          ErrorProperty.NOT_INITIALIZED_FIELDS, nonNullFieldsImplicitlyNullInit);
      _errorReporter.reportError(analysisError);
    });
    return nonNullFieldsImplicitlyNullInit.length > 0;
  }

  /// (B.3.4) cases (a.2) when the class has no constructor, and (b.2).
  /// In the case of (a.2), this method should only be called if [list] appears in a non-abstract class.
  bool _checkForNonNullVarNotInitialized0(VariableDeclarationList list) {
    if (!_enableNonNullTypes || _isInNativeClass || list.isSynthetic) return false;

    bool foundError = false;
    for (VariableDeclaration variable in list.variables) {
      if (list.type == null || variable.initializer != null) continue;
      DartType type = list.type.type;
      if (type.isAssignableTo(_typeProvider.nullType)) continue;

      // B.3.4.*.1: all const/final var must be explicitly init, so ...
      if (list.isConst || list.isFinal) continue; // errors will be reported elsewhere.

      foundError = true;
      _errorReporter.reportErrorForNode(
          StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED, variable.name,
          [variable.name.name]);
    }
    return foundError;
  }

}

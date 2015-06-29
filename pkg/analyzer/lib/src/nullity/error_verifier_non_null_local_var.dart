/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// Place holder for B.3.4.c - a read-before-write error verifier.

part of engine.resolver;

/// B.3.4.c - a read-before-write error verifier for non-null local variables.
class NonNullLocalVariableRbwVerifier extends RecursiveAstVisitor<dynamic> {

  final ErrorReporter _errorReporter;
  final TypeProvider _typeProvider;
  final NonNullLocalVariableScopeManager<bool> _variableMgr;

  NonNullLocalVariableRbwVerifier(this._typeProvider, this._errorReporter) :
  _variableMgr = new NonNullLocalVariableScopeManager<bool>();

  void safelyVisit(AstNode node) {
    if (node != null) node.accept(this);
  }

}

class NonNullLocalVariableScopeManager<T> {
}

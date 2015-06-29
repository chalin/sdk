/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null

part of engine.ast;

abstract class AstNodeWithMetadata extends AstNode {
  NodeList<Annotation> get metadata;
}

final String NON_NULL_TYPE_OP_NAME = '!';
final String NULLABLE_TYPE_OP_NAME = '?';

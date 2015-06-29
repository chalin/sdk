/// Definitions added in support of the Non-null DEP30
/// https://github.com/chalin/DEP-non-null
///
/// [NullityElement] related definitions.

part of engine.element;

/// A (consolidating) model element representing nullity annotations
/// either explicitly applied to an AST node or inherited from
/// a parent node.
class NullityElement {
  static const String NULLABLE_BY_DEFAULT_ANNO_NAME = "nullable_by_default";
  static const String AT_NULLABLE_BY_DEFAULT_ANNO_NAME =
      "@" + NULLABLE_BY_DEFAULT_ANNO_NAME;
  static const String NULLABLE_ANNO_NAME = "nullable";
  static const String AT_NULLABLE_ANNO_NAME = "@" + NULLABLE_ANNO_NAME;
  static const String NULLABLE_TYPE_OP_NAME = "?";
  static const String NON_NULL_ANNO_NAME = "non_null";
  static const String AT_NON_NULL_ANNO_NAME = "@" + NON_NULL_ANNO_NAME;
  static const String NON_NULL_TYPE_OP_NAME = "!";

  static final String pattern = r"/\*\s*(@nullable|@non_null|\?|!)\s*\*/";
  static final RegExp nullityAnnoRegExp = new RegExp(pattern);

  int get nullableByDefaultAnnoCount => _nullableByDefaultAnnoCount;
  int get nullableAnnoCount => _nullableAnnoCount;
  int get nonNullAnnoCount => _nonNullAnnoCount;

  void set nullableByDefaultAnnoCount(int c) {
    _nullableByDefaultAnnoCount = c;
  }

  // Counts for the various nullity annotations.
  int _nullableByDefaultAnnoCount = 0;
  int _nullableAnnoCount = 0;
  int _nonNullAnnoCount = 0;

  NullityElement();

  NullityElement.from(NullityElement init, [String comment]) {
    this._nullableByDefaultAnnoCount = init._nullableByDefaultAnnoCount;
    this._nullableAnnoCount = init.nullableAnnoCount;
    this._nonNullAnnoCount = init.nonNullAnnoCount;
    addAnnoFromComments(comment);
  }

  void addAnnoFromComments(@nullable String comment) {
    if (comment == null) return;

    Match match = nullityAnnoRegExp.firstMatch(comment);
    if (match == null) return;
    var s = match[1];
    switch (s) {
      case AT_NULLABLE_ANNO_NAME:
      case NULLABLE_TYPE_OP_NAME:
        _nullableAnnoCount++;
        break;
      case AT_NON_NULL_ANNO_NAME:
      case NON_NULL_TYPE_OP_NAME:
        _nonNullAnnoCount++;
        break;
      default:
      // TODO: log call with args.
    }
  }

  String toString() {
    StringBuffer result = new StringBuffer();
    if (_nullableByDefaultAnnoCount > 0) result
        .write("$AT_NULLABLE_BY_DEFAULT_ANNO_NAME ");
    if (nullableAnnoCount > 0) result.write("$AT_NULLABLE_ANNO_NAME ");
    if (nonNullAnnoCount > 0) result.write("$AT_NON_NULL_ANNO_NAME ");
    return result.toString();
  }

  bool get defaultIsNullable => _nullableByDefaultAnnoCount > 0;

  /// True if a declaration with this nullity would be considered nullable.
  bool get isNullable =>
      defaultIsNullable ? nonNullAnnoCount <= 0 : nullableAnnoCount > 0;

  /// True if a declaration with this nullity would be considered nullable.
  bool get isNonNull =>
      defaultIsNullable ? nonNullAnnoCount > 0 : nullableAnnoCount <= 0;

  /// Set this nullity from [node.metadata] and [node] comments.
  void setFromNode(AstNodeWithMetadata node) {
    setFromMetadata(node.metadata);
    addAnnoFromComments(getComment(node));
  }

  void setFromMetadata(NodeList<Annotation> metadata) {
    metadata.forEach((a) {
      ElementAnnotation e = a.elementAnnotation;
      if (e is NullityElementAnnotationImpl &&
          e.isValid) _setNullityFromName(e.element.name);
    });
  }

  void _setNullityFromName(String annotationName) {
    switch (annotationName) {
      case NULLABLE_BY_DEFAULT_ANNO_NAME:
        _nullableByDefaultAnnoCount++;
        break;
      case NULLABLE_ANNO_NAME:
        _nullableAnnoCount++;
        break;
      case NON_NULL_ANNO_NAME:
        _nonNullAnnoCount++;
        break;
      default:
    }
  }
}

/// Returns the lexeme of the comment associated with the first token of [node].
@nullable String getComment(AstNode node) {
  var c = node.beginToken.precedingComments;
  return c == null ? null : c.lexeme;
}

/// An nullity annotation.
class NullityElementAnnotationImpl extends ElementAnnotationImpl {
  NullityElementAnnotationImpl(Element element) : super(element);

  bool get isValid {
    if (element != null) {
      LibraryElement library = element.library;
      if (library != null && (!annoMustBeFromDartCore || library.isDartCore)) {
        if (element is PropertyAccessorElement
            /* TODO: && element.name == ...*/) {
          return true;
        }
      }
    }
    return false;
  }
}

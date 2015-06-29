// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library engine.static_type_warning_code_test;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:unittest/unittest.dart';

import '../reflective_tests.dart';
import 'resolver_test.dart';
import 'test_support.dart';

void main() {
  groupSep = ' | ';

  print("NNBD is ${isDEP30 ? 'enabled' : 'disabled'}");
  runReflectiveTests(NullityUnitTest);
  runReflectiveTests(NullityBasicAnnotationTestGroup);
  runReflectiveTests(NullLiteralTestGroup);
  runReflectiveTests(MainTestGroup);
  runReflectiveTests(UnionTypeMemberTestGroup);
  runReflectiveTests(MemberLookupTestGroup);
  runReflectiveTests(TypedefTestGroup);
  runReflectiveTests(NullableByDefaultAndOtherAnnoTestGroup);
  runReflectiveTests(GenericsTestGroup);
  runReflectiveTests(TypeTestAndCastTestGroup);
  runReflectiveTests(NotNullConditionalTypeOverride_LocalVar_and_MethodCallTestGroup);
  runReflectiveTests(TypeOverrideForFunctionTypesTestGroup);
  runReflectiveTests(InitLocalVar_TypePropatation_FlowAnalysis_TestGroup);
  runReflectiveTests(MiscTestGroup);
  runReflectiveTests(MiscStaticTypeTestGroup);
  runReflectiveTests(LibTestGroup);
  runReflectiveTests(OptionalParamTestGroup);
  runReflectiveTests(InitLocalVarTestGroup);
  runReflectiveTests(InitFieldTestGroup);
  runReflectiveTests(InitLibraryVarTestGroup);
  runReflectiveTests(MiscOver$NullTests);
}


class NullityTestSupertype extends ResolverTestCase {
  final String nonNullAnno = '';
  final String nullableAnno = '@nullable';

  @override
  setUp() {
    super.setUp();
    analysisContext.analysisOptions.enableNonNullTypes = isDEP30;
    // analysisContext.analysisOptions.enableStrictCallChecks = isNNBD;
  }

  List<ErrorCode> dup(List<ErrorCode> list, int count) {
    List<ErrorCode> result = [];
    for(var e in list) result.addAll(new List.filled(count, e));
    return result;
  }
  
  /// Expect errors only if ([cond] || errors.length > 0).
  void resolve(Source source) {
    computeLibrarySourceErrors(source);
  }
  
  void resolveAndAssert(Source source, [List<ErrorCode> errors = ErrorCode.EMPTY_LIST, bool cond]) {
    cond = cond == null ? errors != null && errors.length > 0 : cond;
    computeLibrarySourceErrors(source);
    assertErrors(source, cond ? errors : ErrorCode.EMPTY_LIST);
  }
  
  /// Expect errors only if [isDEP30] && ([cond] || errors.length > 0).
  void resolveAndAssertErrDEP30(Source source, List<ErrorCode> errors, [bool cond]) {
    cond = cond == null ? errors.length > 0 : cond;
    resolveAndAssert(source, errors, isDEP30 && cond);
  }

  /// Expect errors only if ([cond] || errors.length > 0).
  void resolveAndVerify(Source source, [List<ErrorCode> errors, bool cond]) {
    resolveAndAssert(source, errors, cond);
    verify([source]);
  }

  /// Expect errors only if [isDEP30] && ([cond] || errors.length > 0).
  void resolveAndVerifyErrDEP30(Source source, List<ErrorCode> errors, [bool cond]) {
    cond = cond == null ? true : cond;
    resolveAndVerify(source, errors, isDEP30 && cond);
  }

}

class NullityStaticTypeAnalyzerSupertype extends NullityTestSupertype {
  
  String testCode;
  Source testSource;
  CompilationUnit testUnit;
  LibraryElement library;
  
  void _resolveTestUnit(String code, [List<ErrorCode> errors, bool cond]) {
    testCode = code;
    testSource = addSource(testCode);
    resolveAndVerify(testSource, errors, cond);
    library = resolve2(testSource);
    testUnit = resolveCompilationUnit(testSource, library);
  }

  AstNode _findNode(String pattern, [bool pred(AstNode node)]) {
    if (pred == null) pred = (_) => true;
    AstNode node = EngineTestCase.findNode(testUnit, testCode, pattern, pred);
    return node;
  }

  void expectTypeOfExpr(DartType expected, Type type, String typeName) {
    if (!isDEP30) typeName = typeName.replaceAll(new RegExp(r'[\?!]'), '');
    if (typeName != null) expect(expected.displayName, typeName);
    expect(expected.runtimeType, type);
  }

  void expectTypeOfExpr0(Expression expr, Type type, String typeName) =>
      expectTypeOfExpr(expr.staticType, type, typeName);

  Expression expectType(String pattern, Type type, String typeName, [bool pred(AstNode node)]) {
    Expression expr = _findNode(pattern, pred);
    expectTypeOfExpr0(expr, type, typeName);
    return expr;
  }
  
  Type NonNullOf(Type type) => isDEP30 ? NonNullTypeImpl : type;
  Type UnionWithNullOf(Type type) => isDEP30 ? UnionWithNullTypeImpl : type;

}

@reflectiveTest
class NullityUnitTest extends NullityTestSupertype {

  TypeProvider _typeProvider;
  
  void setUp() { super.setUp(); _typeProvider = analysisContext2.typeProvider; }
  
  void test_isNNBD_match_flag() {
    expect(analysisContext2.analysisOptions.enableNonNullTypes, isDEP30);
  }

  void test_isNullType() {
    if (!isDEP30) return;
    expect(_typeProvider.nullType.isNull, isTrue);
    expect(_typeProvider.objectType.isNull, isFalse);
    expect(_typeProvider.dynamicType.isNull, isFalse);
    expect(isNullType(_typeProvider.nullType), isTrue);
    expect(isNullType(_typeProvider.objectType), isFalse);
    expect(isNullType(_typeProvider.intType), isFalse);
    expect(isNullType(_typeProvider.dynamicType), isFalse);
  }

  void skip_test_nullity() {
    if (!isDEP30) return;
//    var n = analysisContext2.typeProvider.nullType;
//    var i = analysisContext2.typeProvider.intType;
//    expect(new UnionWithNullTypeImpl(n,i), isNotNull);
//    expect(() => new UnionWithNullTypeImpl(n,n), throws);
//    expect(() => new UnionWithNullTypeImpl(null,n), throws);
//    expect(() => new UnionWithNullTypeImpl(n,null), throws);
//    expect(() => new UnionWithNullTypeImpl(n,null), throws);
//    expect(() => new UnionWithNullTypeImpl(n,_typeProvider.dynamicType), throws);
  }

}

@reflectiveTest
class NullityBasicAnnotationTestGroup extends NullityTestSupertype {

  void test_nullable_anno() {
    Source source = addSource('@nullable int i = null;');
    resolveAndVerify(source);
  }

  void test_non_null_anno() {
    Source source = addSource('@non_null int i = 1;');
    resolveAndVerify(source);
  }
  
  void test_nullable_anno_as_comments() {
    Source source = addSource('''
      final /*@nullable*/int i1 = null; // case: no space between anno and type
      final /* @nullable */ String s1 = null; // case: space between anno and type
      final /*?*/int i2 = null; // case: alt token
      final /* ? */ String s2 = null; // case: alt token with space

      final /*@non_null*/int i3 = 1;
      final /* @non_null */ String s3 = '';
      final /*!*/int i4 = 1;
      final /* ! */ String s4 = '';
    ''');
    resolveAndVerify(source);
  }

  void test_lib_var_declared_non_null() {
    Source source = addSource('''
      library a;
      /*!*/int i = null;
    ''');
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT]);
  }
  
  void test_nullable_anno_as_comments_not_first() {
    Source source = addSource('''
      /*@nullable*/int i1 = null; // comment anno processed
      /*@nullable*/ String s1 = null; // comment NOT processed
    ''');
    // The problem here is that the comment associated with [String]
    // is "// comment anno processed". The "/*@nullable*/" immediately
    // preceding it is lost to the token stream.
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT]);
  }

  void test_nullable_anno_func_literal_param_ok() {
    Source source = addSource('''
      var x = ((/*@nullable*/int i) => i)(null);
    ''');
    resolveAndVerify(source);
  }

}


@reflectiveTest
class NullableByDefaultAndOtherAnnoTestGroup extends NullityStaticTypeAnalyzerSupertype {

  void test_anno() {
    addNamedSource("/x.dart", "@nullable part of a; int nui;");
    Source source = addSource('''
      @nullable_by_default 
      library a;
      @nullable_by_default 
      part 'x.dart';
      int i = nui;
      ''');
    resolveAndVerify(source);
  }
  
  void test_lib_var_nubd_via_lib_anno() {
    addNamedSource("/x.dart", "part of a; int nui;");
    String code = '''
      @nullable_by_default 
      library a;
      part 'x.dart';
      int i = nui; //lib
      ''';
    _resolveTestUnit(code);
    expectType('i =', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('nui; //lib', UnionWithNullOf(InterfaceTypeImpl), '?int');

    CompilationUnitElement a = library.parts[0];
    TopLevelVariableElement nui = a.topLevelVariables[0];
    expectTypeOfExpr(nui.type, UnionWithNullOf(InterfaceTypeImpl), '?int');
  }
  
  void test_lib_var_nubd_via_part_of_anno() {
    addNamedSource("/x.dart", "@nullable_by_default part of a; int nui;");
    String code = '''
      library a;
      part 'x.dart';
      int i = nui; //lib
      ''';
    _resolveTestUnit(code);
    expectType('i =', InterfaceTypeImpl, 'int');
    expectType('nui; //lib', UnionWithNullOf(InterfaceTypeImpl), '?int');

    CompilationUnitElement a = library.parts[0];
    TopLevelVariableElement nui = a.topLevelVariables[0];
    expectTypeOfExpr(nui.type, UnionWithNullOf(InterfaceTypeImpl), '?int');
  }
  
  void test_lib_var_nubd_via_part_anno() {
    addNamedSource("/x.dart", "part of a; int nui;");
    String code = '''
      library a;
      @nullable_by_default 
      part 'x.dart';
      int i = nui; //lib
      ''';
    _resolveTestUnit(code);
    expectType('i =', InterfaceTypeImpl, 'int');
    expectType('nui; //lib', UnionWithNullOf(InterfaceTypeImpl), '?int');

    CompilationUnitElement a = library.parts[0];
    TopLevelVariableElement nui = a.topLevelVariables[0];
    expectTypeOfExpr(nui.type, UnionWithNullOf(InterfaceTypeImpl), '?int');
  }
  
  void test_lib_var_nnbd() {
    addNamedSource("/x.dart", "part of a; int nui;");
    String code = '''
      library a;
      part 'x.dart';
      int i = nui; //lib
      ''';
    _resolveTestUnit(code);
    expectType('i =', InterfaceTypeImpl, 'int');
    expectType('nui; //lib', InterfaceTypeImpl, 'int');

    CompilationUnitElement a = library.parts[0];
    TopLevelVariableElement nui = a.topLevelVariables[0];
    expectTypeOfExpr(nui.type, InterfaceTypeImpl, 'int');
  }

  void test_lib_var_nubd_w_no_anno() {
    Source source = addSource('''
      @nullable_by_default library a;
      int i = null;
      ''');
    resolveAndVerify(source);
  }

  void test_lib_var_nubd_w_declared_non_null() {
    Source source = addSource('''
      @nullable_by_default library a;
      /*!*/int i = null;
      ''');
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndVerifyErrDEP30(source, err);
  }

  void _test_dynamic_and_Null_lib_var(String libraryDirective) {
    String code = '''
      $libraryDirective
      var d0;
      dynamic d1;
      /*!*/dynamic d2;
      /*?*/dynamic d3;
      md([var pd0, dynamic pd1, /*!*/dynamic pd2, /*?*/dynamic pd3]) {
        pd0; pd1; pd2; pd3;
      }

      Null n1;
      /*!*/Null n2;
      /*?*/Null n3;
      mn([Null pn1, /*!*/Null pn2, /*?*/Null pn3]) { pn1; pn2; pn3; }
    ''';
    _resolveTestUnit(code);
    List vars = ['d0;', 'd1;', 'd2;', 'd3;', 
      'pd0,', 'pd1,', 'pd2,', 'pd3]',
      'pd0;', 'pd1;', 'pd2;', 'pd3;'];
    vars.forEach((id) {
      expectType(id, DynamicTypeImpl, 'dynamic');
    });
    // TODO: report error for !Null and ?Null.
    vars = ['n1;', 'n2;', 'n3;', 
      'pn1,', 'pn2,', 'pn3]',
      'pn1;', 'pn2;', 'pn3;'];
    vars.forEach((id) {
      expectType(id, InterfaceTypeImpl, 'Null');
    });
  }
  
  void test_dynamic_lib_var_nnbd() => _test_dynamic_and_Null_lib_var('');
  void test_dynamic_lib_var_nubd() => _test_dynamic_and_Null_lib_var('@nullable_by_default library a;');
  
  void test_nubd_lib_var_anno() {
    String code = '''
      @nullable_by_default library a;
      class C<T> {}
      int i = 0;       C<int> ci = new C<int>();
      /*!*/int j = 0;  /*!*/C<int> cj = new C<int>();
      /*?*/int k = 0;  /*?*/C<int> ck = null;
      m1([int pi, /*!*/int pj, /*?*/int pk]) { pi; pj; pk; }
      m2([int pif(int i), int /*!*/pjf(int i), int /*?*/pkf(int i)]) { pif; pjf; pkf; }
      m3([C<int> pci, /*!*/C<int> pcj, /*?*/C<int> pck]) { pci; pcj; pck; }
    ''';
    _resolveTestUnit(code);

    expectType('i =', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('j =', InterfaceTypeImpl, 'int');
    expectType('k =', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('ci =', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    expectType('cj =', InterfaceTypeImpl, 'C<?int>');
    expectType('ck =', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    
    expectType('pi,', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('pj,', InterfaceTypeImpl, 'int');
    expectType('pk]', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('pi;', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('pj;', InterfaceTypeImpl, 'int');
    expectType('pk;', UnionWithNullOf(InterfaceTypeImpl), '?int');

    // FunctionType's have same nullities as InterfaceTypes
    var nInt2nInt = '(?int) → ?int';
    var nullableFunc = '?$nInt2nInt';
    
    expectType('pif(', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    expectType('pjf(', FunctionTypeImpl, nInt2nInt);
    expectType('pkf(', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    
    expectType('pif;', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    expectType('pjf;', FunctionTypeImpl, nInt2nInt);
    expectType('pkf;', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    
    expectType('pif(', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    expectType('pjf(', FunctionTypeImpl, nInt2nInt);
    expectType('pkf(', UnionWithNullOf(FunctionTypeImpl), nullableFunc);
    
    // C
    expectType('pci,', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    expectType('pcj,', InterfaceTypeImpl, 'C<?int>');
    expectType('pck]', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');

    expectType('pci;', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    expectType('pcj;', InterfaceTypeImpl, 'C<?int>');
    expectType('pck;', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
  }
  
  void test_nnbd_lib_var_anno_and_optional_method_param() {
    String code = '''
      class C<T> {}
      int i = 0;       C<int> ci = new C<int>();
      /*!*/int j = 0;  /*!*/C<int> cj = new C<int>();
      /*?*/int k = 0;  /*?*/C<int> ck = null;
      m1([int pi, /*!*/int pj, /*?*/int pk]) { pi; pj; pk; }
      m2([int pif(int i), int /*!*/pjf(int i), int /*?*/pkf(int i)]) { pif; pjf; pkf; }
      m3([C<int> pci, /*!*/C<int> pcj, /*?*/C<int> pck]) { pci; pcj; pck; }
    ''';
    _resolveTestUnit(code);
    expectType('i =', InterfaceTypeImpl, 'int');
    expectType('j =', InterfaceTypeImpl, 'int');
    expectType('k =', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('ci =', InterfaceTypeImpl, 'C<int>');
    expectType('cj =', InterfaceTypeImpl, 'C<int>');
    expectType('ck =', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');

    expectType('pi,', InterfaceTypeImpl, 'int');
    expectType('pj,', InterfaceTypeImpl, 'int');
    expectType('pk]', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('pi;', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('pj;', InterfaceTypeImpl, 'int');
    expectType('pk;', UnionWithNullOf(InterfaceTypeImpl), '?int');

    // FunctionType's have same nullities as InterfaceTypes
    expectType('pif(', FunctionTypeImpl, '(int) → int');
    expectType('pjf(', FunctionTypeImpl, '(int) → int');
    expectType('pkf(', UnionWithNullOf(FunctionTypeImpl), '?(int) → int');
    
    expectType('pif;', UnionWithNullOf(FunctionTypeImpl), '?(int) → int');
    expectType('pjf;', FunctionTypeImpl, '(int) → int');
    expectType('pkf;', UnionWithNullOf(FunctionTypeImpl), '?(int) → int');
    
    // C
    expectType('pci,', InterfaceTypeImpl, 'C<int>');
    expectType('pcj,', InterfaceTypeImpl, 'C<int>');
    expectType('pck]', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');

    expectType('pci;', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');
    expectType('pcj;', InterfaceTypeImpl, 'C<int>');
    expectType('pck;', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');
  }

  void _test_type_param(String libraryDirective) {
    String code = '''
      $libraryDirective
      class C<T> {
        T o; // warn: null init
        final /*!*/T o2;
        /*?*/T o3;
        C(/*!*/T this.o2);
        m([T po, /*!*/T po2, /*?*/T po3]) { po; po2; po3; }
      }
    ''';
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    _resolveTestUnit(code, err, isDEP30);
    expectType('o;', TypeParameterTypeImpl, 'T');
    expectType('o2;', NonNullOf(TypeParameterTypeImpl), '!T');
    expectType('o3;', UnionWithNullOf(TypeParameterTypeImpl), '?T');

    expectType('po,', TypeParameterTypeImpl, 'T');
    expectType('po2,', NonNullOf(TypeParameterTypeImpl), '!T');
    expectType('po3]', UnionWithNullOf(TypeParameterTypeImpl), '?T');

    expectType('po;',  UnionWithNullOf(TypeParameterTypeImpl), '?T');
    expectType('po2;', NonNullOf(TypeParameterTypeImpl), '!T');
    expectType('po3;', UnionWithNullOf(TypeParameterTypeImpl), '?T');
  }
  
  void test_type_param_nnbd() => _test_type_param('');
  void test_type_param_nubd() => _test_type_param('@nullable_by_default library a;');

  void _test_instantiated_type(String libraryDirective) {
    String code = '''
      $libraryDirective
      class C<T> {
        T o; // warn: null init
        @non_null T o2; // warn: null init
        @nullable T o3;
        C();
        m([T po, /*!*/T po2, /*?*/T po3]) { po; po2; po3; }
      }
      m() { 
        new C<int>().o; /*1*/
        new C<int>().o2; /*1*/
        new C<int>().o3; /*1*/

        new C</*?*/int>().o; /*2*/
        new C</*?*/int>().o2; /*2*/
        new C</*?*/int>().o3; /*2*/

        new C</*!*/int>().o; /*3*/
        new C</*!*/int>().o2; /*3*/
        new C</*!*/int>().o3; /*3*/

        new C<Null>().o; /*4*/
        new C<Null>().o2; /*4 - o2 has a malformed type (B.3.2) */
        new C<Null>().o3; /*4*/
      }
    ''';
    var err = dup([StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED],2);
    _resolveTestUnit(code, err, isDEP30);
    bool nubd = !libraryDirective.isEmpty;
    expectType('o; /*1', 
        nubd ? UnionWithNullOf(InterfaceTypeImpl) : InterfaceTypeImpl, 
        nubd ? '?int' : 'int');
    expectType('o2; /*1', InterfaceTypeImpl, 'int');
    expectType('o3; /*1', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('o; /*2', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('o2; /*2', InterfaceTypeImpl, 'int');
    expectType('o3; /*2', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('o; /*3', InterfaceTypeImpl, 'int');
    expectType('o2; /*3', InterfaceTypeImpl, 'int');
    expectType('o3; /*3', UnionWithNullOf(InterfaceTypeImpl), '?int');
    
    expectType('o; /*4', InterfaceTypeImpl, 'Null');
    expectType('o2; /*4', isDEP30 ? DynamicTypeImpl : InterfaceTypeImpl, 
                          isDEP30 ? 'dynamic' : 'Null');
    expectType('o3; /*4', InterfaceTypeImpl, 'Null');
  }
  
  void test_instantiated_type_nnbd() => _test_instantiated_type('');
  void test_instantiated_type_nubd() => _test_instantiated_type('@nullable_by_default library a;');

  void test_scope_of_nullable_by_default() {
    String code = '''
      @nullable_by_default library a;
      class C<T> { }
      m() {
        new C<int>();    // C is !C
        try {} 
          on C</*!*/int> // catch target: C is !C
          catch (e) {}
        C d;
        (d as C<int>); /*as*/
        (d is C<int>); /*is*/       // C is !C
        (d as /*!*/C<int>); /*as2*/
        (d is /*?*/C</*!*/int>); /*is2*/
        (d as /*?*/C</*?*/int>); /*as3*/
      }
    ''';
    _resolveTestUnit(code);
    expectType('C<T', InterfaceTypeImpl, 'Type');
    expectType('C<int>()', InterfaceTypeImpl, 'C<?int>');
    expectType('C</*!*/int> // catch', InterfaceTypeImpl, 'C<int>');
    expectType('C d', UnionWithNullOf(InterfaceTypeImpl), '?C');

    expectType('C<int>); /*as*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    expectType('C<int>); /*is*/', InterfaceTypeImpl, 'C<?int>');
    expectType('C<int>); /*as2*/', InterfaceTypeImpl, 'C<?int>');
    expectType('C</*!*/int>); /*is2*/', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');
    expectType('C</*?*/int>); /*as3*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');

    expectType('(d as C<int>); /*as*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
    expectType('(d is C<int>); /*is*/', InterfaceTypeImpl, 'bool');
    expectType('(d as /*!*/C<int>); /*as2*/', InterfaceTypeImpl, 'C<?int>');
    expectType('(d is /*?*/C</*!*/int>); /*is2*/', InterfaceTypeImpl, 'bool');
    expectType('(d as /*?*/C</*?*/int>); /*as3*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
  }

  void test_anno_on_class() {
    String code = '''
      class C0 { int i0 = 1; }
      @nullable_by_default class C1 { int i1 = 1; }
      class C2 { int i2 = 1; }
    ''';
    _resolveTestUnit(code);
    expectType('i0', InterfaceTypeImpl, 'int');
    expectType('i1', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('i2', InterfaceTypeImpl, 'int');
  }

  // The disabled test below fails, but only because it fails in DartC too. Bug/feature?
  // Investigate later.
  // typedef int F(String s);
  // var f = ((int i) => i);
  // var x = ((int i) => i)("");
  // F f2 = ((int i) => i); // A value of type '(int) → int' cannot be assigned to a variable of type 'F'
  // var x2 = f2(3); // The argument type 'int' cannot be assigned to the parameter type 'String'
  void later_test_func_literal_nullable_anno_tmp2() {
    String code = '''
      var x = ((int i) => i)("");
    ''';
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    _resolveTestUnit(code);
    expectType('((int i) => i)', FunctionTypeImpl, '(int) → int');
  }

  // TODO: explore later. Also try with `Function` instead of `F`.
  void later_test_func_type_and_bang() {
    String code = '''
      class F {}
      class C<T extends /*?*/F> {
        /*!*/T tf;
        C(this.tf);
        set (F f) { tf = f; }
      }
    ''';
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    _resolveTestUnit(code, err);
    expectType('tf;', NonNullOf(TypeParameterTypeImpl), '!T');
    // expectType('i0', InterfaceTypeImpl, 'int');
    // expectType('i1', UnionWithNullOf(InterfaceTypeImpl), '?int');
    // expectType('i2', InterfaceTypeImpl, 'int');
  }

}


@reflectiveTest
class NullLiteralTestGroup extends NullityTestSupertype {

  void test_methods_on_null() {
    //if (!isNNBD) return; // because null.toString() doesn't resolve for some reason
    // probably because the 
    Source source = addSource('''main() {
      1.toString();
      "".toString();
      null.toString();
      null.hashCode;
      }''');
    resolveAndAssert(source);
    if (isDEP30) verify([source]);
    // if !isNNBD, then don't verify since, e.g., hashCode will not have been resolved
    // because `null` will have been \bot, and hence no resolution happens on method
    // call or field access.
  }

  void test_cannot_call_1() {
    Source source = addSource('void main() { 1(); }');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION_EXPRESSION];
    resolveAndVerify(source, err);
  }

  void test_cannot_call_null() {
    // addNamedSource("/nullity.dart", nullity_dart_src);
    Source source = addSource('void main() { null(); }');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION_EXPRESSION];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_null_callUndefinedMethod() {
    Source source = addSource('main() { null.m(); }');
    var err = [StaticTypeWarningCode.UNDEFINED_METHOD];
    resolveAndAssertErrDEP30(source, err);
  }

  void test_null_equality() {
    Source source = addSource('main() { null == null; 1 != null; null != 1; }');
    resolve(source);
    if (isDEP30) verify([source]);
  }

  void test_null_return_for_void_func_ok() {
    Source source = addSource('void m() { return null; }');
    resolveAndVerify(source);
  }

  void test_null_map_literal_key_ok() {
    Source source = addSource('var m = { null:1 };');
    resolveAndVerify(source);
  }

  void test_null_const_map_literal_key_ok() {
    Source source = addSource('var m = const { null:1 };');
    // Without our tmp fix, problem reported is:
    // The constant map entry key expression type 'Null' cannot override the == operator
    // var err = [CompileTimeErrorCode.CONST_MAP_KEY_EXPRESSION_TYPE_IMPLEMENTS_EQUALS];
    resolveAndVerify(source);
  }

}


@reflectiveTest
class MainTestGroup extends NullityTestSupertype {
  
  void test_non_null_init_null_warning_basic() {
    Source source = addSource('int i = null;');
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT]);
  }

  void _test_null_assigned_to_lib_var(String anno) {
    Source source = addSource('''
      class A { const A(); }
      typedef int F(int i);
      $anno Null n = null;
      $anno Object o1 = null; // 1. invalid in NNBD and non_null
      $anno Object o2 = [];
      $anno int i1 = null; // 2. invalid in NNBD and non_null
      $anno int i2 = 1;
      $anno Function f1 = null; // 3. invalid in NNBD and non_null
      $anno Function f2 = (o) => o;
      $anno A a = new A();
      $anno const A c1 = null; // 4. invalid in NNBD and non_null AND compile time mismatach
      $anno const A c2 = const A();
      $anno final String fs1 = null; // 5. invalid in NNBD and non_null
      $anno final String fs2 = 'hello';
      $anno F ff1 = null; // 6. invalid in NNBD and non_null
      $anno F ff2 = (o) => o;
      @nullable int nui = null;
      int i = nui; // ok because ?int <==> int.
      var id0 = null;
      var id1 = [];
      $anno dynamic d0 = null;
      $anno dynamic d1 = [];
      ''');
    // var x = CompileTimeErrorCode.CONST_WITH_UNDEFINED_CONSTRUCTOR_DEFAULT;
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 6)
              ..add(CheckedModeCompileTimeErrorCode.VARIABLE_TYPE_MISMATCH);
    resolveAndVerifyErrDEP30(source, err, anno != nullableAnno);
  }

  void test_assignment_to_lib_var_non_null() =>  _test_null_assigned_to_lib_var(nonNullAnno);
  void test_assignment_to_lib_var_nullable() =>  _test_null_assigned_to_lib_var(nullableAnno);

  void _test_assignment_to_instance_var(String anno) {
    Source source = addSource('''
      class A { const A(); }
      typedef F(o);
      class B {
        Null n = null;
        $anno int i1 = null; // 1. invalid in NNBD and non_null
        $anno int i2 = 1;
        $anno Function f1 = null; // 2. invalid in NNBD and non_null
        $anno Function f2 = (o) => o;
        $anno static A sa1 = null; // 3. invalid in NNBD and non_null
        $anno static A sa2 = const A();
        $anno static A sa3 = new A();
        $anno final String fs1 = null; // 4. invalid in NNBD and non_null
        $anno final String fs2 = 'hello';
        $anno static final String sfs1 = null; // 5. invalid in NNBD and non_null
        $anno static final String sfs2 = 'hello';
        $anno F ff1 = null; // 6. invalid in NNBD and non_null
        $anno F ff2 = (o) => o;
        static /*?*/ int nui = null;
        int i = nui; // ok because ?int <==> int.
        var id0 = null;
        var id1 = [];
        $anno dynamic d0 = null;
        $anno dynamic d1 = [];
      }''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 6);
    resolveAndVerifyErrDEP30(source, err, anno != nullableAnno);
  }

  void test_assignment_to_instance_var_non_null() =>  _test_assignment_to_instance_var(nonNullAnno);
  void test_assignment_to_instance_var_nullable() =>  _test_assignment_to_instance_var(nullableAnno);

  void _test_assignment_to_local_var(String anno) {
    Source source = addSource('''
      class A { const A(); }
      typedef F(o);
      void main() {
        Null n = null;
        $anno Object o1 = null; // 1. invalid in NNBD and non_null
        $anno Object o2 = [];
        $anno int i1 = null; // 2. invalid in NNBD and non_null
        $anno int i2 = 1;
        $anno Function f1 = null; // 3. invalid in NNBD and non_null
        $anno Function f2 = (o) => o;
        $anno A a = new A();
        $anno const A c1 = null; // 4. invalid in NNBD and non_null and compile time mismatach
        $anno const A c2 = const A();
        $anno final String fs1 = null; // 5. invalid in NNBD and non_null
        $anno final String fs2 = 'hello';
        $anno F ff1 = null; // 6. invalid in NNBD and non_null
        $anno F ff2 = (o) => o;
        @nullable int nui = 1;
        int i = nui; // ok because ?int <==> int.
        var id0 = null;
        var id1 = [];
        $anno dynamic d0 = null;
        $anno dynamic d1 = [];
      }''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],6)
        ..add(CheckedModeCompileTimeErrorCode.VARIABLE_TYPE_MISMATCH);
    resolveAndVerifyErrDEP30(source, err, anno != nullableAnno);
  }

  void test_assignment_to_local_var_non_null() =>  _test_assignment_to_local_var(nonNullAnno);
  void test_assignment_to_local_var_nullable() =>  _test_assignment_to_local_var(nullableAnno);

  void _test_func_param(String anno, String calls, [int errCount = 0]) {
    Source source = addSource('''
      class A { const A(); }
      typedef F(o);
      fn(Null o) => o;
      fo($anno Object o) => o;
      fi($anno int o) => o;
      fa($anno A o) => o;
      ff($anno F o) => o;
      fg(int /*$anno*/o(int)) => o;
      fs($anno final String o) => o;
      fv($anno var o) => o;
      fd($anno dynamic o) => o;
      void main() { $calls }
      ''');
    var err = dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE], errCount);
    resolveAndVerifyErrDEP30(source, err, anno != nullableAnno);
  }
  
  var fp_calls_ok = "fn(null); fv(null); fd(null);";
  void test_func_param_non_null_ok() =>  _test_func_param(nonNullAnno,fp_calls_ok);
  void test_func_param_nullable_ok() =>  _test_func_param(nullableAnno,fp_calls_ok);
  
  var fp_calls_err = "fo(null); fi(null); fa(null); ff(null); fg(null); fs(null);";
  void test_func_param_non_null_err() =>  _test_func_param(nonNullAnno, fp_calls_err, 6);
  void test_func_param_nullable_err() =>  _test_func_param(nullableAnno, fp_calls_err, 6);

  void _test_func_param_func_sig_w_valid_call(String anno) {
    Source source = addSource('''
      int ff($anno int f(int)) => 1; // return type is qualified by $anno
      void main() { ff(null); }''');
    resolveAndVerifyErrDEP30(source, [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  void test_func_param_func_sig_non_null_w_valid_call() => _test_func_param_func_sig_w_valid_call(nonNullAnno);
  void test_func_param_func_sig_nullable_w_valid_call() => _test_func_param_func_sig_w_valid_call(nullableAnno);

  void test_func_param_func_sig_err() {
    // TODO: add ff0(... F o)
    Source source = addSource('''
      typedef int F(int i);
      ff1(@nullable Function o) => o(1);
      ff2(int /*@nullable*/o(int i)) => o(1);
      ff3(int /*@nullable*/o(int i)) => o(1);
      ''');
    resolveAndVerifyErrDEP30(source, dup([StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION],3));
  }
  
  void test_func_param_func_sig() {
    Source source = addSource('''
      typedef int F(int i);
      ff1(Function o) => o is F ? o(1) : 1;
      ff2(int /*@nullable*/o(int i)) => o is F ? o(1) : 1;
      ff3(int /*@nullable*/o(int i)) => o != null ? o(1) : 1;
      ''');
    resolveAndVerify(source);
  }
  
  void fixme_not_sure_this_should_work_in_dartc_test_func_param_func_sig() {
    AnalysisOptionsImpl opt = new AnalysisOptionsImpl.from(analysisContext.analysisOptions);
    opt.enableStrictCallChecks = true;
    opt.enableNonNullTypes = true; // must be true since our version contains a code fix
    analysisContext.analysisOptions = opt;
    analysisContext2.analysisOptions = opt;
    Source source = addSource('''
      typedef int F(int i);
      int f() => 1;
      String s = (f as dynamic);
      ff1() => s is F ? s(1) : 1;
      ''');
    resolveAndVerify(source);
  }

  void _test_ctr_param(String anno) {
    Source source = addSource('''
      class A {
        $anno final int i;
        const A($anno int i1, $anno final int i2, this.i);
      }
      var v = const A(null, null, null);''');
    var errors = [CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH,
                  StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE];
    resolveAndVerifyErrDEP30(source, dup(errors, 3), anno != nullableAnno);
  }

  void test_ctr_param_non_null() =>  _test_ctr_param(nonNullAnno);
  void test_ctr_param_nullable() =>  _test_ctr_param(nullableAnno);

  // Tests covering the use of a nullable expression applied to
  // a property, method or operator.
  void _test_getter_or_method_or_op(String anno, String getterOrMethodName, 
                                    String opName, 
                                    [errorOrList = ErrorCode.EMPTY_LIST]) {
    Source source = addSource('''
      $anno String s = '';
      $anno external String f();
      void main() {
        s.$getterOrMethodName;
        f().$getterOrMethodName;
        f() $opName;
      }''');
    resolveAndAssertErrDEP30(source, errorOrList);
  }

  // For a property, method or operator common to all types (including [Null]).
  void test_call_method_and_op_non_null1() =>  _test_getter_or_method_or_op(nonNullAnno, 'toString()', '== s');
  void test_call_method_and_op_nullable1() =>  _test_getter_or_method_or_op(nullableAnno, 'toString()', '!= s');
  void test_call_getter_and_op_non_null1() =>  _test_getter_or_method_or_op(nonNullAnno, 'hashCode', '!= s');
  void test_call_getter_and_op_nullable1() =>  _test_getter_or_method_or_op(nullableAnno, 'hashCode', '== s');

  // For a property, method or operator specific to [String].
  void test_call_method_and_op_non_null2() =>  _test_getter_or_method_or_op(nonNullAnno, 'toLowerCase()', '+ s');
  void test_call_getter_and_op_non_null2() =>  _test_getter_or_method_or_op(nonNullAnno, 'length', '[0]');
  void test_call_method_and_op_nullable2() => 
      _test_getter_or_method_or_op(nullableAnno, 'toLowerCase()', '+ s',
          [HintCode.UNDEFINED_OPERATOR, HintCode.UNDEFINED_METHOD, HintCode.UNDEFINED_METHOD]);
  void test_call_getter_and_op_nullable2() =>  
      _test_getter_or_method_or_op(nullableAnno, 'length', '[0]',
      [StaticTypeWarningCode.UNDEFINED_OPERATOR, HintCode.UNDEFINED_METHOD, HintCode.UNDEFINED_METHOD]);

  void test_parameterAssignable_nullable_field_sanity() {
    Source source = addSource(r'''
      class A { final int i; const A(num this.i); }
      final A x1 = const A(1); // ok
      final A x2 = const A(1.0); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH
    ''');
    var err = [CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH];
    resolveAndVerify(source, err);
  }

  // Both ctr param and final field as nullable
  void test_parameterAssignable_nullable_field1() {
    Source source = addSource(r'''
      class A { @nullable final int i; const A(@nullable num this.i); }
      final A x1 = const A(1); // ok
      final A x2 = const A(1.0); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH
      final A x3 = const A(null);
    ''');
    var err = [CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH];
    resolveAndVerify(source, err);
  }

  // Ctr param as nullable; field as non-null.
  void test_parameterAssignable_nullable_field2() {
    Source source = addSource(r'''
      class A { final int i; const A(@nullable num this.i); }
      final A x1 = const A(1); // ok
      final A x2 = const A(1.0); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH
      final A x3 = const A(null); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH
    ''');
    var err = [CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH];
    if (isDEP30) err.add(CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH);
    resolveAndVerify(source, err);
  }

  // Ctr param as non-null and field as nullable
  void test_parameterAssignable_nullable_field3() {
    Source source = addSource(r'''
      class A { @nullable final int i; const A(num this.i); }
      final A x1 = const A(1); // ok
      final A x2 = const A(1.0); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH
      final A x3 = const A(null); // CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH, ARGUMENT_TYPE_NOT_ASSIGNABLE
    ''');
    var err = [CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH];
    if (isDEP30) err.addAll([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE,
      CheckedModeCompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH]);
    resolveAndVerify(source, err);
  }

  void test_call_of_nullable_non_function_var() {
    Source source = addSource('''
      void main() {
        Null n = null;
        n();
        @nullable int i = null;
        i();
      }''');
    var err = dup([StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION],2);
    resolveAndVerify(source, err);
  }

  void test_call_of_nullable_function_var() {
    Source source = addSource('main() { @nullable Function f = null; f(); }');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION];
    resolveAndVerifyErrDEP30(source, err);
  }

  void _test_method_and_get_set_decl1(String anno) {
    Source source = addSource('''
      class A {
        $anno int m() { return null; }
        $anno int get i { return null; }
        void set i($anno int _i) { }
        main() { i = null; }
      }''');
    var err = dup([StaticTypeWarningCode.RETURN_OF_INVALID_TYPE],2);
    err.add(StaticTypeWarningCode.INVALID_ASSIGNMENT);
    resolveAndVerifyErrDEP30(source, err, anno != nullableAnno);
  }
  
  void test_method_and_get_set_decl_non_null1() =>  _test_method_and_get_set_decl1(nonNullAnno);
  void test_method_and_get_set_decl_nullable1() =>  _test_method_and_get_set_decl1(nullableAnno);

  void _test_method_and_get_decl2(String anno) {
    Source source = addSource('''
      class A {
        $anno int m() => 1;
        $anno int get i { return 1; }
        $anno String s = '';
        A(this.s) {
          Null n = this.s;
        }
        m2() { 
          Null n1 = m();
          Null n2 = i;
          Null n3 = this.s;
        }
      }''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],4);
    resolveAndVerify(source, err, !isDEP30 || anno != nullableAnno);
  }
  
  void test_method_and_get_decl_non_null2() =>  _test_method_and_get_decl2(nonNullAnno);
  void test_method_and_get_decl_nullable2() =>  _test_method_and_get_decl2(nullableAnno);

  void _test_method_and_get_decl3(String anno) {
    Source source = addSource('''
      class A {
        $anno int m() => 1;
        $anno int get i { return 1; }
        $anno String s = '';
        m2() { 
         int i1 = m(); // ok in all modes
         int i2 = i; // ok in all modes
         String s1 = this.s; // ok in all modes
        }
      }''');
    resolveAndVerify(source);
  }
  
  void test_method_and_get_decl_non_null3() =>  _test_method_and_get_decl3(nonNullAnno);
  void test_method_and_get_decl_nullable3() =>  _test_method_and_get_decl3(nullableAnno);

}

@reflectiveTest
class TypedefTestGroup extends NullityTestSupertype {

  void test_return_null_for_nonnull_higher_order_func() {
    // addNamedSource("/nullity.dart", nullity_dart_src);
    Source source = addSource('''
      typedef int F();
      F f() => null; // DEP30: warning.
      main() {
        var foo = f()();
      }
      ''');
    var err = [StaticTypeWarningCode.RETURN_OF_INVALID_TYPE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_return_null_for_nullable_higher_order_func() {
    Source source = addSource('''
      typedef int F();
      @nullable F f() => null; // DEP30: ok.
      main() {
        var foo = f()(); // DEP30: INVOCATION_OF_NON_FUNCTION_EXPRESSION
      }
      ''');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION_EXPRESSION];
    resolveAndVerifyErrDEP30(source, err);
  }

}


@reflectiveTest
class InitLocalVarTestGroup extends NullityTestSupertype {

  void test_implicit_assignment_of_null_to_dynamic_ok() {
    Source source = addSource('main() { var o; dynamic d; }');
    resolveAndVerify(source);
  }

  void test_implicit_assignment_of_null_ok() {
    Source source = addSource('main() { Null n; @nullable int o; }');
    resolveAndVerify(source);
  }

  void test_non_null_local_var_w_implicit_null_init_but_not_read_ok() {
    Source source = addSource('main() { int o; }');
    resolveAndVerify(source);
  }

  void test_T_local_var_w_implicit_null_init_but_not_read_ok() {
    Source source = addSource('''class C<T> { main() {
      @nullable T o;
    } }''');
    resolveAndVerify(source);
  }

  void disabled_lvrbw_test_implicit_assignment_of_null_as_invalid() {
    Source source = addSource('main() { int o; o.toString(); }');
    var err = [StaticWarningCode.NON_NULL_VAR_READ_BEFORE_WRITE];
    resolveAndVerifyErrDEP30(source, err);
  }

}


@reflectiveTest
class InitLocalVar_TypePropatation_FlowAnalysis_TestGroup extends NullityStaticTypeAnalyzerSupertype {

  void test_local_var_single_path_rbw_ok_init_at_decl() {
    Source source = addSource('''main() {
      int i = 1; i;
    }''');
    resolveAndVerify(source);
  }

  void test_local_var_single_path_rbw_ok_init_after_decl() {
    Source source = addSource('''main() {
      int i; i = 1; i;
    }''');
    resolveAndVerify(source);
  }

  void disabled_lvrbw_test_local_var_single_path_rbw_err() {
    Source source = addSource('''main() {
      int i; i;
    }''');
    var err = [StaticWarningCode.NON_NULL_VAR_READ_BEFORE_WRITE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_local_var_single_ift_ok() {
    Source source = addSource('''m(bool b) {
      int i; if(b) { i = 1; } i;
    }''');
    resolveAndVerify(source);
  }

  void disabled_lvrbw_test_local_var_single_ifte_ok() {
    Source source = addSource('''m(bool b) {
      int i; if(b) { i = 1; } else { i = 2; } i;
    }''');
    var err = [StaticWarningCode.NON_NULL_VAR_READ_BEFORE_WRITE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void disabled_lvrbw_test_local_var_single_ifte_err0a() {
    Source source = addSource('''m(bool b) {
      int i; if(b) { i; } else { } i;
    }''');
    var err = [StaticWarningCode.NON_NULL_VAR_READ_BEFORE_WRITE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void disabled_lvrbwtest_local_var_init_some_paths_err() {
    String code = '''m(bool b) {
      int i;
      if (b) { i = 1; } else { }
      i; //
    }''';
    var err = [StaticWarningCode.NON_NULL_VAR_READ_BEFORE_WRITE];
    _resolveTestUnit(code, err);
    expectType('i; //', InterfaceTypeImpl, 'int');
  }

  void test_assignment_to_local_var_with_dartc_flow_analysis() {
    Source source = addSource('''main() {
      @nullable int nui = null;
      int i = nui; // hint because the propagated type of nui is Null.
    }''');
    var err = [HintCode.INVALID_ASSIGNMENT];
    resolveAndVerifyErrDEP30(source, err);
  }

}


/// B.3.4
@reflectiveTest
class InitLibraryVarTestGroup extends NullityTestSupertype {

  void test_final_and_const_nullable_lib_var_w_explicit_init_ok() {
    Source source = addSource('''
        final Null n = null;
        final /*?*/int j = null;
        const /*?*/bool b = null;
      ''');
    resolveAndVerify(source);
  }

  // B.3.4.b.1 for library var
  void test_final_nullable_lib_var_w_implicit_init_err() {
    Source source = addSource('''
        // All final/const must be explicitly init (B.3.4.b.1)
        final Null fn;      // warn final not init
        final int fi;       // warn final not init
        final /*?*/int fj;  // warn final not init
        const Null cn;      // error const missing init
        const bool cnnb;    // error const missing init
        const /*?*/bool cb; // error const missing init
      ''');
    var err = dup([StaticWarningCode.FINAL_NOT_INITIALIZED], 3)
      ..addAll(dup([CompileTimeErrorCode.CONST_NOT_INITIALIZED],3));
    resolveAndVerify(source, err);
  }

  // ??????B.3.4.a.2
  void test_non_null_field_not_init_w_init_ctr_ok() {
    Source source = addSource('''
      var d0;
      dynamic d1;
      Null n;
      /*?*/int i;
    ''');
    resolveAndVerify(source);
  }

  // ?????B.3.4.a.2 with non-init ctr
  void test_non_null_field_not_init_w_non_init_ctr_err_1() {
    Source source = addSource('''
	    bool b;
	    List l;
    ''');
    var err = dup([StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED],2);
    resolveAndVerifyErrDEP30(source, err);
  }

}


/// B.3.4
@reflectiveTest
class InitFieldTestGroup extends NullityTestSupertype {

  // B.3.4.(a|b|c).1
  void test_final_and_const_nullable_fields_w_explicit_init_ok() {
    Source source = addSource('''
      class C {
        static final Null sn = null;
        static final /*?*/int sj = null;
        static const /*?*/bool sb = null;
        final Null n = null;
        final /*?*/int j = null;
        m() {
          Null n = null;
          final /*?*/int j = null;
          const /*?*/bool b = null;
        }
      }
      ''');
    resolveAndVerify(source);
  }

  // B.3.4.(a|b|c).1 and (a|b).2
  void test_final_nullable_fields_w_implicit_init_err() {
    Source source = addSource('''
      class C<T> {
        static final Null sn;     // warn: missing init 1
        static final /*?*/int sj; // warn: missing init 2
        static const /*?*/bool sb;// error const missing init
        static final int sj2;     // warn: missing init 3
        static const bool sb2;    // error const missing init
        final Null n;             // warn: missing init 4
        final /*?*/int j;         // warn: missing init 5
        final int j2;             // warn: missing init 6
        m() {
          final /*?*/int j;       // warn: missing init 7
          const /*?*/bool b;      // error const missing init
        }
      }
      ''');
    var err = dup([StaticWarningCode.FINAL_NOT_INITIALIZED], 7)
      ..addAll(dup([CompileTimeErrorCode.CONST_NOT_INITIALIZED],3));
    resolveAndVerify(source, err);
  }

  // B.3.4.a.2 - no ctr
  void test_non_null_field_not_init_wo_ctr_err() {
    Source source = addSource('class C { bool b; }');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }

  // B.3.4.a.2 - abstract class, no ctr
  void test_non_null_field_abstract_class_not_init_wo_ctr_ok() {
    Source source = addSource('abstract class C { bool b; }');
    resolveAndVerify(source);
  }

  // B.3.4.a.2 - abstract class, ctr
  void test_non_null_field_abstract_class_not_init_ctr_ok() {
    Source source = addSource('abstract class C { C(); bool b; }');
    resolveAndVerify(source);
  }

  // B.3.4.a.2
  void test_non_null_field_not_init_w_init_ctr_ok() {
    Source source = addSource('''
      class C {
        bool b;
        int i = 1;
        C(this.b);
        C.from(this.b);
        C.alt() : b = true;
      }
    ''');
    resolveAndVerify(source);
  }

  // B.3.4.a.2 with non-init ctr
  void test_non_null_field_not_init_w_non_init_ctr_err_1() {
    Source source = addSource('''
      class C {
        bool b;
        C();
      }
    ''');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }

  // B.3.4.a.2 with non-init ctr
  void test_non_null_field_not_init_w_non_init_ctr_err_2() {
    Source source = addSource('''
      class C {
        bool b1, b2; // warn: b1 or b2 not init
        C(this.b2);
        C.alt(this.b1);
      }
    ''');
    var err = dup([StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED],2);
    resolveAndVerifyErrDEP30(source, err);
  }

  // B.3.4.a.2 with non-init ctr
  void test_non_null_field_not_init_w_non_init_ctr_err_3() {
    Source source = addSource('''
      class C {
        bool b;
        C(this.b);
        C.from(this.b);
        C.noInit();
      }
    ''');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_const_final_fields_init_sanity_ok() {
    Source source = addSource('''
      class A {
        final int i;      // ok: ctr field init
        final int j = 1;  // ok
        const A(this.i);
      }
      var v = const A(1);
      ''');
    resolveAndVerify(source);
  }

  void test_static_field_not_init_err() {
    Source source = addSource('''
      class C<T> {
        static int f;
        C();
      }
    ''');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_misc_01_ok() {
    Source source = addSource('''
      class AsciiCodec {
        final bool _allowInvalid;
        const AsciiCodec({bool allowInvalid: false}) : _allowInvalid = allowInvalid;
      }
    ''');
    resolveAndVerify(source);
  }

}

/// Also see tests in [NullableByDefaultAndOtherAnnoTestGroup].
@reflectiveTest
class OptionalParamTestGroup extends NullityStaticTypeAnalyzerSupertype {

  void test_required_param_type_sanity() {
    Source source = addSource('''
      class C {
        String s = '';
        C(this.s) {
          Null n = s; // INVALID_ASSIGNMENT
        }
        m1(int i, int f(int i), d) {
          Null ni = i; // INVALID_ASSIGNMENT
          Null nf = f; // INVALID_ASSIGNMENT
          Null nd = d; // ok
        }
        m2() { m1(null,null,null); } // 2 x ARGUMENT_TYPE_NOT_ASSIGNABLE
        m3() { m1(1,(o) => o,null); }
      }
      ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],3);
    if (isDEP30) err.addAll(dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE],2));
    resolveAndVerify(source,err);
  }

  void test_optional_param_type_caller_view() {
    Source source = addSource('''
      class C {
        m1([int i, int f(int i)]) {}
        m2() { m1(null,null); } // 2 x ARGUMENT_TYPE_NOT_ASSIGNABLE
      }
      ''');
    var err = dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE],2);
    resolveAndVerify(source,err,isDEP30);
  }

  void test_optional_param_type_caller_view_dynamic() {
    Source source = addSource('''
      class C {
        m1([var d1, d2]) {}
        m2() { m1(null,null); }
      }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_nullable_param_type_caller_view() {
    Source source = addSource('''
      class C {
        m1([/*?*/int i, int /*?*/f(int i)]) {}
        m2() { m1(null,null); }
      }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_param_type_nullable_init_ok() {
    Source source = addSource('''
      class C { m([int i, int f(int i), d]) {} }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_param_type_nullable() {
    Source source = addSource('''
      class C {
        m([int i, int f(int i)]) {
          Null ni = i; // ok in NNBD, INVALID_ASSIGNMENT in DartC
          Null nf = f; // ok in NNBD, INVALID_ASSIGNMENT in DartC
        }
      }
      ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],2);
    resolveAndVerify(source, err, !isDEP30);
  }

  void test_optional_nullable_param() {
    Source source = addSource('''
      class C {
        m([/*?*/int i, int /*?*/f(int i)]) {
          Null ni = i; // ok in NNBD, INVALID_ASSIGNMENT in DartC
          Null nf = f; // ok in NNBD, INVALID_ASSIGNMENT in DartC
        }
      }
      ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],2);
    resolveAndVerify(source, err, !isDEP30);
  }

  void test_optional_param_type_nullable_assigned_null() {
    Source source = addSource('''
      class C {
        m([int i, int f(int i), /*?*/int j, int /*?*/g(int i)]) {
          i = null; // ok
          f = null; // ok
          j = null; // ok
          g = null; // ok
        }
      }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_nullable_field_param_ctr() {
    Source source = addSource('''
      class C {
        @nullable String s;
        C([this.s]) { Null n = this.s; }
      }
      ''');
    // One warning in DartC because it doesn't interpret @nullable.
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndVerify(source, err, !isDEP30);
  }

  void test_optional_nullable_field_param_ctr_assigned_null() {
    Source source = addSource('''
      class C {
        @nullable String s;
        C([this.s]) { this.s = null; }
        m() { new C(null); }
      }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_non_null_field_param_ctr1() {
    Source source = addSource('''
      class C {
        String s = '';
        C([/*?*/String this.s]) {
          Null n = this.s; // warn since this.s has static type String.
        }
      }
      ''');
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndVerify(source, err);
  }

  void test_optional_non_null_field_param_ctr2() {
    Source source = addSource('''
      class C {
        String s = '';
        C([/*?*/String this.s]) {}
        m() { new C(null); }
      }
      ''');
    resolveAndVerify(source);
  }

  void test_optional_non_null_field_param_ctr3() {
    Source source = addSource('''
      class C {
        String s = '';
        C([this.s]) {}
        m() { new C(null); }
      }
      ''');
    var err = [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE];
    resolveAndVerify(source, err, isDEP30);
  }

  void test_ctr_field_init_sanity() {
    Source source = addSource('''
      // All ok since ctr arg type <==> instance var type
      class C { String s = ''; C([this.s]) {} }
      class D { int s = 1; D([num this.s]) {} // dynamic type error only
      }
      class D2 { num s = 1; D2([int this.s]) {} }
      class E<T> { final T o; E([T this.o]) {}  }
      class E2<T, U extends T> { final T o; E2([U this.o]) {} }
      ''');
    resolveAndVerify(source);
  }

  void test_ctr_field_init() {
    Source source = addSource('''
      // All ok since ctr arg type <==> instance var type
      class Cu0 {      String s = ''; Cu0([            this.s]) {} }
      class Cu1 { /*?*/String s = ''; Cu1([            this.s]) {} }
      class Cu2 {      String s = ''; Cu2([/*?*/String this.s]) {} }
      class Cu3 { /*?*/String s = ''; Cu3([/*?*/String this.s]) {} }

      class Cn0 {      String s = ''; Cn0([            this.s]) {} }
      class Cn1 { /*!*/String s = ''; Cn1([            this.s]) {} }
      class Cn2 {      String s = ''; Cn2([/*!*/String this.s]) {} }
      class Cn3 { /*!*/String s = ''; Cn3([/*!*/String this.s]) {} }
      ''');
    resolveAndVerify(source);
  }

  /// E.1.1.1
  void test_optional_arg_type_non_null_because_of_default_value() {
    Source source = addSource('''
      class C {
        m([int i = 1, String s = '', int j = null]) { // INVALID_ASSIGNMENT to j
          Null ni = i; // INVALID_ASSIGNMENT
          Null ns = s; // INVALID_ASSIGNMENT
        }
      }
      ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],2);
    if (isDEP30) err.add(StaticTypeWarningCode.INVALID_ASSIGNMENT);
    resolveAndVerify(source, err);
  }

  /// E.1.1.1
  void test_optional_arg_type_non_null_because_of_default_value2() {
    String code = '''
      m([int i = 1, String s = '', int j = null]) { // INVALID_ASSIGNMENT for j
          i; s; j;
      }
      ''';
    var err = [];
    if (isDEP30) err.add(StaticTypeWarningCode.INVALID_ASSIGNMENT);
    _resolveTestUnit(code, err);
    expectType('i;', InterfaceTypeImpl, 'int');
    expectType('s;', InterfaceTypeImpl, 'String');
    // Because of our simplified algorithm, the callee view of j
    // will be 'int'. But this doesn't matter since the default value
    // is not of a valid type.
    expectType('j;', InterfaceTypeImpl, 'int');
  }

  void test_regression_dont_make_opt_param_nullable_if_init() {
    Source source = addSource('''
      String join(Iterable iter,
          [String separator = ' ', int start = 0, int end = -1]) {
        if (start != 0) {
          iter = iter; //.skip(start);
        }
        if (end != -1) {
          iter = iter; //.take(end - start);
        }
        return ''; // iter.join(separator);
      }
      ''');
    resolveAndVerify(source);
  }
  
  void test_regression2_dont_make_opt_param_nullable_if_init() {
    Source source = addSource(r'''
      void notNull(Object value, [String description]) {
        if (value == null) {
          if (description == null) {
            throw /*new Exception*/('Must not be null');
          } else {
            throw /*new Exception*/('Must not be null: $description');
          }
        }
      }
      ''');
    resolveAndVerify(source, []);
  }

  void test_misc_optl_param_with_default_value() {
    String code = '''
        class C {
          List _this = new List();

          int indexOf(/*?*/Object element, [int startIndex = 0]) {
            if (startIndex >= _this.length) {
              return -1;
            }
            if (startIndex < 0) {
              startIndex = 0;
            }
            for (int i = startIndex; i < _this.length; i++) {
              if (_this[i] == element) {
                return i;
              }
            }
            return -1;
          }
        }
      ''';
    _resolveTestUnit(code);
    expectType('startIndex <', InterfaceTypeImpl, 'int');
  }

}


/// Also see tests in [NullableByDefaultAndOtherAnnoTestGroup].
@reflectiveTest
class GenericsTestGroup extends NullityTestSupertype {
  
  void test_extends_core_type_field_asgn_ok() {
    Source source = addSource('''
      class CEO<T extends Object> { T o = new Object(); }
      class CEI<T extends int> { T o = 1; }
      class CEL<T extends List<int>> { T o = <int>[]; }
      class CEN<T extends Null> { T o = null; }
      class CED<T extends dynamic> { T o; main() { o = []; } }
      class A {}
      class B extends A {}
      class CEB<T extends B> { T o = new A(); }
    ''');
    resolveAndVerify(source);
  }
  
  void test_extends_core_type_field_asgn_err() {
    Source source = addSource('''
      class C<T extends int> { T o = 1.0; }
    ''');
    resolveAndVerify(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT]);
  }
  
  void test_generic_subtype_rel_sanity_check_ok() {
    Source source = addSource('''
      class C<T extends num> { }
      main() { // All ok since for the T in C<T> below:  T <: num (DSS 19.8)
        new C();
        new C<dynamic>();
        new C<num>();
        new C<int>();
      }
    ''');
    resolveAndVerify(source);
  }
  
  void test_generic_subtype_rel_sanity_check_err() {
    Source source = addSource('''
      class C<T extends int> { }
      main() { // All warnings since for the T in C<T> below:  T <!: int (DSS 19.8)
        new C<Null>();
        new C<num>();
        new C<String>();
        new C<Object>();
      }
    ''');
    var err = dup([StaticTypeWarningCode.TYPE_ARGUMENT_NOT_MATCHING_BOUNDS], 4);
    resolveAndVerify(source, err);
  }

  void test_generic_subtype_rel_ok() {
    Source source = addSource('''
      class C<T extends /*?*/num> { }
      main() { // All ok since for the T in C<T> below:  T <: ?num (DSS 19.8)
        new C();
        new C<dynamic>();
        new C<num>();
        new C<int>();
        new C</*?*/int>();
        new C</*?*/num>();
      }
    ''');
    resolveAndVerify(source);
  }
  
  void test_generic_subtype_rel_err1() {
    Source source = addSource('''
      class C<T extends /*?*/num> { }
      main() {// All warnings since for the T in C<T> below:  T <!: ?num (DSS 19.8)
        new C<Null>(); // Warn in DartC, ok in NNBD
      }
    ''');
    var err = [StaticTypeWarningCode.TYPE_ARGUMENT_NOT_MATCHING_BOUNDS];
    resolveAndVerify(source,  err, !isDEP30);
  }
  
  void test_generic_subtype_rel_err2() {
    Source source = addSource('''
      class C<T extends /*?*/num> { }
      main() { // All warnings since for the T in C<T> below:  T <!: ?num (DSS 19.8)
        new C<String>();
        new C<Object>();
        new C</*?*/String>();
        new C</*?*/Object>();
      }
    ''');
    var err = dup([StaticTypeWarningCode.TYPE_ARGUMENT_NOT_MATCHING_BOUNDS], 4);
    resolveAndVerify(source, err);
  }
  
  void test_generic_subtype_rel_err3() {
    Source source = addSource('''
      class C<T extends /*?*/int> { }
      main() { // All warnings since for the T in C<T> below:  T <!: ?int (DSS 19.8)
        new C<num>();
        new C<String>();
        new C<Object>();
        new C</*?*/String>();
        new C</*?*/Object>();
      }
    ''');
    var err = dup([StaticTypeWarningCode.TYPE_ARGUMENT_NOT_MATCHING_BOUNDS], 5);
    resolveAndVerify(source, err);
  }

  void test_generic_assignability_rel_ok1() {
    Source source = addSource('''
      class C<T> { final T o; C([this.o]); }
      f(C<int> o) => o;
      min() {
        f(new C());
        f(new C<dynamic>());
        f(new C<Object>());
        f(new C<int>());
        f(new C</*?*/int>());
        f(new C<num>());
        f(new C</*?*/num>());
      }
    ''');
    resolveAndVerify(source);
  }

  void test_generic_assignability_rel_err() {
    Source source = addSource('''
      class C<T> { final T o; C([this.o]); }
      f(C<int> o) => o;
      min() {
        f(new C<Null>());
        f(new C</*?*/String>());
      }
    ''');
    var err = dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE], 2);
    resolveAndVerify(source, err);
  }

  void _test_nullable_instance_var_of_generic_type_is_nullable(String anno) {
    Source source = addSource('''
      class C0<T> {
        $anno final T o; C0([this.o]);
        m() { Null n = o; }
      }
      class C1<T extends /*?*/Object> {
        $anno final T o; C1([this.o]);
        m() { Null n = o; }
      }
      class C2<T extends Object> {
        $anno T o = new Object();
        m() { Null n = o; }
      }
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],3);
    resolveAndVerify(source, err, !isDEP30 || anno != nullableAnno);
  }
  
  void test_nullable_instance_var_of_generic_type_is_nullable_non_null() =>  _test_nullable_instance_var_of_generic_type_is_nullable(nonNullAnno);
  void test_nullable_instance_var_of_generic_type_is_nullable_nullable() =>  _test_nullable_instance_var_of_generic_type_is_nullable(nullableAnno);

  void _test_toString_of_nullable_type_param(String anno) {
    Source source = addSource('''
      class C0<T> {
        $anno final T o; C0([this.o]);
        m() { String s = o.toString(); }
      }
      class C1<T extends /*?*/Object> {
        $anno final T o; C1([this.o]);
        m() { String s = o.toString(); }
      }
      class C2<T extends Object> {
        $anno T o = new Object();
        m() { String s = o.toString(); }
      }
    ''');
    resolveAndVerify(source);
  }
  
  void test_assignment_to_local_var_non_null() =>  _test_toString_of_nullable_type_param(nonNullAnno);
  void test_assignment_to_local_var_nullable() =>  _test_toString_of_nullable_type_param(nullableAnno);

  /// See explanation in [MiscTestGroup.test_toString_of_nullable_confirm_return_type_from_D].
  void test_toString_of_nullable_confirm_return_type_from_Null_type_param() {
    Source source = addSource('''
      class D { int toString() => 5; } // INVALID_METHOD_OVERRIDE_RETURN_TYPE
      class C<T extends D> {
        @nullable T o;
        main() { String s = o.toString(); }
      }''');
    var err = [StaticWarningCode.INVALID_METHOD_OVERRIDE_RETURN_TYPE];
    if (!isDEP30) err.add(StaticTypeWarningCode.INVALID_ASSIGNMENT);
    resolveAndAssert(source, err);
  }
  
  void test_field_of_generic_type_assign_ok() {
    Source source = addSource('''
      class A {}
      class B extends A {}
      class CEN0<T extends Null> { T o; }
      class CEN1<T extends Null> { T o = null; }
      class CED0<T extends dynamic> { T o; }
      class CED1<T extends dynamic> { T o = null; }
    ''');
    resolveAndVerify(source);
  }

  void test_field_of_generic_type_null_init_err1() {
    Source source = addSource('''
      class A {}
      class B extends A {}
      class CEB0<T extends /*?*/B> { T o; }       // warn T <=!=> Null
      class CEO0<T extends /*?*/Object> { T o; }  // warn T <=!=> Null
      class CEI0<T> { T o; }                      // implicit ?Object upper bound
    ''');
    var err = dup([StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED], 3);
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_field_of_generic_type_assign_err2() {
    Source source = addSource('''
      class A {}
      class B extends A {}
      class CEB1<T extends /*?*/B> { T o = null; }      // warn T <=!=> Null
      class CEB2<T extends /*?*/B> { T o = new A(); }   // warn T <=!=> A (T could be Null)
      class CEO1<T extends /*?*/Object> { T o = null; } // warn T <=!=> Null
      class CEI1<T> { T o = null; }                     // implicit ?Object upper bound
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 4);
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_field_of_generic_type_assign_misc_err() {
    Source source = addSource('''
      class C<T> { T o = 1; m() { o = ''; o = 1.0; } }
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 3);
    resolveAndVerify(source, err);
  }
  
  void test_field_of_non_null_generic_type_null_init_err() {
    Source source = addSource('''
      class A {}
      class B extends A {}
      class CEB0<T extends B> { T o; }              // warn null init T <=!=> Null
      class CEB1<T extends B> { T o = null; }       // warn null asgn T <=!=> Null
      class CEO0<T extends Object> { T o; }         // warn null init T <=!=> Null
      class CEO1<T extends Object> { T o = null; }  // warn null asgn T <=!=> Null
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT,
                  StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED], 2);
    resolveAndVerifyErrDEP30(source, err);
  }

  // TODO: test List<E>
  
  void test_type_of_generic_field_get_set_type_ok() {
    Source source = addSource('''
      class C<T> {
        T o; // warn null init T <=!=> Null
        @nullable T o2;
      }
      int i = new C<int>().o;
      Object o = new C<Object>().o;
      String s = new C<Object>().o;
      List l = new C().o; // dynamic
      @nullable String nus1 = new C</*?*/String>().o;
      @nullable String nus2 = new C<String>().o2;
      @nullable String nus3 = new C<String>().o;

      md0() { new C().o = null; }
      md1() { new C<dynamic>().o = null; }
      mi1() { new C<int>().o = 1; }
      ni1() { new C</*?*/int>().o = 1; }
      nin() { new C</*?*/int>().o = null; }
      ni2() { new C<int>().o2 = 1; }
      nin2(){ new C<int>().o2 = null; }
    ''');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_type_of_generic_field_get_type_err1() {
    Source source = addSource('''
      class C<T> {
        final T o; C([this.o]);
        @nullable T o2;
      }
      Null ni = new C<int>().o; // INVALID_ASSIGNMENT
      String si1 = new C<int>().o; // INVALID_ASSIGNMENT
      String si2 = new C<int>().o2; // INVALID_ASSIGNMENT
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 3);
    resolveAndVerify(source, err);
  }
  
  void test_type_of_generic_field_get_set_type_ok2() {
    Source source = addSource('''
      class C<T> { final T o; C([this.o]); /*?*/T o2; }
      // All ok since String <==> ?String
      String sus0 = new C<String>().o; 
      String sus1 = new C</*?*/String>().o; 
      String sus2 = new C</*?*/String>().o2;
      String sus3 = new C<String>().o2;
      Null n0 = new C<String>().o2;
      Null n1 = new C</*?*/String>().o; 
      Null n2 = new C</*?*/String>().o2;
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT], 3);
    resolveAndVerify(source, err, !isDEP30);
  }

  void test_type_of_generic_field_set_type_err2() {
    Source source = addSource('''
      class C<T> { 
        T o; // warn null init T <=!=> Null
        @nullable T o2; }
      min() { new C<int>().o = null; } // Waring in DartNNBD only
    ''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT,
                  StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED],1);
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_generic_subtype_rel_sanity_check_ok2() {
    Source source = addSource('''
      class C<T> { T o; } // warn null init T <=!=> Null
      f(C<num> o) => o;
      min() { // All ok since the C<T> below are <==> C<num>
        f(new C());
        f(new C<dynamic>());
        f(new C<num>());
        f(new C<int>());
        f(new C<Object>());
      }
    ''');
    var err = [StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_generic_subtype_rel_sanity_check_err2() {
    Source source = addSource('''
      class C<T> { T o; } // warn null init T <=!=> Null
      f(C<num> o) => o;
      min() {
        f(new C<Null>());
        f(new C<String>());
      }
    ''');
    var err = dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE], 2);
    if (isDEP30) err.add(StaticWarningCode.NON_NULL_VAR_NOT_INITIALIZED);
    resolveAndVerify(source, err);
  }
  
  void test_eq_eq_of_nullable() {
    Source source = addSource('''
      abstract class C<T> { T get o; m(int i) { T r = o; r == null; } }
      ''');
    resolveAndAssert(source, []);
  }
  
  void test_assignability_to_field_of_type_parameter_sanity_ok() {
    Source source = addSource('''
      external int fint();
      external num fnum();
      class C1<T1 extends int> { T1 o = fint(); }
      class C2<T2 extends int> { T2 o = fnum(); }
      class C4<T4 extends num> { T4 o = fnum(); }
      class C5<T5 extends num> { T5 o = new Object(); }
      class C6<T6 extends Object> { T6 o = new Object(); }
    ''');
    resolveAndVerify(source);
  }
  
  void test_assignability_to_field_of_type_parameter_sanity_err() {
    Source source = addSource('''
      external int fint();
      class C<T extends num> { T o = fint(); } // A value of type 'int' cannot be assigned to a variable of type 'T3'
    ''');
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndVerify(source, err);
  }

  void test_assignability_to_field_of_type_parameter_ok() {
    Source source = addSource('''
      /*?*/int o = 0; // ok
      class C1<T1 extends int> { T1 o1 = 0; } // ok
      class C2<T2 extends int> { /*?*/T2 o2 = 0; /*?*/T2 o22 = null; } // should be ok
    ''');
    resolveAndVerify(source);
  }

  void test_assignability_to_field_of_type_parameter_ok2() {
    Source source = addSource('''
      @nullable Object o = 0;
      class C0 { /*?*/Object o = 0; }
      class C1<T1 extends int> { T1 o = 0; }
      class C2<T2 extends int> { /*?*/T2 o = new Object(); }
      class C3<T3 extends Object> { /*?*/T3 o = new Object(); }
    ''');
    resolveAndVerify(source);
  }

  void test_nullable_object_is_supertype_of_type_param() {
    Source source = addSource(r'''
      class C<T> { 
        m1(/*?*/Object o) {}
        m2(T t) { m1(t); }
    }
    ''');
    resolveAndVerify(source);
  }

  void test_object_is_not_supertype_of_type_param() {
    Source source = addSource(r'''
      class C<T> { 
        m1(Object o) {}
        m2(T t) { m1(t); } // The argument type 'T' cannot be assigned to the parameter type 'Object'
    }
    ''');
    var err = [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_type_param_is_subtype_of_itself_nulled() {
    Source source = addSource(r'''
      class C<T> { 
        m1(T t) {}
        m2([T t]) { m1(t); }
    }
    ''');
    resolveAndVerify(source);
  }

  void test_null_is_assignable_to_nullable_type_param() {
    Source source = addSource(r'''
      class C<T> { 
        m1(T t) { m2(null); }
        m2(/*?*/T t) { }
    }
    ''');
    resolveAndVerify(source);
  }

  void test_null_return_for_nullable_type_param_ok() {
    Source source = addSource(r'''
      /*?*/int m1() => null;
      /*?*/Object m2() { return null; }
      class C<T> { 
        /*?*/T m1() => null;
        /*?*/T m2() { return null; }
    }
    ''');
    resolveAndVerify(source);
  }

  void test_null_return_for_type_param_err() {
    Source source = addSource(r'''
      int m1() => null;
      Object m2() { return null; }
      class C<T> { 
        T m1() => null;
        T m2() { return null; }
    }
    ''');
    var err = dup([StaticTypeWarningCode.RETURN_OF_INVALID_TYPE], 4);
    resolveAndVerifyErrDEP30(source, err);
  }

}


@reflectiveTest
class TypeTestAndCastTestGroup extends NullityStaticTypeAnalyzerSupertype {

  /// See [NullableByDefaultAndOtherAnnoTestGroup.test_scope_of_nullable_by_default].
  /// This matches the above referenced test except it is in NNBD (i.e., the
  /// library directive has been removed).
  void test_scope_of_nullable_by_default() {
    String code = '''
      class C<T> { }
      m() {
        C d;
        (d as C<int>); /*as*/
        (d is C<int>); /*is*/       // C is !C
        (d as /*!*/C<int>); /*as2*/
        (d is /*?*/C</*!*/int>); /*is2*/
        (d as /*?*/C</*?*/int>); /*as3*/
      }
    ''';
    _resolveTestUnit(code);

    expectType('C<int>); /*as*/', InterfaceTypeImpl, 'C<int>');
    expectType('C<int>); /*is*/', InterfaceTypeImpl, 'C<int>');
    expectType('C<int>); /*as2*/', InterfaceTypeImpl, 'C<int>');
    expectType('C</*!*/int>); /*is2*/', UnionWithNullOf(InterfaceTypeImpl), '?C<int>');
    expectType('C</*?*/int>); /*as3*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');

    expectType('(d as C<int>); /*as*/', InterfaceTypeImpl, 'C<int>');
    expectType('(d is C<int>); /*is*/', InterfaceTypeImpl, 'bool');
    expectType('(d as /*!*/C<int>); /*as2*/', InterfaceTypeImpl, 'C<int>');
    expectType('(d is /*?*/C</*!*/int>); /*is2*/', InterfaceTypeImpl, 'bool');
    expectType('(d as /*?*/C</*?*/int>); /*as3*/', UnionWithNullOf(InterfaceTypeImpl), '?C<?int>');
  }

}


@reflectiveTest
class UnionTypeMemberTestGroup extends NullityTestSupertype {
  
  void test_toString_and_hashCode_of_nullable_ok() {
    Source source = addSource('''
      class C { String toString() => ''; }
      m(/*?*/C o) { o.toString(); o.hashCode; }
    ''');
    resolveAndVerify(source);
  }
  
  void test_toString_alt_and_hashCode_of_nullable_ok() {
    Source source = addSource('''
      class C { String toString([o]) => o.toString(); }
      m(/*?*/C o) { o.toString(); o.hashCode; }
    ''');
    resolveAndVerify(source);
  }
  
  void test_toString_alt_and_hashCode_of_nullable_err() {
    Source source = addSource('''
      class C { String get toString => ''; }
      m(/*?*/C o) { o.toString(); o.hashCode; }
    ''');
    resolveAndVerify(source);
  }

  void test_nullable_Future_then_call_err() {
    Source source = addSource('''
      import 'dart:async';
      var d;
      class C { m([Future fu]) { fu.then(d); } } // 'then' not defined for ?Future
    ''');
    var err = [HintCode.UNDEFINED_METHOD];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_int_and_nullable_func_err() {
    Source source = addSource('''
      f(/*?*/int i, int /*?*/f()) => i+f();''');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION,
      HintCode.UNDEFINED_OPERATOR];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_compound_assignment_op_err() {
    Source source = addSource('''
      f(/*?*/int i) => i += 1;''');
    var err = [HintCode.UNDEFINED_OPERATOR];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_index_op_err() {
    Source source = addSource('''
      f(/*?*/List l) => l[0];''');
    var err = [StaticTypeWarningCode.UNDEFINED_OPERATOR];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_prefix_op_err() {
    Source source = addSource('''
      f(/*?*/int i) => --i;''');
    var err = [HintCode.UNDEFINED_OPERATOR];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_postfix_op_err() {
    Source source = addSource('''
      f(/*?*/int i) => i++;''');
    var err = [HintCode.UNDEFINED_OPERATOR];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_nullable_property_access_err() {
    Source source = addSource('''
      class C { String get m => ''; }
      external /*?*/C f();
      g(/*?*/int i) => f().m;
    ''');
    var err = [HintCode.UNDEFINED_METHOD];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_undefined_getter_of_nullable() {
    Source source = addSource('f(@nullable int o) => o.foo;');
    resolveAndAssert(source, [StaticTypeWarningCode.UNDEFINED_GETTER]);
  }

  void test_undefined_setter_sanity() {
    Source source = addSource('f(int o) => o.foo = 1;');
    resolveAndAssert(source, [StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  void test_undefined_setter_of_nullable() {
    Source source = addSource('f(@nullable int o) => o.foo = 1;');
    resolveAndAssert(source, [StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  void test_cannot_set_hashCode() {
    analysisContext.analysisOptions.enableNonNullTypes = false;
    Source source = addSource('f(int o) { o.hashCode = 1; }');
    resolveAndAssert(source, [StaticWarningCode.ASSIGNMENT_TO_FINAL_NO_SETTER]);
  }

  void test_cannot_set_hashCode_of_nullable() {
    analysisContext.analysisOptions.enableNonNullTypes = false;
    Source source = addSource('f(@nullable int o) { o.hashCode = 1; }');
    resolveAndAssert(source, [StaticWarningCode.ASSIGNMENT_TO_FINAL_NO_SETTER]);
  }

  void test_undefined_op_of_nullable() {
    Source source = addSource('f(@nullable int o) => o + 1;');
    resolveAndAssertErrDEP30(source, [HintCode.UNDEFINED_OPERATOR]);
  }

  void test_eq_eq_of_nullable() {
    Source source = addSource('''
      class D { int operator ==(D other) => 1; } // INVALID_METHOD_OVERRIDE_RETURN_TYPE
      main() {
        @nullable D o;
        bool b = o == o; // STA assumes == is of type bool
      }''');
    resolveAndAssert(source, [StaticWarningCode.INVALID_METHOD_OVERRIDE_RETURN_TYPE]);
  }

  void test_undefined_method_of_nullable() {
    Source source = addSource('''
      main() {
        @nullable int o;
        String s = o.m();
      }''');
    resolveAndAssert(source, [StaticTypeWarningCode.UNDEFINED_METHOD]);
  }

  void _test_hashcode_of_nullable(String anno) {
    Source source = addSource('''
      class D { String hashCode = ''; } // INVALID_GETTER_OVERRIDE_RETURN_TYPE
      f($anno D o) { int i = o.hashCode; }
    ''');
    var err = [StaticWarningCode.INVALID_GETTER_OVERRIDE_RETURN_TYPE];
    /// See explanation in [MiscTestGroup.test_toString_of_nullable_confirm_return_type_from_D].
    if (!isDEP30 || anno != nullableAnno) err.add(StaticTypeWarningCode.INVALID_ASSIGNMENT);
    resolveAndAssert(source, err);
  }
  
  void test_ctr_param_non_null() =>  _test_hashcode_of_nullable(nonNullAnno);
  void test_ctr_param_nullable() =>  _test_hashcode_of_nullable(nullableAnno);

  void _test_getter_as_method_of_nullable(String anno) {
    Source source = addSource('''
      $anno int o = 1;
      main() {
        int i = o.hashCode(); // ok, rhs is of type int, the type of hashCode.
        String s = o.hashCode(); // warn
      }''');
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    err.addAll(dup([StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION],2));
    resolveAndAssert(source, err);
  }

  void test_getter_as_method_of_nullable_non_null() => _test_getter_as_method_of_nullable(nonNullAnno);
  void test_getter_as_method_of_nullable_nullablel() => _test_getter_as_method_of_nullable(nullableAnno);
  
  void test_toString_of_nullable_sanity() {
    Source source = addSource('''
      class D { int toString() => 5; } // INVALID_METHOD_OVERRIDE_RETURN_TYPE
      main() {
        D o = new D();
        String s = o.toString(); // rhs is of type int
      }''');
    var err = [StaticWarningCode.INVALID_METHOD_OVERRIDE_RETURN_TYPE,
      StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndAssert(source, err);
  }

  void test_toString_of_nullable_confirm_return_type_from_D() {
    Source source = addSource('''
      class D { int toString() => 5; } // INVALID_METHOD_OVERRIDE_RETURN_TYPE
      m(@nullable D o) {
        int i = o.toString(); // hint: INVALID_ASSIGNMENT
      }''');
    // In our current approximation of multimembers from union types, the static
    // type of o.toString() is dynamic (the LUB), but the _propagated type is
    // String. This results in a hint of an invalid assignment.
    var err = [StaticWarningCode.INVALID_METHOD_OVERRIDE_RETURN_TYPE];
    if (isDEP30) err.add(HintCode.INVALID_ASSIGNMENT);
    resolveAndAssert(source, err);
  }

  void test_toString_of_nullable_with_propagated_type() {
    Source source = addSource('''
    class D { int toString() => 5; } // INVALID_METHOD_OVERRIDE_RETURN_TYPE
    main() {
      @nullable D o = new D(); // propagated type is D
      o.toString();
      }''');
    resolveAndAssert(source, [StaticWarningCode.INVALID_METHOD_OVERRIDE_RETURN_TYPE]);
  }

}


@reflectiveTest
class NotNullConditionalTypeOverride_LocalVar_and_MethodCallTestGroup extends NullityStaticTypeAnalyzerSupertype {

  void test_nullable_func_result_base_case() {
    Source source = addSource('''
      external /*?*/ String f();
      m() { f().toLowerCase(); }
    ''');
    var err = [HintCode.UNDEFINED_METHOD];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_nullable_func_result_propagated_type_ok() {
    Source source = addSource('''
      /*?*/ String f() => ''; // String return type propagated.
      m() { f().toLowerCase(); }
    ''');
    resolveAndVerify(source);
  }

  void test_nullable_eq_eq_null_op_ok() {
    Source source = addSource('''
      m1(/*?*/int i) { if(i != null) { return i+2; } }
      m2(/*?*/int i) { if(i == null) {} else { return i+2; } }
    ''');
    resolveAndVerify(source);
  }

  void test_nullable_eq_eq_null_but_mutated_err() {
    Source source = addSource('''
      m1(/*?*/int i) { if(i != null) { i++; } }
      m2(/*?*/int i) { if(i == null) {} else { i++; } }
    ''');
    var err = dup([HintCode.UNDEFINED_OPERATOR],2);
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_nullable_eq_eq_null_types_ok() {
    String code = '''
      m11(/*?*/int i) { if(i != null) { i;/*m11t*/ } else { i;/*m11e*/ } }
      m12(/*?*/int i) { if(!(i == null)) { i;/*m12t*/ } else { i;/*m12e*/ } }
      m13(/*?*/int i) { if(i != null && i > 0) { i;/*m13t*/ } else { i;/*m13e*/ } }

      m21(/*?*/int i) { if(i == null) { i;/*m21t*/ } else { i;/*m21e*/ } }
      m22(/*?*/int i) { if(!((i != null))) { i;/*m22t*/ } else { i;/*m22e*/ } }
      m23(/*?*/int i, int j, int k) { if(j == k || i == null) { i;/*m23t*/ } else { i;/*m23e*/ } }
      m24(/*?*/int i) { if(i == null || i > 0) { i;/*m24t*/ } else { i;/*m24e*/ } }

      // Then block has non-mutating operator over i.
      m3(/*?*/int i) { if(i != null) { i+3; i;/*m3t*/ } else { i;/*m3e*/ } }
      // Then block has potentially mutated occurrence of i.
      m4(/*?*/int i) { if(i != null) { i;/*m4t*/ if(i != null) i=i; } else { i;/*m4e*/ } }
    ''';
    _resolveTestUnit(code);
    var nullOrInt = isDEP30 ? 'Null' : 'int';
    expectType('i;/*m11t*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m12t*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m13t*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m11e*/', InterfaceTypeImpl, nullOrInt);
    expectType('i;/*m12e*/', InterfaceTypeImpl, nullOrInt);
    expectType('i;/*m13e*/', UnionWithNullOf(InterfaceTypeImpl), '?int');

    expectType('i;/*m21t*/', InterfaceTypeImpl, nullOrInt);
    expectType('i;/*m22t*/', InterfaceTypeImpl, nullOrInt);
    expectType('i;/*m21e*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m22e*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m23t*/', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('i;/*m23e*/', InterfaceTypeImpl, 'int');
    expectType('i;/*m24t*/', UnionWithNullOf(InterfaceTypeImpl), '?int');
    expectType('i;/*m24e*/', InterfaceTypeImpl, 'int');
    
    expectType('i+', InterfaceTypeImpl, 'int'); //m3t
    expectType('i;/*m3t*/', InterfaceTypeImpl, 'int');
    
    expectType('i;/*m4t*/', UnionWithNullOf(InterfaceTypeImpl), '?int');
  }

  void test_nullable_int_and_nullable_func_neq_null_op_ok() {
    Source source = addSource('''
      m(/*?*/int i, int /*?*/f()) {
        if(i != null && f != null) { return i+f(); } else { return 1; };
    }''');
    resolveAndVerify(source);
  }

  void test_type_propagation_is_currently_only_for_local_var_not_inst_var() {
    String code = '''
    class C {
      /*?*/C c;
      m0() { }
      m1(/*?*/int i) { c == null || c.m0(); }
      m2(/*?*/int i) { i == null || i.toString().length > 0; }
    }''';
    var err = [HintCode.UNDEFINED_METHOD];
    _resolveTestUnit(code, err, isDEP30);
    expectType('c.m', UnionWithNullOf(InterfaceTypeImpl), '?C');
    expectType('i.t', InterfaceTypeImpl, 'int');
  }

  void test_misc_03_err() {
    Source source = addSource('''
      import 'dart:async';
      
      class DoneSubscription<T> {
        int _pauseCount = 0;
        void pause([Future resumeSignal]) {
          if (resumeSignal != null) resumeSignal.then(_resume);
          _pauseCount++;
        }
        void resume() {
          _resume(null);
        }
        void _resume(_) {
          if (_pauseCount > 0) _pauseCount--;
        }
      }
    ''');
    resolveAndVerify(source);
  }

  void test_misc_04_err() {
      String code = '''
      class E { E(num invalidValue, int minValue, int maxValue,
                   [String name, String message]); }
      class C {
        static int checkValidRange(int start, final /*?*/int end, int length, //DEP30
                                    [String startName, String endName,
                                     String message]) {
          if (0 > start || start > length) {
            if (startName == null) startName = "start";
            // startName is non-null;
            throw new E(start, 0, length, startName, message); // was RangeError.range
          }
          if (end != null) {
            if (start > end || end > length) {
              if (endName == null) endName = "end";
              throw new E(end, start, length, endName, message); // was RangeError.range
            }
            return end;
          }
          return length;
        }
      }
      ''';
      _resolveTestUnit(code);
      expectType('end >', InterfaceTypeImpl, 'int');
      expectType('end,', UnionWithNullOf(InterfaceTypeImpl), '?int');
    }

}

@reflectiveTest
class TypeOverrideForFunctionTypesTestGroup extends NullityTestSupertype {
  
  void test_function_call_and_function_field_sanity() {
    Source source = addSource('''
      typedef int F(int i);
      int f1(int i) => i;
      m(F f) { f(1); }
      class A { F f = f1; }
      g(A a) { a.f(1); }
      ''');
    resolveAndVerify(source);
  }

  void test_typedef_sanity() {
    Source source = addSource('''
      typedef int F(int i);
      m1(F f) { f(1); }
      m2(F f) { f(null); }
      ''');
    var err = [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE];
    resolveAndVerifyErrDEP30(source, err);
  }

  void test_typePromotion_functionType_return_voidToDynamic() {
    Source source = addSource('''
      typedef FuncDynToDyn(x);
      typedef void FuncDynToVoid(x);
      class A {}
      main(FuncDynToVoid f) {
        if (f is FuncDynToDyn) { A a = f(null); }
      }''');
    resolveAndVerify(source);
  }
  
  void test_func_param_tested_not_null_call_ok() {
    Source source = addSource('''
      int ff(int /*@nullable*/f()) {
        if(f != null) { return f(); } else { return 1; };
    }''');
    var x = StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION; x = x;
    resolveAndVerify(source);
  }
  
  void test_func_param_tested_not_null_call_ok2() {
    Source source = addSource('''
      int ff(@nullable int /*?*/f()) {
        if(f != null) { return f(); } else { return 1; };
    }''');
    resolveAndVerify(source);
  }

  void test_func_param_tested_not_null_call_err() {
    Source source = addSource('''
      int ff(@nullable int /*?*/f()) {
        if(f != null) { f = null; return f(); } else { return 1; };
    }''');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_func_param_tested_not_null_call_err2() {
    Source source = addSource('''
      typedef int F(int i);
      class C {
        @nullable F f;
        m1(int i) { if(f != null) { m0(i); return f(1); } else { return 1; }; }
        m0(int i) { if (i > 0) f = null; }
      }
    ''');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_type_promotion_doesnt_work_for_fields() {
    Source source = addSource('''
      typedef int F(int i);
      class C {
        @nullable F f;
        m() { if(f != null) { return f(1); } else { return 1; }; }
      }
    ''');
    var err = [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_typePromotion_nullable_functionType_via_cast() {
    Source source = addSource(r'''
      typedef int F(int i);
      main(@nullable F f) {
        if (f is F) { f(null); }
      }''');
    var err = [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE];
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_typePromotion_nullable_functionType_via_cast_else() {
    Source source = addSource(r'''
      typedef int F(int i);
      main(@nullable F f) {
        if (f is F) {} else { f(1); }
        // if (f is! Null) { f(1); } else {} // NOT SUPPORTED
        if (0 > 1 || f != null) { f(1); }
      }''');
    var err = dup([StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION],2);
    resolveAndVerifyErrDEP30(source, err);
  }
  
  void test_typePromotion_nullable_functionType_via_eq_or_neq_ok() {
    Source source = addSource(r'''
      typedef int F(int i);
      main(@nullable F f) {
        if (f != null) { f(1); }
        if (null != f) { f(1); }
        if (f == null) {} else { f(1); }
        if (null == f) {} else { f(1); }

        if (0 < 1 && f != null) { f(1); } // Fails in DartC
      }''');
    resolveAndAssert(source);
    if (isDEP30) verify([source]); // Can't verify in DartC due to "null == f" case.
  }
  
  void test_typePromotion_nullable_functionType_doesnt_impact_arg_type() {
    Source source = addSource(r'''
      typedef int F(int i);
      main(@nullable F f) {
        if (f != null) { f(null); }
        if (null != f) { f(null); }
        if (f == null) {} else { f(null); }
        if (null == f) {} else { f(null); }

        if (0 < 1 && f != null) { f(null); }
      }''');
    var err = dup([StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE], 5);
    resolveAndAssertErrDEP30(source, err); // Can't verify in DartC due to "null == f" case.
    if (isDEP30) verify([source]);
  }
  
  void test_typePromotion_nullable_functionType_via_eq_or_neq_else() {
    Source source = addSource(r'''
      typedef int F(int i);
      main(@nullable F f) {
        if (f != null) {} else { f(1); }
        if (null != f) {} else { f(1); }
        if (f == null) { f(1); }
        if (null == f) { f(1); }
      }''');
    var err = dup([StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION],4);
    resolveAndAssertErrDEP30(source, err); // Can't verify in DartC due to "null == f" case.
    if (isDEP30) verify([source]);
  }
  
  void test_typePromotion_sanity_via_cast_ok() {
    Source source = addSource(r'''
      m1(o) { if (o is int) { o++; } } // ok
      // m2(Object o) { if (o is int) { o++; } } // warning: BUG/feature in DartC? Static type overrides type test.
      ''');
    resolveAndVerify(source);
  }
  
  void test_typePromotion_nullable_functionType_via_conditional_ok() {
    Source source = addSource('''
      typedef int F(int i);
      m(@nullable F f) {
        f is F ? f(1) : 0;
        f != null && f(1) > 0 ? f(1) : 0;
        null != f ? f(1) : 0;
        f == null ? 0 : f(1);
        null == f ? 0 : f(1);

        f != null && f(1) > 0 ? f(1) : 0;
        f == null || f(1) > 0 ? 0 : f(1);
        !(f != null) || f(1) > 0 ? 0 : f(1);
      }
    ''');
    resolveAndAssert(source);
    if (isDEP30) verify([source]);
  }

  // TODO:
  // void test_typePromotion_nullable_functionType_via_conditional_err() {

  // TODO:
  // @nullable F f = (i) => 1;
  // g() { f != null ? f(1) : 0; }

}


@reflectiveTest
class MemberLookupTestGroup extends NullityTestSupertype {
  
  void test_method_over_dynamic_sanity() {
    Source source = addSource('''
      abstract class C { get o; m() { o.foo(); } }
      ''');
    resolveAndVerify(source);
  }
  
  void test_method_over_type_param_sanity() {
    Source source = addSource('''
      abstract class A { ma(); }
      abstract class C<T extends A> { T get o; m() { o.ma(); } }
      ''');
    resolveAndVerify(source);
  }
  
  void test_undefined_method_over_type_param_sanity_err() {
    Source source = addSource('''
      abstract class A { ma(); }
      abstract class C<T extends A> { T get o; m() { o.mb(); } }
      ''');
    var err = [StaticTypeWarningCode.UNDEFINED_METHOD];
    resolveAndAssert(source, err);
  }
  
  void test_nullable_Object_member_access() {
    Source source = addSource('''
      abstract class C<T> { T get o; m() {
        // o gets resolved to ?Object for the purpose of lookup
        o.toString();
        o.hashCode;
      } }
      ''');
    resolveAndVerify(source);
  }
  
  void test_nullable_member_access_ok() {
    Source source = addSource('''
      abstract class A { ma(); }
      abstract class C { /*?*/A get o; m() {
        o.toString();
        o.hashCode;
      } }
      ''');
    resolveAndVerify(source);
  }
  
  void test_nullable_member_access_err() {
    Source source = addSource('''
      abstract class A { ma(); }
      abstract class C { /*?*/A get o; m() {
        o.ma();
      } }
      ''');
    var err = [HintCode.UNDEFINED_METHOD];
    resolveAndAssertErrDEP30(source, err);
  }

}


@reflectiveTest
class MiscTestGroup extends NullityTestSupertype {

  void test_func_arg_nullable_func_nullable_return() {
    Source source = addSource('''
      @nullable Function ff(int /*@nullable*/f()) => f;
      var v = ff(null);
    ''');
    resolveAndVerify(source);
  }
  
  void test_func_arg_nullable_func_non_null_return_err1() {
    Source source = addSource('''
      Function ff(int /*@nullable*/f()) => null;
      var v = ff(null);
    ''');
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.RETURN_OF_INVALID_TYPE]);
  }
  
  void test_func_arg_nullable_func_non_null_return_err2() {
    Source source = addSource('''
      Function ff(int /*@nullable*/f()) => f;
      var v = ff(null);
    ''');
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.RETURN_OF_INVALID_TYPE]);
  }
  
  void test_nullable_func_lib_var_call_err() {
    Source source = addSource(r'''
      typedef int F(int i);
      @nullable F f = (i) => 1;
      g() { f(1); }
    ''');
    resolveAndVerifyErrDEP30(source, [StaticTypeWarningCode.INVOCATION_OF_NON_FUNCTION]);
  }

  void test_misc_01_err() {
    Source source = addSource('''
      class C {
        int m(int i) {
          @nullable int result;
          if (i > 3) result = 1;
          return result; // ok since ?int <==> int.
        }
      }
    ''');
    resolveAndVerify(source);
  }

  void test_misc_02() {
    Source source = addSource('''
      class C<T> {
        C.periodic(int period,
                        [@nullable T computation(int computationCount)]) {
          if (computation == null) computation = ((i) => null);
          }
      }
    ''');
    resolveAndVerify(source);
  }

  void test_misc_03() {
    Source source = addSource('''
      class C<T> {
        C([List values, T t]) {
          if (values != null) {
            values[0] = t;
            m(values);
          }
        }
        m(o) { }
      }
    ''');
    resolveAndVerify(source);
  }

  void test_misc_04() {
    Source source = addSource('''
      class C<T> {
        C([List values, T t]) {
          if (values != null) {
            values[0] = t;
            m(values);
          }
        }
        m(o) { }
      }
    ''');
    resolveAndVerify(source);
  }

}


@reflectiveTest
class MiscStaticTypeTestGroup extends NullityStaticTypeAnalyzerSupertype {

  void test_lub_of_T_and_null_current_impl() {
    String code = '''
      g(o) => o ? true : null;
    ''';
    _resolveTestUnit(code);
    expectType('o ? true : null', DynamicTypeImpl, 'dynamic');
  }

  void fixme_awaiting_feature_impl_test_lub_of_T_and_null() {
    String code = '''
      g(o) => o ? true : null;
    ''';
    _resolveTestUnit(code);
    expectType('o ? true : null', UnionWithNullOf(InterfaceTypeImpl), '?bool');
  }
  
  void test_misc_optional_named_param_func_type() {
    analysisContext.analysisOptions.enableNonNullTypes = false;
    String code = '''
      var _reviver;
      dynamic decode(String source, {reviver(var key, var value)}) {
        if (reviver == null) reviver = _reviver;
        if (reviver == null) return null; // decoder.convert(source);
        return null;
      }
    ''';
    _resolveTestUnit(code);
    expectType('reviver = _reviver;', UnionWithNullOf(FunctionTypeImpl), '?(dynamic, dynamic) → dynamic');
  }

  void test_optional_arg_type_left_as_non_null() {
    String code = '''
      m([int i = 1]) { int j = i; }
      ''';
    _resolveTestUnit(code);
    expectType('i;', InterfaceTypeImpl, 'int');
  }

  void test_optional_arg_type_left_as_nullable_because_of_explicit_decl() {
    String code = '''
      m([/*?*/int i = 1]) { int j = i; }
      ''';
    _resolveTestUnit(code);
    expectType('i;', UnionWithNullOf(InterfaceTypeImpl), '?int');
  }

//  - Error - ast.dart: NodeList(this.owner, [List<E> elements])
//    In new NodeList<FormalParameter>() ... the List<E> becomes ?List<dynamic>.

  void test_null_return_for_type_param_err() {
    String code = '''
      class C<E> {
        List <E> list = [];
        C(int i, [List<E> l]) { list = l; }
      }
      m() { new C<int>(0, <int>[1]).list; }
    ''';
    _resolveTestUnit(code);
    expectType('l;', UnionWithNullOf(InterfaceTypeImpl), '?List<E>');
    expectType('list;', InterfaceTypeImpl, 'List<int>');
  }

}


@reflectiveTest
class LibTestGroup extends NullityTestSupertype {
  
  void test_assignment_sanity_err() {
    Source source = addSource('''
      int nni = 0;
      main() {
        Null n0 = 0,
            n1 = nni,
            n2 = nni + 2,
            n3 = nni.abs();
      }''');
    var err = dup([StaticTypeWarningCode.INVALID_ASSIGNMENT],4);
    resolveAndVerify(source, err);
  }
  
  void test_assignment_nullable_ok() {
    Source source = addSource('''
      @nullable int nui;
      int nni = 0;
      main() {
        int i = nui;
        Null n = nui; // invalid in DartC
        int j = nni;
      }''');
    resolveAndVerify(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT], !isDEP30);
  }
  
  void test_int_parse_is_nullable() {
    Source source = addSource('''
      main() {
        Null n = int.parse('1');
      }''');
    resolveAndVerify(source, [StaticTypeWarningCode.INVALID_ASSIGNMENT], !isDEP30);
  }
  
}


/**
 * Tests over const Null $null = null.
 */
@reflectiveTest
class MiscOver$NullTests extends NullityTestSupertype {

  void test_null_assign_Null() {
    Source source = addSource(r'const Null $null = null;');
    resolveAndVerify(source);
  }

  void $null_assign_to(String type, { bool expectError : true}) {
    Source source = addSource('''
      const Null \$null = null;
      $type o = \$null; // INVALID_ASSIGNMENT
      ''');
    var err = [StaticTypeWarningCode.INVALID_ASSIGNMENT];
    resolveAndVerify(source, err, expectError);
  }
  
  void test_$null_assign_int() { $null_assign_to('int'); }
  void test_$null_assign_Object() { $null_assign_to('Object', expectError:isDEP30); }

}

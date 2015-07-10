// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "platform/assert.h"

#include "vm/dart_api_impl.h"
#include "vm/dart_api_state.h"
#include "vm/globals.h"
#include "vm/profiler.h"
#include "vm/profiler_service.h"
#include "vm/unit_test.h"

namespace dart {

class ProfileSampleBufferTestHelper {
 public:
  static intptr_t IterateCount(const Isolate* isolate,
                               const SampleBuffer& sample_buffer) {
    intptr_t c = 0;
    for (intptr_t i = 0; i < sample_buffer.capacity(); i++) {
      Sample* sample = sample_buffer.At(i);
      if (sample->isolate() != isolate) {
        continue;
      }
      c++;
    }
    return c;
  }


  static intptr_t IterateSumPC(const Isolate* isolate,
                               const SampleBuffer& sample_buffer) {
    intptr_t c = 0;
    for (intptr_t i = 0; i < sample_buffer.capacity(); i++) {
      Sample* sample = sample_buffer.At(i);
      if (sample->isolate() != isolate) {
        continue;
      }
      c += sample->At(0);
    }
    return c;
  }
};


TEST_CASE(Profiler_SampleBufferWrapTest) {
  SampleBuffer* sample_buffer = new SampleBuffer(3);
  Isolate* i = reinterpret_cast<Isolate*>(0x1);
  EXPECT_EQ(0, ProfileSampleBufferTestHelper::IterateSumPC(i, *sample_buffer));
  Sample* s;
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  s->SetAt(0, 2);
  EXPECT_EQ(2, ProfileSampleBufferTestHelper::IterateSumPC(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  s->SetAt(0, 4);
  EXPECT_EQ(6, ProfileSampleBufferTestHelper::IterateSumPC(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  s->SetAt(0, 6);
  EXPECT_EQ(12, ProfileSampleBufferTestHelper::IterateSumPC(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  s->SetAt(0, 8);
  EXPECT_EQ(18, ProfileSampleBufferTestHelper::IterateSumPC(i, *sample_buffer));
  delete sample_buffer;
}


TEST_CASE(Profiler_SampleBufferIterateTest) {
  SampleBuffer* sample_buffer = new SampleBuffer(3);
  Isolate* i = reinterpret_cast<Isolate*>(0x1);
  EXPECT_EQ(0, ProfileSampleBufferTestHelper::IterateCount(i, *sample_buffer));
  Sample* s;
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  EXPECT_EQ(1, ProfileSampleBufferTestHelper::IterateCount(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  EXPECT_EQ(2, ProfileSampleBufferTestHelper::IterateCount(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  EXPECT_EQ(3, ProfileSampleBufferTestHelper::IterateCount(i, *sample_buffer));
  s = sample_buffer->ReserveSample();
  s->Init(i, 0, 0);
  EXPECT_EQ(3, ProfileSampleBufferTestHelper::IterateCount(i, *sample_buffer));
  delete sample_buffer;
}


TEST_CASE(Profiler_AllocationSampleTest) {
  Isolate* isolate = Isolate::Current();
  SampleBuffer* sample_buffer = new SampleBuffer(3);
  Sample* sample = sample_buffer->ReserveSample();
  sample->Init(isolate, 0, 0);
  sample->set_metadata(99);
  sample->set_is_allocation_sample(true);
  EXPECT_EQ(99, sample->allocation_cid());
  delete sample_buffer;
}

static RawClass* GetClass(const Library& lib, const char* name) {
  const Class& cls = Class::Handle(
      lib.LookupClassAllowPrivate(String::Handle(Symbols::New(name))));
  EXPECT(!cls.IsNull());  // No ambiguity error expected.
  return cls.raw();
}


class AllocationFilter : public SampleFilter {
 public:
  explicit AllocationFilter(Isolate* isolate, intptr_t cid)
      : SampleFilter(isolate),
        cid_(cid) {
  }

  bool FilterSample(Sample* sample) {
    return sample->is_allocation_sample() && (sample->allocation_cid() == cid_);
  }

 private:
  intptr_t cid_;
};


TEST_CASE(Profiler_TrivialRecordAllocation) {
  const char* kScript =
      "class A {\n"
      "  var a;\n"
      "  var b;\n"
      "}\n"
      "class B {\n"
      "  static boo() {\n"
      "    return new A();\n"
      "  }\n"
      "}\n"
      "main() {\n"
      "  return B.boo();\n"
      "}\n";

  Dart_Handle lib = TestCase::LoadTestScript(kScript, NULL);
  EXPECT_VALID(lib);
  Library& root_library = Library::Handle();
  root_library ^= Api::UnwrapHandle(lib);

  const Class& class_a = Class::Handle(GetClass(root_library, "A"));
  EXPECT(!class_a.IsNull());
  class_a.SetTraceAllocation(true);

  Dart_Handle result = Dart_Invoke(lib, NewString("main"), 0, NULL);
  EXPECT_VALID(result);


  {
    Isolate* isolate = Isolate::Current();
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, class_a.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have 1 allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    // Exclusive code: B.boo -> main.
    walker.Reset(Profile::kExclusiveCode);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(!walker.Down());

    // Inclusive code: main -> B.boo.
    walker.Reset(Profile::kInclusiveCode);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(!walker.Down());

    // Exclusive function: B.boo -> main.
    walker.Reset(Profile::kExclusiveFunction);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(!walker.Down());

    // Inclusive function: main -> B.boo.
    walker.Reset(Profile::kInclusiveFunction);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(!walker.Down());
  }
}


TEST_CASE(Profiler_ToggleRecordAllocation) {
  const char* kScript =
      "class A {\n"
      "  var a;\n"
      "  var b;\n"
      "}\n"
      "class B {\n"
      "  static boo() {\n"
      "    return new A();\n"
      "  }\n"
      "}\n"
      "main() {\n"
      "  return B.boo();\n"
      "}\n";

  Dart_Handle lib = TestCase::LoadTestScript(kScript, NULL);
  EXPECT_VALID(lib);
  Library& root_library = Library::Handle();
  root_library ^= Api::UnwrapHandle(lib);

  const Class& class_a = Class::Handle(GetClass(root_library, "A"));
  EXPECT(!class_a.IsNull());

  Dart_Handle result = Dart_Invoke(lib, NewString("main"), 0, NULL);
  EXPECT_VALID(result);


  {
    Isolate* isolate = Isolate::Current();
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, class_a.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have no allocation samples.
    EXPECT_EQ(0, profile.sample_count());
  }

  // Turn on allocation tracing for A.
  class_a.SetTraceAllocation(true);

  result = Dart_Invoke(lib, NewString("main"), 0, NULL);
  EXPECT_VALID(result);

  {
    Isolate* isolate = Isolate::Current();
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, class_a.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    // Exclusive code: B.boo -> main.
    walker.Reset(Profile::kExclusiveCode);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(!walker.Down());

    // Inclusive code: main -> B.boo.
    walker.Reset(Profile::kInclusiveCode);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(!walker.Down());

    // Exclusive function: boo -> main.
    walker.Reset(Profile::kExclusiveFunction);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(!walker.Down());

    // Inclusive function: main -> boo.
    walker.Reset(Profile::kInclusiveFunction);
    // Move down from the root.
    EXPECT(walker.Down());
    EXPECT_STREQ("main", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("B.boo", walker.CurrentName());
    EXPECT(!walker.Down());
  }

  // Turn off allocation tracing for A.
  class_a.SetTraceAllocation(false);

  result = Dart_Invoke(lib, NewString("main"), 0, NULL);
  EXPECT_VALID(result);

  {
    Isolate* isolate = Isolate::Current();
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, class_a.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should still only have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
  }
}


TEST_CASE(Profiler_IntrinsicAllocation) {
  const char* kScript = "double foo(double a, double b) => a + b;";
  Dart_Handle lib = TestCase::LoadTestScript(kScript, NULL);
  EXPECT_VALID(lib);
  Library& root_library = Library::Handle();
  root_library ^= Api::UnwrapHandle(lib);
  Isolate* isolate = Isolate::Current();

  const Class& double_class =
      Class::Handle(isolate->object_store()->double_class());
  EXPECT(!double_class.IsNull());

  Dart_Handle args[2] = { Dart_NewDouble(1.0), Dart_NewDouble(2.0), };

  Dart_Handle result = Dart_Invoke(lib, NewString("foo"), 2, &args[0]);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, double_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have no allocation samples.
    EXPECT_EQ(0, profile.sample_count());
  }

  double_class.SetTraceAllocation(true);
  result = Dart_Invoke(lib, NewString("foo"), 2, &args[0]);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, double_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    walker.Reset(Profile::kExclusiveCode);
    EXPECT(walker.Down());
    EXPECT_STREQ("_Double._add", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("_Double.+", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("foo", walker.CurrentName());
    EXPECT(!walker.Down());
  }

  double_class.SetTraceAllocation(false);
  result = Dart_Invoke(lib, NewString("foo"), 2, &args[0]);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, double_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should still only have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
  }
}


TEST_CASE(Profiler_ArrayAllocation) {
  const char* kScript =
      "List foo() => new List(4);\n"
      "List bar() => new List();\n";
  Dart_Handle lib = TestCase::LoadTestScript(kScript, NULL);
  EXPECT_VALID(lib);
  Library& root_library = Library::Handle();
  root_library ^= Api::UnwrapHandle(lib);
  Isolate* isolate = Isolate::Current();

  const Class& array_class =
      Class::Handle(isolate->object_store()->array_class());
  EXPECT(!array_class.IsNull());

  Dart_Handle result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, array_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have no allocation samples.
    EXPECT_EQ(0, profile.sample_count());
  }

  array_class.SetTraceAllocation(true);
  result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, array_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    walker.Reset(Profile::kExclusiveCode);
    EXPECT(walker.Down());
    EXPECT_STREQ("_List._List", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("List.List", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("foo", walker.CurrentName());
    EXPECT(!walker.Down());
  }

  array_class.SetTraceAllocation(false);
  result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, array_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should still only have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
  }

  // Clear the samples.
  ProfilerService::ClearSamples();

  // Compile bar (many List objects allocated).
  result = Dart_Invoke(lib, NewString("bar"), 0, NULL);
  EXPECT_VALID(result);

  // Enable again.
  array_class.SetTraceAllocation(true);

  // Run bar.
  result = Dart_Invoke(lib, NewString("bar"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, array_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should still only have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    walker.Reset(Profile::kExclusiveCode);
    EXPECT(walker.Down());
    EXPECT_STREQ("_List._List", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("_GrowableList._GrowableList", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("List.List", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("bar", walker.CurrentName());
    EXPECT(!walker.Down());
  }
}


TEST_CASE(Profiler_TypedArrayAllocation) {
  const char* kScript =
      "import 'dart:typed_data';\n"
      "List foo() => new Float32List(4);\n";
  Dart_Handle lib = TestCase::LoadTestScript(kScript, NULL);
  EXPECT_VALID(lib);
  Library& root_library = Library::Handle();
  root_library ^= Api::UnwrapHandle(lib);
  Isolate* isolate = Isolate::Current();

  const Library& typed_data_library =
      Library::Handle(isolate->object_store()->typed_data_library());

  const Class& float32_list_class =
      Class::Handle(GetClass(typed_data_library, "_Float32Array"));
  EXPECT(!float32_list_class.IsNull());

  Dart_Handle result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, float32_list_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have no allocation samples.
    EXPECT_EQ(0, profile.sample_count());
  }

  float32_list_class.SetTraceAllocation(true);
  result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, float32_list_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
    ProfileTrieWalker walker(&profile);

    walker.Reset(Profile::kExclusiveCode);
    EXPECT(walker.Down());
    EXPECT_STREQ("_Float32Array._new", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("_Float32Array._Float32Array", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("Float32List.Float32List", walker.CurrentName());
    EXPECT(walker.Down());
    EXPECT_STREQ("foo", walker.CurrentName());
    EXPECT(!walker.Down());
  }

  float32_list_class.SetTraceAllocation(false);
  result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, float32_list_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should still only have one allocation sample.
    EXPECT_EQ(1, profile.sample_count());
  }

  float32_list_class.SetTraceAllocation(true);
  result = Dart_Invoke(lib, NewString("foo"), 0, NULL);
  EXPECT_VALID(result);

  {
    StackZone zone(isolate);
    HANDLESCOPE(isolate);
    Profile profile(isolate);
    AllocationFilter filter(isolate, float32_list_class.id());
    profile.Build(&filter, Profile::kNoTags);
    // We should now have two allocation samples.
    EXPECT_EQ(2, profile.sample_count());
  }
}

}  // namespace dart

#!/usr/bin/env julia

# Test script for the new lesson appending functionality
using Pkg
Pkg.activate(".")

include("src/LessonsFromText.jl")
include("src/lesson_generator.jl")

# Create some test lessons
test_lessons = [
    Lesson("Test 1", "Statistics concept", "This is a test definition", "What is this?", "A test", Statistics),
    Lesson("Test 2", "Python concept", "This is another test", "What is Python?", "A language", Python),
    Lesson("Test 3", "SQL concept", "This is SQL test", "What is SQL?", "A query language", SQL),
    Lesson("Test 4", "More Stats", "Another stats concept", "Tell me more", "More info", Statistics),
    Lesson("Test 5", "More Python", "Another Python concept", "Python question", "Python answer", Python),
]

# Test the append functionality
println("Testing lesson appending functionality...")
println("=" ^ 50)

# Create test output directory
test_output = "test_lesson_packs"
mkpath(test_output)

# Test 1: Append lessons to new files
println("\n1. Testing append to new files:")
success = append_lessons_to_part(test_lessons, "TestTopic", test_output, 3)
println("Success: $success")

# Test 2: Append more lessons (should create new parts when full)
more_lessons = [
    Lesson("Test 6", "Even more stats", "Yet another concept", "Question?", "Answer!", Statistics),
    Lesson("Test 7", "Final test", "Last concept", "Final question?", "Final answer!", Statistics),
]

println("\n2. Testing append to existing files:")
success = append_lessons_to_part(more_lessons, "TestTopic", test_output, 3)
println("Success: $success")

# Test 3: Try to append duplicates (should be filtered out)
println("\n3. Testing duplicate filtering:")
success = append_lessons_to_part(test_lessons[1:2], "TestTopic", test_output, 3)
println("Success: $success")

# Show results
println("\n📁 Created files:")
for file in readdir(test_output)
    if endswith(file, ".json")
        println("  - $file")
    end
end

println("\n✅ Test completed! Check the $test_output directory for results.")
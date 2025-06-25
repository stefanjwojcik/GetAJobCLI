#!/usr/bin/env julia

# Debug script to test lesson display formatting
using GetAJobCLI: load_lesson_pack, Lesson, Term, display_lesson_summary
using Term: Panel, parse_md

println("=== Lesson Display Debug Script ===\n")

# Test 1: Load a lesson from a pack and inspect its raw content
println("🔍 Test 1: Loading lesson from pack...")
lessons = load_lesson_pack("lesson_packs/sample_lessons.json")

if !isnothing(lessons) && !isempty(lessons)
    lesson = lessons[1]
    
    println("📋 Raw lesson data:")
    println("Short name: ", repr(lesson.short_name))
    println("Concept: ", repr(lesson.concept_or_lesson))
    println("Definition (first 100 chars): ", repr(lesson.definition_and_examples[1:min(100, length(lesson.definition_and_examples))]), "...")
    println("Question: ", repr(lesson.question_or_exercise))
    println("Answer: ", repr(lesson.answer))
    println("Topic: ", lesson.topic)
    println()
    
    # Test 2: Test different Panel configurations
    println("🔍 Test 2: Testing different Panel configurations...")
    
    println("--- Default Panel ---")
    println(Term.Panel(lesson.definition_and_examples, title="Default", style="blue"))
    
    println("\n--- Panel with fit=true ---")
    println(Term.Panel(lesson.definition_and_examples, title="Fit=true", style="green", fit=true))
    
    println("\n--- Panel with fit=false ---")
    println(Term.Panel(lesson.definition_and_examples, title="Fit=false", style="red", fit=false))
    
    println("\n--- Panel with width specified ---")
    println(Term.Panel(lesson.definition_and_examples, title="Width=80", style="yellow", width=80))
    
    # Test 3: Test markdown parsing
    println("\n🔍 Test 3: Testing markdown parsing...")
    
    test_markdown = """
# Test Lesson

## Definition
$(lesson.definition_and_examples)
"""
    
    println("--- Raw markdown ---")
    println(Term.Panel(test_markdown, title="Raw Markdown", style="cyan"))
    
    println("\n--- Parsed markdown ---")
    println(Term.Panel(Term.parse_md(test_markdown), title="Parsed Markdown", style="magenta"))
    
    # Test 4: Test the actual display function
    println("\n🔍 Test 4: Testing actual display function...")
    display_lesson_summary(lesson)
    
else
    println("❌ Could not load lessons from sample pack")
end

println("\n=== Debug Complete ===")
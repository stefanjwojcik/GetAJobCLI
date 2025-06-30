#!/usr/bin/env julia
"""
Precompilation workload script for GetAJobCLI

This script exercises key functionality to ensure critical methods
are precompiled when creating the app with PackageCompiler.jl
"""

# Load the main module
using GetAJobCLI

# Exercise configuration management
println("Testing configuration management...")
GetAJobCLI.ensure_config_dir()
keys = GetAJobCLI.load_api_keys()

# Exercise session management
println("Testing session management...")
GetAJobCLI.init_session!()
session_lessons = GetAJobCLI.get_session_lessons()

# Exercise lesson loading and display
println("Testing lesson functionality...")
try
    sample_lessons = GetAJobCLI.load_sample_lessons()
    if !isempty(sample_lessons)
        lesson = sample_lessons[1]
        GetAJobCLI.display_lesson_summary(lesson)
    end
catch e
    println("Sample lessons not available: $e")
end

# Exercise UI components
println("Testing UI components...")
GetAJobCLI.show_session_status()

# Exercise search functionality
println("Testing search...")
try
    GetAJobCLI.search_lessons("test", max_results=1)
catch e
    println("Search test completed with: $e")
end

# Exercise modes (without user interaction)
println("Testing mode components...")
try
    lessons = GetAJobCLI.get_session_lessons()
    topics = GetAJobCLI.list_topics(lessons)
    println("Available topics: ", topics)
catch e
    println("Mode testing completed with: $e")
end

# Exercise lesson pack management
println("Testing lesson pack management...")
try
    GetAJobCLI.list_available_packs()
catch e
    println("Pack listing completed with: $e")
end

println("Precompilation workload completed!")
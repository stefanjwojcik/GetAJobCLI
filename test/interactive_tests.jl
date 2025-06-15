"""
Interactive tests for GetAJobCLI - Test aesthetics and user experience manually

Run these tests interactively to check the visual appearance and behavior
of the CLI components. These tests are designed for manual verification
of aesthetics, formatting, and user interaction flows.

Usage:
    julia> include("test/interactive_tests.jl")
    julia> run_all_aesthetic_tests()
    
Or run individual test functions:
    julia> test_welcome_screen()
    julia> test_lesson_displays()
    julia> test_mode_interfaces()
"""

using GetAJobCLI
using Term

println("""
🎨 Interactive Aesthetic Tests for GetAJobCLI
==============================================

These tests are designed to be run manually to verify:
- Visual appearance and formatting
- Color schemes and panel styling  
- Text layout and readability
- Interactive flows and user experience

Run individual functions to test specific components.
""")

"""
Test the welcome screen and logo display
"""
function test_welcome_screen()
    println(Term.Panel("""
Testing welcome screen aesthetics...

This will display the main welcome banner and logo.
Check for:
- Proper logo centering
- Clean text formatting  
- Appropriate colors and styling
- Overall visual appeal
""", title="Welcome Screen Test", style="bold blue"))
    
    println("\n" * "="^80)
    println("WELCOME SCREEN DISPLAY:")
    println("="^80)
    
    GetAJobCLI.render_welcome()
    
    println("\n" * "="^80)
    println("Did the welcome screen look good? Check logo alignment and banner styling.")
    println("="^80)
end

"""
Test lesson display formatting
"""
function test_lesson_displays()
    println(Term.Panel("""
Testing lesson display aesthetics...

This will show both lesson summary and quiz formats.
Check for:
- Readable markdown formatting
- Proper panel styling and colors
- Clear section separation
- Emoji usage and visual hierarchy
""", title="Lesson Display Test", style="bold green"))
    
    # Create a comprehensive test lesson
    test_lesson = Lesson(
        "Test Topic: Advanced Statistics",
        "This is a test concept to verify formatting and display quality in the terminal interface",
        """This is a longer definition with multiple sentences to test text wrapping and readability. 
        
        **Key Points:**
        - First important point with emphasis
        - Second point with *italic* text
        - Third point with `code formatting`
        
        **Example:** Here's an example with some mathematical notation: μ = Σx/n, where μ is the mean.
        
        This definition includes various formatting elements to test how well they render in the terminal display.""",
        "This is a sample question that might be longer than usual to test how questions are formatted and displayed in the quiz interface?",
        "This is the answer, which should be clearly distinguishable from the question and properly formatted."
    )
    
    println("\n" * "="^80)
    println("LESSON SUMMARY DISPLAY:")
    println("="^80)
    
    display_lesson_summary(test_lesson)
    
    println("\n" * "="^80)
    println("QUIZ PANEL DISPLAY (Question Only):")
    println("="^80)
    
    # Show just the quiz question panel without the interactive part
    lesson_markdown = """
# 📚 $(test_lesson.short_name)

## 📖 Concept
$(test_lesson.concept_or_lesson)

## 📝 Definition & Examples
$(test_lesson.definition_and_examples)

## ❓ Question
$(test_lesson.question_or_exercise)
"""
    
    println(Term.Panel(lesson_markdown, title="Lesson Quiz", style="bold blue"))
    
    println("\n" * "="^80)
    println("Check formatting quality, readability, and visual appeal.")
    println("="^80)
end

"""
Test mode interface aesthetics
"""
function test_mode_interfaces()
    println(Term.Panel("""
Testing mode interface aesthetics...

This will display the quiz and learn mode welcome screens.
Check for:
- Clear mode differentiation (colors, styling)
- Readable command instructions
- Professional appearance
- Consistent styling across modes
""", title="Mode Interface Test", style="bold yellow"))
    
    println("\n" * "="^80)
    println("QUIZ MODE WELCOME:")
    println("="^80)
    
    println(Term.Panel("""
# 🧠 Quiz Mode

Test your knowledge with interactive questions!

**Commands:**
- 'random' - Get a random quiz question
- 'topic [name]' - Quiz on specific topic
- 'back' or 'exit' - Return to main menu
- 'help' - Show quiz mode help
""", title="Quiz Mode", style="bold yellow"))

    println("\n" * "="^80)
    println("LEARN MODE WELCOME:")
    println("="^80)
    
    println(Term.Panel("""
# 📚 Learn Mode

Study concepts and review lessons!

**Commands:**
- 'show' - Display a random lesson
- 'topic [name]' - Show lesson on specific topic
- 'list' - List available topics
- 'back' or 'exit' - Return to main menu
- 'help' - Show learn mode help
""", title="Learn Mode", style="bold green"))

    println("\n" * "="^80)
    println("Check mode differentiation and command clarity.")
    println("="^80)
end

"""
Test API key setup interface
"""
function test_api_key_interface()
    println(Term.Panel("""
Testing API key interface aesthetics...

This will display API key warning and setup screens.
Check for:
- Clear warning messages
- Professional setup flow appearance
- Appropriate color coding (warnings, success, etc.)
- User-friendly instructions
""", title="API Key Interface Test", style="bold cyan"))
    
    println("\n" * "="^80)
    println("API KEY WARNING (No Keys):")
    println("="^80)
    
    warning_text = """
⚠️  **No API Keys Detected**

You need to set up API keys to use the full functionality of this application.

**Available Providers:**
- OpenAI (for GPT models)
- Anthropic (for Claude models)

**Commands:**
- Type 'setup-keys' to configure your API keys
- Type 'check-keys' to see current key status

Some features may not work without proper API key configuration.
"""
    println(Term.Panel(warning_text, title="API Key Warning", style="bold yellow"))
    
    println("\n" * "="^80)
    println("API KEY SETUP SCREEN:")
    println("="^80)
    
    println(Term.Panel("""
# 🔑 API Key Setup

Configure your API keys for OpenAI and Anthropic services.

**Note:** Your keys will be saved locally and are not shared.
Press Enter to skip a provider if you don't want to configure it.
""", title="API Key Setup", style="bold cyan"))

    println("\n" * "="^80)
    println("API KEY STATUS DISPLAY:")
    println("="^80)
    
    status_text = """
**OpenAI:** ✅ Configured
**Anthropic:** ❌ Not configured

Type 'setup-keys' to configure missing keys.
"""
    
    println(Term.Panel(status_text, title="API Key Status", style="bold blue"))
    
    println("\n" * "="^80)
    println("Check warning clarity and setup flow aesthetics.")
    println("="^80)
end

"""
Test help system formatting
"""
function test_help_system()
    println(Term.Panel("""
Testing help system aesthetics...

This will display all help screens.
Check for:
- Clear command organization
- Consistent formatting across help screens
- Easy-to-scan command lists
- Professional documentation appearance
""", title="Help System Test", style="bold magenta"))
    
    println("\n" * "="^80)
    println("MAIN HELP SCREEN:")
    println("="^80)
    
    GetAJobCLI.show_help()
    
    println("\n" * "="^80)
    println("QUIZ MODE HELP:")
    println("="^80)
    
    show_quiz_help()
    
    println("\n" * "="^80)
    println("LEARN MODE HELP:")
    println("="^80)
    
    show_learn_help()
    
    println("\n" * "="^80)
    println("Check help consistency and readability.")
    println("="^80)
end

"""
Test topic listing and search results
"""
function test_topic_displays()
    println(Term.Panel("""
Testing topic and search result aesthetics...

This will display topic lists and search results.
Check for:
- Clean topic listing format
- Clear search result presentation
- Proper handling of empty results
- Readable topic organization
""", title="Topic Display Test", style="bold white"))
    
    sample_lessons = load_sample_lessons()
    
    println("\n" * "="^80)
    println("TOPIC LIST DISPLAY:")
    println("="^80)
    
    list_topics(sample_lessons)
    
    println("\n" * "="^80)
    println("EMPTY SEARCH RESULT:")
    println("="^80)
    
    println(Term.Panel("No lessons found for topic: 'nonexistent_topic'", title="No Results", style="bold yellow"))
    
    println("\n" * "="^80)
    println("SEARCH RESULT WITH MATCHES:")
    println("="^80)
    
    println(Term.Panel("Found 2 lesson(s) for 'python'", title="Topic Quiz", style="bold blue"))
    
    println("\n" * "="^80)
    println("Check topic presentation and search result clarity.")
    println("="^80)
end

"""
Test error and status message formatting
"""
function test_status_messages()
    println(Term.Panel("""
Testing status and error message aesthetics...

This will display various status messages and error states.
Check for:
- Clear error message formatting
- Appropriate color coding
- Professional error presentation
- Helpful status indicators
""", title="Status Message Test", style="bold red"))
    
    println("\n" * "="^80)
    println("SUCCESS MESSAGE:")
    println("="^80)
    
    println(Term.Panel("API keys saved successfully!", title="Success", style="bold green"))
    
    println("\n" * "="^80)
    println("ERROR MESSAGE:")
    println("="^80)
    
    println(Term.Panel("Failed to save API keys!", title="Error", style="bold red"))
    
    println("\n" * "="^80)
    println("WARNING MESSAGE:")
    println("="^80)
    
    println(Term.Panel("📝 OpenAI API key not found. Type 'setup-keys' to configure.", title="Info", style="blue"))
    
    println("\n" * "="^80)
    println("QUIZ RESULT - CORRECT:")
    println("="^80)
    
    result_markdown = """
✅ **CORRECT!** Well done!

Your understanding of the concept is on track.
"""
    println(Term.Panel(result_markdown, title="Result", style="bold green"))
    
    println("\n" * "="^80)
    println("QUIZ RESULT - INCORRECT:")
    println("="^80)
    
    result_markdown = """
❌ **Hmm, Not Quite.**

💡 **Correct Answer:** The sampling distribution approaches normality.

Keep studying - you'll get it next time!
"""
    println(Term.Panel(result_markdown, title="Result", style="bold red"))
    
    println("\n" * "="^80)
    println("Check message clarity and appropriate emotional tone.")
    println("="^80)
end

"""
Run all aesthetic tests in sequence
"""
function run_all_aesthetic_tests()
    println(Term.Panel("""
🎨 Running Complete Aesthetic Test Suite
=======================================

This will run through all visual components to verify:
- Overall design consistency
- Color scheme effectiveness  
- Text readability and formatting
- Professional appearance
- User experience quality

Press Enter between each test to proceed at your own pace.
""", title="Complete Aesthetic Test", style="bold rainbow"))
    
    println("\nPress Enter to start testing...")
    readline()
    
    test_welcome_screen()
    println("\nPress Enter to continue to lesson displays...")
    readline()
    
    test_lesson_displays()  
    println("\nPress Enter to continue to mode interfaces...")
    readline()
    
    test_mode_interfaces()
    println("\nPress Enter to continue to API key interface...")
    readline()
    
    test_api_key_interface()
    println("\nPress Enter to continue to help system...")
    readline()
    
    test_help_system()
    println("\nPress Enter to continue to topic displays...")
    readline()
    
    test_topic_displays()
    println("\nPress Enter to continue to status messages...")
    readline()
    
    test_status_messages()
    
    println(Term.Panel("""
🎉 Aesthetic Testing Complete!

Review the output above and verify:
- ✅ Professional appearance
- ✅ Consistent styling and colors
- ✅ Clear readability
- ✅ Proper formatting
- ✅ Good user experience

Any issues found should be addressed in the respective source files.
""", title="Testing Complete", style="bold green"))
end

# Quick reference for available test functions
println("""
Available test functions:
- test_welcome_screen()
- test_lesson_displays()  
- test_mode_interfaces()
- test_api_key_interface()
- test_help_system()
- test_topic_displays()
- test_status_messages()
- run_all_aesthetic_tests()
""")
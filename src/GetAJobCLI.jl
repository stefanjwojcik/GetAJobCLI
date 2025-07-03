module GetAJobCLI

using Term
using ReplMaker
import PromptingTools as PT
using PromptingTools: aiclassify, aigenerate, aiextract
using JSON3
import RAGTools as RT
using CSV, DataFrames, Dates, HTTP, Random
using ProgressMeter

include("LessonsFromText.jl")
include("modes.jl")
include("lesson_generator.jl")

export Lesson, 
       lessonfromchunks,
       display_lesson_summary, 
       generate_file_paths,
       interactive_lesson_quiz, 
       get_chunks, 
       load_sample_lessons, 
       list_topics, 
       show_lesson_by_topic,
       quiz_by_topic,
       show_quiz_help,
       show_learn_help,
       quiz_mode,
       learn_mode,
       generate_lessons_from_files,
       load_lesson_pack,
       list_available_packs,
       interactive_pack_selection,
       save_lesson_pack,
       ensure_api_keys_loaded


# Session state management
mutable struct SessionState
    loaded_lessons::Vector{Lesson}
    session_start_time::DateTime
end

# Global session state
const SESSION = Ref{SessionState}(SessionState(Lesson[], now()))

"""
Initialize or reset the session state.
"""
function init_session!()
    SESSION[] = SessionState(Lesson[], now())
    return SESSION[]
end

"""
Add lessons to the current session.
"""
function add_lessons_to_session!(lessons::Vector{Lesson})
    append!(SESSION[].loaded_lessons, lessons)
    println("📚 Added $(length(lessons)) lessons to session (total: $(length(SESSION[].loaded_lessons)))")
end

"""
Get all lessons available in the current session (loaded + samples).
"""
function get_session_lessons()::Vector{Lesson}
    session_lessons = copy(SESSION[].loaded_lessons)
    
    # Add sample lessons if no lessons are loaded
    if isempty(session_lessons)
        sample_lessons = load_sample_lessons()
        append!(session_lessons, sample_lessons)
    end
    
    return session_lessons
end

"""
Clear all loaded lessons from the session.
"""
function clear_session_lessons!()
    old_count = length(SESSION[].loaded_lessons)
    SESSION[].loaded_lessons = Lesson[]
    println("🗑️  Cleared $old_count lessons from session")
end

"""
Show session status including loaded lessons count and topics.
"""
function show_session_status()
    lessons = SESSION[].loaded_lessons
    session_time = SESSION[].session_start_time
    
    if isempty(lessons)
        status_text = """
**Session Status:**
- Started: $(Dates.format(session_time, "yyyy-mm-dd HH:MM:SS"))
- Loaded Lessons: 0 (using sample lessons)
- Available Commands: load-pack, generate-lessons
"""
    else
        topic_counts = Dict{String, Int}()
        for lesson in lessons
            topic_str = String(Symbol(lesson.topic))
            topic_counts[topic_str] = get(topic_counts, topic_str, 0) + 1
        end
        
        topics_text = join(["$topic: $count" for (topic, count) in sort(collect(topic_counts))], ", ")
        
        status_text = """
**Session Status:**
- Started: $(Dates.format(session_time, "yyyy-mm-dd HH:MM:SS"))
- Loaded Lessons: $(length(lessons))
- Topics: $topics_text
- Available Commands: quiz, learn, clear-lessons, search
"""
    end
    
    println(Term.Panel(status_text, title="Session Info", style="bold blue"))
end

"""
Search lessons using regex pattern across all text fields.
"""
function search_lessons(pattern::AbstractString; max_results::Int = 10)
    lessons = get_session_lessons()
    
    if isempty(lessons)
        println(Term.Panel("No lessons available to search.", title="Search", style="bold red"))
        return
    end
    
    try
        regex = Regex(pattern, "i")  # Case insensitive search
        matches = []
        
        for (i, lesson) in enumerate(lessons)
            # Search across all text fields
            search_text = join([
                lesson.short_name,
                lesson.concept_or_lesson,
                lesson.definition_and_examples,
                lesson.question_or_exercise,
                lesson.answer,
                String(Symbol(lesson.topic))
            ], " ")
            
            if occursin(regex, search_text)
                # Find which fields contain matches
                matching_fields = String[]
                occursin(regex, lesson.short_name) && push!(matching_fields, "name")
                occursin(regex, lesson.concept_or_lesson) && push!(matching_fields, "concept")
                occursin(regex, lesson.definition_and_examples) && push!(matching_fields, "definition")
                occursin(regex, lesson.question_or_exercise) && push!(matching_fields, "question")
                occursin(regex, lesson.answer) && push!(matching_fields, "answer")
                occursin(regex, String(Symbol(lesson.topic))) && push!(matching_fields, "topic")
                
                push!(matches, (lesson, i, matching_fields))
            end
        end
        
        if isempty(matches)
            println(Term.Panel("No lessons found matching pattern: '$pattern'", title="Search Results", style="bold yellow"))
            return
        end
        
        # Display results
        results_text = "Found $(length(matches)) lesson(s) matching '$pattern':\n\n"
        
        for (i, (lesson, lesson_num, fields)) in enumerate(matches[1:min(max_results, length(matches))])
            topic_str = String(Symbol(lesson.topic))
            fields_str = join(fields, ", ")
            results_text *= "**$i. $(lesson.short_name)** [$topic_str]\n"
            results_text *= "   Matches in: $fields_str\n"
            
            # Show a snippet of the definition
            definition_snippet = lesson.definition_and_examples[1:min(120, length(lesson.definition_and_examples))]
            if length(lesson.definition_and_examples) > 120
                definition_snippet *= "..."
            end
            results_text *= "   Preview: $definition_snippet\n\n"
        end
        
        if length(matches) > max_results
            results_text *= "... and $(length(matches) - max_results) more results.\n"
            results_text *= "Use 'search \"$pattern\" --limit 20' for more results."
        end
        
        println(Term.Panel(results_text, title="Search Results ($(length(matches)) found)", style="bold green"))
        
        # Ask if user wants to view a specific lesson
        if length(matches) > 0
            println("\nType 'view <number>' to see full lesson details, or press Enter to continue.")
            print("Action: ")
            user_input = strip(readline())
            
            if startswith(lowercase(user_input), "view ")
                try
                    num_str = replace(user_input, r"^view\s+"i => "")
                    num = parse(Int, num_str)
                    if 1 <= num <= min(max_results, length(matches))
                        selected_lesson = matches[num][1]
                        println()
                        display_lesson_summary(selected_lesson)
                    else
                        println("Invalid number. Please use 1-$(min(max_results, length(matches))).")
                    end
                catch
                    println("Invalid format. Use 'view <number>'.")
                end
            end
        end
        
    catch e
        println(Term.Panel("Invalid regex pattern: $e", title="Search Error", style="bold red"))
    end
end

"""
Interactive search interface.
"""
function search_interactive()
    println(Term.Panel("""
# 🔍 Search Lessons

Search through all loaded lessons using regex patterns.

**Examples:**
- 'regression' - Find lessons about regression
- 'python.*list' - Find lessons about Python lists
- '^SQL' - Find lessons starting with SQL
- 'interview|hiring' - Find lessons about interviews OR hiring

**Commands:**
- Type your search pattern and press Enter
- 'back' or 'exit' - Return to main menu
- 'help' - Show this help again
""", title="Search Mode", style="bold magenta"))

    while true
        print("\e[35mSearch> \e[0m")
        user_input = strip(readline())
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["back", "exit", "q"]
            println("Returning to main menu...")
            break
        elseif lowercase(user_input) == "help"
            println(Term.Panel("""
**Search Help:**

- Use regular expressions for powerful pattern matching
- Search is case-insensitive by default
- Searches across: lesson names, concepts, definitions, questions, answers, and topics

**Examples:**
- 'statistics' - Simple text search
- 'python.*comprehension' - Python AND comprehension
- '(SQL|database)' - SQL OR database
- '^Central.*Theorem' - Starts with "Central" and contains "Theorem"
""", title="Search Help", style="blue"))
        else
            # Parse potential limit parameter
            max_results = 10
            pattern = user_input
            
            if occursin(r"--limit\s+\d+", user_input)
                limit_match = match(r"--limit\s+(\d+)", user_input)
                if !isnothing(limit_match)
                    max_results = parse(Int, limit_match.captures[1])
                    pattern = replace(user_input, r"\s*--limit\s+\d+" => "")
                end
            end
            
            search_lessons(pattern; max_results=max_results)
        end
    end
end

# Configuration management
const CONFIG_DIR = joinpath(homedir(), ".getajobcli")
const CONFIG_FILE = joinpath(CONFIG_DIR, "config.json")

function ensure_config_dir()
    if !isdir(CONFIG_DIR)
        mkpath(CONFIG_DIR)
    end
end

function load_api_keys()
    ensure_config_dir()
    if !isfile(CONFIG_FILE)
        return Dict("openai_api_key" => nothing, "anthropic_api_key" => nothing)
    end
    
    try
        config_data = JSON3.read(read(CONFIG_FILE, String))
        return Dict(
            "openai_api_key" => get(config_data, :openai_api_key, nothing),
            "anthropic_api_key" => get(config_data, :anthropic_api_key, nothing)
        )
    catch e
        println("Warning: Could not load config file: $e")
        return Dict("openai_api_key" => nothing, "anthropic_api_key" => nothing)
    end
end

function save_api_keys(openai_key::Union{String,Nothing}, anthropic_key::Union{String,Nothing})
    ensure_config_dir()
    try
        config_data = Dict(
            :openai_api_key => openai_key,
            :anthropic_api_key => anthropic_key
        )
        write(CONFIG_FILE, JSON3.write(config_data))
        return true
    catch e
        println("Error: Could not save config file: $e")
        return false
    end
end

"""
Ensure API keys are loaded into environment variables from config file.
Call this before any AI operations.
"""
function ensure_api_keys_loaded()
    keys = load_api_keys()
    
    # Always set environment variables if keys are available in config
    if !isnothing(keys["openai_api_key"])
        ENV["OPENAI_API_KEY"] = keys["openai_api_key"]
    end
    if !isnothing(keys["anthropic_api_key"])
        ENV["ANTHROPIC_API_KEY"] = keys["anthropic_api_key"]
    end
    
    return keys
end

"""
Module initialization function - runs at runtime, not during compilation.
This ensures API keys are loaded only when the app is actually running.
"""
function __init__()
    # Load API keys from config file into environment variables
    # This happens at runtime, not during compilation
    try
        ensure_api_keys_loaded()
    catch e
        # Silently handle any errors during initialization
        # User will be prompted to set up keys when they try to use AI features
    end
end

function check_and_warn_api_keys()
    keys = ensure_api_keys_loaded()
    
    openai_available = !isnothing(keys["openai_api_key"]) || haskey(ENV, "OPENAI_API_KEY")
    anthropic_available = !isnothing(keys["anthropic_api_key"]) || haskey(ENV, "ANTHROPIC_API_KEY")
    
    if !openai_available && !anthropic_available
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
        return false
    elseif !openai_available
        println(Term.Panel("📝 OpenAI API key not found. Type 'setup-keys' to configure.", title="Info", style="blue"))
    elseif !anthropic_available
        println(Term.Panel("📝 Anthropic API key not found. Type 'setup-keys' to configure.", title="Info", style="blue"))
    else
        println(Term.Panel("✅ API keys are configured and ready!", title="Status", style="bold green"))
    end
    
    return true
end

function setup_api_keys()
    println(Term.Panel("""
# 🔑 API Key Setup

Configure your API keys for OpenAI and Anthropic services.

**How to get API keys:**
• OpenAI: Visit https://platform.openai.com/account/api-keys
  - Sign up/log in to your OpenAI account
  - Click "Create new secret key"
  - Copy the key (starts with "sk-")

• Anthropic: Visit https://console.anthropic.com/account/keys
  - Sign up/log in to your Anthropic account
  - Click "Create Key"
  - Copy the key (starts with "sk-ant-")

**Note:** Your keys will be saved locally in ~/.getajobcli/config.json and are not shared.
Press Enter to skip a provider if you don't want to configure it.
""", title="API Key Setup", style="bold cyan"))

    keys = load_api_keys()
    
    # Create mutable copies to handle type conversion
    openai_key = keys["openai_api_key"]
    anthropic_key = keys["anthropic_api_key"]
    
    # OpenAI setup
    openai_status = isnothing(openai_key) ? "Not configured" : "Configured (hidden)"
    println("OpenAI API Key Status: $openai_status")
    print("Enter OpenAI API Key (or press Enter to skip): ")
    openai_input = strip(readline())
    
    if !isempty(openai_input)
        openai_key = String(openai_input)
        println("✅ OpenAI API key updated")
    end
    
    # Anthropic setup  
    anthropic_status = isnothing(anthropic_key) ? "Not configured" : "Configured (hidden)"
    println("Anthropic API Key Status: $anthropic_status")
    print("Enter Anthropic API Key (or press Enter to skip): ")
    anthropic_input = strip(readline())
    
    if !isempty(anthropic_input)
        anthropic_key = String(anthropic_input)
        println("✅ Anthropic API key updated")
    end
    
    # Save configuration
    if save_api_keys(openai_key, anthropic_key)
        println(Term.Panel("API keys saved successfully!", title="Success", style="bold green"))
        
        # Set environment variables
        if !isnothing(openai_key)
            ENV["OPENAI_API_KEY"] = openai_key
        end
        if !isnothing(anthropic_key)
            ENV["ANTHROPIC_API_KEY"] = anthropic_key
        end
    else
        println(Term.Panel("Failed to save API keys!", title="Error", style="bold red"))
    end
end

function check_api_keys_status()
    keys = load_api_keys()
    
    openai_status = if !isnothing(keys["openai_api_key"])
        "✅ Configured"
    elseif haskey(ENV, "OPENAI_API_KEY")
        "✅ Available in environment"
    else
        "❌ Not configured"
    end
    
    anthropic_status = if !isnothing(keys["anthropic_api_key"])
        "✅ Configured"
    elseif haskey(ENV, "ANTHROPIC_API_KEY")
        "✅ Available in environment"
    else
        "❌ Not configured"
    end
    
    status_text = """
**OpenAI:** $openai_status
**Anthropic:** $anthropic_status

Type 'setup-keys' to configure missing keys.
"""
    
    println(Term.Panel(status_text, title="API Key Status", style="bold blue"))
end

"""
Interactive lesson generation interface.
"""
function generate_lessons_interactive()
    println(Term.Panel("""
# 🏭 Lesson Generation

Generate lesson packs from your text files in the clean_txt directory.

This process will:
1. Read all text files from clean_txt/
2. Create text chunks for processing
3. Use AI to extract structured lessons
4. Organize lessons by topic and create packs
5. Save serialized lesson files

**Note:** This requires API keys to be configured.
""", title="Generate Lessons", style="bold cyan"))

    # Check if clean_txt directory exists
    if !isdir("clean_txt")
        println(Term.Panel("❌ clean_txt directory not found! Please ensure text files are in the clean_txt/ directory.", title="Error", style="bold red"))
        return
    end
    
    # Get user preferences
    print("Maximum files to process (-1 for all): ")
    max_files_input = strip(readline())
    max_files = isempty(max_files_input) ? -1 : parse(Int, max_files_input)
    
    print("Chunk size (default 1000): ")
    chunk_size_input = strip(readline())
    chunk_size = isempty(chunk_size_input) ? 1000 : parse(Int, chunk_size_input)
    
    print("Proceed with generation? (y/N): ")
    confirm = strip(lowercase(readline()))
    
    if confirm != "y"
        println("Lesson generation cancelled.")
        return
    end
    
    # Run generation
    println("\n🚀 Starting lesson generation...")
    try
        lessons_by_topic = generate_lessons_from_files(
            "clean_txt",
            output_dir = "lesson_packs",
            max_files = max_files,
            chunk_size = chunk_size,
            verbose = true
        )
        
        if !isempty(lessons_by_topic)
            println(Term.Panel("✅ Lesson generation completed successfully! Check the lesson_packs/ directory for generated files.", title="Success", style="bold green"))
        end
        
    catch e
        println(Term.Panel("❌ Error during lesson generation: $e", title="Error", style="bold red"))
    end
end

"""
Interactive lesson pack loading interface.
"""
function load_pack_interactive()
    println(Term.Panel("""
# 📦 Load Lesson Pack

Load lessons from a file or URL to use in quiz and learn modes.

**Options:**
- Select from available local packs
- Provide absolute file path
- Provide URL to remote lesson pack

Loaded lessons will be added to the current session.
""", title="Load Lesson Pack", style="bold green"))

    # Try interactive selection first
    lessons = interactive_pack_selection("lesson_packs")
    
    if !isnothing(lessons) && !isempty(lessons)
        println(Term.Panel("✅ Successfully loaded $(length(lessons)) lessons!", title="Success", style="bold green"))
        
        # Add lessons to active session
        add_lessons_to_session!(lessons)
        
        # Display the count by topic
        topic_counts = Dict{String, Int}()
        for lesson in lessons
            topic_str = String(Symbol(lesson.topic))
            topic_counts[topic_str] = get(topic_counts, topic_str, 0) + 1
        end
        
        count_text = join(["$topic: $count" for (topic, count) in sort(collect(topic_counts))], "\n")
        println(Term.Panel("**Loaded Lessons by Topic:**\n\n$count_text", title="Lesson Summary", style="cyan"))
        
    else
        println(Term.Panel("No lessons were loaded.", title="Info", style="yellow"))
    end
end

const LOGO = raw"""


____      _                 _       _     
/ ___| ___| |_    __ _      | | ___ | |__  
| |  _ / _ \ __|  / _` |  _  | |/ _ \| '_ \ 
| |_| |  __/ |_  | (_| | | |_| | (_) | |_) |
\____|\___|\__|  \__,_|  \___/ \___/|_.__/ 

          Get a Job
"""

function print_centered_logo()
    width = displaysize(stdout)[2]
    lines = split(LOGO, '\n')
    centered_lines = [
        lpad(line, div(width + length(line), 2)) for line in lines
    ]
    return centered_lines
end

const CENTERED_LOGO = print_centered_logo()


logo_and_info = join(CENTERED_LOGO, "\n") * "\n\n" * """
GET A JOB CLI

Natural language STUDY assistant

Type 'help' for available commands
Type 'exit' to quit
"""

logo_banner = Panel(
    logo_and_info,
    title="Welcome To",
    style="bold red",
    fit=true,
)


function render_welcome()
    # Print the logo and info
    println(logo_banner)
    println()
end


function show_help()
    help_text = """
**Main Commands:**
- **quiz** - Enter quiz mode for interactive learning
- **learn** - Enter learn mode to study lessons
- **search** - Search through lessons using regex patterns
- **setup-keys** - Configure OpenAI/Anthropic API keys
- **check-keys** - Check API key status
- **clear** - Clear the console
- **help** - Show this help message
- **exit/quit** - Exit the application

**Lesson Pack Management:**
- **generate-lessons** - Create lesson packs from text files
- **list-packs** - Show available lesson packs
- **load-pack** - Load lessons from file or URL

**Session Management:**
- **session-status** - Show current session info and loaded lessons
- **clear-lessons** - Clear all loaded lessons from session

**Getting Started:**
1. Set up your API keys with 'setup-keys'
2. Load lesson packs with 'load-pack' or use 'generate-lessons'
3. Try 'quiz' for interactive questions using your loaded lessons
4. Try 'learn' for study materials from your session
5. Use 'session-status' to see what lessons are currently available
"""
    
    println(Panel(help_text, title="Help", style="blue", fit=true))
end

function thinking_spinner(task::Function)
    # Unicode squares for rotation
    squares = ["■", "▣", "□", "▢"]
    # ANSI escape for blue
    blue = "\033[34m"
    reset = "\033[0m"
    msg = " thinking..."
    running = Ref(true)
    result = nothing

    spinner_task = @async begin
        i = 1
        while running[]
            print("\r$(blue)$(squares[i])$(reset)$msg")
            flush(stdout)
            sleep(0.15)
            i = i == length(squares) ? 1 : i + 1
        end
        # Clear the line after done
        print("\r" * " " ^ (length(msg) + 4) * "\r")
        flush(stdout)
    end

    try
        result = task()
    finally
        running[] = false
        wait(spinner_task)
    end
    return result
end

# Function to simulate streaming output
function stream_panel_update(title, style, stream_chunks)
    output = ""
    for chunk in stream_chunks
        output *= chunk
        # Move cursor up by the panel height (estimate or track lines)
        print("\033[2J\033[H")  # Clear screen and move cursor to top left
        println(Panel(output, title=title, style=style))
        flush(stdout)
        sleep(0.15)  # Simulate streaming delay
    end
end

function main()
    Term.Consoles.clear()
    render_welcome()
    
    # Initialize session
    init_session!()
    
    # Check API keys on startup (keys are loaded via __init__())
    check_and_warn_api_keys()
    println()

    # Main command loop
    running = true
    while running
        print("\e[36mGetAJob> \e[0m")
        
        user_input = strip(readline())
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["exit", "quit"]
            running = false
            continue
        elseif lowercase(user_input) == "help"
            show_help()
            continue
        elseif lowercase(user_input) == "clear"
            Term.Consoles.clear()
            render_welcome()
            continue
        elseif lowercase(user_input) == "setup-keys"
            setup_api_keys()
            continue
        elseif lowercase(user_input) == "check-keys"
            check_api_keys_status()
            continue
        elseif lowercase(user_input) == "quiz"
            quiz_mode()
            continue
        elseif lowercase(user_input) == "learn"
            learn_mode()
            continue
        elseif lowercase(user_input) == "generate-lessons"
            generate_lessons_interactive()
            continue
        elseif lowercase(user_input) == "list-packs"
            list_available_packs()
            continue
        elseif lowercase(user_input) == "load-pack"
            load_pack_interactive()
            continue
        elseif lowercase(user_input) == "session-status"
            show_session_status()
            continue
        elseif lowercase(user_input) == "clear-lessons"
            clear_session_lessons!()
            continue
        elseif lowercase(user_input) == "search"
            search_interactive()
            continue
        else
            println("Unknown command. Type 'help' for available commands.")
        end
    end
    
    println(Panel("Thank you for using Get A Job CLI!", 
                 title="Goodbye", 
                 style="blue bold", 
                 fit=true))
end

# Launch UI
#main()

end

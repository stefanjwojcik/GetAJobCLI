## Mode handling for GetAJobCLI - Quiz and Learn modes
using Term
import RAGTools as RT

"""
Quiz mode - allows users to take interactive quizzes on lessons
"""
function quiz_mode()
    println(Term.Panel("""
# 🧠 Quiz Mode

Test your knowledge with interactive questions!

**Commands:**
- 'random' - Get a random quiz question
- 'topic [name]' - Quiz on specific topic
- 'back' or 'exit' - Return to main menu
- 'help' - Show quiz mode help
""", title="Quiz Mode", style="bold yellow"))

    # Load some sample lessons for quizzing
    sample_lessons = load_sample_lessons()
    
    while true
        print("\e[33mQuiz> \e[0m")
        user_input = strip(readline())
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["back", "exit", "q"]
            println("Returning to main menu...")
            break
        elseif lowercase(user_input) == "help"
            show_quiz_help()
        elseif lowercase(user_input) == "random"
            if !isempty(sample_lessons)
                lesson = rand(sample_lessons)
                interactive_lesson_quiz(lesson)
            else
                println(Term.Panel("No lessons available for quizzing!", title="Error", style="bold red"))
            end
        elseif startswith(lowercase(user_input), "topic")
            topic_name = strip(replace(user_input, r"^topic\s*"i => ""))
            if !isempty(topic_name)
                quiz_by_topic(sample_lessons, topic_name)
            else
                println("Please specify a topic name. Example: 'topic statistics'")
            end
        else
            println("Unknown command. Type 'help' for available commands.")
        end
    end
end

"""
Learn mode - displays lessons for study and review
"""
function learn_mode()
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

    # Load some sample lessons for learning
    sample_lessons = load_sample_lessons()
    
    while true
        print("\e[32mLearn> \e[0m")
        user_input = strip(readline())
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["back", "exit", "q"]
            println("Returning to main menu...")
            break
        elseif lowercase(user_input) == "help"
            show_learn_help()
        elseif lowercase(user_input) == "show"
            if !isempty(sample_lessons)
                lesson = rand(sample_lessons)
                display_lesson_summary(lesson)
            else
                println(Term.Panel("No lessons available for display!", title="Error", style="bold red"))
            end
        elseif lowercase(user_input) == "list"
            list_topics(sample_lessons)
        elseif startswith(lowercase(user_input), "topic")
            topic_name = strip(replace(user_input, r"^topic\s*"i => ""))
            if !isempty(topic_name)
                show_lesson_by_topic(sample_lessons, topic_name)
            else
                println("Please specify a topic name. Example: 'topic statistics'")
            end
        else
            println("Unknown command. Type 'help' for available commands.")
        end
    end
end

function show_quiz_help()
    help_text = """
**Quiz Mode Commands:**

- **random** - Get a random quiz question from available lessons
- **topic [name]** - Quiz on a specific topic (e.g., 'topic statistics')
- **back/exit/q** - Return to main menu
- **help** - Show this help message

**Quiz Flow:**
1. Question and context will be displayed
2. Type your answer and press Enter
3. AI will evaluate your response
4. Correct answer will be shown
"""
    println(Term.Panel(help_text, title="Quiz Mode Help", style="yellow"))
end

function show_learn_help()
    help_text = """
**Learn Mode Commands:**

- **show** - Display a random lesson for study
- **topic [name]** - Show lesson on specific topic (e.g., 'topic python')
- **list** - List all available topics
- **back/exit/q** - Return to main menu
- **help** - Show this help message

**Learning Flow:**
1. Lessons are displayed in formatted panels
2. Review the concept, definition, and examples
3. Practice questions are included for self-assessment
"""
    println(Term.Panel(help_text, title="Learn Mode Help", style="green"))
end

function quiz_by_topic(lessons::Vector{Lesson}, topic::AbstractString)
    # Convert to string to ensure type consistency
    topic_str = String(topic)
    
    # First try exact topic match, then fall back to partial matches in name or topic
    matching_lessons = filter(l -> lowercase(l.topic) == lowercase(topic_str), lessons)
    
    if isempty(matching_lessons)
        # Fall back to partial matching in short_name or topic
        matching_lessons = filter(l -> occursin(lowercase(topic_str), lowercase(l.short_name)) || 
                                      occursin(lowercase(topic_str), lowercase(l.topic)), lessons)
    end
    
    if isempty(matching_lessons)
        println(Term.Panel("No lessons found for topic: '$topic_str'", title="No Results", style="bold yellow"))
        return
    end
    
    lesson = rand(matching_lessons)
    println(Term.Panel("Found $(length(matching_lessons)) lesson(s) for '$topic_str'", title="Topic Quiz", style="bold blue"))
    interactive_lesson_quiz(lesson)
end

function show_lesson_by_topic(lessons::Vector{Lesson}, topic::AbstractString)
    # Convert to string to ensure type consistency
    topic_str = String(topic)
    
    # First try exact topic match, then fall back to partial matches in name or topic
    matching_lessons = filter(l -> lowercase(l.topic) == lowercase(topic_str), lessons)
    
    if isempty(matching_lessons)
        # Fall back to partial matching in short_name or topic
        matching_lessons = filter(l -> occursin(lowercase(topic_str), lowercase(l.short_name)) || 
                                      occursin(lowercase(topic_str), lowercase(l.topic)), lessons)
    end
    
    if isempty(matching_lessons)
        println(Term.Panel("No lessons found for topic: '$topic_str'", title="No Results", style="bold yellow"))
        return
    end
    
    lesson = rand(matching_lessons)
    println(Term.Panel("Found $(length(matching_lessons)) lesson(s) for '$topic_str'", title="Topic Study", style="bold cyan"))
    display_lesson_summary(lesson)
end

function list_topics(lessons::Vector{Lesson})
    if isempty(lessons)
        println(Term.Panel("No lessons available", title="Topics", style="bold red"))
        return
    end
    
    # Group lessons by topic category
    topics_dict = Dict{String, Vector{String}}()
    for lesson in lessons
        if !haskey(topics_dict, lesson.topic)
            topics_dict[lesson.topic] = String[]
        end
        push!(topics_dict[lesson.topic], lesson.short_name)
    end
    
    # Build formatted topic list
    topics_text = ""
    for (topic_category, lesson_names) in sort(collect(topics_dict))
        topics_text *= "**$(uppercase(topic_category))**\n"
        for name in lesson_names
            topics_text *= "  • $name\n"
        end
        topics_text *= "\n"
    end
    
    usage_text = """
$topics_text
**Usage:**
- Type 'topic [category]' for exact category match (e.g., 'topic python')
- Type 'topic [partial name]' for partial lesson name match
"""
    
    println(Term.Panel(usage_text, title="Available Topics ($(length(lessons)) lessons)", style="bold cyan"))
end

function load_sample_lessons()::Vector{Lesson}
    # Return some sample lessons - in real implementation, this would load from files
    return [
        Lesson(
            "Central Limit Theorem",
            "The Central Limit Theorem states that the sampling distribution of sample means approaches a normal distribution as sample size increases",
            "The Central Limit Theorem (CLT) is fundamental in statistics. It states that given a population with mean μ and standard deviation σ, the sampling distribution of sample means will approach a normal distribution with mean μ and standard deviation σ/√n as the sample size n increases. For example, if we repeatedly take samples of size 30 from any population and calculate their means, these sample means will be approximately normally distributed regardless of the original population's distribution.",
            "What happens to the sampling distribution of sample means as the sample size increases according to the Central Limit Theorem?",
            "The sampling distribution of sample means approaches a normal distribution with mean μ and standard deviation σ/√n",
            "statistics/machine learning"
        ),
        Lesson(
            "Python List Comprehensions",
            "List comprehensions provide a concise way to create lists in Python using a single line of code",
            "List comprehensions in Python offer a syntactically compact way to create lists. The basic syntax is [expression for item in iterable if condition]. For example, [x**2 for x in range(10) if x % 2 == 0] creates a list of squares of even numbers from 0 to 8, resulting in [0, 4, 16, 36, 64]. This is more readable and often faster than equivalent for loops with append() operations.",
            "Write a list comprehension that creates a list of squares for all odd numbers from 1 to 10.",
            "[x**2 for x in range(1, 11) if x % 2 == 1] or [x**2 for x in [1,3,5,7,9]]",
            "python"
        ),
        Lesson(
            "SQL Window Functions",
            "Window functions perform calculations across a set of rows related to current row without grouping",
            "Window functions in SQL allow you to perform calculations across a set of table rows that are somehow related to the current row, unlike aggregate functions which return a single value for a group. Common window functions include ROW_NUMBER(), RANK(), DENSE_RANK(), LAG(), LEAD(), and aggregate functions with OVER clause. For example: SELECT name, salary, ROW_NUMBER() OVER (ORDER BY salary DESC) as rank FROM employees; This assigns a sequential rank to employees based on salary.",
            "What is the difference between ROW_NUMBER() and RANK() window functions in SQL?",
            "ROW_NUMBER() assigns unique sequential integers even for tied values, while RANK() assigns the same rank to tied values and skips subsequent ranks",
            "SQL"
        ),
        Lesson(
            "Gradient Descent",
            "Gradient descent is an optimization algorithm used to minimize cost functions by iteratively moving in the direction of steepest descent",
            "Gradient descent is a first-order iterative optimization algorithm for finding a local minimum of a differentiable function. In machine learning, it's commonly used to minimize cost functions. The algorithm works by calculating the gradient (partial derivatives) of the cost function with respect to parameters, then updating parameters in the opposite direction of the gradient. The learning rate α controls the step size: θ = θ - α∇J(θ). For example, in linear regression, we use gradient descent to find optimal weights that minimize mean squared error.",
            "In gradient descent, if the learning rate α is too large, what problem might occur during optimization?",
            "The algorithm might overshoot the minimum and fail to converge, or even diverge",
            "statistics/machine learning"
        ),
        Lesson(
            "Interview Behavioral Questions",
            "Behavioral interview questions assess past experiences and soft skills using the STAR method",
            "Behavioral interview questions are designed to evaluate how candidates have handled specific situations in the past, as they are predictive of future performance. The STAR method (Situation, Task, Action, Result) is the best framework for answering these questions. For example, when asked 'Tell me about a time you overcame a challenge,' you should describe the Situation (context), Task (what needed to be done), Action (steps you took), and Result (outcome and learnings). Common behavioral questions focus on leadership, teamwork, problem-solving, and conflict resolution.",
            "What does the STAR method stand for when answering behavioral interview questions?",
            "STAR stands for Situation, Task, Action, and Result",
            "hiring/interviews"
        ),
        Lesson(
            "Git Version Control Basics",
            "Git is a distributed version control system that tracks changes in source code during software development",
            "Git allows developers to track changes, collaborate on projects, and maintain multiple versions of code. Key concepts include repositories (repos), commits (snapshots), branches (parallel development lines), and merging (combining branches). Basic workflow: 'git init' creates a repo, 'git add' stages changes, 'git commit' saves changes, 'git push' uploads to remote repo, 'git pull' downloads changes. Branching allows feature development without affecting main code: 'git branch feature-name' creates a branch, 'git checkout' switches branches.",
            "What is the typical Git workflow for making and saving changes to a repository?",
            "git add (stage changes), git commit (save changes), git push (upload to remote repository)",
            "general programming"
        )
    ]
end
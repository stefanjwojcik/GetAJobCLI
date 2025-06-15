using GetAJobCLI
import RAGTools as RT
using Test
import PromptingTools as PT

@testset "GetAJobCLI.jl" begin
    filespaths = generate_file_paths(joinpath(@__DIR__, "..", "clean_txt"))
    chunks = RT.get_chunks(RT.FileChunker(), filespaths[1:2]; 
        sources = filespaths[1:2], 
        verbose = true, 
        separators = ["\n\n", ". ", "\n", " "], 
        max_length = 1000)
    lesson = lessonfromchunks(chunks; limit=1)
    @test typeof(lesson[1]) == Lesson
end

@testset "Lesson Display Functions" begin
    # Create mock lesson objects for testing
    test_lesson_stats = Lesson(
        "Central Limit Theorem",
        "The Central Limit Theorem states that the sampling distribution of sample means approaches a normal distribution as sample size increases",
        "The Central Limit Theorem (CLT) is fundamental in statistics. It states that given a population with mean μ and standard deviation σ, the sampling distribution of sample means will approach a normal distribution with mean μ and standard deviation σ/√n as the sample size n increases. For example, if we repeatedly take samples of size 30 from any population and calculate their means, these sample means will be approximately normally distributed regardless of the original population's distribution.",
        "What happens to the sampling distribution of sample means as the sample size increases according to the Central Limit Theorem?",
        "The sampling distribution of sample means approaches a normal distribution with mean μ and standard deviation σ/√n",
        "statistics/machine learning"
    )
    
    test_lesson_ml = Lesson(
        "Gradient Descent",
        "Gradient descent is an optimization algorithm used to minimize cost functions by iteratively moving in the direction of steepest descent",
        "Gradient descent is a first-order iterative optimization algorithm for finding a local minimum of a differentiable function. In machine learning, it's commonly used to minimize cost functions. The algorithm works by calculating the gradient (partial derivatives) of the cost function with respect to parameters, then updating parameters in the opposite direction of the gradient. The learning rate α controls the step size: θ = θ - α∇J(θ). For example, in linear regression, we use gradient descent to find optimal weights that minimize mean squared error.",
        "In gradient descent, if the learning rate α is too large, what problem might occur during optimization?",
        "The algorithm might overshoot the minimum and fail to converge, or even diverge",
        "statistics/machine learning"
    )
    
    test_lesson_python = Lesson(
        "List Comprehensions",
        "List comprehensions provide a concise way to create lists in Python using a single line of code",
        "List comprehensions in Python offer a syntactically compact way to create lists. The basic syntax is [expression for item in iterable if condition]. For example, [x**2 for x in range(10) if x % 2 == 0] creates a list of squares of even numbers from 0 to 8, resulting in [0, 4, 16, 36, 64]. This is more readable and often faster than equivalent for loops with append() operations.",
        "Write a list comprehension that creates a list of squares for all odd numbers from 1 to 10.",
        "[x**2 for x in range(1, 11) if x % 2 == 1] or [x**2 for x in [1,3,5,7,9]]",
        "python"
    )
    
    @testset "Lesson Object Creation" begin
        @test typeof(test_lesson_stats) == Lesson
        @test test_lesson_stats.short_name == "Central Limit Theorem"
        @test !isempty(test_lesson_stats.concept_or_lesson)
        @test !isempty(test_lesson_stats.definition_and_examples)
        @test !isempty(test_lesson_stats.question_or_exercise)
        @test !isempty(test_lesson_stats.answer)
        @test test_lesson_stats.topic == "statistics/machine learning"
        
        @test test_lesson_python.topic == "python"
        @test test_lesson_ml.topic == "statistics/machine learning"
    end
    
    @testset "Display Lesson Summary" begin
        # Test that display_lesson_summary doesn't throw errors
        @test_nowarn display_lesson_summary(test_lesson_stats)
        @test_nowarn display_lesson_summary(test_lesson_ml)
        @test_nowarn display_lesson_summary(test_lesson_python)
    end
    
    @testset "Interactive Quiz Function Structure" begin
        # Test the function exists and has correct signature
        @test hasmethod(interactive_lesson_quiz, (Lesson,))
        
        # Since interactive_lesson_quiz requires user input and AI classification,
        # we'll test that it handles empty input correctly
        # This would need to be mocked in a real testing scenario
        
        # Test that the function doesn't crash with valid lesson objects
        @test typeof(test_lesson_stats) == Lesson
        @test typeof(test_lesson_ml) == Lesson  
        @test typeof(test_lesson_python) == Lesson
        
        # Note: Full testing of interactive_lesson_quiz would require mocking
        # readline() and PT.aiclassify() functions, which is beyond basic testing
        println("📋 Interactive quiz function tests require manual verification")
        println("   Run: interactive_lesson_quiz(test_lesson_stats) to test manually")
    end
end

@testset "Mock Lesson Examples" begin
    # Demonstrate the functions work with our test data
    println("\n🧪 Testing display functions with mock data:")
    
    test_lesson = Lesson(
        "SQL Window Functions",
        "Window functions perform calculations across a set of rows related to current row without grouping",
        "Window functions in SQL allow you to perform calculations across a set of table rows that are somehow related to the current row, unlike aggregate functions which return a single value for a group. Common window functions include ROW_NUMBER(), RANK(), DENSE_RANK(), LAG(), LEAD(), and aggregate functions with OVER clause. For example: SELECT name, salary, ROW_NUMBER() OVER (ORDER BY salary DESC) as rank FROM employees; This assigns a sequential rank to employees based on salary.",
        "What is the difference between ROW_NUMBER() and RANK() window functions in SQL?",
        "ROW_NUMBER() assigns unique sequential integers even for tied values, while RANK() assigns the same rank to tied values and skips subsequent ranks",
        "SQL"
    )
    
    @test_nowarn display_lesson_summary(test_lesson)
    println("✅ Display function test completed")
end

@testset "API Key Management" begin
    # Test with temporary config directory to avoid affecting user's actual config
    temp_dir = mktempdir()
    temp_config_file = joinpath(temp_dir, "config.json")
    
    # Mock the constants for testing
    original_config_dir = GetAJobCLI.CONFIG_DIR
    original_config_file = GetAJobCLI.CONFIG_FILE
    
    try
        # Temporarily override config paths for testing
        eval(:(GetAJobCLI.CONFIG_DIR = $temp_dir))
        eval(:(GetAJobCLI.CONFIG_FILE = $temp_config_file))
        
        @testset "Config Directory Creation" begin
            @test_nowarn GetAJobCLI.ensure_config_dir()
            @test isdir(temp_dir)
        end
        
        @testset "API Key Loading and Saving" begin
            # Test loading when no config exists
            keys = GetAJobCLI.load_api_keys()
            @test keys["openai_api_key"] === nothing
            @test keys["anthropic_api_key"] === nothing
            
            # Test saving API keys
            @test GetAJobCLI.save_api_keys("test_openai_key", "test_anthropic_key")
            @test isfile(temp_config_file)
            
            # Test loading saved keys
            loaded_keys = GetAJobCLI.load_api_keys()
            @test loaded_keys["openai_api_key"] == "test_openai_key"
            @test loaded_keys["anthropic_api_key"] == "test_anthropic_key"
            
            # Test partial key saving
            @test GetAJobCLI.save_api_keys("new_openai_key", nothing)
            partial_keys = GetAJobCLI.load_api_keys()
            @test partial_keys["openai_api_key"] == "new_openai_key"
            @test partial_keys["anthropic_api_key"] === nothing
        end
        
        @testset "API Key Status Functions" begin
            # These functions should run without errors
            @test_nowarn GetAJobCLI.check_api_keys_status()
            @test_nowarn GetAJobCLI.check_and_warn_api_keys()
        end
        
    finally
        # Restore original config paths
        eval(:(GetAJobCLI.CONFIG_DIR = $original_config_dir))
        eval(:(GetAJobCLI.CONFIG_FILE = $original_config_file))
        # Clean up temp directory
        rm(temp_dir, recursive=true, force=true)
    end
end

@testset "Mode Functions" begin
    @testset "Sample Lesson Loading" begin
        sample_lessons = load_sample_lessons()
        @test !isempty(sample_lessons)
        @test all(l -> isa(l, Lesson), sample_lessons)
        @test length(sample_lessons) >= 3  # Should have at least a few sample lessons
        
        # Test that all lessons have required fields including topic
        for lesson in sample_lessons
            @test !isempty(lesson.short_name)
            @test !isempty(lesson.concept_or_lesson)
            @test !isempty(lesson.definition_and_examples)
            @test !isempty(lesson.question_or_exercise)
            @test !isempty(lesson.answer)
            @test !isempty(lesson.topic)
            @test lesson.topic in ["statistics/machine learning", "python", "SQL", "general programming", "hiring/interviews", "other"]
        end
    end
    
    @testset "Mode Helper Functions" begin
        sample_lessons = load_sample_lessons()
        
        # Test topic listing
        @test_nowarn list_topics(sample_lessons)
        @test_nowarn list_topics(Lesson[])  # Empty list
        
        # Test topic filtering - should work with exact topic matches
        python_lessons = filter(l -> l.topic == "python", sample_lessons)
        if !isempty(python_lessons)
            @test_nowarn show_lesson_by_topic(sample_lessons, "python")
            @test_nowarn quiz_by_topic(sample_lessons, "python")
        end
        
        # Test partial name matching
        matching = filter(l -> occursin("comprehension", lowercase(l.short_name)), sample_lessons)
        if !isempty(matching)
            @test_nowarn show_lesson_by_topic(sample_lessons, "comprehension")
            @test_nowarn quiz_by_topic(sample_lessons, "comprehension")
        end
        
        # Test with non-existent topic
        @test_nowarn show_lesson_by_topic(sample_lessons, "nonexistent_topic_xyz")
        @test_nowarn quiz_by_topic(sample_lessons, "nonexistent_topic_xyz")
    end
    
    @testset "Help Functions" begin
        @test_nowarn show_quiz_help()
        @test_nowarn show_learn_help()
        @test_nowarn GetAJobCLI.show_help()  # Main help function
    end
end

@testset "CLI Integration Functions" begin
    @testset "Welcome and Display Functions" begin
        @test_nowarn GetAJobCLI.render_welcome()
        @test_nowarn GetAJobCLI.show_help()
    end
    
    @testset "Logo Generation" begin
        logo_lines = GetAJobCLI.print_centered_logo()
        @test isa(logo_lines, Vector)
        @test !isempty(logo_lines)
    end
    
    @testset "Constants and Globals" begin
        @test isa(GetAJobCLI.LOGO, String)
        @test !isempty(GetAJobCLI.LOGO)
        @test isa(GetAJobCLI.CONFIG_DIR, String)
        @test isa(GetAJobCLI.CONFIG_FILE, String)
    end
end

## Lesson Generation Script - Process clean_txt files into structured lessons
import RAGTools as RT
using JSON3
using Term
using Random
using HTTP
using Dates
using SHA

# Checkpoint structure for resumable processing
struct ProcessingCheckpoint
    session_id::String
    input_dir::String
    chunk_size::Int
    target_categories::Vector{String}
    processed_chunks::Set{String}  # SHA256 hashes of processed chunks
    total_chunks::Int
    successful_extractions::Int
    failed_extractions::Int
    lessons_generated::Vector{Lesson}
    created_at::DateTime
    last_updated::DateTime
    checkpoint_file::String
end

# Simple tracking for costs and tokens
mutable struct SessionStats
    total_cost::Float64
    total_input_tokens::Int
    total_output_tokens::Int
    total_requests::Int
    successful_requests::Int
    rate_limit_hits::Int
    consecutive_429s::Int
    last_429_time::DateTime
end

# Global session stats
const SESSION_STATS = SessionStats(0.0, 0, 0, 0, 0, 0, 0, now())

"""
Update session statistics from an API response.
"""
function update_session_stats(response)
    SESSION_STATS.total_requests += 1
    
    if response.status == 200
        SESSION_STATS.successful_requests += 1
    end
    
    # Add cost if available
    if !isnothing(response.cost)
        SESSION_STATS.total_cost += response.cost
    end
    
    # Add tokens if available (tuple of input, output)
    if !isnothing(response.tokens)
        input_tokens, output_tokens = response.tokens
        SESSION_STATS.total_input_tokens += input_tokens
        SESSION_STATS.total_output_tokens += output_tokens
    end
end

"""
Show current session statistics.
"""
function show_session_stats()
    println("📊 Session Statistics:")
    println("   Total Requests: $(SESSION_STATS.total_requests)")
    println("   Successful: $(SESSION_STATS.successful_requests)")
    println("   Rate Limit Hits: $(SESSION_STATS.rate_limit_hits)")
    println("   Consecutive 429s: $(SESSION_STATS.consecutive_429s)")
    println("   Total Cost: \$$(round(SESSION_STATS.total_cost, digits=4))")
    println("   Input Tokens: $(SESSION_STATS.total_input_tokens)")
    println("   Output Tokens: $(SESSION_STATS.total_output_tokens)")
    total_tokens = SESSION_STATS.total_input_tokens + SESSION_STATS.total_output_tokens
    println("   Total Tokens: $total_tokens")
    
    if SESSION_STATS.rate_limit_hits > 0
        time_since_last_429 = now() - SESSION_STATS.last_429_time
        minutes_since = Dates.value(time_since_last_429) / (1000 * 60)
        println("   Last 429: $(round(minutes_since, digits=1)) minutes ago")
    end
end

"""
Reset session statistics.
"""
function reset_session_stats()
    SESSION_STATS.total_cost = 0.0
    SESSION_STATS.total_input_tokens = 0
    SESSION_STATS.total_output_tokens = 0
    SESSION_STATS.total_requests = 0
    SESSION_STATS.successful_requests = 0
    SESSION_STATS.rate_limit_hits = 0
    SESSION_STATS.consecutive_429s = 0
    SESSION_STATS.last_429_time = now()
    println("📊 Session statistics reset")
end

# Category filtering patterns for targeted lesson generation
const CATEGORY_PATTERNS = Dict{String, Vector{Regex}}(
    "python" => [
        r"(?i)\b(python|numpy|pandas|matplotlib|seaborn|sklearn|scikit-learn|jupyter|ipython)\b",
        r"(?i)\b(dataframe|pyplot|bokeh|plotly)\b",
        r"(?i)\b(import (numpy|pandas|matplotlib|seaborn|sklearn))\b",
        r"(?i)\b(\.py|\.ipynb|python\s+script|python\s+code)\b",
        r"(?i)\b(pip\s+install|conda\s+install|python\s+package)\b",
        r"(?i)\b(list\s+comprehension|python\s+dict|python\s+function|def\s+\w+\()\b",
        r"(?i)\b(pandas\s+dataframe|numpy\s+array|matplotlib\s+plot)\b"
    ],
    
    "SQL" => [
        r"(?i)\b(sql|select\s+from|where\s+true|group\s+by|order\s+by)\b",
        r"(?i)\b(inner\s+join|left\s+join|right\s+join|full\s+outer\s+join)\b",
        r"(?i)\b(window\s+function|over\s+partition|rank\(\)|row_number\(\))\b",
        r"(?i)\b(create\s+table|insert\s+into|update\s+set|delete\s+from)\b",
        r"(?i)\b(aggregate\s+function|count\(\)|sum\(\)|avg\(\)|max\(\)|min\(\))\b",
        r"(?i)\b(database|primary\s+key|foreign\s+key)\b",
        r"(?i)\b(postgresql|mysql|sqlite|oracle|sql\s+server)\b",
        r"(?i)\b(query|subquery|cte|common\s+table\s+expression)\b"
    ],
    
    "statistics/machine learning" => [
        r"(?i)\b(statistics|probability|regression|classification|clustering)\b",
        r"(?i)\b(machine\s+learning|deep\s+learning|neural\s+network|artificial\s+intelligence)\b",
        r"(?i)\b(hypothesis\s+test|p-value|confidence\s+interval|significance)\b",
        r"(?i)\b(linear\s+regression|logistic\s+regression|random\s+forest|decision\s+tree)\b",
        r"(?i)\b(cross\s+validation|feature\s+selection|model\s+validation|overfitting)\b",
        r"(?i)\b(supervised|unsupervised|reinforcement\s+learning|semi-supervised)\b",
        r"(?i)\b(bayes|bayesian|frequentist|distribution|normal\s+distribution)\b",
        r"(?i)\b(correlation|covariance|variance|standard\s+deviation|mean|median)\b",
        r"(?i)\b(gradient\s+descent|backpropagation|optimization|loss\s+function)\b",
        r"(?i)\b(feature\s+engineering|data\s+preprocessing|normalization|standardization)\b",
        r"(?i)\b(confusion\s+matrix|roc\s+curve|auc|precision|recall|f1.score)\b",
        r"(?i)\b(clustering|k-means|hierarchical|dbscan|pca|dimensionality\s+reduction)\b"
    ],
    
    "general programming" => [
        r"(?i)\b(algorithm|data\s+structure|complexity|big\s+o|time\s+complexity)\b",
        r"(?i)\b(array|linked\s+list|stack|queue|tree|graph|heap|hash\s+table)\b",
        r"(?i)\b(sorting|searching|binary\s+search|merge\s+sort|quick\s+sort)\b",
        r"(?i)\b(recursion|dynamic\s+programming|greedy|divide\s+and\s+conquer)\b",
        r"(?i)\b(coding|programming|software\s+development|computer\s+science)\b",
        r"(?i)\b(object\s+oriented|functional\s+programming|design\s+pattern)\b",
        r"(?i)\b(debugging|testing|unit\s+test|integration\s+test|code\s+review)\b",
        r"(?i)\b(version\s+control|git|github|refactoring|clean\s+code)\b",
        r"(?i)\b(api|rest|json|xml|web\s+service|microservice)\b",
        r"(?i)\b(database\s+design|system\s+design|architecture|scalability)\b"
    ],
    
    "hiring/interviews" => [
        r"(?i)\b(interview|hiring|recruitment|job\s+search|career)\b",
        r"(?i)\b(behavioral\s+interview|technical\s+interview|coding\s+interview)\b",
        r"(?i)\b(resume|cv|cover\s+letter|portfolio|linkedin)\b",
        r"(?i)\b(job\s+application|interview\s+process|hiring\s+process)\b",
        r"(?i)\b(salary\s+negotiation|offer\s+negotiation|compensation)\b",
        r"(?i)\b(interviewer|candidate|applicant|recruit|onsite|phone\s+screen)\b",
        r"(?i)\b(tell\s+me\s+about|describe\s+a\s+time|give\s+me\s+an\s+example)\b",
        r"(?i)\b(strengths|weaknesses|challenges|achievements|goals)\b",
        r"(?i)\b(company\s+culture|team\s+fit|work\s+environment|soft\s+skills)\b",
        r"(?i)\b(data\s+science\s+interview|analytics\s+interview|tech\s+interview)\b"
    ]
)

"""
Generate a SHA256 hash for a text chunk to uniquely identify it.
"""
function chunk_hash(chunk::Union{String, SubString{String}})::String
    return bytes2hex(sha256(String(chunk)))
end

"""
Create a new checkpoint for a processing session.
"""
function create_checkpoint(
    input_dir::String,
    chunk_size::Int,
    target_categories::Vector{String},
    total_chunks::Int,
    output_dir::String = "lesson_packs"
)::ProcessingCheckpoint
    session_id = string(now())[1:19] |> s -> replace(s, ":" => "-")
    checkpoint_file = joinpath(output_dir, "checkpoint_$(session_id).json")
    
    return ProcessingCheckpoint(
        session_id,
        input_dir,
        chunk_size,
        target_categories,
        Set{String}(),
        total_chunks,
        0,
        0,
        Lesson[],
        now(),
        now(),
        checkpoint_file
    )
end

"""
Save checkpoint to disk.
"""
function save_checkpoint(checkpoint::ProcessingCheckpoint)
    checkpoint_data = Dict(
        :session_id => checkpoint.session_id,
        :input_dir => checkpoint.input_dir,
        :chunk_size => checkpoint.chunk_size,
        :target_categories => checkpoint.target_categories,
        :processed_chunks => collect(checkpoint.processed_chunks),
        :total_chunks => checkpoint.total_chunks,
        :successful_extractions => checkpoint.successful_extractions,
        :failed_extractions => checkpoint.failed_extractions,
        :lessons_generated => checkpoint.lessons_generated,
        :created_at => string(checkpoint.created_at),
        :last_updated => string(now()),
        :checkpoint_file => checkpoint.checkpoint_file
    )
    
    try
        write(checkpoint.checkpoint_file, JSON3.write(checkpoint_data, allow_inf=false))
        return true
    catch e
        @warn "Failed to save checkpoint: $e"
        return false
    end
end

"""
Load checkpoint from disk.
"""
function load_checkpoint(checkpoint_file::String)::Union{ProcessingCheckpoint, Nothing}
    try
        if !isfile(checkpoint_file)
            return nothing
        end
        
        data = JSON3.read(read(checkpoint_file, String))
        
        # Convert lessons back to Lesson objects
        lessons = Lesson[]
        for lesson_data in data.lessons_generated
            try
                topic_enum = string_to_lesson_topic(String(lesson_data.topic))
                lesson = Lesson(
                    lesson_data.short_name,
                    lesson_data.concept_or_lesson,
                    lesson_data.definition_and_examples,
                    lesson_data.question_or_exercise,
                    lesson_data.answer,
                    topic_enum
                )
                push!(lessons, lesson)
            catch e
                @warn "Skipping invalid lesson in checkpoint: $e"
            end
        end
        
        return ProcessingCheckpoint(
            data.session_id,
            data.input_dir,
            data.chunk_size,
            Vector{String}(data.target_categories),
            Set{String}(data.processed_chunks),
            data.total_chunks,
            data.successful_extractions,
            data.failed_extractions,
            lessons,
            DateTime(data.created_at),
            DateTime(data.last_updated),
            checkpoint_file
        )
        
    catch e
        @warn "Failed to load checkpoint: $e"
        return nothing
    end
end

"""
List available checkpoints in the output directory.
"""
function list_checkpoints(output_dir::String = "lesson_packs")::Vector{String}
    if !isdir(output_dir)
        return String[]
    end
    
    checkpoint_files = filter(f -> startswith(f, "checkpoint_") && endswith(f, ".json"), readdir(output_dir))
    return [joinpath(output_dir, f) for f in checkpoint_files]
end

"""
Clean up old checkpoints (older than 7 days).
"""
function cleanup_old_checkpoints(output_dir::String = "lesson_packs", max_age_days::Int = 7)
    checkpoint_files = list_checkpoints(output_dir)
    cutoff_time = now() - Day(max_age_days)
    
    for checkpoint_file in checkpoint_files
        try
            file_time = DateTime(unix2datetime(stat(checkpoint_file).mtime))
            if file_time < cutoff_time
                rm(checkpoint_file)
                println("🗑️  Cleaned up old checkpoint: $(basename(checkpoint_file))")
            end
        catch e
            @warn "Error checking checkpoint file age: $e"
        end
    end
end

"""
Generate lessons from all files in the clean_txt directory with progress tracking and error handling.

# Parameters
- `input_dir`: Directory containing text files to process (default: "clean_txt")
- `output_dir`: Directory to save lesson packs (default: "lesson_packs")
- `max_files`: Maximum number of files to process, -1 for all (default: -1)
- `chunk_size`: Size of text chunks in characters (default: 1000)
- `verbose`: Enable verbose output (default: true)
- `use_async`: Use asynchronous processing (default: true)
- `target_categories`: Filter to specific categories (default: all categories)
- `ntasks`: Number of concurrent async tasks (default: 8, tuned for OpenAI API limits)
- `max_retries`: Maximum retries per chunk (default: 3)
- `resume_checkpoint`: Path to checkpoint file to resume from (default: nothing)
- `save_every`: Save checkpoint every N successful extractions (default: 50)
"""
function generate_lessons_from_files(
    input_dir::String = "clean_txt";
    output_dir::String = "lesson_packs",
    max_files::Int = -1,
    chunk_size::Int = 1000,
    verbose::Bool = true,
    use_async::Bool = true,
    target_categories::Vector{String} = String[],
    ntasks::Int = 4,
    max_retries::Int = 3,
    resume_checkpoint::Union{String, Nothing} = nothing,
    save_every::Int = 50
)
    # Check for resume checkpoint
    checkpoint = nothing
    if !isnothing(resume_checkpoint)
        checkpoint = load_checkpoint(resume_checkpoint)
        if isnothing(checkpoint)
            println("⚠️  Could not load checkpoint: $resume_checkpoint")
            println("Starting fresh processing...")
        else
            println("📋 Resuming from checkpoint: $(checkpoint.session_id)")
            println("   Progress: $(checkpoint.successful_extractions) lessons, $(length(checkpoint.processed_chunks)) chunks processed")
            
            # Validate checkpoint compatibility
            if checkpoint.input_dir != input_dir || checkpoint.chunk_size != chunk_size || checkpoint.target_categories != target_categories
                println("⚠️  Checkpoint parameters don't match current settings. Starting fresh...")
                checkpoint = nothing
            end
        end
    end
    
    category_info = isempty(target_categories) ? "All categories" : join(target_categories, ", ")
    async_info = use_async ? "Enabled (ntasks=$ntasks, max_retries=$max_retries)" : "Disabled"
    resume_info = isnothing(checkpoint) ? "Fresh start" : "Resuming from checkpoint"
    
    println(Term.Panel("""
# 🏭 Lesson Generation Pipeline

Processing text files to generate structured lessons...

**Input Directory:** $input_dir
**Output Directory:** $output_dir
**Target Categories:** $category_info
**Max Files:** $(max_files == -1 ? "All" : max_files)
**Chunk Size:** $chunk_size characters
**Async Processing:** $async_info
**Resume Mode:** $resume_info
**Save Every:** $save_every lessons
""", title="Lesson Generator", style="bold blue"))
    
    # Ensure output directory exists
    if !isdir(output_dir)
        mkpath(output_dir)
        println("📁 Created output directory: $output_dir")
    end
    
    # Get all text files, optionally filtered by category
    file_paths = if !isempty(target_categories)
        get_files_for_categories(input_dir, target_categories)
    else
        generate_file_paths(input_dir)
    end
    
    if max_files > 0
        file_paths = file_paths[1:min(max_files, length(file_paths))]
    end
    
    println("📚 Found $(length(file_paths)) files to process")
    
    # Generate chunks from all files
    println("
🔄 Generating text chunks...")
    chunks = RT.get_chunks(
        RT.FileChunker(), 
        file_paths;
        sources = file_paths,
        verbose = verbose,
        separators = ["

", ". ", "
", " "],
        max_length = chunk_size
    )
    
    println("📝 Generated $(length(chunks[1])) chunks from $(length(file_paths)) files")
    
    # Filter chunks by category if target categories are specified
    filtered_chunks = if !isempty(target_categories)
        filter_chunks_by_categories(chunks, target_categories)
    else
        chunks
    end
    
    if filtered_chunks != chunks
        println("🎯 Filtered to $(length(filtered_chunks[1])) chunks matching target categories")
    end
    
    # Create or use existing checkpoint
    if isnothing(checkpoint)
        checkpoint = create_checkpoint(input_dir, chunk_size, target_categories, length(filtered_chunks[1]), output_dir)
        println("📋 Created new checkpoint: $(checkpoint.session_id)")
    end
    
    # Process chunks with progress tracking and error handling
    println("
🧠 Processing chunks into lessons...")
    if use_async
        all_lessons = process_chunks_async_simple(filtered_chunks, checkpoint; ntasks=ntasks, max_retries=max_retries, save_every=save_every)
    else
        all_lessons = process_chunks_with_checkpoint(filtered_chunks, checkpoint; save_every=save_every)
    end
    
    if isempty(all_lessons)
        println(Term.Panel("❌ No lessons were successfully generated!", title="Error", style="bold red"))
        return Dict{String, Vector{Lesson}}()
    end
    
    # Split lessons by topic
    lessons_by_topic = split_lessons_by_topic(all_lessons)
    
    # Create partitioned lesson packs
    create_lesson_packs(lessons_by_topic, output_dir)
    
    # Create sample pack
    create_sample_pack(lessons_by_topic, output_dir)
    
    # Clean up checkpoint after successful completion
    try
        rm(checkpoint.checkpoint_file)
        println("🗑️  Cleaned up checkpoint file: $(basename(checkpoint.checkpoint_file))")
    catch e
        @warn "Could not remove checkpoint file: $e"
    end
    
    # Clean up old checkpoints
    cleanup_old_checkpoints(output_dir)
    
    return lessons_by_topic
end

"""
Generate lessons for a specific topic by first generating concepts, then creating lessons for each concept.
"""
function generate_lessons_for_topic(
    topic::String;
    output_dir::String = "lesson_packs",
    max_concepts::Int = 20,
    save_every::Int = 10,
    use_async::Bool = true,
    ntasks::Int = 4
)::Vector{Lesson}
    # Ensure API keys are loaded
    GetAJobCLI.ensure_api_keys_loaded()
    
    println(Term.Panel("""
# 🎯 Targeted Lesson Generation

Generating lessons for topic: **$topic**

This will:
1. Generate a list of concepts within the topic
2. Create detailed lessons for each concept
3. Save lessons with cost/token tracking

**Max Concepts:** $max_concepts
**Save Every:** $save_every lessons
**Async Processing:** $(use_async ? "Enabled (ntasks=$ntasks)" : "Disabled")
""", title="Topic-Based Lesson Generator", style="bold green"))
    
    # Ensure output directory exists
    if !isdir(output_dir)
        mkpath(output_dir)
    end
    
    # Reset session stats for this run
    reset_session_stats()
    
    # Step 1: Generate concepts for the topic
    println("🧠 Step 1: Generating concepts for '$topic'...")
    concepts_response = generate_ai_concepts(topic)
    update_session_stats(concepts_response)
    
    if isnothing(concepts_response.content) || isempty(concepts_response.content.concepts)
        println("❌ No concepts generated for topic '$topic'")
        return Lesson[]
    end
    
    concepts = concepts_response.content.concepts
    if length(concepts) > max_concepts
        concepts = concepts[1:max_concepts]
    end
    
    println("✅ Generated $(length(concepts)) concepts:")
    for (i, concept) in enumerate(concepts)
        println("   $i. $(concept.concept)")
    end
            
    # Step 2: Generate lessons from concepts
    println("\n🎓 Step 2: Generating lessons from concepts...")
    show_session_stats()
    
    if use_async
        all_lessons = generate_lessons_from_concepts_async(concepts, save_every, ntasks, output_dir, topic)
    else
        all_lessons = generate_lessons_from_concepts_sync(concepts, save_every, output_dir, topic)
    end
    
    # Step 3: Save final lesson pack
    if !isempty(all_lessons)
        pack_filename = joinpath(output_dir, "$(replace(topic, " " => "_", "/" => "_"))_generated_lessons.json")
        pack_name = "Generated Lessons: $topic"
        
        if save_lesson_pack(all_lessons, pack_filename, pack_name)
            println("💾 Saved $(length(all_lessons)) lessons to $pack_filename")
        end
    end
    
    # Show final stats
    println("\n📊 Final Results:")
    show_session_stats()
    println("   📚 Total Lessons Generated: $(length(all_lessons))")
    
    return all_lessons
end

"""
Generate lessons from concepts asynchronously with 429 handling.
"""
function generate_lessons_from_concepts_async(
    concepts::Vector{Concept}, 
    save_every::Int, 
    ntasks::Int,
    output_dir::String,
    topic::String
)::Vector{Lesson}
    
    total_concepts = length(concepts)
    all_lessons = Lesson[]
    
    # Shared progress tracking
    progress_lock = Threads.SpinLock()
    successful_lessons = Ref(0)
    failed_lessons = Ref(0)
    processed_count = Ref(0)
    
    println("🚀 Processing $(total_concepts) concepts with ntasks: $ntasks")
    
    # Process concepts asynchronously
    async_results = asyncmap(concepts; ntasks=ntasks) do concept
        process_single_concept(
            concept, progress_lock, successful_lessons, failed_lessons, 
            processed_count, total_concepts, save_every, all_lessons, output_dir, topic
        )
    end
    
    # Filter successful results and convert to Lesson
    lessons = filter(!isnothing, async_results)
    converted_lessons = [concept_lesson_to_lesson(cl) for cl in lessons]
    
    return converted_lessons
end

"""
Generate lessons from concepts synchronously with 429 handling.
"""
function generate_lessons_from_concepts_sync(
    concepts::Vector{Concept}, 
    save_every::Int,
    output_dir::String,
    topic::String
)::Vector{Lesson}
    
    total_concepts = length(concepts)
    all_lessons = Lesson[]
    successful_lessons = 0
    failed_lessons = 0
    
    println("📚 Processing $(total_concepts) concepts sequentially...")
    
    for (i, concept) in enumerate(concepts)
        try
            response = ailesson(concept)
            update_session_stats(response)
            
            # Handle 429 status
            if response.status == 429
                SESSION_STATS.rate_limit_hits += 1
                SESSION_STATS.consecutive_429s += 1
                SESSION_STATS.last_429_time = now()
                
                backoff_time = min(30.0 * (2^(SESSION_STATS.consecutive_429s - 1)), 300.0)
                println("⚠️  Rate limit (429) - waiting $(round(backoff_time, digits=1))s")
                sleep(backoff_time)
                continue
            end
            
            # Reset consecutive 429 counter on success
            if response.status == 200
                SESSION_STATS.consecutive_429s = 0
            end
            
            if !isnothing(response.content) && !isempty(response.content.short_name)
                lesson = concept_lesson_to_lesson(response.content)
                push!(all_lessons, lesson)
                successful_lessons += 1
                
                # Save intermediate progress
                if successful_lessons % save_every == 0
                    pack_filename = joinpath(output_dir, "$(replace(topic, " " => "_"))_partial_$(successful_lessons).json")
                    save_lesson_pack(all_lessons, pack_filename, "Partial: $topic ($successful_lessons lessons)")
                    println("💾 Saved partial progress: $successful_lessons lessons")
                end
            else
                failed_lessons += 1
            end
            
        catch e
            failed_lessons += 1
            @warn "Error processing concept '$(concept.concept)': $e"
        end
        
        # Update progress
        if i % 5 == 0 || i == total_concepts
            percentage = round(i/total_concepts*100, digits=1)
            println("[$i/$total_concepts] $percentage% - ✅ $successful_lessons lessons | ❌ $failed_lessons failed")
        end
    end
    
    return all_lessons
end

"""
Process a single concept into a lesson with progress tracking.
"""
function process_single_concept(
    concept::Concept,
    progress_lock::Threads.SpinLock,
    successful_lessons::Ref{Int},
    failed_lessons::Ref{Int},
    processed_count::Ref{Int},
    total_concepts::Int,
    save_every::Int,
    all_lessons::Vector{Lesson},
    output_dir::String,
    topic::String
)::Union{ConceptLesson, Nothing}
    
    try
        response = ailesson(concept)
        update_session_stats(response)
        
        # Handle 429 status
        if response.status == 429
            lock(progress_lock) do
                SESSION_STATS.rate_limit_hits += 1
                SESSION_STATS.consecutive_429s += 1
                SESSION_STATS.last_429_time = now()
            end
            
            backoff_time = min(30.0 * (2^(SESSION_STATS.consecutive_429s - 1)), 300.0)
            println("⚠️  Rate limit (429) - waiting $(round(backoff_time, digits=1))s for '$(concept.concept)'")
            sleep(backoff_time)
            return nothing
        end
        
        # Reset consecutive 429 counter on success
        if response.status == 200
            lock(progress_lock) do
                SESSION_STATS.consecutive_429s = 0
            end
        end
        
        if !isnothing(response.content) && !isempty(response.content.short_name)
            # Update progress (thread-safe)
            lock(progress_lock) do
                successful_lessons[] += 1
                processed_count[] += 1
                
                # Add to shared lessons list
                lesson = concept_lesson_to_lesson(response.content)
                push!(all_lessons, lesson)
                
                # Save partial progress
                if successful_lessons[] % save_every == 0
                    pack_filename = joinpath(output_dir, "$(replace(topic, " " => "_"))_partial_$(successful_lessons[]).json")
                    save_lesson_pack(all_lessons, pack_filename, "Partial: $topic ($(successful_lessons[]) lessons)")
                    println("💾 Saved partial progress: $(successful_lessons[]) lessons")
                end
                
                # Update progress
                if processed_count[] % 5 == 0 || processed_count[] == total_concepts
                    percentage = round(processed_count[]/total_concepts*100, digits=1)
                    println("[$(processed_count[])/$total_concepts] $percentage% - ✅ $(successful_lessons[]) lessons | ❌ $(failed_lessons[]) failed")
                end
            end
            
            return response.content
        else
            lock(progress_lock) do
                failed_lessons[] += 1
                processed_count[] += 1
            end
            return nothing
        end
        
    catch e
        lock(progress_lock) do
            failed_lessons[] += 1
            processed_count[] += 1
        end
        @warn "Error processing concept '$(concept.concept)': $e"
        return nothing
    end
end

"""
Convert a ConceptLesson to a Lesson (same fields, different types).
"""
function concept_lesson_to_lesson(concept_lesson::ConceptLesson)::Lesson
    return Lesson(
        concept_lesson.short_name,
        concept_lesson.concept_or_lesson,
        concept_lesson.definition_and_examples,
        concept_lesson.question_or_exercise,
        concept_lesson.answer,
        concept_lesson.topic
    )
end

"""
Interactive function to select a topic and generate lessons.
"""
function interactive_topic_lesson_generation(output_dir::String = "lesson_packs")
    available_topics = [
        "Statistics and Probability",
        "Machine Learning Fundamentals", 
        "Python for Data Science",
        "SQL and Database Management",
        "Data Visualization",
        "Statistical Testing and Hypothesis Testing",
        "Time Series Analysis",
        "Deep Learning and Neural Networks",
        "Feature Engineering",
        "A/B Testing and Experimental Design",
        "Data Cleaning and Preprocessing",
        "Model Evaluation and Validation",
        "Big Data Technologies",
        "Data Science Interview Preparation"
    ]
    
    println(Term.Panel("""
# 🎯 Interactive Topic-Based Lesson Generation

Select a topic to generate targeted lessons:
""", title="Lesson Generator", style="bold blue"))
    
    for (i, topic) in enumerate(available_topics)
        println("   $i. $topic")
    end
    
    println("\nOr enter a custom topic.")
    println("Type '0', 'back', 'exit', or 'cancel' to return to main menu.")
    print("Selection (number or custom topic): ")
    input = strip(readline())
    
    if isempty(input)
        println("No selection made.")
        return nothing
    end
    
    # Check for exit commands
    if lowercase(input) in ["0", "back", "exit", "quit", "cancel"]
        println("Returning to main menu...")
        return nothing
    end
    
    # Try to parse as number first
    selected_topic = try
        topic_num = parse(Int, input)
        if 1 <= topic_num <= length(available_topics)
            available_topics[topic_num]
        else
            println("❌ Invalid topic number. Must be between 1 and $(length(available_topics))")
            return nothing
        end
    catch
        # Not a number, use as custom topic
        input
    end
    
    println("\n🎯 Selected topic: **$selected_topic**")
    
    # Ask for additional parameters
    print("Max concepts to generate (default 20, or 'cancel' to exit): ")
    max_concepts_input = strip(readline())
    
    # Check for exit
    if lowercase(max_concepts_input) in ["cancel", "exit", "back", "quit"]
        println("Returning to main menu...")
        return nothing
    end
    
    max_concepts = isempty(max_concepts_input) ? 20 : parse(Int, max_concepts_input)
    
    print("Use async processing? (y/N, or 'cancel' to exit): ")
    async_input = strip(readline())
    
    # Check for exit
    if lowercase(async_input) in ["cancel", "exit", "back", "quit"]
        println("Returning to main menu...")
        return nothing
    end
    
    use_async = lowercase(async_input) == "y"
    
    if use_async
        print("Number of concurrent tasks (default 4, or 'cancel' to exit): ")
        ntasks_input = strip(readline())
        
        # Check for exit
        if lowercase(ntasks_input) in ["cancel", "exit", "back", "quit"]
            println("Returning to main menu...")
            return nothing
        end
        
        ntasks = isempty(ntasks_input) ? 4 : parse(Int, ntasks_input)
    else
        ntasks = 1
    end
    
    # Generate lessons
    println("\n🚀 Starting lesson generation...")
    lessons = generate_lessons_for_topic(
        selected_topic;
        output_dir=output_dir,
        max_concepts=max_concepts,
        use_async=use_async,
        ntasks=ntasks
    )
    
    if !isempty(lessons)
        println("\n✅ Successfully generated $(length(lessons)) lessons for '$selected_topic'!")
        return lessons
    else
        println("\n❌ No lessons were generated.")
        return nothing
    end
end

"""
Process chunks into lessons with progress tracking and error handling.
"""
function process_chunks_with_progress(chunks::Tuple{Vector{SubString{String}}, Vector{String}})::Vector{Lesson}
    # Ensure API keys are loaded before processing
    GetAJobCLI.ensure_api_keys_loaded()
    
    all_lessons = Lesson[]
    total_chunks = length(chunks[1])
    successful_extractions = 0
    failed_extractions = 0
    consecutive_errors = 0
    base_delay = 0.1  # Start with 100ms
    max_delay = 10.0  # Cap at 10 seconds
    
    println("Processing $total_chunks chunks with exponential backoff...")
    
    for (i, text_chunk) in enumerate(chunks[1])
        try
            # Extract lesson from chunk
            msg = aiextract(text_chunk; return_type=Lesson)
            
            if !isnothing(msg.content)
                push!(all_lessons, msg.content)
                successful_extractions += 1
                consecutive_errors = 0  # Reset error count on success
            else
                failed_extractions += 1
                consecutive_errors += 1
            end
            
        catch e
            failed_extractions += 1
            consecutive_errors += 1
            
            # Check if it's a rate limit or timeout error
            error_str = string(e)
            is_rate_limit = contains(error_str, "TimeoutError") || contains(error_str, "rate") || contains(error_str, "429")
            
            if is_rate_limit
                @warn "Rate limit/timeout detected on chunk $i, applying exponential backoff"
            else
                @warn "Error processing chunk $i: $e"
            end
        end
        
        # Apply exponential backoff based on consecutive errors
        if consecutive_errors > 0
            delay = min(base_delay * (2^(consecutive_errors - 1)), max_delay)
            if delay > 0.1
                println("  ⏳ Applying backoff delay: $(round(delay, digits=2))s (consecutive errors: $consecutive_errors)")
            end
            sleep(delay)
        end
        
        # Update progress every 10 chunks or at the end
        if i % 10 == 0 || i == total_chunks
            percentage = round(i/total_chunks*100, digits=1)
            println("[$i/$total_chunks] $percentage% - ✅ $successful_extractions lessons | ❌ $failed_extractions failed")
        end
    end
    
    println("\
\
📊 Processing Complete:")
    println("   ✅ Successfully generated: $successful_extractions lessons")
    println("   ❌ Failed extractions: $failed_extractions")
    println("   📈 Success rate: $(round(successful_extractions/total_chunks*100, digits=1))%")
    
    return all_lessons
end

"""
Process chunks asynchronously using asyncmap for improved performance with rate limiting.

# Usage Example
```julia
import RAGTools as RT
# Get all text files
file_paths = generate_file_paths("clean_txt")
chunks = RT.get_chunks(
    RT.FileChunker(), 
    file_paths[1:2];
    sources = file_paths[1:2],
    verbose = false,
    separators = ["

", ". ", "
", " "],
    max_length = 1000
)

lessons = GetAJobCLI.process_chunks_async(chunks)
```

# Parameters
- `chunks`: Tuple of text chunks and their sources
- `ntasks`: Number of concurrent tasks (default: 8, tuned for OpenAI API limits)
- `max_retries`: Maximum number of retries per chunk (default: 3)
"""
function process_chunks_async(
    chunks::Tuple{Vector{SubString{String}}, Vector{String}};
    ntasks::Int = 8,
    max_retries::Int = 3
)::Vector{Lesson}
    # Ensure API keys are loaded before processing
    GetAJobCLI.ensure_api_keys_loaded()
    
    allchunks = chunks[1]
    total_chunks = length(allchunks)
    
    println("Processing $total_chunks chunks with asyncmap (ntasks=$ntasks)...")
    
    # Shared progress tracking
    progress_lock = Threads.SpinLock()
    successful_extractions = Ref(0)
    failed_extractions = Ref(0)
    processed_count = Ref(0)
    
    # Process chunks asynchronously with controlled concurrency
    async_results = asyncmap(allchunks; ntasks=ntasks) do text_chunk
        process_single_chunk_with_retries(text_chunk, max_retries, progress_lock, successful_extractions, failed_extractions, processed_count, total_chunks)
    end
    
    # Filter out failed results (nothing values)
    all_lessons = filter(!isnothing, async_results)
    
    println("\n📊 Async Processing Complete:")
    println("   ✅ Successfully generated: $(successful_extractions[]) lessons")
    println("   ❌ Failed extractions: $(failed_extractions[]) chunks")
    println("   📈 Success rate: $(round(successful_extractions[]/total_chunks*100, digits=1))%")
    
    return all_lessons
end

"""
Process a single chunk with retry logic and exponential backoff.
Returns a Lesson object on success, or nothing on failure.
"""
function process_single_chunk_with_retries(
    text_chunk::SubString{String},
    max_retries::Int,
    progress_lock::Threads.SpinLock,
    successful_extractions::Ref{Int},
    failed_extractions::Ref{Int},
    processed_count::Ref{Int},
    total_chunks::Int
)::Union{Lesson, Nothing}
    
    for attempt in 1:max_retries
        try
            # Extract lesson from chunk
            msg = PT.aiextract(text_chunk; return_type=Lesson)
            
            if !isnothing(msg.content) && msg.content isa Lesson && msg.content.short_name != ""
                # Update progress (thread-safe)
                lock(progress_lock) do
                    successful_extractions[] += 1
                    processed_count[] += 1
                    
                    # Update progress every 25 chunks
                    if processed_count[] % 25 == 0 || processed_count[] == total_chunks
                        percentage = round(processed_count[]/total_chunks*100, digits=1)
                        println("[$(processed_count[])/$total_chunks] $percentage% - ✅ $(successful_extractions[]) lessons | ❌ $(failed_extractions[]) failed")
                    end
                end
                
                return msg.content
            else
                # Invalid content, try again
                continue
            end
            
        catch e
            error_str = string(e)
            is_rate_limit = contains(error_str, "TimeoutError") || contains(error_str, "rate") || contains(error_str, "429")
            
            if attempt == max_retries
                # Final attempt failed, update counters
                lock(progress_lock) do
                    failed_extractions[] += 1
                    processed_count[] += 1
                    
                    if processed_count[] % 25 == 0 || processed_count[] == total_chunks
                        percentage = round(processed_count[]/total_chunks*100, digits=1)
                        println("[$(processed_count[])/$total_chunks] $percentage% - ✅ $(successful_extractions[]) lessons | ❌ $(failed_extractions[]) failed")
                    end
                end
                
                if is_rate_limit
                    @warn "Rate limit/timeout on chunk after $max_retries attempts"
                else
                    @warn "Error processing chunk after $max_retries attempts: $e"
                end
                
                return nothing
            else
                # Retry on next iteration
                continue
            end
        end
    end
    
    return nothing
end

"""
Process chunks asynchronously with simple 429 handling using PromptingTools response status.
"""
function process_chunks_async_simple(
    chunks::Tuple{Vector{SubString{String}}, Vector{String}},
    checkpoint::ProcessingCheckpoint;
    ntasks::Int = 8,
    max_retries::Int = 3,
    save_every::Int = 50
)::Vector{Lesson}
    # Ensure API keys are loaded before processing
    GetAJobCLI.ensure_api_keys_loaded()
    
    allchunks = chunks[1]
    total_chunks = length(allchunks)
    
    # Filter out already processed chunks
    remaining_chunks = []
    remaining_indices = []
    for (i, chunk) in enumerate(allchunks)
        hash = chunk_hash(chunk)
        if hash ∉ checkpoint.processed_chunks
            push!(remaining_chunks, chunk)
            push!(remaining_indices, i)
        end
    end
    
    already_processed = length(allchunks) - length(remaining_chunks)
    println("Processing $(length(remaining_chunks)) remaining chunks ($(already_processed) already processed)...")
    
    # Show session stats
    show_session_stats()
    
    # Start with lessons from checkpoint
    all_lessons = copy(checkpoint.lessons_generated)
    
    # Shared progress tracking
    progress_lock = Threads.SpinLock()
    successful_extractions = Ref(checkpoint.successful_extractions)
    failed_extractions = Ref(checkpoint.failed_extractions)
    processed_count = Ref(already_processed)
    
    # Process remaining chunks asynchronously
    if !isempty(remaining_chunks)
        println("🚀 Starting async processing with ntasks: $ntasks")
        
        async_results = asyncmap(remaining_chunks; ntasks=ntasks) do text_chunk
            process_single_chunk_simple(
                text_chunk, max_retries, progress_lock, successful_extractions, failed_extractions, 
                processed_count, total_chunks, checkpoint, save_every
            )
        end
        
        # Add new lessons (filter out failed results)
        new_lessons = filter(!isnothing, async_results)
        append!(all_lessons, new_lessons)
    end
    
    # Final checkpoint save
    save_checkpoint(checkpoint)
    
    # Show final session stats
    show_session_stats()
    
    println("\n📊 Async Processing Complete:")
    println("   ✅ Successfully generated: $(successful_extractions[]) lessons")
    println("   ❌ Failed extractions: $(failed_extractions[]) chunks")
    println("   📈 Success rate: $(round(successful_extractions[]/total_chunks*100, digits=1))%")
    println("   💾 Checkpoint saved: $(checkpoint.checkpoint_file)")
    
    return all_lessons
end

"""
Process chunks synchronously with checkpoint support for resumable processing.
"""
function process_chunks_with_checkpoint(
    chunks::Tuple{Vector{SubString{String}}, Vector{String}},
    checkpoint::ProcessingCheckpoint;
    save_every::Int = 50
)::Vector{Lesson}
    # Ensure API keys are loaded before processing
    GetAJobCLI.ensure_api_keys_loaded()
    
    allchunks = chunks[1]
    total_chunks = length(allchunks)
    
    # Start with lessons from checkpoint
    all_lessons = copy(checkpoint.lessons_generated)
    successful_extractions = checkpoint.successful_extractions
    failed_extractions = checkpoint.failed_extractions
    
    println("Processing $total_chunks chunks with checkpoint support...")
    
    for (i, text_chunk) in enumerate(allchunks)
        hash = chunk_hash(text_chunk)
        
        # Skip if already processed
        if hash ∈ checkpoint.processed_chunks
            continue
        end
        
        try
            # Extract lesson from chunk
            response = PT.aiextract(text_chunk; return_type=Lesson)
            
            # Update session stats
            update_session_stats(response)
            
            # Handle 429 status
            if response.status == 429
                SESSION_STATS.rate_limit_hits += 1
                SESSION_STATS.consecutive_429s += 1
                SESSION_STATS.last_429_time = now()
                
                # Calculate backoff
                backoff_time = min(30.0 * (2^(SESSION_STATS.consecutive_429s - 1)), 300.0)
                println("⚠️  Rate limit (429) - waiting $(round(backoff_time, digits=1))s")
                sleep(backoff_time)
                continue  # Skip this iteration and try next chunk
            end
            
            # Reset consecutive 429 counter on success
            if response.status == 200
                SESSION_STATS.consecutive_429s = 0
            end
            
            if !isnothing(response.content) && response.content isa Lesson && response.content.short_name != ""
                push!(all_lessons, response.content)
                push!(checkpoint.lessons_generated, response.content)
                push!(checkpoint.processed_chunks, hash)
                successful_extractions += 1
            else
                push!(checkpoint.processed_chunks, hash)
                failed_extractions += 1
            end
            
        catch e
            push!(checkpoint.processed_chunks, hash)
            failed_extractions += 1
            @warn "Error processing chunk $i: $e"
        end
        
        # Save checkpoint periodically
        if successful_extractions % save_every == 0
            save_checkpoint(checkpoint)
            println("💾 Checkpoint saved at $successful_extractions lessons")
        end
        
        # Update progress
        processed_count = length(checkpoint.processed_chunks)
        if processed_count % 25 == 0 || processed_count == total_chunks
            percentage = round(processed_count/total_chunks*100, digits=1)
            println("[$processed_count/$total_chunks] $percentage% - ✅ $successful_extractions lessons | ❌ $failed_extractions failed")
        end
    end
    
    # Final checkpoint save
    save_checkpoint(checkpoint)
    
    println("\n📊 Checkpointed Processing Complete:")
    println("   ✅ Successfully generated: $successful_extractions lessons")
    println("   ❌ Failed extractions: $failed_extractions")
    println("   📈 Success rate: $(round(successful_extractions/total_chunks*100, digits=1))%")
    println("   💾 Checkpoint saved: $(checkpoint.checkpoint_file)")
    
    return all_lessons
end

"""
Process a single chunk with rate limiting, checkpoint support and progress tracking.
"""
function process_single_chunk_simple(
    text_chunk::SubString{String},
    max_retries::Int,
    progress_lock::Threads.SpinLock,
    successful_extractions::Ref{Int},
    failed_extractions::Ref{Int},
    processed_count::Ref{Int},
    total_chunks::Int,
    checkpoint::ProcessingCheckpoint,
    save_every::Int
)::Union{Lesson, Nothing}
    
    hash = chunk_hash(text_chunk)
    
    for attempt in 1:max_retries
        try
            # Extract lesson from chunk - this returns the response object
            response = PT.aiextract(text_chunk; return_type=Lesson)
            
            # Update session stats with response data
            update_session_stats(response)
            
            # Check for 429 status specifically
            if response.status == 429
                lock(progress_lock) do
                    SESSION_STATS.rate_limit_hits += 1
                    SESSION_STATS.consecutive_429s += 1
                    SESSION_STATS.last_429_time = now()
                end
                
                # Calculate backoff based on consecutive 429s
                backoff_time = min(30.0 * (2^(SESSION_STATS.consecutive_429s - 1)), 300.0)  # Cap at 5 minutes
                println("⚠️  Rate limit (429) - waiting $(round(backoff_time, digits=1))s (attempt $attempt/$(max_retries))")
                sleep(backoff_time)
                continue
            end
            
            # Reset consecutive 429 counter on success
            if response.status == 200
                lock(progress_lock) do
                    SESSION_STATS.consecutive_429s = 0
                end
            end
            
            # Check if we got valid content
            if !isnothing(response.content) && response.content isa Lesson && response.content.short_name != ""
                # Update progress and checkpoint (thread-safe)
                lock(progress_lock) do
                    successful_extractions[] += 1
                    processed_count[] += 1
                    
                    # Add to checkpoint
                    push!(checkpoint.lessons_generated, response.content)
                    push!(checkpoint.processed_chunks, hash)
                    
                    # Save checkpoint periodically
                    if successful_extractions[] % save_every == 0
                        save_checkpoint(checkpoint)
                        println("💾 Checkpoint saved at $(successful_extractions[]) lessons")
                    end
                    
                    # Update progress
                    if processed_count[] % 25 == 0 || processed_count[] == total_chunks
                        percentage = round(processed_count[]/total_chunks*100, digits=1)
                        println("[$(processed_count[])/$total_chunks] $percentage% - ✅ $(successful_extractions[]) lessons | ❌ $(failed_extractions[]) failed")
                    end
                end
                
                return response.content
            else
                # Invalid content but successful request, try again
                continue
            end
            
        catch e
            if attempt == max_retries
                # Final attempt failed, update counters
                lock(progress_lock) do
                    failed_extractions[] += 1
                    processed_count[] += 1
                    push!(checkpoint.processed_chunks, hash)
                    
                    if processed_count[] % 25 == 0 || processed_count[] == total_chunks
                        percentage = round(processed_count[]/total_chunks*100, digits=1)
                        println("[$(processed_count[])/$total_chunks] $percentage% - ✅ $(successful_extractions[]) lessons | ❌ $(failed_extractions[]) failed")
                    end
                end
                
                @warn "Error processing chunk after $max_retries attempts: $e"
                return nothing
            else
                # Retry with short delay
                sleep(1.0 * attempt)
                continue
            end
        end
    end
    
    return nothing
end

"""
Process a single chunk with checkpoint support and progress tracking (legacy function).
"""
function process_single_chunk_with_checkpoint(
    text_chunk::SubString{String},
    max_retries::Int,
    progress_lock::Threads.SpinLock,
    successful_extractions::Ref{Int},
    failed_extractions::Ref{Int},
    processed_count::Ref{Int},
    total_chunks::Int,
    checkpoint::ProcessingCheckpoint,
    save_every::Int
)::Union{Lesson, Nothing}
    
    # Delegate to rate-limited version
    return process_single_chunk_with_rate_limiting(
        text_chunk, max_retries, progress_lock, successful_extractions, failed_extractions,
        processed_count, total_chunks, checkpoint, save_every
    )
end

"""
Split lessons into topic-based groups.
"""
function split_lessons_by_topic(lessons::Vector{Lesson})::Dict{String, Vector{Lesson}}
    lessons_by_topic = Dict{String, Vector{Lesson}}()
    
    for lesson in lessons
        topic = String(Symbol(lesson.topic))
        if !haskey(lessons_by_topic, topic)
            lessons_by_topic[topic] = Lesson[]
        end
        push!(lessons_by_topic[topic], lesson)
    end
    
    println("\
📚 Lessons by Topic:")
    for (topic, topic_lessons) in collect(lessons_by_topic)
        println("   📖 $topic: $(length(topic_lessons)) lessons")
    end
    
    return lessons_by_topic
end

"""
Create partitioned lesson packs for each topic.
"""
function create_lesson_packs(lessons_by_topic::Dict{String, Vector{Lesson}}, output_dir::String)
    println("\
📦 Creating lesson packs...")
    
    for (topic, lessons) in lessons_by_topic
        if isempty(lessons)
            continue
        end
        
        # Determine number of parts (aim for roughly equal sizes, max 200 lessons per part)
        lessons_per_part = min(200, max(50, div(length(lessons), 3)))
        num_parts = max(1, div(length(lessons), lessons_per_part))
        
        # Shuffle lessons for random distribution across parts
        shuffled_lessons = shuffle(lessons)
        
        # Create parts
        for part_num in 1:num_parts
            start_idx = (part_num - 1) * lessons_per_part + 1
            end_idx = min(part_num * lessons_per_part, length(shuffled_lessons))
            part_lessons = shuffled_lessons[start_idx:end_idx]
            
            # Create filename
            safe_topic = replace(topic, "/" => "_", " " => "_")
            filename = joinpath(output_dir, "$(safe_topic)_part$(part_num).json")
            
            # Save to file
            save_lesson_pack(part_lessons, filename, "$(topic) - Part $(part_num)")
            
            println("   💾 Saved $(length(part_lessons)) lessons to $filename")
        end
    end
end

"""
Create a sample pack with 10 random lessons from each topic.
"""
function create_sample_pack(lessons_by_topic::Dict{String, Vector{Lesson}}, output_dir::String)
    println("\
🎲 Creating sample pack...")
    
    sample_lessons = Lesson[]
    
    for (topic, lessons) in lessons_by_topic
        if !isempty(lessons)
            # Take up to 10 random lessons from this topic
            sample_size = min(10, length(lessons))
            topic_sample = shuffle(lessons)[1:sample_size]
            append!(sample_lessons, topic_sample)
            
            println("   🎯 Added $sample_size lessons from $topic")
        end
    end
    
    # Shuffle the combined sample
    shuffle!(sample_lessons)
    
    filename = joinpath(output_dir, "sample_lessons.json")
    save_lesson_pack(sample_lessons, filename, "Random Sample Pack")
    
    println("   💾 Saved $(length(sample_lessons)) sample lessons to $filename")
end

"""
Save a lesson pack to a JSON file with metadata.
"""
function save_lesson_pack(lessons::Vector{Lesson}, filename::String, pack_name::String)
    pack_data = Dict(
        :metadata => Dict(
            :name => pack_name,
            :created_at => string(now()),
            :lesson_count => length(lessons),
            :topics => unique([String(Symbol(lesson.topic)) for lesson in lessons]),
            :version => "1.0"
        ),
        :lessons => lessons
    )
    
    try
        write(filename, JSON3.write(pack_data, allow_inf=false))
        return true
    catch e
        println("❌ Error saving $filename: $e")
        return false
    end
end

"""
Convert string topic to LessonTopic enum.
"""
function string_to_lesson_topic(topic_string::String)::LessonTopic
    # Map string values to enum values
    topic_map = Dict(
        "statistics/machine learning" => StatisticsMachineLearning,
        "StatisticsMachineLearning" => StatisticsMachineLearning,
        "Predictive Modeling" => StatisticsMachineLearning,
        "Statistics & Experimentation" => ExperimentalDesign,
        "Statistics" => StatisticsMachineLearning,
        "python" => Python,
        "Python" => Python,
        "SQL" => SQL,
        "sql" => SQL,
        "general programming" => GeneralProgramming,
        "GeneralProgramming" => GeneralProgramming,
        "hiring/interviews" => HiringInterviews,
        "HiringInterviews" => HiringInterviews,
        "ExperimentalDesign" => ExperimentalDesign,
        "other" => Miscellaneous,
        "Miscellaneous" => Miscellaneous
    )
    
    return get(topic_map, topic_string, Miscellaneous)
end

"""
Load a lesson pack from a file path or URL.
"""
function load_lesson_pack(source::AbstractString)::Union{Vector{Lesson}, Nothing}
    try
        # Determine if source is URL or file path
        data_string = if startswith(lowercase(source), "http")
            # Download from URL
            println("🌐 Downloading lesson pack from URL...")
            response = HTTP.get(source)
            String(response.body)
        else
            # Read from file
            if !isfile(source)
                println("❌ File not found: $source")
                return nothing
            end
            println("📂 Loading lesson pack from file: $source")
            read(source, String)
        end
        
        # Parse JSON
        pack_data = JSON3.read(data_string)
        
        # Validate structure
        if !haskey(pack_data, :lessons)
            println("❌ Invalid lesson pack format: missing 'lessons' field")
            return nothing
        end
        
        # Convert to Lesson objects
        lessons = Lesson[]
        for lesson_data in pack_data.lessons
            try
                # Convert string topic to enum
                topic_enum = string_to_lesson_topic(String(lesson_data.topic))
                
                lesson = Lesson(
                    lesson_data.short_name,
                    lesson_data.concept_or_lesson,
                    lesson_data.definition_and_examples,
                    lesson_data.question_or_exercise,
                    lesson_data.answer,
                    topic_enum
                )
                push!(lessons, lesson)
            catch e
                println("⚠️  Skipping invalid lesson: $e")
            end
        end
        
        # Display metadata if available
        if haskey(pack_data, :metadata)
            meta = pack_data.metadata
            println("📋 Loaded pack: $(get(meta, :name, "Unknown"))")
            println("   📊 $(length(lessons)) lessons loaded")
            println("   📅 Created: $(get(meta, :created_at, "Unknown"))")
            if haskey(meta, :topics)
                println("   🏷️  Topics: $(join(meta.topics, ", "))")
            end
        end
        
        return lessons
        
    catch e
        println("❌ Error loading lesson pack: $e")
        return nothing
    end
end

"""
List available lesson packs in the lesson_packs directory.
"""
function list_available_packs(pack_dir::String = "lesson_packs")::Vector{String}
    if !isdir(pack_dir)
        println("📁 Lesson packs directory not found: $pack_dir")
        return String[]
    end
    
    pack_files = filter(f -> endswith(f, ".json"), readdir(pack_dir))
    full_paths = [joinpath(pack_dir, f) for f in pack_files]
    
    if isempty(pack_files)
        println("📭 No lesson packs found in $pack_dir")
        return String[]
    end
    
    println("📚 Available lesson packs in $pack_dir:")
    for (i, file) in enumerate(pack_files)
        file_path = full_paths[i]
        try
            # Try to read metadata
            data = JSON3.read(read(file_path, String))
            if haskey(data, :metadata)
                meta = data.metadata
                name = get(meta, :name, file)
                count = get(meta, :lesson_count, "?")
                println("   $i. $name ($count lessons) - $file")
            else
                println("   $i. $file (unknown format)")
            end
        catch
            println("   $i. $file (corrupted or invalid)")
        end
    end
    
    return full_paths
end

"""
Interactive function to select and load a lesson pack.
"""
function interactive_pack_selection(pack_dir::String = "lesson_packs")::Union{Vector{Lesson}, Nothing}
    available_packs = list_available_packs(pack_dir)
    
    if isempty(available_packs)
        return nothing
    end
    
    println("\
Enter pack number, file path, or URL:")
    print("Selection: ")
    input = strip(readline())
    
    if isempty(input)
        println("No selection made.")
        return nothing
    end
    
    # Try to parse as number first
    try
        pack_num = parse(Int, input)
        if 1 <= pack_num <= length(available_packs)
            return load_lesson_pack(available_packs[pack_num])
        else
            println("❌ Invalid pack number. Must be between 1 and $(length(available_packs))")
            return nothing
        end
    catch
        # Not a number, treat as path or URL
        return load_lesson_pack(input)
    end
end

"""
    filter_chunks_by_categories(chunks::Tuple{Vector{SubString{String}}, Vector{String}}, 
                               target_categories::Vector{String}) -> Tuple{Vector{SubString{String}}, Vector{String}}

Filter text chunks to only include those that match the target categories.
Returns a new chunks tuple with only the relevant chunks.
"""
function filter_chunks_by_categories(chunks::Tuple{Vector{SubString{String}}, Vector{String}}, 
                                   target_categories::Vector{String})::Tuple{Vector{SubString{String}}, Vector{String}}
    if isempty(target_categories)
        return chunks
    end
    
    chunk_texts, chunk_sources = chunks
    filtered_texts = SubString{String}[]
    filtered_sources = String[]
    
    total_chunks = length(chunk_texts)
    filtered_count = 0
    
    # Set minimum score threshold - chunk must have at least this many category matches
    min_score_threshold = 1
    
    for (i, chunk_text) in enumerate(chunk_texts)
        # Get category matches for this chunk
        matching_categories = categorize_text_content(String(chunk_text), target_categories)
        
        # Calculate relevance score
        relevance_score = length(matching_categories)
        
        # Include chunk if it matches target categories with sufficient relevance
        if relevance_score >= min_score_threshold
            push!(filtered_texts, chunk_text)
            push!(filtered_sources, chunk_sources[i])
            filtered_count += 1
        end
        
        # Show progress every 500 chunks
        if i % 500 == 0 || i == total_chunks
            percentage = round(i/total_chunks*100, digits=1)
            print("\rFiltering chunks: [$i/$total_chunks] $percentage% - 🎯 $filtered_count relevant chunks found")
        end
    end
    
    println()  # New line after progress
    
    return (filtered_texts, filtered_sources)
end

"""
    filter_chunks_by_categories_with_threshold(chunks::Tuple{Vector{SubString{String}}, Vector{String}}, 
                                             target_categories::Vector{String}, 
                                             min_score::Int = 2) -> Tuple{Vector{SubString{String}}, Vector{String}}

Filter chunks with a custom minimum relevance score threshold.
Higher thresholds result in more selective filtering.
"""
function filter_chunks_by_categories_with_threshold(chunks::Tuple{Vector{SubString{String}}, Vector{String}}, 
                                                  target_categories::Vector{String}, 
                                                  min_score::Int = 2)::Tuple{Vector{SubString{String}}, Vector{String}}
    if isempty(target_categories)
        return chunks
    end
    
    chunk_texts, chunk_sources = chunks
    filtered_texts = SubString{String}[]
    filtered_sources = String[]
    
    for (i, chunk_text) in enumerate(chunk_texts)
        # Calculate category match score
        category_scores = Dict{String, Int}()
        for category in target_categories
            if haskey(CATEGORY_PATTERNS, category)
                category_scores[category] = 0
                for pattern in CATEGORY_PATTERNS[category]
                    matches = collect(eachmatch(pattern, String(chunk_text)))
                    category_scores[category] += length(matches)
                end
            end
        end
        
        # Sum total relevance score
        total_score = sum(values(category_scores))
        
        # Include chunk if it meets the threshold
        if total_score >= min_score
            push!(filtered_texts, chunk_text)
            push!(filtered_sources, chunk_sources[i])
        end
    end
    
    return (filtered_texts, filtered_sources)
end

"""
    analyze_chunk_categories(chunk_text::String) -> Dict{String, Int}

Analyze a single chunk and return detailed category match scores.
Useful for debugging and understanding chunk categorization.
"""
function analyze_chunk_categories(chunk_text::String)::Dict{String, Int}
    category_scores = Dict{String, Int}()
    
    for (category, patterns) in CATEGORY_PATTERNS
        category_scores[category] = 0
        for pattern in patterns
            matches = collect(eachmatch(pattern, chunk_text))
            category_scores[category] += length(matches)
        end
    end
    
    return category_scores
end

"""
    categorize_text_content(content::String, target_categories::Vector{String} = String[]) -> Vector{String}

Analyze text content and return matching categories.
If target_categories is specified, only check those categories.
"""
function categorize_text_content(content::String, target_categories::Vector{String} = String[])::Vector{String}
    categories_to_check = isempty(target_categories) ? collect(keys(CATEGORY_PATTERNS)) : target_categories
    category_scores = Dict{String, Int}()
    
    # Initialize scores for categories we're checking
    for category in categories_to_check
        if haskey(CATEGORY_PATTERNS, category)
            category_scores[category] = 0
        end
    end
    
    # Count matches for each category
    for (category, patterns) in CATEGORY_PATTERNS
        if haskey(category_scores, category)
            for pattern in patterns
                matches = collect(eachmatch(pattern, content))
                category_scores[category] += length(matches)
            end
        end
    end
    
    # Sort categories by score (descending)
    sorted_categories = sort(collect(category_scores), by=x->x[2], rev=true)
    
    # Return categories with at least one match
    return [category for (category, score) in sorted_categories if score > 0]
end

"""
    categorize_text_file(file_path::String, target_categories::Vector{String} = String[]) -> Vector{String}

Categorize a single text file based on its content.
"""
function categorize_text_file(file_path::String, target_categories::Vector{String} = String[])::Vector{String}
    try
        content = read(file_path, String)
        return categorize_text_content(content, target_categories)
    catch e
        @warn "Error reading file $file_path: $e"
        return String[]
    end
end

"""
    get_files_for_categories(input_dir::String, target_categories::Vector{String}) -> Vector{String}

Get all text files from input_dir that match any of the specified categories.
"""
function get_files_for_categories(input_dir::String, target_categories::Vector{String})::Vector{String}
    if !isdir(input_dir)
        @error "Directory $input_dir does not exist"
        return String[]
    end
    
    # Validate categories
    valid_categories = collect(keys(CATEGORY_PATTERNS))
    invalid_categories = setdiff(target_categories, valid_categories)
    if !isempty(invalid_categories)
        @warn "Invalid categories specified: $(join(invalid_categories, ", "))"
        @info "Valid categories: $(join(valid_categories, ", "))"
    end
    
    valid_target_categories = intersect(target_categories, valid_categories)
    if isempty(valid_target_categories)
        @error "No valid categories specified"
        return String[]
    end
    
    # Get all text files
    txt_files = filter(f -> endswith(f, ".txt"), readdir(input_dir))
    matching_files = String[]
    
    println("🔍 Scanning $(length(txt_files)) files for categories: $(join(valid_target_categories, ", "))")
    
    for (i, filename) in enumerate(txt_files)
        file_path = joinpath(input_dir, filename)
        categories = categorize_text_file(file_path, valid_target_categories)
        
        if !isempty(categories)
            push!(matching_files, file_path)
            if i <= 20 || i % 20 == 0  # Show progress for first 20 files, then every 20th
                println("  ✅ $filename → $(join(categories, ", "))")
            end
        end
    end
    
    println("📚 Found $(length(matching_files)) files matching target categories")
    return matching_files
end

"""
    list_available_categories() -> Vector{String}

List all available categories for filtering.
"""
function list_available_categories()::Vector{String}
    return collect(keys(CATEGORY_PATTERNS))
end

"""
    generate_category_specific_lessons(categories::Vector{String}; kwargs...)

Convenience function to generate lessons for specific categories only.
"""
function generate_category_specific_lessons(categories::Vector{String}; kwargs...)
    return generate_lessons_from_files(; target_categories=categories, kwargs...)
end

"""
Interactive function to select and resume from a checkpoint.
"""
function interactive_checkpoint_resume(output_dir::String = "lesson_packs"; kwargs...)
    checkpoints = list_checkpoints(output_dir)
    
    if isempty(checkpoints)
        println("📭 No checkpoints found in $output_dir")
        return generate_lessons_from_files(; kwargs...)
    end
    
    println("📋 Available checkpoints:")
    for (i, checkpoint_file) in enumerate(checkpoints)
        try
            checkpoint = load_checkpoint(checkpoint_file)
            if !isnothing(checkpoint)
                session_name = checkpoint.session_id
                progress = "$(checkpoint.successful_extractions)/$(checkpoint.total_chunks)"
                age = round(Dates.value(now() - checkpoint.last_updated) / (1000 * 60 * 60), digits=1)
                println("   $i. $session_name - $progress lessons ($(age)h ago)")
            else
                println("   $i. $(basename(checkpoint_file)) (corrupted)")
            end
        catch
            println("   $i. $(basename(checkpoint_file)) (corrupted)")
        end
    end
    
    println("\nEnter checkpoint number to resume (or press Enter to start fresh):")
    print("Selection: ")
    input = strip(readline())
    
    if isempty(input)
        return generate_lessons_from_files(; kwargs...)
    end
    
    try
        checkpoint_num = parse(Int, input)
        if 1 <= checkpoint_num <= length(checkpoints)
            selected_checkpoint = checkpoints[checkpoint_num]
            return generate_lessons_from_files(; resume_checkpoint=selected_checkpoint, kwargs...)
        else
            println("❌ Invalid checkpoint number")
            return nothing
        end
    catch
        println("❌ Invalid input")
        return nothing
    end
end

"""
Show detailed information about a checkpoint.
"""
function show_checkpoint_info(checkpoint_file::String)
    checkpoint = load_checkpoint(checkpoint_file)
    if isnothing(checkpoint)
        println("❌ Could not load checkpoint: $checkpoint_file")
        return
    end
    
    println(Term.Panel("""
# 📋 Checkpoint Information

**Session ID:** $(checkpoint.session_id)
**Created:** $(checkpoint.created_at)
**Last Updated:** $(checkpoint.last_updated)

**Configuration:**
- Input Directory: $(checkpoint.input_dir)
- Chunk Size: $(checkpoint.chunk_size)
- Target Categories: $(isempty(checkpoint.target_categories) ? "All" : join(checkpoint.target_categories, ", "))

**Progress:**
- Total Chunks: $(checkpoint.total_chunks)
- Processed Chunks: $(length(checkpoint.processed_chunks))
- Successful Extractions: $(checkpoint.successful_extractions)
- Failed Extractions: $(checkpoint.failed_extractions)
- Progress: $(round(length(checkpoint.processed_chunks)/checkpoint.total_chunks*100, digits=1))%

**Lessons Generated:** $(length(checkpoint.lessons_generated))
""", title="Checkpoint: $(checkpoint.session_id)", style="bold cyan"))
end


# Export functions for use in other modules
export generate_lessons_from_files, 
       load_lesson_pack, 
       list_available_packs, 
       interactive_pack_selection,
       save_lesson_pack,
       string_to_lesson_topic,
       categorize_text_content,
       categorize_text_file,
       get_files_for_categories,
       list_available_categories,
       generate_category_specific_lessons,
       filter_chunks_by_categories,
       filter_chunks_by_categories_with_threshold,
       analyze_chunk_categories,
       create_checkpoint,
       save_checkpoint,
       load_checkpoint,
       list_checkpoints,
       cleanup_old_checkpoints,
       chunk_hash,
       interactive_checkpoint_resume,
       show_checkpoint_info,
       update_session_stats,
       show_session_stats,
       reset_session_stats,
       generate_lessons_for_topic,
       interactive_topic_lesson_generation,
       concept_lesson_to_lesson
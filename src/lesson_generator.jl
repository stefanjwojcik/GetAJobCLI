## Lesson Generation Script - Process clean_txt files into structured lessons
import RAGTools as RT
using JSON3
using Term
using Random
using HTTP
using Dates

"""
Generate lessons from all files in the clean_txt directory with progress tracking and error handling.
"""
function generate_lessons_from_files(
    input_dir::String = "clean_txt";
    output_dir::String = "lesson_packs",
    max_files::Int = -1,
    chunk_size::Int = 1000,
    verbose::Bool = true,
    use_async::Bool = true
)
    println(Term.Panel("""
# 🏭 Lesson Generation Pipeline

Processing text files to generate structured lessons...

**Input Directory:** $input_dir
**Output Directory:** $output_dir
**Max Files:** $(max_files == -1 ? "All" : max_files)
**Chunk Size:** $chunk_size characters
""", title="Lesson Generator", style="bold blue"))
    
    # Ensure output directory exists
    if !isdir(output_dir)
        mkpath(output_dir)
        println("📁 Created output directory: $output_dir")
    end
    
    # Get all text files
    file_paths = generate_file_paths(input_dir)
    if max_files > 0
        file_paths = file_paths[1:min(max_files, length(file_paths))]
    end
    
    println("📚 Found $(length(file_paths)) files to process")
    
    # Generate chunks from all files
    println("\n🔄 Generating text chunks...")
    chunks = RT.get_chunks(
        RT.FileChunker(), 
        file_paths;
        sources = file_paths,
        verbose = verbose,
        separators = ["\n\n", ". ", "\n", " "],
        max_length = chunk_size
    )
    
    println("📝 Generated $(length(chunks[1])) chunks from $(length(file_paths)) files")
    
    # Process chunks with progress tracking and error handling
    println("\n🧠 Processing chunks into lessons...")
    all_lessons = if use_async
        process_chunks_async(chunks)
    else
        process_chunks_with_progress(chunks)
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
    
    return lessons_by_topic
end

"""
Process chunks into lessons with progress tracking and error handling.
"""
function process_chunks_with_progress(chunks::Tuple{Vector{SubString{String}}, Vector{String}})::Vector{Lesson}
    all_lessons = Lesson[]
    total_chunks = length(chunks[1])
    successful_extractions = 0
    failed_extractions = 0
    
    println("Processing $total_chunks chunks...")
    
    for (i, text_chunk) in enumerate(chunks[1])
        try
            # Extract lesson from chunk
            msg = aiextract(text_chunk; return_type=Lesson)
            
            if !isnothing(msg.content)
                push!(all_lessons, msg.content)
                successful_extractions += 1
            else
                failed_extractions += 1
            end
            
        catch e
            failed_extractions += 1
        end
        
        # Update progress every 10 chunks or at the end
        if i % 10 == 0 || i == total_chunks
            percentage = round(i/total_chunks*100, digits=1)
            println("[$i/$total_chunks] $percentage% - ✅ $successful_extractions lessons | ❌ $failed_extractions failed")
        end
    end
    
    println("\\n\\n📊 Processing Complete:")
    println("   ✅ Successfully generated: $successful_extractions lessons")
    println("   ❌ Failed extractions: $failed_extractions")
    println("   📈 Success rate: $(round(successful_extractions/total_chunks*100, digits=1))%")
    
    return all_lessons
end

"""
Process chunks asynchronously to improve performance.
import RAGTools as RT
    # Get all text files
    file_paths = generate_file_paths("clean_txt")
    chunks = RT.get_chunks(
        RT.FileChunker(), 
        file_paths[1:2];
        sources = file_paths[1:2],
        verbose = false,
        separators = ["\n\n", ". ", "\n", " "],
        max_length = 1000
    )

lessons = GetAJobCLI.process_chunks_async(chunks)

"""
function process_chunks_async(chunks::Tuple{Vector{SubString{String}}, Vector{String}})::Vector{Lesson}
    allchunks = chunks[1]
    total_chunks = length(allchunks)
    successful_extractions = 0
    failed_extractions = 0
    
    println("Processing $total_chunks chunks asynchronously...")
    
    # Create a function that wraps aiextract with error handling
    function extract_with_error_handling(text_chunk)
        msg = PT.aiextract(text_chunk; return_type=Lesson)
        return msg.content
    end
    
    # Use asyncmap to process all chunks concurrently
    responses = asyncmap(extract_with_error_handling, allchunks)
    
    # Process results and collect lessons
    all_lessons = Lesson[]
    for (i, lesson) in enumerate(responses)
        if lesson isa Lesson && lesson.short_name != ""
            push!(all_lessons, lesson)
            successful_extractions += 1
        else
            failed_extractions += 1
        end
        
        # Update progress every 100 chunks or at the end
        if i % 100 == 0 || i == total_chunks
            percentage = round(i/total_chunks*100, digits=1)
            println("[$i/$total_chunks] $percentage% - ✅ $successful_extractions lessons | ❌ $failed_extractions failed")
        end
    end
    
    println("\\n\\n📊 Async Processing Complete:")
    println("   ✅ Successfully generated: $successful_extractions lessons")
    println("   ❌ Failed extractions: $failed_extractions")
    println("   📈 Success rate: $(round(successful_extractions/total_chunks*100, digits=1))%")
    
    return all_lessons
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
    
    println("\\n📚 Lessons by Topic:")
    for (topic, topic_lessons) in collect(lessons_by_topic)
        println("   📖 $topic: $(length(topic_lessons)) lessons")
    end
    
    return lessons_by_topic
end

"""
Create partitioned lesson packs for each topic.
"""
function create_lesson_packs(lessons_by_topic::Dict{String, Vector{Lesson}}, output_dir::String)
    println("\\n📦 Creating lesson packs...")
    
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
    println("\\n🎲 Creating sample pack...")
    
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
    
    println("\\nEnter pack number, file path, or URL:")
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

# Export functions for use in other modules
export generate_lessons_from_files, 
       load_lesson_pack, 
       list_available_packs, 
       interactive_pack_selection,
       save_lesson_pack,
       string_to_lesson_topic
## Extracting Lessons from text chunks - this works surprisingly well 
using RAGTools 
using CSV, DataFrames


"""
You're a world-class data extraction engine built by OpenAI together with Google and to extract filter metadata to power the most advanced Data Science learning platform in the world. 

Extract concepts or lessons, definitions and examples, questions or exercises, and answers from the provided text. The extracted items should be relevant to Statistics, Machine Learning, or analyzing data with Python, SQL, or R.

It is incredibly important to extract useful concepts and lessons from the provided text - if something lacks context, or is not related to Statistics, Machine Learning, or analyzing data with Python, SQL, or R, it should not be extracted. You can fill in missing context with your own knowledge, but it must be relevant to the text provided and you must be absolutely certain in the accuracy of the information you provide.
    
    **Instructions for Extraction:**
    1. Carefully read through the provided Text
    2. Identify and extract:
       - One or two individual concepts or lessons contained in this text, such as how to calculate root mean squared error, the elements of xgboost learning, linear regression assumptions, or programming topics such as SQL windowing, etc.
       - Define the main concept or takeaway from the lesson and incorporate clear examples. Keep the definition concise and focused on the key points. Again, you can fill in missing context if the provided text is missing some details, but *only* if you are absolutely certain in the accuracy of the information you provide.
       - Identify a question or coding exercise that could be asked about the lesson - ensuring the anser is containd in the concept definition you just created
       - Answer to the question or exercise, which should be a direct answer to the question or exercise you just created
       - Give the lesson a short name
    
    **Example 1:**
    - Document Chunk: \"Any collection of possible outcomes X ⊆  is called an event; the previous
definition assigns a probability of P(X ) = |X |/|| to such an event. Events are sets
and we can apply the usual operations on them: Let A be as above the event of having
a sum of at least 10. Let us further denote by B the event that both dice show an
even number; thus, B = {(2, 2), (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (6, 2), (6, 4), (6, 6)}
and |B| = 9. The event C of rolling a sum of at least 10 and both dice even is then
described by the intersection of the two events:
 C = A ∩ B = {(4, 6), (6, 4), (6, 6)},
and has probability
 3
 P(C) = P(A ∩ B) = .
 36\"
    - Extracted items:
      - Short Name: Sets and events in probability theory
      - Concept or Lesson: how to calculate the probability of an event using the intersection of two events
      - Definition and Examples: Any collection of possible outcomes can be called an event, and the probability of an event can be calculated as the ratio of the number of outcomes in the event to the total number of outcomes. For example in a dice roll, if A is the event of rolling a sum of at least 10, and B is the event that both dice show an even number, then the intersection of these two events, C, represents the outcomes where both conditions are satisfied. The probability of this intersection can be calculated as P(C) = P(A ∩ B) = 3/36.
      - Question or Exercise: Let A be the event of having
    a sum of at least 10 in a dice roll. Let us further denote by B the event that both dice show an even number; thus, B = {(2, 2), (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (6, 2), (6, 4), (6, 6)} and |B| = 9. The event C of rolling a sum of at least 10 and both dice even is then
    described by the intersection of the two events:
    C = A ∩ B = {(4, 6), (6, 4), (6, 6)}. What is the probability of event C?
      - Answer: P(C) = P(A ∩ B) = 3/36

Some text will have no concepts or lessons, and will be just boilerplate information such as tables of content or forewords of books, random notes, in these cases, just return an empty list.

"""
struct Lesson 
    short_name::String # required field!
    concept_or_lesson::String # required field!
    definition_and_examples::String # required field!
    question_or_exercise::String # required field!
    answer::String # required field!
end

"""
## Select some resources to index in a RAG system 
allfiles = readdir("clean_txt")
r1 = allfiles[[1, 3]]

paths_to_files = joinpath.("clean_txt", r1)
# Build an index of chunks, embed them, and create a lookup index of metadata/tags for each chunk
import RAGTools as RT
mychunks = get_chunks(RT.FileChunker(),
	paths_to_files;
    sources = paths_to_files,
	verbose = true,
	separators = separators = ["\n\n", ". ", "\n", " "], 
    max_length = 1000)


#msg = aiextract(mychunks[1][1]; return_type=Lesson)
#msg.content
"""
function lessonsfromchunks(chunks)
    lessons = Lesson[]
    for chunk in chunks
        msg = aiextract(chunk; return_type=Lesson)
        if !isempty(msg.content)
            push!(lessons, msg.content)
        end
    end
    return lessons
end
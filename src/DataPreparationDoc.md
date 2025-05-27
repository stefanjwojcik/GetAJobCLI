# Data Preparation 


## Run a bash script to convert all files in a directory to text files
```bash 
./convert_all_files_to_txt.sh resources/Data Science Interview Resources
```

## Now open Julia, and use PromptingTools to classify the files as: 
```julia
import PromptingTools as PT 
# Load all file names 
files = readdir("all_txt")
sysprompt = """
You are a world-class organizer. You will be given a file name, and you will classify the file into one of the following categories:

1. TeachingResource - teaches core Statistics, Data Science, or Machine Learning concepts - not including a specific programming language.
2. ProgrammingLanguageResource - teaches a concept or idea but within the scope of a specific programming language, such as Python, SQL, R, or Julia. 
3. QuestionSet - a set of questions around a specific topic, such as a Data Science interview question set.
4. InterviewResource - a resource that provides insight into tech screens or specific interview instances at specific companies. 
5. Other - any other resource that does not fit into the above categories.
"""
context = 

```
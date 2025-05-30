import os

fortran_files_list_path = "fortran_files.txt"
documentation_base_dir = "documentation"

with open(fortran_files_list_path, 'r') as f:
    fortran_files = [line.strip() for line in f if line.strip()]

# Process files from index 750 to 799 (inclusive)
start_index = 750
end_index = 800 # Python slicing up to end_index-1

# Ensure we don't go out of bounds if the list is shorter
files_to_process = fortran_files[start_index:min(end_index, len(fortran_files))]

for fortran_file_path in files_to_process:
    if not fortran_file_path.endswith(".F"):
        print(f"Skipping non-Fortran file: {fortran_file_path}")
        continue

    # Remove the .F extension and add .md
    markdown_file_name = os.path.splitext(os.path.basename(fortran_file_path))[0] + ".md"

    # Construct the full path for the markdown file within the documentation directory
    markdown_file_dir = os.path.join(documentation_base_dir, os.path.dirname(fortran_file_path))
    markdown_file_path = os.path.join(markdown_file_dir, markdown_file_name)

    try:
        # Create the directory structure if it doesn't exist
        os.makedirs(markdown_file_dir, exist_ok=True)

        # Create the empty markdown file with a header
        with open(markdown_file_path, 'w') as md_file:
            md_file.write(f"# {os.path.splitext(os.path.basename(fortran_file_path))[0]}\n\n")
            md_file.write(f"Documentation for `{fortran_file_path}`\n")

        print(f"Successfully created: {markdown_file_path}")

    except Exception as e:
        print(f"Error creating file {markdown_file_path}: {e}")

print(f"Documentation file creation process completed for files from index {start_index} to {end_index-1}.")

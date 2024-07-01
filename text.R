# Install required packages if not already installed
library(httr2)

# Define your GitHub credentials (replace with your own)
github_username <- "timothy-hister"
github_pat <- readLines("../bc_ferries/token.txt")

# Replace with the details of your repository and file
repo_owner <- "timothy-hister"
repo_name <- "bc-ferries"
file_path <- "hello.txt"  # Adjust the path as needed

# Function to encode file content in base64
encode_file <- function(file_path) {
  file <- readLines(file_path)
  base64enc::base64encode(paste(file, collapse = "\n"))
}




# Generate personal access token (PAT) from GitHub settings if you don't have one
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

# Construct the API URLs
create_blob_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/blobs")
create_commit_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/commits")
create_tree_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/trees")
create_ref_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/refs/heads/main")

# Read file content
#file_content <- jsonlite::base64_enc(readBin(file_path, "raw", file.info(file_path$size)))

file_content = jsonlite::base64_enc(file_path)


# Create a blob with the file content
request(create_blob_url) |>
  req_headers(Authorization = paste0("token ", github_pat)) |>
  req_body_json(list(content = file_content, encoding = "base64")) |>
  req_perform()

if (!httr::status_code(blob_response) == 201) {
  stop("Error creating blob:", content(blob_response, as = "character"))
}

blob_sha <- content(blob_response, as = "json")$sha

# Create a tree object for the commit
tree_response <- POST(create_tree_url, 
                      add_headers(Authorization = paste0("token ", github_pat)),
                      body = list(
                        base_tree = "HEAD",  # Replace with appropriate base SHA if needed 
                        tree = list(path = basename(file_path), mode = "100644", type = "blob", sha = blob_sha)
                      ))

if (!httr::status_code(tree_response) == 201) {
  stop("Error creating tree:", content(tree_response, as = "character"))
}

tree_sha <- content(tree_response, as = "json")$sha

# Create a commit with the tree
commit_response <- POST(create_commit_url, 
                        add_headers(Authorization = paste0("token ", github_pat)),
                        body = list(
                          message = paste0("Committing file: ", basename(file_path)),
                          author = list(name = github_username),
                          parents = c("HEAD"),  # Replace with appropriate parent SHA if needed 
                          tree = tree_sha
                        ))

if (!httr::status_code(commit_response) == 201) {
  stop("Error creating commit:", content(commit_response, as = "character"))
}

commit_sha <- content(commit_response, as = "json")$sha

# Push the commit to the master branch
push_response <- PUT(create_ref_url, 
                     add_headers(Authorization = paste0("token ", github_pat)),
                     body = list(sha = commit_sha))

if (!httr::status_code(push_response) == 200) {
  stop("Error pushing commit:", content(push_response, as = "character"))
}

cat("Successfully committed and pushed file to GitHub!")
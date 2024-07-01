# Install required packages if not already installed
library(httr2)

# Define your GitHub credentials (replace with your own)
github_username <- "timothy-hister"
github_pat <- readLines("../bc_ferries/token.txt")

# Replace with the details of your repository and file
repo_owner <- "timothy-hister"
repo_name <- "text"
file_path <- "hello.txt"  # Adjust the path as needed




# Generate personal access token (PAT) from GitHub settings if you don't have one
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

# Construct the API URLs
create_blob_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/blobs")
create_commit_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/commits")
get_tree_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/trees/main")
create_tree_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/trees")
create_ref_url <- paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/git/refs/heads/main")
get_commits_url = paste0("https://api.github.com/repos/", repo_owner, "/", repo_name, "/branches/main")

# Read file content
#file_content <- jsonlite::base64_enc(readBin(file_path, "raw", file.info(file_path$size)))

file_content = jsonlite::base64_enc(file_path)


# Create a blob with the file content
blob_response = request(create_blob_url) |>
  req_headers(Authorization = paste0("token ", github_pat)) |>
  req_body_json(list(content = file_content, encoding = "base64")) |>
  req_perform()

stopifnot(blob_response$status_code == 201)

blob_sha = resp_body_json(blob_response)$sha

# last commit
last_commit_response = request(get_commits_url) |>
  req_perform()

stopifnot(last_commit_response$status_code == 200)

last_commit_sha = resp_body_json(last_commit_response)$commit$sha

request(create_tree_url) |>
  req_perform()


# tree
request(create_tree_url) |>
  req_headers(Authorization = paste0("token ", github_pat)) |>
  req_body_json(jsonlite::toJSON(list(base_tree = last_commit_sha, tree = list(path = file_path, mode = "100644", type = "blob", sha = blob_sha)))) |>
  req_perform()


# Create a tree object for the commit
tree_response <- request(create_tree_url) |>
  req_headers(Authorization = paste0("token ", github_pat)) |>
  req_body_json(list(base_tree = "HEAD", tree = list(path = basename(file_path), mode = "100644", type = "blob", sha = blob_sha))) |>
  req_perform()

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
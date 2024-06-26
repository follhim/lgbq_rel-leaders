# Install necessary packages (run only if not already installed)
# install.packages("pacman")

pacman::p_load(usethis, git2r)

# Set up your GitHub credentials
use_git_config(user.name = "follhim", user.email = "follhim@gmail.com")

# Clone your repository
repo <- clone("git@github.com:follhim/lgbq_rel-leaders.git", 
              "/Users/seungjukim/Library/CloudStorage/GoogleDrive-seungju7@illinois.edu/My Drive/LGBQxRel-Leaders/Analysis")

# Navigate to your repository directory
setwd("/Users/seungjukim/Library/CloudStorage/GoogleDrive-seungju7@illinois.edu/My Drive/LGBQxRel-Leaders/Analysis")

# Make changes to your repository (this part will vary depending on what changes you are making)

# Add all changes
add(repo, "*")

# Commit changes
commit(repo, "Initial upload")

# Push changes to GitHub
push(repo)

# Pull changes from GitHub
pull(repo)

# Replace "your-github-username", "your-email@example.com", and "path/to/local/dir" with your actual GitHub username, email, and the path to your local directory.
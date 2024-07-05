# Git Prepare Commit Message Script

This script automates the modification of Git commit messages to include prefixes based on branch names and appends a list of changed files.

## Installation

1. **Download the Script:** [prepare-commit-msg script](https://raw.githubusercontent.com/stdioh321/utils/main/git-pre-message-with-prefix/prepare-commit-msg)
   
2. **Save the Script:** Save the downloaded script as `.git/hooks/prepare-commit-msg` in your Git repository.

3. **Make it Executable:** Run `chmod +x .git/hooks/prepare-commit-msg` to make the script executable.

## Usage

On a terminal inside git repository:
```bash
curl -o .git/hooks/prepare-commit-msg https://raw.githubusercontent.com/stdioh321/utils/main/git-pre-message-with-prefix/prepare-commit-msg
# or using wget:
wget -O .git/hooks/prepare-commit-msg https://raw.githubusercontent.com/stdioh321/utils/main/git-pre-message-with-prefix/prepare-commit-msg

chmod +x .git/hooks/prepare-commit-msg
```

- Automatically adds prefixes (`feat`, `fix`, etc.) to commit messages based on branch names.
- Appends a list of created, deleted, and updated files at the end of each commit message.

## Examples

**Original Commit Message:**

```
Some commit message
```

**Modified Commit Message:**
```
fix(main): Some commit message

Created: package.json
Deleted: .env.old
Updated: .env.example

```

## Contributing

Feel free to contribute by opening issues or pull requests on the [GitHub repository](https://github.com/stdioh321/utils/tree/main/git-pre-message-with-prefix).

## License

This script is distributed under the MIT License. See LICENSE for more information.


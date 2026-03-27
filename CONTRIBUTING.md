# Contributing to CloudUpload

Thank you for your interest in contributing to CloudUpload!

## How to Contribute

### Reporting Bugs

- Search existing [issues](https://github.com/sxyseo/cloudupload/issues) before creating a new one
- Use the [bug report template](./.github/ISSUE_TEMPLATE/bug_report.yml) when available
- Include: OS, shell version, tool versions, error message, and steps to reproduce
- Run with `-x` (bash) or `-Debug` (PowerShell) and include debug output

### Suggesting Features

- Open a [feature request issue](https://github.com/sxyseo/cloudupload/issues/new?labels=enhancement)
- Describe the use case and cloud provider
- Explain why existing workarounds are insufficient

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes with tests
4. Ensure all scripts pass syntax checks:
   ```bash
   # Shell scripts
   bash -n script.sh

   # PowerShell scripts
   pwsh -c "Get-Command -Syntax script.ps1"
   ```
5. Commit with clear messages (follow [Conventional Commits](https://www.conventionalcommits.org/))
6. Push and open a Pull Request

### Code Style

- **Shell scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **PowerShell scripts**: Follow [Microsoft PowerShell style guide](https://learn.microsoft.com/en-us/powershell/scripting/community/contributing/artistic-guidelines)
- Use `shellcheck` to lint Shell scripts
- Use `PSScriptAnalyzer` to lint PowerShell scripts

### Adding a New Cloud Provider

1. Create `lib/{provider}.sh` and `lib/{provider}.ps1`
2. Implement `do_upload()` function with multi-level fallback (CLI → SDK → curl)
3. Implement `_generate_url()` function
4. Add provider detection in `config.sh` (`_normalize_provider()`)
5. Add tool detection in `lib/detect.sh` (`detect_tools()`)
6. Add upload method selection in `lib/detect.sh` (`get_upload_method()`)
7. Add routing in `upload` and `upload.ps1`
8. Add i18n strings in `i18n/i18n.sh` and `i18n/i18n.ps1`
9. Add provider entry in `config.example`
10. Add to table in `README.md`
11. Add to `CONTRIBUTING.md`

### Testing

```bash
# Test all syntax
for f in upload install.sh config.sh lib/*.sh; do bash -n "$f"; done

# Integration test (with mock credentials)
export UPLOAD_CONFIG_FILE=test.uploadrc
./upload test.txt my-profile
```

### Documentation

- Update `README.md` for user-facing changes
- Add inline comments for non-obvious code
- Update `CHANGELOG.md` under `## [Unreleased]`

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

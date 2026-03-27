# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please do **NOT** create a public GitHub issue.
Instead, email the maintainer directly or contact via GitHub Security Advisories.

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Security Best Practices

When using CloudUpload:

1. **Protect your config file**: `chmod 600 ~/.uploadrc`
2. **Use least-privilege credentials**: Use IAM/scoped keys with minimal permissions
3. **Rotate credentials regularly**: Don't commit real credentials to version control
4. **Use environment variables**: For CI/CD, pass credentials via environment variables instead of config files
5. **Validate HTTPS**: Always use HTTPS endpoints; never upload over plain HTTP
6. **Audit access logs**: Regularly review your cloud provider's access logs for unusual activity

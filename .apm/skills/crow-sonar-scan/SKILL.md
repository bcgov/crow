---
name: crow-sonar-scan
description: Triggers when the user asks for a code analysis, quality scan, or SonarQube / SonarCloud scan using the sonar-mcp server.
---

# Sonar Scan Skill

This skill contains instructions and automation guidelines for triggering SonarQube code scans through the `sonar-mcp` server. It outlines how to locate configuration settings, fallbacks, and parameter resolution logic prior to initiating a scan.

## Execution Rules & Pre-conditions

When a user requests a code analysis, quality gate check, or SonarQube scan, follow these preparation steps to construct the arguments for the scan tool.

### 1. Configuration File Parsing (`sonar.config`)
Always check the repository root for a `sonar.config` file first.
If `sonar.config` is present, read it and extract the following parameters:
- **Project Key** (`Project Key` or `projectKey`)
- **Project Name** (`Project Name` or `projectName`)
- **Version** (`Version` or `version`)
- **Exclusions** (`Exclusions` or `exclusions`)

Always read the repository root `.gitignore` as well. Resolve each non-comment `.gitignore` entry against the target repository and add it to the SonarQube exclusion configuration (`sonar.exclusions`) only when the entry matches at least one file or folder that actually exists in that repository. Do not add unmatched patterns from generic or default `.gitignore` files. Preserve any exclusions from `sonar.config` and merge both sets; translate `.gitignore` patterns to equivalent SonarQube glob patterns where their syntax differs.

### 2. Version Resolution Fallback Chain
If no version is specified in the `sonar.config` file, or if the `sonar.config` file is absent, determine the version using the following hierarchical fallback chain:

1. **`version.txt`**: Look for a file named `version.txt` in:
   - The repository root
   - Any project-specific subfolders/roots within the repository.
   If present, use its content as the version.
   
2. **`AssemblyInfo.cs`**: If `version.txt` is missing or empty, search for an `AssemblyInfo.cs` file under the main project's root folder.
   - Look for the `AssemblyVersion` or `AssemblyFileVersion` attribute (e.g., `[assembly: AssemblyVersion("1.0.0.0")]`).
   - Extract the version number within the quotes.

3. **`*.csproj`**: If neither of the above options yields a version, search for a `.csproj` file in the main project's root folder.
   - Look for the `<Version>` or `<AssemblyVersion>` XML element.
   - Extract the inner text as the version.

### 3. Project Key & Name Fallbacks
If the project key or project name cannot be resolved from the `sonar.config` file:
- **Project Key Fallback**: Use the repository folder name as the project key. Replace all spaces with dashes (`-`).
- **Project Name Fallback**: Base the project name on the repository folder name, formatted with proper capitalization and spaces (e.g., `my-cool-project` becomes `My Cool Project`).

### 4. Branch Determination
Retrieve the currently checked-out branch name for the repository being scanned. Provide this as the target branch name parameter for the Sonar scan.

## Scan Execution Method
Once all parameters have been successfully resolved, trigger the Sonar scan using the appropriate tool from the sonar-mcp server, supplying the resolved project key, branch, project path, and additional scan parameters.

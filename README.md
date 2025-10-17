# yagw - Yet Another Git Watcher

**yagw** is a PowerShell-based CLI tool that recursively scans a directory tree to discover Git repositories and provides a clear overview of their status. It can also perform batch `git pull` operations on repositories that are behind their remote counterparts.

---

## Features

- **Recursive Git Repository Discovery**: Scans directories up to a configurable depth to find Git repositories.
- **Status Overview**: Displays the current branch, sync status with remote, and working directory changes.
- **Parallel Execution**: Uses PowerShell 7+ parallelism to speed up repository checks.
- **Batch Git Pull**: Optionally pulls updates for repositories that are behind their remote.
- **Dry Run Mode**: Simulate pull operations without executing them.
- **Configurable via JSON or CLI**: Customize behavior using `config.json` or command-line arguments.

---

## Installation

1. **Clone the repository**:

```powershell
git clone https://github.com/andreabsferrazza/yagw.git
cd yagw
```

2. **Run the installation script**:

```powershell
./install.ps1
```

> If this is not your first time running the installation, manually check your PowerShell profile:
> ```powershell
> notepad $PROFILE
> ```
---

## Usage

```powershell
yagw [status|pull] [options]
```

### Options

| Option | Description |
|--------|-------------|
| `status` | Discover Git repositories and display their status |
| `pull` | Pull updates for repositories that are behind their remote and with no changes pending,. require confirmation|
| `--maxdepth <n>` | Set max recursion depth (default: 4) |
| `--basepath "<path>"` | Set base directory to start scanning (default: current dir) |
| `--disable-clear-screen` or `-d` | Prevent screen clearing before output |
| `--dry-run` | Simulate `git pull` without executing it |
| `--version` or `-v` | Show yagw version |
| `--help` or `-h` | Show help message |

> CLI options override `config.json` settings.

---

## Configuration File

You can create a `config.json` file in the root directory to define default settings:

```json
{
  "basePath": ".",
  "maxDepth": 4,
  "excludedFolders": ["node_modules", ".venv"],
  "enableClearScreen": true,
  "noParallel": false
}
```

---

## Examples

### Check status of all Git repos under current directory:

```powershell
yagw status
```

### Check status with max depth 3:

```powershell
yagw status --maxdepth 3
```

### Pull updates for all repos that are behind and have no changes pending:

```powershell
yagw pull
```
> It will ask for confirmation before executing git pull

### Simulate pull without executing:

```powershell
yagw pull --dry-run
```

### Disable screen clearing and parallel execution:

```powershell
yagw status --disable-clear-screen --no-parallel
```

# Java Module

This module provides multiple Java versions (8 and 17) with directory-based version switching capabilities.

## Features

- Java 8 (OpenJDK 8)
- Java 17 (OpenJDK 17) - Default
- Directory-based version switching with direnv
- Manual version switching with commands

## Usage

### Global Java Version Switching

```bash
# Switch to Java 8
java8
# or
java-switch 8

# Switch to Java 17
java17
# or
java-switch 17
```

### Directory-based Java Version (with direnv)

Create a `.envrc` file in your project directory:

For Java 8:
```bash
use_java_8
```

For Java 17:
```bash
use_java_17
```

Then run `direnv allow` in the directory.

### Example Project Setup

```bash
# Java 8 project
mkdir my-java8-project
cd my-java8-project
echo "use_java_8" > .envrc
direnv allow

# Java 17 project
mkdir my-java17-project
cd my-java17-project
echo "use_java_17" > .envrc
direnv allow
```

## Environment Variables

- `JAVA_HOME`: Points to the active Java installation
- `PATH`: Modified to include the active Java binaries

## Default Configuration

- Default Java version: Java 17
- Available through global PATH and JAVA_HOME
- Compatible with existing Scala/sbt configurations
# Contributing to GaitGuard

Thank you for your interest in contributing to GaitGuard! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template** if available
3. **Include detailed information**:
   - Device model and Android/iOS version
   - Flutter version (`flutter --version`)
   - Steps to reproduce the issue
   - Expected vs actual behavior
   - Screenshots or logs if applicable

### Suggesting Features

1. **Open an issue** with the "feature request" label
2. **Describe the problem** you're trying to solve
3. **Propose your solution** with as much detail as possible
4. **Consider alternatives** you've thought about

### Submitting Code

#### Getting Started

1. **Fork the repository**
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/GaitGuard.git
   cd GaitGuard
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Install dependencies**:
   ```bash
   flutter pub get
   ```

#### Development Guidelines

##### Code Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`
- Keep lines under 80 characters when practical

##### Architecture

- Follow the existing **Clean Architecture** pattern
- Place business logic in **services** (`lib/core/services/`)
- Use **repositories** for data access (`lib/data/repositories/`)
- Use **Cubit** for state management (`lib/features/*/logic/`)
- Keep UI components in feature-specific `ui/` folders

##### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `gait_feature_extractor.dart` |
| Classes | PascalCase | `GaitFeatureExtractor` |
| Variables/Functions | camelCase | `extractFeatures()` |
| Constants | lowerCamelCase | `defaultSamplingRate` |
| Private members | _prefixed | `_calculateVariance()` |

##### Testing

- Write tests for new features
- Place tests in the `test/` directory
- Name test files with `_test.dart` suffix
- Run tests before submitting:
  ```bash
  flutter test
  ```

#### Commit Guidelines

Use clear, descriptive commit messages:

```
type(scope): brief description

- Detailed explanation if needed
- List changes made
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(gait): add step frequency smoothing algorithm
fix(calibration): resolve crash on session timeout
docs(readme): update installation instructions
test(auth): add login failure test cases
```

#### Pull Request Process

1. **Update documentation** if needed
2. **Add/update tests** for your changes
3. **Ensure all tests pass**:
   ```bash
   flutter test
   flutter analyze
   ```
4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
5. **Open a Pull Request** with:
   - Clear title describing the change
   - Description of what and why
   - Link to related issues
   - Screenshots for UI changes

#### Review Process

- Maintainers will review your PR
- Address any requested changes
- Once approved, your PR will be merged

## Development Setup

### Prerequisites

- Flutter SDK 3.10.3+
- Android Studio or VS Code with Flutter extensions
- Physical Android device (recommended for sensor testing)

### Running Locally

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze
```

### Project Structure

```
lib/
├── core/           # Core services and utilities
├── data/           # Models and repositories
├── features/       # Feature modules (auth, gait, app_lock, etc.)
├── navigation/     # App routing
├── widgets/        # Shared UI components
└── main.dart       # Entry point
```

## Areas for Contribution

We especially welcome contributions in these areas:

- **ML Integration**: TensorFlow Lite model implementation
- **Testing**: Expanding test coverage
- **Documentation**: Improving docs and code comments
- **iOS Support**: Enhancing iOS-specific functionality
- **Accessibility**: Improving app accessibility
- **Localization**: Adding language translations

## Questions?

If you have questions about contributing, feel free to open an issue with the "question" label.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

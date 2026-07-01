---
applyTo: "**/*.go"
---

# Go Development Instructions

You are an expert in Go (Golang) development.

## Go Best Practices

- Follow the Go Code Review Comments and Effective Go guidelines
- Use gofmt for consistent formatting
- Run golint and go vet regularly
- Use meaningful package names that are short and lowercase
- Prefer composition over inheritance
- Use interfaces for abstraction and testability
- Handle errors explicitly and meaningfully
- Use context.Context for cancellation and timeouts
- Follow the principle of least surprise

## Code Organization

- Organize code in packages with clear responsibilities
- Use internal packages for implementation details
- Keep main packages small and focused
- Use pkg/ for library code that can be imported by external applications
- Use cmd/ for application entry points
- Use meaningful directory and file names
- Group related functionality in the same package

## Error Handling

- Always check and handle errors appropriately
- Use meaningful error messages with context
- Wrap errors with additional context using fmt.Errorf with %w verb
- Create custom error types when needed
- Use errors.Is and errors.As for error checking
- Don't ignore errors unless explicitly intended
- Log errors at appropriate levels

## Concurrency

- Use goroutines for concurrent operations
- Use channels for communication between goroutines
- Implement proper synchronization with sync package when needed
- Use context for cancellation and timeouts
- Avoid shared mutable state when possible
- Use sync.WaitGroup for waiting on multiple goroutines
- Implement proper graceful shutdown patterns

## Testing

- Write comprehensive unit tests using the testing package
- Use table-driven tests for multiple test cases
- Use testify for assertions and mocking when needed
- Implement integration tests for external dependencies
- Use build tags for test-specific code
- Achieve good test coverage but focus on critical paths
- Use benchmarks for performance-critical code

## HTTP and Web Services

- Use the standard net/http package or proven frameworks like Gin or Echo
- Implement proper middleware for cross-cutting concerns
- Use proper HTTP status codes and error responses
- Implement request validation and sanitization
- Use proper JSON handling with struct tags
- Implement proper authentication and authorization
- Add proper logging and monitoring

## Database Interactions

- Use database/sql with proper drivers
- Implement connection pooling and proper connection management
- Use prepared statements to prevent SQL injection
- Handle database transactions properly
- Use migrations for schema management
- Implement proper error handling for database operations
- Use context for query timeouts

## Configuration and Environment

- Use environment variables for configuration
- Implement configuration validation
- Use proper defaults for configuration values
- Use configuration structs with proper tags
- Implement configuration reloading when needed
- Use secure practices for sensitive configuration

## Performance and Optimization

- Use profiling tools (pprof) to identify bottlenecks
- Implement proper caching strategies
- Use buffered I/O when appropriate
- Avoid premature optimization
- Use proper data structures for the use case
- Implement proper memory management
- Use benchmarks to measure performance improvements

## Security

- Validate and sanitize all inputs
- Use proper authentication and authorization
- Implement rate limiting
- Use HTTPS and proper TLS configuration
- Handle secrets securely
- Implement proper logging without exposing sensitive data
- Use static analysis tools for security scanning

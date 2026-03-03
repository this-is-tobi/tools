---
applyTo: "**/*.{js,ts,jsx,tsx,mjs,cjs}"
---

# JavaScript & TypeScript Instructions

You are an expert in modern JavaScript and TypeScript development.

## TypeScript Guidelines

- Always use strict TypeScript configuration
- Prefer interfaces over types for object shapes
- Use proper generic constraints and conditional types
- Implement proper error handling with typed errors
- Use discriminated unions for complex state management
- Prefer composition over inheritance
- Always define return types for functions
- Use readonly for immutable data structures
- Leverage utility types (Partial, Required, Pick, Omit, Record)

## Modern JavaScript/TypeScript Patterns

- Use ES6+ features (async/await, destructuring, arrow functions)
- Prefer functional programming patterns
- Use proper module imports/exports (ESM)
- Implement proper error boundaries and error handling
- Use modern array methods (map, filter, reduce, find)
- Prefer const over let, avoid var
- Use template literals for string interpolation
- Implement proper async/await error handling with try/catch

## Code Quality

- Follow consistent naming conventions (camelCase for variables/functions, PascalCase for classes/types)
- Write self-documenting code with meaningful variable names
- Include proper JSDoc comments for public APIs
- Use proper TypeScript utility types
- Implement proper validation and sanitization
- Follow SOLID principles
- Use dependency injection for better testability

## Testing

- Write unit tests for all business logic
- Use descriptive test names that explain the behavior
- Follow AAA pattern (Arrange, Act, Assert)
- Mock external dependencies properly
- Use proper TypeScript types in tests
- Implement integration tests for critical paths
- Use test-driven development when appropriate

## Performance

- Use lazy loading and code splitting appropriately
- Implement proper caching strategies
- Use web workers for CPU-intensive tasks
- Optimize bundle sizes and tree shaking
- Use proper memory management patterns
- Implement efficient data structures and algorithms

## Node.js Specific

- Use proper environment variable management
- Implement graceful shutdown handling
- Use structured logging
- Handle uncaught exceptions and promise rejections
- Use proper middleware patterns for Fastify
- Implement rate limiting and security headers
- Use proper connection pooling for databases

## Bun (alternative runtime)

- Use Bun as a drop-in Node.js alternative for significantly faster startup, test runs, and package installs
- Use `bun install` instead of `npm install` / `pnpm install`; Bun reads `package.json` natively
- Use `bun test` for unit tests (Jest-compatible API, no extra packages needed)
- Use `bun run` to execute scripts; use `bun build` for bundling (replaces esbuild for simple cases)
- Use `Bun.serve()` for lightweight HTTP servers without a framework dependency
- Use `Bun.file()` / `Bun.write()` for fast file I/O instead of `fs`
- Use `bun --hot` for hot reloading during development instead of nodemon/ts-node-dev
- Bun natively supports TypeScript, JSX, `.env` files, and top-level `await` — no extra config needed
- Check `Bun.version` / `which bun` in CI to ensure the runtime is available before running scripts

## Frontend Specific

- Use proper state management patterns
- Implement accessibility (a11y) best practices
- Use semantic HTML elements
- Implement proper error boundaries
- Use progressive enhancement principles
- Optimize for Core Web Vitals
- Implement proper CSP and security headers

## API Development

- Use OpenAPI/Swagger for API documentation
- Implement proper request validation
- Use proper HTTP status codes
- Implement proper authentication and authorization
- Use proper error response formats
- Implement API versioning strategies
- Use proper pagination for large datasets

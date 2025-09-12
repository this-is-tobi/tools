# TypeScript Monorepo Instructions

You are an expert in modern JavaScript and TypeScript development with strong DevOps skills. You will provide comprehensive instructions for setting up, developing, and maintaining a high-quality JavaScript/TypeScript project, ensuring best practices in code quality, security, performance, and maintainability. It is crucial to follow these guidelines meticulously to ensure the project adheres to industry standards and is robust, scalable, and secure.

## TypeScript Guidelines

- Always use strict TypeScript configuration (this is mandatory)
- Avoid using the `any` type; prefer `unknown` or specific types
- Prefer interfaces over types for object shapes
- Use proper generic constraints and conditional types
- Implement proper error handling with typed errors
- Use discriminated unions for complex state management
- Prefer composition over inheritance
- Always define return types for functions
- Use readonly for immutable data structures
- Leverage utility types (Partial, Required, Pick, Omit, Record)
- Rely on zod schema for type inference when validating data

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

- Follow consistent naming conventions (camelCase for variables/functions, PascalCase for classes/types/vue components)
- Write self-documenting code with meaningful variable names
- Include proper JSDoc comments for public APIs
- Use proper TypeScript utility types
- Implement proper validation and sanitization
- Follow SOLID principles
- Use dependency injection for better testability
- Check for existing functions/libraries before implementing new ones
- Avoid code duplication by creating reusable functions/components
- Ensure code is modular and follows the Single Responsibility Principle
- Regularly refactor code to improve readability and maintainability
- Always follow linter rules and fix all warnings/errors using Eslint
- Always type all variables, function parameters, and return types that are not inferred (avoid `any` type)
- Use consistent formatting and indentation (configured in ESLint)
- Avoid deeply nested code (use early returns or helper functions)
- Keep functions small and focused (ideally under 20 lines)
- Keep components small and focused (ideally under 200 lines)
- Keep files small and focused (ideally under 300 lines)
- Keep the cyclomatic complexity low (ideally under 10)
- Keep the dependency graph simple and avoid circular dependencies
- Keep the codebase clean and remove unused code, dependencies, and comments
- Keep the codebase simple and avoid over-engineering

## Testing

- Write unit tests for all business logic
- Use descriptive test names that explain the behavior
- Follow AAA pattern (Arrange, Act, Assert)
- Mock external dependencies properly
- Use proper TypeScript types in tests
- Implement integration tests for critical paths
- Use test-driven development when appropriate
- Ensure high unit test coverage (aim for 90%+)
- Use code coverage tools
- Write end-to-end tests for all user flows
- Use `<filename>.spec.ts` naming convention for test files
- Use proper setup and teardown methods
- Use consistent test data and fixtures
- Write unit tests alongside the code they test
- Ignore coverage for code that does not need testing (e.g., DTOs, types, interfaces, index files that only re-export, etc.)
- Keep tests isolated and independent

## Performance

- Use lazy loading and code splitting appropriately
- Implement proper caching strategies
- Use web workers for CPU-intensive tasks
- Optimize bundle sizes and tree shaking
- Use proper memory management patterns
- Implement efficient data structures and algorithms
- Avoid unnecessary re-renders in frontend applications
- Use debouncing/throttling for event handlers
- Optimize database queries and indexing strategies if applicable

## Node.js Specific

- Always use the latest LTS version of Node.js
- Use async/await for asynchronous operations
- Avoid blocking the event loop
- Use environment variables for configuration
- Implement proper logging and monitoring
- Use proper environment variable management
- Implement graceful shutdown handling
- Use structured logging
- Handle uncaught exceptions and promise rejections
- Use proper middleware patterns for Fastify
- Implement rate limiting and security headers
- Use proper connection pooling for databases

## Frontend Specific

- Use proper state management patterns
- Implement accessibility (a11y) best practices
- Use semantic HTML elements
- Implement proper error boundaries
- Use progressive enhancement principles
- Optimize for Core Web Vitals
- Implement proper CSP and security headers
- Follow responsive design principles
- Follow mobile-first design principles
- Use Tailwind CSS for consistent styling
- Use component libraries (e.g., shadcn-vue) for consistent UI/UX
- Use Vue Router for client-side routing
- Use Pinia for state management in Vue applications
- Use Axios for making HTTP requests
- Use Vite for frontend tooling and development server

## API Development

- Use OpenAPI/Swagger for API documentation
- Implement proper request validation
- Use proper HTTP status codes
- Implement proper authentication and authorization
- Use proper error response formats
- Implement API versioning strategies (`/api/v1/resource`)
- Use proper pagination for large datasets (limit, offset)

## Deployment

- Always consider running in cloud environments (Kubernetes)
- Keep the application stateless (avoid in-memory storage, state or sessions)
- Use environment variables for configuration
- Implement health checks and readiness probes
- Use containerization (Docker) for consistent environments

## Metrics and Monitoring

- Implement structured logging
- Use compatible code with monitoring tools (Prometheus, Grafana)
- Track application performance metrics
- Implement tracing for critical paths

## Security Best Practices

- Sanitize all user inputs to prevent XSS and SQL Injection
- Use HTTPS for all communications in production
- Implement proper authentication and authorization mechanisms
- Store sensitive data securely (e.g., use environment variables, secrets management)
- Regularly update dependencies to patch known vulnerabilities
- Use security headers (e.g., Content Security Policy, X-Content-Type-Options)
- Implement rate limiting to prevent brute-force attacks
- Avoid exposing stack traces and sensitive information in error messages
- Use libraries to set secure HTTP headers

## Documentation

- Maintain a comprehensive README.md with setup, usage, and contribution guidelines
- Use inline comments to explain complex logic
- Document public APIs with JSDoc or similar tools
- Keep documentation up to date with code changes
- Use diagrams and examples where applicable to enhance understanding

## Tools and Libraries

- Use [proto](https://moonrepo.dev/proto) for version management
- Use [nodejs](https://nodejs.org/) in LTS version
- Use [pnpm](https://pnpm.io/) as the package manager
- Use [typescript](https://www.typescriptlang.org/) with strict mode enabled
- Use [husky](https://typicode.github.io/husky/#/) for git hooks
- Use [lint-staged](https://github.com/lint-staged/lint-staged) to run linters on staged files
- Use [commitlint](https://commitlint.js.org/#/) with [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for commit message conventions
- Use [vite](https://vitejs.dev/) for frontend tooling
- Use [turbo](https://turbo.build/) for monorepo management if needed
- Use [eslint](https://eslint.org/) and [@antfu/eslint-config](https://github.com/antfu/eslint-config) for code linting and formating (do not use prettier)
- Use [fastify](https://www.fastify.io/) for building APIs
  - Use [@fastify/helmet](https://github.com/fastify/fastify-helmet) to set security headers
  - Use [@fastify/csrf-protection](https://github.com/fastify/csrf-protection) with [@fastify/cookie](https://github.com/fastify/fastify-cookie) for CSRF protection
  - Use [@fastify/swagger](https://github.com/fastify/fastify-swagger) for API documentation
  - Use [@fastify/swagger-ui](https://github.com/fastify/fastify-swagger-ui) for serving API docs
  - Use [@fastify/websocket](https://github.com/fastify/fastify-websocket) if WebSocket support is needed
- Use [vitest](https://vitest.dev/) for unit testing
- Use [playwright](https://playwright.dev/) for end-to-end testing
- Use [zod](https://zod.dev/) for schema validation
- Use [prisma](https://www.prisma.io/) as the ORM if a database is used
- Use [tsup](https://tsup.egoist.dev/) for building and bundling
- Use [pino](https://getpino.io/#/) for logging
- Use [better-auth](https://www.better-auth.com/docs/comparison) for authentication and authorization
- Use [tRPC](https://trpc.io) for type-safe APIs between services if microservices architecture is used
- Use [vue](https://vuejs.org/) for frontend development
- Use [pinia](https://pinia.vuejs.org/) for state management in Vue
- Use [vue-router](https://router.vuejs.org/) for routing in Vue applications
- Use [axios](https://axios-http.com/) for making HTTP requests
- Use [tailwindcss](https://tailwindcss.com/) for utility-first CSS
- Use [shadcn-vue](https://www.shadcn-vue.com/) for UI components based on Tailwind CSS
- Use [Vitepress](https://vitepress.vuejs.org/) for documentation sites
- Use [Docker](https://www.docker.com/) for containerization
- Use [Makefile](https://www.gnu.org/software/make/) for task automation
- Use [Prototools](https://moonrepo.dev/prototools) for managing project tasks and scripts

## Project Structure

```txt
.
├── .github/                # GitHub workflows and issue templates
├── .husky/                 # Husky git hooks
├── apps/                   # Application source code
│   ├── api/                # API application (Fastify)
│   ├── web/                # Frontend application (Vite)
│   ├── docs/               # Documentation (Vitepress)
│   └── ...                 # Other applications
├── ci/                     # CI/CD configurations and scripts
├── packages/               # Shared packages
│   ├── eslint/             # ESLint configuration
│   ├── backend-utils/      # Shared utilities accross backend applications
│   ├── frontend-utils/     # Shared utilities accross frontend applications
│   ├── schemas/            # Shared Zod schemas
│   ├── shared/             # Shared code (functions, const, etc...) between frontend and backend
│   ├── test-utils/         # Shared testing utilities
│   ├── types/              # Shared TypeScript types
│   ├── typescript/         # TypeScript configuration
│   └── ...                 # Other shared packages
├── scripts/                # Bash scripts for automation
├── tests/                  # Integration and e2e tests (Playwright)
├── commitlint.config.js    # Commitlint configuration
├── eslint.config.js        # ESLint configuration
├── lint-staged.config.js   # lint-staged configuration
├── package.json            # Project manifest
├── pnpm-workspace.yaml     # pnpm workspace configuration
├── Makefile                # Makefile for common tasks
├── README.md               # Project README
├── turbo.json              # Turborepo configuration
├── .dockerignore           # Docker ignore file
├── .gitignore              # Git ignore file
├── .prototools             # Prototools configuration
└── ...
```

## Task flow

On each task, follow these steps:
- Always pull changes from the main branch to keep your branch up to date
- Deeply evaluate the current state of the repository
- Avoid duplication by reusing existing code or libraries, or opt for refactoring if necessary
- Always refer to the project structure when adding new files or folders
- Add or update types and interfaces as needed
- Add or update zod schemas for data validation
- Never use `any` type, prefer `unknown` (highly prefer using specific types)
- Add or update tests to cover new or changed functionality
- Update documentation (README, inline comments, JSDoc) to reflect changes
- Check that linting, building and tests are passing (using `pnpm run lint`, `pnpm run build`, `pnpm run test`)
- Double-check that changes do not introduce breakings along the application
- Double-check that changes adhere to best practices and guidelines mentioned above
- Commit changes with meaningful commit messages following the Conventional Commits specification
- Push changes to a dedicated branch (avoid using `--no-verify` flag)
- Open a pull request with a detailed description of the changes made
- Follow the best practices and guidelines mentioned above

---
applyTo: "**/*.py"
---

# Python Development Instructions

You are an expert in Python development following modern best practices.

## Project Setup

- Use `pyproject.toml` as the single configuration source (PEP 517/518)
- Use `uv` or `poetry` for dependency and virtual environment management
- Pin exact dependency versions in lock files for reproducible builds
- Use `src/` layout for installable packages to avoid import confusion
- Always include a `py.typed` marker for typed packages

## Code Style & Formatting

- Use `ruff` for linting and formatting (replaces flake8, black, isort, pyupgrade)
- Enforce strict `mypy` type checking: `disallow_untyped_defs = true`
- Follow PEP 8; use `ruff format` for consistent style
- Maximum line length: 100 characters
- Use double quotes for strings consistently

## Type Annotations

- Annotate all function signatures (parameters and return types)
- Use `from __future__ import annotations` for forward references
- Prefer built-in generics (`list[str]`, `dict[str, int]`) over `typing.List`, `typing.Dict` (Python 3.9+)
- Use `TypeAlias` and `TypeVar` for reusable types
- Use `Protocol` for structural typing instead of abstract base classes
- Use `dataclasses` or `pydantic` for structured data; prefer pydantic for validation

## Code Quality

- Keep functions small and focused (< 25 lines as a guide)
- Use early returns to reduce nesting
- Prefer explicit over implicit; avoid magic numbers
- Use `pathlib.Path` over `os.path` for file operations
- Use context managers (`with`) for resource management
- Avoid mutable default arguments; use `None` sentinel instead
- Use `__slots__` for performance-critical classes

## Error Handling

- Raise specific exceptions; never bare `except:` or `except Exception` without re-raising
- Create custom exception hierarchies for domain errors
- Use `contextlib.suppress` for intentional ignoring of specific errors
- Provide meaningful error messages with context
- Use structured logging (`structlog` or `logging` with JSON formatter)

## Testing

- Use `pytest` with `pytest-cov` for coverage
- Target 90%+ coverage for business logic; exclude tests, migrations, type stubs
- Use `pytest.fixture` for test data; prefer factory functions over hard-coded fixtures
- Use `pytest.mark.parametrize` for table-driven tests
- Mock external I/O with `pytest-mock` or `unittest.mock`; never hit real network in unit tests
- Name test files `test_<module>.py`; use descriptive test names: `test_<function>_<scenario>`
- Use `pytest-asyncio` for async code

## Async Programming

- Use `asyncio` with `async`/`await` for I/O-bound concurrency
- Use `anyio` or `trio` as the async backend abstraction in libraries
- Never mix sync blocking I/O inside async functions
- Use `asyncio.TaskGroup` (Python 3.11+) or `anyio.create_task_group()` for structured concurrency
- Set timeouts on all network calls

## Security

- Never use `eval()` or `exec()` on untrusted input
- Use `secrets` module for cryptographic randomness; never `random`
- Validate and sanitize all external inputs with pydantic or marshmallow
- Use parameterized queries for databases; never string-format SQL
- Store secrets in environment variables; use `python-dotenv` for local dev only
- Scan dependencies with `pip-audit` or `safety`

## Performance

- Profile with `cProfile` or `py-spy` before optimizing
- Use `__slots__` to reduce memory for value objects
- Prefer generators and iterators over loading full datasets into memory
- Use `functools.lru_cache` / `functools.cache` for expensive pure functions
- Use `multiprocessing` for CPU-bound, `asyncio` for I/O-bound workloads

## API Development (FastAPI)

- Use FastAPI for all new APIs: automatic OpenAPI docs, async-first, native pydantic v2 integration
- Define every request and response with a pydantic `BaseModel`; never pass raw dicts to route handlers
- Use `Annotated` + `Depends()` for dependency injection (DB sessions, auth, config)
- Return proper HTTP status codes; raise `HTTPException` with a clear `detail` message
- Use `APIRouter` to split route groups into separate modules; mount under a versioned prefix (`/api/v1/`)
- Implement pagination for all list endpoints using cursor or offset+limit schemes
- Add `/healthz` (liveness) and `/readyz` (readiness) endpoints
- Use lifespan context managers (`@asynccontextmanager` on `lifespan=`) for startup/shutdown logic

## Common Patterns

```python
# Preferred: pathlib for paths
from pathlib import Path
config_path = Path(__file__).parent / "config.toml"

# Preferred: dataclass for simple value objects
from dataclasses import dataclass, field

@dataclass(frozen=True)
class Config:
    host: str
    port: int = 8080
    tags: list[str] = field(default_factory=list)

# Preferred: context manager for resource cleanup
from contextlib import contextmanager

@contextmanager
def managed_resource():
    resource = acquire()
    try:
        yield resource
    finally:
        resource.release()

# Preferred: structured error with context
class ServiceError(Exception):
    def __init__(self, message: str, *, cause: Exception | None = None) -> None:
        super().__init__(message)
        self.__cause__ = cause
```

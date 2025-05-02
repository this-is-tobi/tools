import antfu from '@antfu/eslint-config'

export default antfu(
  {
    stylistic: {
      overrides: {
        'antfu/if-newline': 'off',
        'jsonc/sort-keys': 'off',
        'no-console': 'off',
        'node/prefer-global/process': ['error', 'always'],
        'node/prefer-global/console': ['error', 'always'],
        'node/prefer-global/buffer': ['error', 'always'],
        'style/comma-dangle': ['error', 'always-multiline'],
        'style/quote-props': ['error', 'as-needed', { keywords: false, unnecessary: true }],
        'style/brace-style': ['error', '1tbs', { allowSingleLine: true }],
        'style/max-statements-per-line': ['error', { max: 2 }],
        'ts/ban-ts-comment': 'off',
        'unused-imports/no-unused-imports': 'error',
        'unused-imports/no-unused-vars': ['error', { vars: 'all', varsIgnorePattern: '^_', args: 'after-used', argsIgnorePattern: '^_', caughtErrors: 'all', caughtErrorsIgnorePattern: '^_', destructuredArrayIgnorePattern: '^_' }],
        'vue/no-v-html': 'off',
        'vue/no-irregular-whitespace': 'off',
        'vue/script-indent': 'off',
      },
    },
    typescript: true,
    yaml: {
      overrides: {
        'yaml/quotes': ['error', { prefer: 'double' }],
        'yaml/indent': ['error', 2, { indentBlockSequences: false }],
      },
    },
    ignores: [
      '**/node_modules',
      '**/pnpm-lock.yaml',
      '**/.turbo',
      '**/dist/',
      '**/types/',
      '**/coverage/',
      '**/templates/**/*.{yaml,yml}',
      '**/Chart.yaml',
      '**/*.d.ts',
      '**/*.md/*.js',
      '**/*.md/*.ts',
      '**/eslint.config.js',
    ],
  },
)

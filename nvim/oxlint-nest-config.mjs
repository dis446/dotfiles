const andNestOxlintConfig = {
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['**/dist/**', '**/build/**'],
  rules: {
    'typescript/no-explicit-any': 'off',
    'typescript/no-floating-promises': 'warn',
    'typescript/no-unsafe-argument': 'off',
    'typescript/no-unsafe-assignment': 'off',
    'typescript/no-unsafe-call': 'off',
    'typescript/no-unsafe-member-access': 'off',
    'typescript/no-unsafe-return': 'off',
    'typescript/restrict-template-expressions': 'off',
  },
};

export default andNestOxlintConfig;

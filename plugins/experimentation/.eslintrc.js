module.exports = {
  root: true,
  extends: 'airbnb-base',
  env: {
    browser: true,
  },
  parser: '@babel/eslint-parser',
  parserOptions: {
    allowImportExportEverywhere: true,
    sourceType: 'module',
    requireConfigFile: false,
  },
  rules: {
    // allow reassigning param
    'no-param-reassign': [2, { props: false }],
    'linebreak-style': ['error', 'unix'],
    'import/extensions': ['error', {
      js: 'always',
    }],
    // allow importing from these modules
    'import/no-unresolved': ['error', {
      ignore: [
        '@playwright/test',
        'monocart-coverage-reports',
        './lib-franklin.js',
        './cookie-consent/lib-cookie-consent.js',
        './analytics/lib-analytics.js',
      ],
    }],
  },
};

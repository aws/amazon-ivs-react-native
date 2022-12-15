module.exports = {
  "rootDir": "..",
  "testMatch": ["<rootDir>/e2e/**/*.e2e.js"],
  "testTimeout": 2400000,
  "verbose": true,
  "maxWorkers": 1,
  "reporters": ["detox/runners/jest/reporter"],
  "globalSetup": "detox/runners/jest/globalSetup",
  "globalTeardown": "detox/runners/jest/globalTeardown",
  "testEnvironment": "detox/runners/jest/testEnvironment"
};

// Jest setup file for parallels-contract
// This file runs before each test file

// Ensure Hardhat loads from the project directory
const path = require('path');
const expectedCwd = __dirname;
try {
  if (process.cwd() !== expectedCwd) {
    process.chdir(expectedCwd);
  }
} catch (_) {}

// Import jest-websocket-mock once for side effects (CommonJS)
require('jest-websocket-mock');

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  // Uncomment to ignore a specific log level
  // log: jest.fn(),
  // debug: jest.fn(),
  // info: jest.fn(),
  // warn: jest.fn(),
  // error: jest.fn(),
};

// Set up test environment variables
process.env.NODE_ENV = 'test';

// Do not override global WebSocket: jest-websocket-mock patches it internally

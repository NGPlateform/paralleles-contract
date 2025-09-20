// Jest setup file for testing
// Set environment variables before importing hardhat
process.env.HARDHAT_NETWORK = 'hardhat';

// Global test setup
beforeAll(async () => {
  // Setup global test environment
  console.log("Setting up test environment...");
});

afterAll(async () => {
  // Cleanup after all tests
  console.log("Cleaning up test environment...");
});

const { activate, deactivate } = require("../src/extension.js");

describe("extension", () => {
  it("exports activate and deactivate", () => {
    expect(typeof activate).toBe("function");
    expect(typeof deactivate).toBe("function");
  });
});

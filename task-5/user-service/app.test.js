const request = require("supertest");
const app = require("./app");

describe("GET /health", () => {
  it("returns service health payload", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      status: "ok",
      service: "user-service"
    });
  });
});
